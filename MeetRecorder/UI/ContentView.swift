import SwiftUI
import EventKit
import KeyboardShortcuts

// MARK: - Root

struct ContentView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var calendarManager: CalendarManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(showingSettings: $showingSettings)

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
        .background(.ultraThinMaterial)
        .onAppear {
            recordingManager.inject(calendarManager: calendarManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

// MARK: - Header

struct HeaderView: View {
    @Binding var showingSettings: Bool
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: recordingManager.phase.isRecording ? "waveform.circle.fill" : "waveform")
                .foregroundColor(recordingManager.phase.isRecording
                                 ? Color(nsColor: .systemRed)
                                 : .secondary)
                .symbolEffect(.pulse, isActive: recordingManager.phase.isRecording)
                .imageScale(.medium)
                .accessibilityHidden(true)

            Text("Glyph")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(GhostButtonStyle())
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Idle

struct IdleView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var calendarManager: CalendarManager

    var body: some View {
        VStack(spacing: 16) {
            if !SettingsStore.shared.isConfigured {
                ConfigurationBanner()
            }

            Button(action: { recordingManager.startRecording() }) {
                Label("Start Recording", systemImage: "record.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(RecordButtonStyle())
            .disabled(!SettingsStore.shared.isConfigured)
            .padding(.horizontal, 16)

            if let event = calendarManager.upcomingEvent {
                UpcomingEventCard(event: event)
                    .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
    }
}

struct ConfigurationBanner: View {
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(nsColor: .systemOrange))
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(SettingsStore.shared.offlineMode
                 ? "Download on-device models in Settings to begin."
                 : "Add API keys in Settings to begin.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .systemOrange).opacity(0.08))
        )
        .padding(.horizontal, 16)
    }
}

struct UpcomingEventCard: View {
    let event: EKEvent
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Meeting")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                Text("\(event.startDate, style: .time) – \(event.endDate, style: .time)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
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
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

// MARK: - Recording

struct RecordingView: View {
    let record: MeetingRecord
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(Color(nsColor: .systemRed))
                    .symbolEffect(.pulse)
                    .imageScale(.large)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    // Live elapsed timer, monospaced to avoid jitter.
                    TimelineView(.periodic(from: record.startTime, by: 1)) { context in
                        Text(Self.elapsed(since: record.startTime, now: context.date))
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(.primary)
                    }
                }

                Spacer()

                StatusBadge(text: "REC", style: .recording)
                    .accessibilityLabel("Recording in progress")
            }
            .padding(.horizontal, 16)

            Button(action: { recordingManager.stopRecording() }) {
                Label("Stop Recording", systemImage: "stop.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 32)
            }
            .buttonStyle(RecordButtonStyle())
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .systemRed).opacity(0.06))
                .padding(.horizontal, 12)
        )
        .padding(.vertical, 4)
    }

    private static func elapsed(since start: Date, now: Date) -> String {
        let total = max(0, Int(now.timeIntervalSince(start)))
        let m = total / 60, s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Processing

struct ProcessingView: View {
    let stage: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)

            Text(stage)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            StatusBadge(text: "Processing", style: .processing)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding(.vertical, 16)
    }
}

// MARK: - History

struct HistoryView: View {
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .padding(.horizontal, 16)

            Text("Recent")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            List(recordingManager.records.prefix(5)) { record in
                HistoryRow(record: record)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .frame(height: min(CGFloat(recordingManager.records.count), 5) * 40)
            .environment(\.defaultMinListRowHeight, 36)
        }
    }
}

struct HistoryRow: View {
    let record: MeetingRecord

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .imageScale(.small)
                .frame(width: 16, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(record.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(record.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if let mdURL = record.markdownURL {
                Button(action: { NSWorkspace.shared.open(mdURL.deletingLastPathComponent()) }) {
                    Image(systemName: "arrow.up.forward.square")
                        .imageScale(.small)
                }
                .buttonStyle(GhostButtonStyle())
                .accessibilityLabel("Open in Finder")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private var iconName: String {
        switch record.status {
        case .completed: return "checkmark.circle.fill"
        case .processing, .recording: return "ellipsis.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch record.status {
        case .completed: return Color(nsColor: .systemGreen)
        case .processing, .recording: return Color(nsColor: .systemOrange)
        case .failed: return Color(nsColor: .systemRed)
        }
    }
}

// MARK: - Footer

struct FooterView: View {
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack {
            if let shortcut = KeyboardShortcuts.getShortcut(for: .toggleRecording) {
                Text(shortcut.description)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color(nsColor: .quaternaryLabelColor), lineWidth: 0.5)
                    )
            }

            Spacer()

            if recordingManager.phase.isRecording {
                Text("Recording")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(nsColor: .systemRed))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(height: 0.5)
        }
    }
}
