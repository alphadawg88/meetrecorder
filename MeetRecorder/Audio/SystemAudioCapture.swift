import ScreenCaptureKit
import AVFoundation

actor SystemAudioCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private var tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("system_\(UUID().uuidString).m4a")
    private var isReady = false
    // While paused we simply drop incoming buffers — ScreenCaptureKit has no
    // native pause. The monotonic-PTS guard below makes the resume seamless:
    // the next kept buffer's PTS is still > lastPTS, so the writer concatenates
    // across the gap (the recording skips the paused stretch).
    private var isPaused = false
    // Last appended presentation timestamp — AVAssetWriterInput throws on
    // out-of-order samples, so we drop any buffer that goes backwards.
    private var lastPTS: CMTime = .invalid
    // Log writer failures only once per session to avoid flooding.
    private var loggedWriterFailure = false
    // Serial queue so sample buffers are delivered (and enqueued to the actor) in arrival order.
    private let sampleQueue = DispatchQueue(label: "com.alfredwong.glyph.systemaudio.samples")

    func start() async throws {
        // Reset per-session state. (isPaused MUST reset here — else a Stop-while-
        // paused leaves it true and the NEXT recording silently drops every buffer.)
        isReady = false
        isPaused = false
        lastPTS = .invalid
        loggedWriterFailure = false
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("system_\(UUID().uuidString).m4a")
        Log.info("SystemAudio.start — requesting shareable content")
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            Log.error("SystemAudio.start — no display available")
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        assetWriter = try AVAssetWriter(url: tempURL, fileType: .m4a)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        audioInput?.expectsMediaDataInRealTime = true
        if let input = audioInput { assetWriter?.add(input) }
        guard assetWriter?.startWriting() == true else {
            throw CaptureError.writerStartFailed(assetWriter?.error)
        }

        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: sampleQueue)
        try await stream?.startCapture()
        Log.info("SystemAudio capture started (writer.status=\(assetWriter?.status.rawValue ?? -1))")
    }

    /// Pause/resume system-audio capture. We keep the stream + writer alive and
    /// simply stop appending buffers while paused (ScreenCaptureKit has no native
    /// pause); the monotonic-PTS guard makes resume seamless across the gap.
    func setPaused(_ paused: Bool) {
        isPaused = paused
        Log.info("SystemAudio \(paused ? "paused" : "resumed")")
    }

    func stop() async -> URL {
        try? await stream?.stopCapture()
        // Only finalize an input that actually started writing, else finishWriting can fail.
        if assetWriter?.status == .writing {
            audioInput?.markAsFinished()
            await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                assetWriter?.finishWriting { cont.resume() }
            }
        }
        Log.info("SystemAudio.stop — writer.status=\(assetWriter?.status.rawValue ?? -1), file=\(tempURL.lastPathComponent), error=\(String(describing: assetWriter?.error))")
        return tempURL
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        Task {
            await append(buffer: sampleBuffer)
        }
    }

    private func append(buffer: CMSampleBuffer) async {
        // Drop everything while paused — resume picks up at the next buffer's PTS.
        guard !isPaused else { return }
        // Only handle a complete buffer carrying a usable timestamp.
        guard CMSampleBufferDataIsReady(buffer) else { return }
        let pts = CMSampleBufferGetPresentationTimeStamp(buffer)
        guard pts.isNumeric else { return }

        guard let writer = assetWriter, let input = audioInput else { return }

        // CRITICAL: AVAssetWriterInput.append() throws an Objective-C exception
        // (→ SIGABRT, whole-app crash) if the writer isn't actively writing.
        // Guard the status instead of letting it abort the process.
        if writer.status == .failed {
            if !loggedWriterFailure {
                loggedWriterFailure = true
                Log.error("SystemAudio writer entered .failed — dropping audio. error: \(String(describing: writer.error))")
            }
            return
        }
        guard writer.status == .writing else { return }   // not started yet, or already finished

        if !isReady {
            writer.startSession(atSourceTime: pts)
            isReady = true
            lastPTS = pts
            Log.info("SystemAudio capture session started @ \(String(format: "%.3f", pts.seconds))s")
        }

        // Enforce monotonically increasing PTS — out-of-order samples also throw.
        guard pts >= lastPTS else { return }
        lastPTS = pts

        if input.isReadyForMoreMediaData {
            input.append(buffer)
        }
    }
}

enum CaptureError: Error {
    case noDisplay
    case writerStartFailed(Error?)
}
