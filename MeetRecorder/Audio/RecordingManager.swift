import AVFoundation
import Combine

/// The single thing the popover is doing right now. Drives the state-first UI.
enum RecordingPhase: Equatable {
    case idle
    case recording(MeetingRecord)
    case processing(String)   // localized stage label

    var isRecording: Bool {
        if case .recording = self { return true }
        return false
    }
}

@MainActor
final class RecordingManager: ObservableObject {
    @Published var isRecording = false
    @Published var currentRecord: MeetingRecord?
    @Published var processingStage: String = ""
    @Published var records: [MeetingRecord] = []

    private let micCapture = MicrophoneCapture()
    private let systemCapture = SystemAudioCapture()
    private let whisperService: Transcriber = WhisperService()
    private let claudeService: Summarizer = ClaudeService()
    private let localTranscriber: Transcriber = WhisperKitTranscriber.shared
    private let localSummarizer: Summarizer = MLXSummarizer.shared
    private let exporter = MarkdownExporter()
    private let settings = SettingsStore.shared
    private var cancellables = Set<AnyCancellable>()
    private var autoStopTimer: Timer?
    private var calendarManager: CalendarManager?
    // The audio channels captured for the in-progress recording (snapshotted at
    // start so a settings change mid-recording can't desync start vs. stop).
    private var activeSource: AudioSource = .both

    init() {
        loadRecords()
        NotificationCenter.default.publisher(for: .toggleRecording)
            .sink { [weak self] _ in self?.toggleRecording() }
            .store(in: &cancellables)
    }

    func inject(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
    }

    /// Derived UI state. Recording wins; otherwise an active processing stage; otherwise idle.
    var phase: RecordingPhase {
        if isRecording, let record = currentRecord {
            return .recording(record)
        }
        if !processingStage.isEmpty {
            return .processing(processingStage)
        }
        return .idle
    }

    /// Maps a processing stage label → 0…1 fraction for the menu bar progress display.
    static func progress(for stage: String) -> Double {
        switch stage {
        case let s where s.contains("Finalizing"):   return 0.10
        case let s where s.contains("Transcrib"):    return 0.40
        case let s where s.contains("Analyz"),
             let s where s.contains("Summariz"):     return 0.70
        case let s where s.contains("Export"):       return 0.90
        default:                                     return stage.isEmpty ? 0 : 0.50
        }
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording(title: String? = nil, calendarEventID: String? = nil) {
        guard !isRecording else { return }
        let record = MeetingRecord(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            title: title ?? "Meeting \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short))",
            calendarEventID: calendarEventID,
            audioURL: nil,
            markdownURL: nil,
            status: .recording
        )
        currentRecord = record
        isRecording = true
        let source = settings.audioSource
        activeSource = source
        NotificationManager.notify(title: "Glyph is recording", body: "Tap the menu bar icon to stop.")

        Task {
            do {
                // Start only the selected channels. Mic-only skips ScreenCaptureKit
                // entirely (no Screen Recording permission / relaunch needed).
                Log.info("Recording START — source=\(source.rawValue)")
                if source.capturesMic { try await micCapture.start() }
                if source.capturesSystem { try await systemCapture.start() }
                scheduleAutoStop(eventID: calendarEventID)
            } catch {
                await handleError(error, context: "Failed to start audio capture")
                // The start failed — stop and discard any partial temp recordings
                // for whichever channels we attempted.
                if source.capturesMic {
                    let micURL = await micCapture.stop()
                    try? FileManager.default.removeItem(at: micURL)
                }
                if source.capturesSystem {
                    let sysURL = await systemCapture.stop()
                    try? FileManager.default.removeItem(at: sysURL)
                }
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        autoStopTimer?.invalidate()
        autoStopTimer = nil
        isRecording = false
        processingStage = "Finalizing audio…"

        guard var record = currentRecord else { return }
        record = MeetingRecord(
            id: record.id,
            startTime: record.startTime,
            endTime: Date(),
            title: record.title,
            calendarEventID: record.calendarEventID,
            audioURL: nil,
            markdownURL: nil,
            status: .processing
        )
        currentRecord = record

        let source = activeSource
        Task {
            do {
                // Stop and collect only the channels that were actually captured.
                async let micStop: URL? = source.capturesMic ? micCapture.stop() : nil
                async let sysStop: URL? = source.capturesSystem ? systemCapture.stop() : nil
                let (micURL, sysURL) = await (micStop, sysStop)
                Log.info("Recording STOP — mixing (mic=\(micURL != nil), system=\(sysURL != nil))")
                let mixedURL = try await AudioMixer.mix(micURL: micURL, systemURL: sysURL)
                let sizeMB = (try? FileManager.default.attributesOfItem(atPath: mixedURL.path)[.size] as? Int).flatMap { $0 }.map { Double($0) / 1_048_576 } ?? 0
                Log.info("Mixed audio ready: \(mixedURL.lastPathComponent) (\(String(format: "%.1f", sizeMB)) MB)")

                record = MeetingRecord(
                    id: record.id,
                    startTime: record.startTime,
                    endTime: record.endTime,
                    title: record.title,
                    calendarEventID: record.calendarEventID,
                    audioURL: mixedURL,
                    markdownURL: nil,
                    status: .processing
                )
                currentRecord = record

                await processAudio(record: record, audioURL: mixedURL)
            } catch {
                await handleError(error, context: "Failed to stop or mix audio")
            }
        }
    }

    private func scheduleAutoStop(eventID: String?) {
        guard settings.autoStop,
              let eventID = eventID ?? currentRecord?.calendarEventID,
              let endDate = calendarManager?.eventEndDate(for: eventID) else { return }

        let interval = endDate.timeIntervalSince(Date())
        guard interval > 0 else { return }

        autoStopTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            // The Timer callback is nonisolated; hop to the main actor before touching
            // @MainActor state (isRecording / stopRecording).
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                self.stopRecording()
                NotificationManager.notify(title: "Meeting Ended", body: "Auto-stopped recording. Processing transcript…")
            }
        }
    }

    private func processAudio(record: MeetingRecord, audioURL: URL) async {
        do {
            let useCloud = settings.usesCloudAPI
            let transcriber: Transcriber = useCloud ? whisperService : localTranscriber
            let summarizer: Summarizer = useCloud ? claudeService : localSummarizer

            processingStage = useCloud ? "Transcribing with Whisper…" : "Transcribing on-device…"
            Log.info("Transcribe START (\(useCloud ? "cloud" : "on-device"))")
            let transcript = try await transcriber.transcribe(audioURL: audioURL)
            Log.info("Transcribe DONE — \(transcript.count) chars")

            // Free the transcription model before the (larger) summarizer loads,
            // so the two on-device models are never co-resident during the
            // memory-heaviest phase. No-op for the cloud path.
            await transcriber.unload()

            processingStage = useCloud ? "Analyzing with Claude…" : "Summarizing on-device…"
            Log.info("Summarize START (\(useCloud ? "cloud" : "on-device"))")
            let aiOutput = try await summarizer.process(
                transcript: transcript,
                targetLanguage: settings.targetLanguage,
                meetingTitle: record.title
            )
            Log.info("Summarize DONE")

            processingStage = "Exporting memory file…"
            let mdURL = try exporter.export(record: record, aiOutput: aiOutput, rawTranscript: transcript)
            Log.info("Export DONE — \(mdURL.lastPathComponent)")

            let completed = MeetingRecord(
                id: record.id,
                startTime: record.startTime,
                endTime: record.endTime,
                title: record.title,
                calendarEventID: record.calendarEventID,
                audioURL: audioURL,
                markdownURL: mdURL,
                status: .completed
            )

            await MainActor.run {
                currentRecord = nil
                processingStage = ""
                records.insert(completed, at: 0)
                saveRecords()
                NotificationManager.notify(title: "Meeting Processed", body: "\(record.title) is ready in your vault.")
            }
        } catch {
            await handleError(error, context: "AI processing failed")
        }
    }

    private func handleError(_ error: Error, context: String) async {
        Log.error("\(context): \(error.localizedDescription) [\(error)]")
        await MainActor.run {
            isRecording = false
            processingStage = ""
            if var record = currentRecord {
                record = MeetingRecord(
                    id: record.id,
                    startTime: record.startTime,
                    endTime: record.endTime,
                    title: record.title,
                    calendarEventID: record.calendarEventID,
                    audioURL: record.audioURL,
                    markdownURL: record.markdownURL,
                    status: .failed
                )
                records.insert(record, at: 0)
                currentRecord = nil
            }
            NotificationManager.notify(title: "Glyph Error", body: "\(context): \(error.localizedDescription)")
        }
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: "meetingRecords"),
              let decoded = try? JSONDecoder().decode([MeetingRecord].self, from: data) else { return }
        records = decoded
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: "meetingRecords")
        }
    }
}
