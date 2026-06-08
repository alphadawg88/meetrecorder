import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
            .background(.ultraThinMaterial)

            Form {
                Section {
                    Toggle("On-device mode — private & offline", isOn: $settings.offlineMode)
                    if settings.offlineMode {
                        Picker("Summary model", selection: $settings.localLLMTier) {
                            Text("Auto (by RAM)").tag("auto")
                            Text("Qwen2.5 7B").tag("8b")
                            Text("Qwen2.5 3B (light)").tag("4b")
                        }
                        Text("Runs WhisperKit + a local LLM on this Mac — no data leaves the device. Models download on first use. On-device Cantonese is good but below cloud; use cloud for nuanced Cantonese translation.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Processing engine")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }

                Section {
                    SecureField("OpenAI API Key", text: $settings.openAIKey)
                    SecureField("Anthropic API Key", text: $settings.anthropicKey)
                } header: {
                    Text("API Keys (cloud mode)")
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
                        Text("Auto").tag("auto")
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
        .frame(width: 480, height: 520)
    }
}
