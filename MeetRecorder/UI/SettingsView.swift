import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            Form {
                Section("API Keys") {
                    SecureField("OpenAI API Key", text: $settings.openAIKey)
                    SecureField("Anthropic API Key", text: $settings.anthropicKey)
                }

                Section("Output") {
                    HStack {
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
                    }
                    Picker("Target Language", selection: $settings.targetLanguage) {
                        Text("English").tag("en")
                        Text("Chinese").tag("zh")
                    }
                    Picker("Source Language", selection: $settings.sourceLanguage) {
                        Text("Auto-detect").tag("auto")
                        Text("English").tag("en")
                        Text("Cantonese").tag("zh-HK")
                        Text("Mandarin").tag("zh-CN")
                    }
                }

                Section("Automation") {
                    Toggle("Calendar Reminders", isOn: $settings.calendarReminders)
                    Toggle("Auto-stop on Event End", isOn: $settings.autoStop)
                    Toggle("Global Shortcut", isOn: $settings.globalShortcutEnabled)
                    if settings.globalShortcutEnabled {
                        KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
                    }
                }
            }
            .formStyle(.grouped)

            Spacer()
        }
        .padding()
        .frame(width: 480, height: 420)
    }
}
