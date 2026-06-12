import SwiftUI
import AppKit
import EventKit
import KeyboardShortcuts

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var calendarManager: CalendarManager
    @State private var showingSettings = false
    @State private var showingHelp = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(showingSettings: $showingSettings, showingHelp: $showingHelp)

            Divider()
                .padding(.horizontal, DS.Space.lg)

            Group {
                switch recordingManager.phase {
                case .idle:
                    IdleView()
                case .recording(let record):
                    RecordingView(record: record)
                case .processing(let stage):
                    ProcessingView(stage: stage)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: recordingManager.phase)

            if !recordingManager.records.isEmpty {
                HistoryView()
            }

            FooterView()
        }
        .frame(width: 360)
        .background(DesignToken.bgBase)
        .preferredColorScheme(.dark)
        .tint(DesignToken.accent)
        .onAppear {
            recordingManager.inject(calendarManager: calendarManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingHelp) {
            HelpView()
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @Binding var showingSettings: Bool
    @Binding var showingHelp: Bool
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            // Waveform icon: recording red + pulse when live; secondary otherwise
            Image(systemName: recordingManager.phase.isRecording
                  ? "waveform.circle.fill"
                  : "waveform")
                .foregroundColor(recordingManager.phase.isRecording
                                 ? DS.Color.recording
                                 : DS.Color.secondary)
                .symbolEffect(.pulse, isActive: recordingManager.phase.isRecording)
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text("Glyph")
                .font(DS.Font.title)
                .foregroundColor(DS.Color.primary)

            Spacer()

            Button(action: { showingHelp.toggle() }) {
                Image(systemName: "questionmark.circle")
                    .imageScale(.medium)
            }
            .buttonStyle(GhostButtonStyle())
            .accessibilityLabel("Help")

            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(GhostButtonStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.md)
    }
}

// MARK: - Idle

struct IdleView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var calendarManager: CalendarManager
    @StateObject private var models = ModelManager.shared
    // Persisted audio-source choice (mic / system / both). Last pick stays.
    @AppStorage("audioSource") private var audioSource: AudioSource = .both

    var body: some View {
        VStack(spacing: DS.Space.lg) {
            // On-device model state banner (download-needed / downloading / ready)
            ConfigurationBanner()
                .padding(.horizontal, DS.Space.lg)

            // Download progress rows — visible only while a download is active
            if models.isBusy {
                DownloadProgressView()
                    .padding(.horizontal, DS.Space.lg)
            }

            // Primary action — adapts label and icon by model readiness
            Button(action: {
                if models.whisper != .ready || models.llm != .ready {
                    models.prepareAll()
                } else {
                    recordingManager.startRecording()
                }
            }) {
                if models.isBusy {
                    HStack(spacing: DS.Space.xs + 2) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text("Downloading…")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                } else {
                    Label(
                        models.whisper == .ready && models.llm == .ready
                            ? "Start Recording"
                            : "Download Models",
                        systemImage: models.whisper == .ready && models.llm == .ready
                            ? "record.circle"
                            : "arrow.down.circle"
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
                }
            }
            .buttonStyle(RecordButtonStyle())
            .disabled(models.isBusy)
            .padding(.horizontal, DS.Space.lg)
            .accessibilityLabel(
                models.isBusy ? "Downloading models" :
                (models.whisper == .ready && models.llm == .ready
                 ? "Start Recording"
                 : "Download on-device models")
            )

            // Audio-source picker — only shown when models are ready and recording
            // is meaningful. CAPTURE label-caps header reads as a designed section.
            if models.whisper == .ready && models.llm == .ready {
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("Capture")
                        .labelCaps()
                        .foregroundColor(DS.Color.secondary)
                        .padding(.horizontal, DS.Space.lg)

                    Picker("Audio source", selection: $audioSource) {
                        ForEach(AudioSource.allCases) { source in
                            Text(source.label).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.horizontal, DS.Space.lg)
                }
            }

            // Upcoming calendar event card
            if let event = calendarManager.upcomingEvent {
                UpcomingEventCard(event: event)
                    .padding(.horizontal, DS.Space.lg)
            }
        }
        .padding(.vertical, DS.Space.md)
    }
}

// MARK: - Configuration banner
//
// Reflects the three on-device model states the design docs predate:
//   • needs-download: neutral info (blue-tinted) + "Download Models" CTA
//   • downloading:    shows inline progress spinner, calm "Downloading…" copy
//   • ready:          success tint, confirms on-device privacy posture
//
// The token mapping: ready → success tint/icon; downloading → surfaceSecondary
// bg with a spinner; needs-download → info tint (systemBlue, not warning/orange —
// this is an invitation, not an error).

struct ConfigurationBanner: View {
    @StateObject private var models = ModelManager.shared

    private var isReady: Bool { models.whisper == .ready && models.llm == .ready }

    var body: some View {
        // When ready, show a minimal positive confirmation — not a persistent
        // banner that adds noise. Hide it once the user has seen it.
        if isReady {
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(DS.Color.success)
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text("On-device — your audio stays on this Mac.")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.secondary)
                Spacer()
            }
            .padding(DS.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Color.successWash)
            )
        } else if models.isBusy {
            // Downloading state: calm progress copy, no alarming icon
            HStack(spacing: DS.Space.sm) {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.75)
                Text("Downloading on-device models…")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.secondary)
                Spacer()
            }
            .padding(DS.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Color.surfaceSecondary)
            )
        } else {
            // Needs-download state: informational (not an error — this is first-run)
            HStack(spacing: DS.Space.sm) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(DesignToken.accent)
                    .imageScale(.small)
                    .accessibilityHidden(true)
                Text("Download on-device models to begin.")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.secondary)
                Spacer()
            }
            .padding(DS.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DesignToken.accent.opacity(0.08))
            )
        }
    }
}

// MARK: - Upcoming event card

struct UpcomingEventCard: View {
    let event: EKEvent
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack(spacing: DS.Space.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Meeting")
                    .font(DS.Font.bodyMedium)
                    .foregroundColor(DS.Color.primary)
                    .lineLimit(1)
                Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.secondary)
            }

            Spacer()

            Button("Record") {
                recordingManager.startRecording(
                    title: event.title,
                    calendarEventID: event.eventIdentifier
                )
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding(DS.Space.sm + 2) // 10px — spec: meeting-card internal padding
        .background(DS.Color.surfaceSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
    }
}

// MARK: - Capture Mode Chip

struct CaptureModeChip: View {
    let source: AudioSource

    private var chipColor: Color {
        switch source {
        case .mic:    return DesignToken.channelMic
        case .system: return DesignToken.channelSystem
        case .both:   return DesignToken.accent
        }
    }

    private var chipBg: Color {
        switch source {
        case .mic:    return DesignToken.channelMic.opacity(0.12)
        case .system: return DesignToken.channelSystem.opacity(0.12)
        case .both:   return DesignToken.accent.opacity(0.12)
        }
    }

    var body: some View {
        HStack(spacing: DS.Space.xs) {
            // Channel COLOR rides on the icon + bg tint (the signature signal);
            // the LABEL stays fgPrimary so it always clears WCAG AA — accent text
            // on its own tint was only 3.11:1 (canon: legibility over colour-on-label).
            Image(systemName: source.systemImage)
                .imageScale(.small)
                .foregroundColor(chipColor)
                .accessibilityHidden(true)
            Text(source.chipLabel)
                .font(DS.Font.caption)
                .foregroundColor(DesignToken.fgPrimary)
        }
        .padding(.horizontal, DS.Space.sm)
        .padding(.vertical, DS.Space.xs)
        .background(
            Capsule(style: .continuous)
                .fill(chipBg)
        )
        .accessibilityLabel("Capturing: \(source.chipLabel)")
    }
}

// MARK: - Recording

struct RecordingView: View {
    let record: MeetingRecord
    @EnvironmentObject var recordingManager: RecordingManager
    @AppStorage("audioSource") private var audioSource: AudioSource = .both

    var body: some View {
        VStack(spacing: DS.Space.lg) {
            HStack(spacing: DS.Space.sm + 2) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(DS.Color.recording)
                    .symbolEffect(.pulse)
                    .imageScale(.large)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(DS.Font.bodyMedium)
                        .foregroundColor(DS.Color.primary)
                        .lineLimit(1)
                    // Live elapsed timer — display token + monospacedDigit to prevent jitter.
                    // Past 45 min, a gentle long-session cue: timer shifts to warning
                    // amber and a passive "N min and counting" readout appears.
                    TimelineView(.periodic(from: record.startTime, by: 1)) { context in
                        let total = max(0, Int(context.date.timeIntervalSince(record.startTime)))
                        let isLongSession = total >= 2700   // 45 minutes
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%02d:%02d", total / 60, total % 60))
                                .font(DS.Font.display)
                                .monospacedDigit()
                                .foregroundColor(isLongSession ? DesignToken.warning : DS.Color.primary)
                                .animation(.easeInOut(duration: 0.4), value: isLongSession)
                            if isLongSession {
                                Text("\(total / 60) min and counting")
                                    .font(DS.Font.caption)
                                    .foregroundColor(DS.Color.secondary)
                            }
                        }
                    }
                }

                Spacer()

                StatusBadge(text: "REC", style: .recording)
                    .accessibilityLabel("Recording in progress")
            }
            .padding(.horizontal, DS.Space.lg)

            HStack {
                CaptureModeChip(source: audioSource)
                Spacer()
            }
            .padding(.horizontal, DS.Space.lg)

            Button(action: { recordingManager.stopRecording() }) {
                Label("Stop Recording", systemImage: "stop.circle")
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(RecordButtonStyle())
            .padding(.horizontal, DS.Space.lg)
        }
        .padding(.vertical, DS.Space.md)
        // Subtle recording-red wash behind the card (per design spec)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.recordingWash)
                .padding(.horizontal, DS.Space.md)
        )
        .padding(.vertical, DS.Space.xs)
    }
}

// MARK: - Processing

struct ProcessingView: View {
    let stage: String
    @AppStorage("audioSource") private var audioSource: AudioSource = .both

    var body: some View {
        VStack(spacing: DS.Space.md) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
                .tint(DesignToken.accent)

            Text(stage)
                .font(DS.Font.caption)
                .foregroundColor(DS.Color.secondary)
                .multilineTextAlignment(.center)

            CaptureModeChip(source: audioSource)

            StatusBadge(text: "Processing", style: .processing)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, DS.Space.lg)
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, DS.Space.lg)

            Text("Recent")
                .labelCaps()
                .foregroundColor(DS.Color.secondary)
                .padding(.horizontal, DS.Space.lg)
                .padding(.top, DS.Space.sm)
                .padding(.bottom, DS.Space.xs)

            List(recordingManager.records.prefix(5)) { record in
                HistoryRow(record: record)
                    .listRowInsets(EdgeInsets(
                        top: 2,
                        leading: DS.Space.lg,
                        bottom: 2,
                        trailing: DS.Space.lg
                    ))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: min(CGFloat(recordingManager.records.count), 5) * 40)
            .environment(\.defaultMinListRowHeight, 36)
        }
    }
}

struct HistoryRow: View {
    let record: MeetingRecord

    var body: some View {
        HStack(spacing: DS.Space.sm) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .imageScale(.small)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(record.title)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundColor(DS.Color.primary)
                    .lineLimit(1)
                Text(record.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(DS.Color.secondary)
            }

            Spacer()

            if let mdURL = record.markdownURL {
                Button(action: {
                    NSWorkspace.shared.open(mdURL.deletingLastPathComponent())
                }) {
                    Image(systemName: "arrow.up.forward.square")
                        .imageScale(.small)
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityLabel("Open in Finder")
            }
        }
        .padding(.vertical, DS.Space.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch record.status {
        case .completed:               return "checkmark.circle.fill"
        case .processing, .recording:  return "ellipsis.circle.fill"
        case .failed:                  return "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch record.status {
        case .completed:               return DS.Color.success
        case .processing, .recording:  return DS.Color.warning
        case .failed:                  return DS.Color.error
        }
    }
}

// MARK: - Download Progress

struct DownloadProgressView: View {
    @StateObject private var models = ModelManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.sm) {
            if let name = models.activeWhisperDownload {
                ModelDownloadRow(label: "Whisper \(name)", state: models.whisper)
            }
            if let id = models.activeLLMDownload {
                let shortName = id.split(separator: "/").last.map(String.init) ?? id
                ModelDownloadRow(label: shortName, state: models.llm)
            }
        }
        .padding(DS.Space.sm + 2) // 10px — card internal padding
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Color.surfaceSecondary)
        )
    }
}

private struct ModelDownloadRow: View {
    let label: String
    let state: ModelManager.State

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack {
                Text(label)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DS.Color.primary)
                Spacer()
                stateLabel
            }
            if case .preparing(let frac) = state, let frac {
                ProgressView(value: frac)
                    .progressViewStyle(.linear)
                    .tint(Color(nsColor: .systemBlue))
            } else if case .preparing(nil) = state {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color(nsColor: .systemBlue))
            }
        }
    }

    @ViewBuilder private var stateLabel: some View {
        switch state {
        case .preparing(let frac):
            if let frac {
                Text("\(Int(frac * 100))%")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(DS.Color.secondary)
            } else {
                Text("Downloading…")
                    .font(DS.Font.caption)
                    .foregroundColor(DS.Color.secondary)
            }
        case .failed(let msg):
            Text("Failed")
                .font(DS.Font.caption)
                .foregroundColor(DS.Color.error)
                .help(msg)
        default:
            EmptyView()
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack {
            // Keyboard shortcut hint — styled as a key cap (outline + caption type)
            if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) {
                Text(shortcut.description)
                    .font(DS.Font.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DS.Color.secondary)
                    .padding(.horizontal, DS.Space.xs + 2)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                            .stroke(DS.Color.divider, lineWidth: 0.5)
                    )
            }

            Spacer()

            // Recording status word — recording red, label-caps weight
            if recordingManager.phase.isRecording {
                Text("Recording")
                    .font(DS.Font.labelCaps)
                    .tracking(0.6)
                    .foregroundColor(DS.Color.recording)
            }

            // Quit affordance — ghost button, consistent with other tertiary actions
            Button(action: { NSApplication.shared.terminate(nil) }) {
                Image(systemName: "power")
                    .imageScale(.small)
            }
            .buttonStyle(GhostButtonStyle())
            .accessibilityLabel("Quit Glyph")
            .help("Quit Glyph")
        }
        .padding(.horizontal, DS.Space.lg)
        .padding(.vertical, DS.Space.sm)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DS.Color.divider.opacity(0.5))
                .frame(height: 0.5)
        }
    }
}
