# Glyph UI/UX Redesign

## Philosophy

Your current UI is functional. This redesign tightens it into a first-class
macOS utility by applying three principles:

1. **State-first layout** — The popover has one job at any moment: idle,
   recording, or processing. Each state gets a tailored layout rather than
   conditional blocks inside a generic VStack.
2. **Minimal chrome** — Remove every pixel that does not communicate state.
   Fewer borders, fewer labels, fewer buttons.
3. **Immediate feedback** — Every action has a visible consequence within
   100 ms. The recording state is unmistakable.

## ContentView Redesign

Replace the monolithic `ContentView` with a state-driven root and extracted
subviews. The diff below keeps your existing `@EnvironmentObject` contracts
and `KeyboardShortcuts` integration.

```swift
import SwiftUI
import KeyboardShortcuts

struct ContentView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @EnvironmentObject var calendarManager: CalendarManager
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(showingSettings: $showingSettings)

            switch recordingManager.phase {
            case .idle:
                IdleView()
            case .recording(let record):
                RecordingView(record: record)
            case .processing(let stage):
                ProcessingView(stage: stage)
            }

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
```

### RecordingPhase Enum

Add this to `RecordingManager` so the UI can switch cleanly:

```swift
enum RecordingPhase: Equatable {
    case idle
    case recording(MeetingRecord)
    case processing(String)   // localized stage label
}
```

### HeaderView

```swift
struct HeaderView: View {
    @Binding var showingSettings: Bool
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: recordingManager.phase.isRecording
                  ? "waveform.circle.fill"
                  : "waveform")
                .foregroundColor(recordingManager.phase.isRecording
                                 ? .init(nsColor: .systemRed)
                                 : .secondary)
                .symbolEffect(.pulse, isActive: recordingManager.phase.isRecording)
                .imageScale(.medium)

            Text("MeetRecorder")
                .font(.system(size: 15, weight: .semibold, design: .default))
                .foregroundColor(.primary)

            Spacer()

            Button(action: { showingSettings.toggle() }) {
                Image(systemName: "gearshape")
                    .imageScale(.medium)
            }
            .buttonStyle(GhostButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
```

### IdleView

The idle state has **one** primary action and zero distractions.

```swift
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
                    .font(.system(size: 13, weight: .semibold, design: .default))
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
```

### RecordButtonStyle

```swift
struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(isEnabled
                        ? (configuration.isPressed
                           ? Color(nsColor: .init(hex: "#E0312A"))
                           : Color(nsColor: .systemRed))
                        : Color(nsColor: .systemGray).opacity(0.4))
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
```

### UpcomingEventCard

```swift
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
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
```

### SecondaryButtonStyle

```swift
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .foregroundColor(.primary)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
```

### RecordingView

```swift
struct RecordingView: View {
    let record: MeetingRecord
    @EnvironmentObject var recordingManager: RecordingManager

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.circle.fill")
                    .foregroundColor(.init(nsColor: .systemRed))
                    .symbolEffect(.pulse)
                    .imageScale(.large)

                VStack(alignment: .leading, spacing: 2) {
                    Text(record.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(record.formattedDuration)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                }

                Spacer()

                StatusBadge(text: "REC", style: .recording)
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
}
```

### ProcessingView

```swift
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
```

### StatusBadge

```swift
struct StatusBadge: View {
    enum Style {
        case recording, processing, done

        var textColor: Color {
            switch self {
            case .recording: return .init(nsColor: .systemRed)
            case .processing: return .init(nsColor: .systemOrange)
            case .done: return .init(nsColor: .systemGreen)
            }
        }

        var bgColor: Color {
            switch self {
            case .recording: return .init(nsColor: .systemRed).opacity(0.1)
            case .processing: return .init(nsColor: .systemOrange).opacity(0.1)
            case .done: return .init(nsColor: .systemGreen).opacity(0.1)
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundColor(style.textColor)
            .background(style.bgColor)
            .clipShape(Capsule())
    }
}
```

### HistoryView

```swift
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
```

### HistoryRow

```swift
struct HistoryRow: View {
    let record: MeetingRecord

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .imageScale(.small)
                .frame(width: 16, alignment: .center)

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
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var iconName: String {
        switch record.status {
        case .completed: return "checkmark.circle.fill"
        case .processing: return "ellipsis.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch record.status {
        case .completed: return .init(nsColor: .systemGreen)
        case .processing: return .init(nsColor: .systemOrange)
        case .failed: return .init(nsColor: .systemRed)
        }
    }
}
```

### GhostButtonStyle

```swift
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor).opacity(configuration.isPressed ? 0.15 : 0))
            )
            .contentShape(Rectangle())
    }
}
```

### FooterView

```swift
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
                    .foregroundColor(.init(nsColor: .systemRed))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.3))
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        )
    }
}
```

### ConfigurationBanner

```swift
struct ConfigurationBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.init(nsColor: .systemOrange))
                .imageScale(.small)

            Text("Add API keys in Settings to begin.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .systemOrange).opacity(0.08))
        )
    }
}
```

## SettingsView Redesign

The settings sheet is currently a single dense form. Break it into logical
sections with visual breathing room.

```swift
struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold, design: .default))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
            .background(.ultraThinMaterial)

            Form {
                Section {
                    SecureField("OpenAI API Key", text: $settings.openAIKey)
                    SecureField("Anthropic API Key", text: $settings.anthropicKey)
                } header: {
                    Text("API Keys")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("Vault Path", text: $settings.vaultPath)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse…") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK {
                                settings.vaultPath = panel.url?.path ?? ""
                            }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }

                    Picker("Target Language", selection: $settings.targetLanguage) {
                        Text("English").tag("en")
                        Text("Chinese").tag("zh")
                    }
                    .pickerStyle(.segmented)

                    Picker("Source Language", selection: $settings.sourceLanguage) {
                        Text("Auto-detect").tag("auto")
                        Text("English").tag("en")
                        Text("Cantonese").tag("zh-HK")
                        Text("Mandarin").tag("zh-CN")
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Output")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }

                Section {
                    Toggle("Calendar Reminders", isOn: $settings.calendarReminders)
                    Toggle("Auto-stop on Event End", isOn: $settings.autoStop)
                    Toggle("Global Shortcut", isOn: $settings.globalShortcutEnabled)
                    if settings.globalShortcutEnabled {
                        KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
                    }
                } header: {
                    Text("Automation")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }
            }
            .formStyle(.grouped)
            .padding(.top, 8)

            Spacer()
        }
        .frame(width: 480, height: 460)
    }
}
```

## Animation Checklist

Add these modifiers to make the UI feel native:

1. **Phase transitions** — Wrap the `switch recordingManager.phase` in:
   ```swift
   .animation(.easeInOut(duration: 0.2), value: recordingManager.phase)
   ```

2. **Button press** — The custom button styles above already include
   `configuration.isPressed` feedback.

3. **List appearance** — Use `.transition(.opacity.combined(with: .move(edge: .top)))`
   when new history rows appear.

4. **Recording timer** — The `formattedDuration` text should update via
   `TimelineView` or a 1-second `Timer` publisher so the UI redraws without
   jank.

## Accessibility

- Every `Image(systemName:)` that is not purely decorative must have a
  `.accessibilityLabel(...)`.
- The "REC" badge should read as "Recording in progress" via
  `.accessibilityLabel("Recording in progress")`.
- Use `.accessibilityElement(children: .combine)` on `HistoryRow` so VoiceOver
  announces the title, date, and status as a single utterance.
- Ensure the custom button styles respect `.isEnabled` and reduce opacity
  correctly.
