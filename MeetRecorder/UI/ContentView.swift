import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var calendarManager: CalendarManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let record = recordingManager.currentRecord {
                recordingView(for: record)
            } else {
                idleView
            }
            Divider()
            meetingList
            Divider()
            footer
        }
        .padding(.vertical, 8)
        .onAppear {
            recordingManager.inject(calendarManager: calendarManager)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundColor(.accentColor)
            Text("MeetRecorder")
                .font(.headline)
            Spacer()
            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private var idleView: some View {
        VStack(spacing: 12) {
            if !SettingsStore.shared.isConfigured {
                Text("API keys required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Button(action: { recordingManager.startRecording() }) {
                Label("Start Recording", systemImage: "record.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .tint(.red)
            .disabled(!SettingsStore.shared.isConfigured)
            .padding(.horizontal)

            if let event = calendarManager.upcomingEvent {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Upcoming")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        VStack(alignment: .leading) {
                            Text(event.title ?? "Meeting")
                                .font(.subheadline)
                                .lineLimit(1)
                            Text("\(event.startDate.formatted(date: .omitted, time: .shortened)) - \(event.endDate.formatted(date: .omitted, time: .shortened))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Record") {
                            recordingManager.startRecording(
                                title: event.title,
                                calendarEventID: event.eventIdentifier
                            )
                        }
                        .controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
    }

    private func recordingView(for record: MeetingRecord) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.red)
                    .symbolEffect(.pulse)
                VStack(alignment: .leading) {
                    Text(record.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(record.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(.horizontal)

            Button(action: { recordingManager.stopRecording() }) {
                Label("Stop Recording", systemImage: "stop.circle")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .padding(.horizontal)

            if !recordingManager.processingStage.isEmpty {
                VStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(recordingManager.processingStage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var meetingList: some View {
        List(recordingManager.records.prefix(5)) { record in
            HStack {
                Image(systemName: record.status == .completed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundColor(record.status == .completed ? .green : .orange)
                VStack(alignment: .leading) {
                    Text(record.title)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(record.startTime.formatted())
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let mdURL = record.markdownURL {
                    Button(action: { NSWorkspace.shared.open(mdURL.deletingLastPathComponent()) }) {
                        Image(systemName: "folder")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(height: min(CGFloat(recordingManager.records.count), 5) * 44)
        .listStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Text("Shortcut: \(KeyboardShortcuts.getShortcut(for: .toggleRecording)?.description ?? "None")")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            if recordingManager.isRecording {
                Text("Recording…")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}
