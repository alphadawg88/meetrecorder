import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @StateObject private var settings = SettingsStore.shared
    @StateObject private var models = ModelManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(DesignToken.h1())
                    .foregroundColor(DesignToken.fgPrimary)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
            .background(DesignToken.bgBase)

            Form {
                Section {
                    Toggle("On-device mode \u2014 private & offline", isOn: $settings.offlineMode)
                        .foregroundColor(DesignToken.fgPrimary)
                    if settings.offlineMode {
                        Picker("Summary model", selection: $settings.localLLMTier) {
                            Text("Auto (by RAM)").tag("auto")
                            Text("Qwen2.5 7B").tag("8b")
                            Text("Qwen2.5 3B (light)").tag("4b")
                        }
                        Text("Runs WhisperKit + a local LLM on this Mac \u2014 no data leaves the device. Models download on first use (~6 GB). On-device Cantonese is good but below cloud; use cloud for nuanced Cantonese translation.")
                            .font(DesignToken.caption())
                            .foregroundColor(DesignToken.fgSecondary)

                        ModelStatusRow(label: "Transcription \u00b7 WhisperKit large-v3", state: models.whisper)
                        ModelStatusRow(label: "Summary \u00b7 Qwen2.5", state: models.llm)

                        Button(models.isBusy ? "Downloading\u2026" : "Download / load on-device models") {
                            models.prepareAll()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(models.isBusy)
                    }
                } header: {
                    Text("Processing engine")
                        .font(DesignToken.labelCaps())
                        .tracking(0.5)
                        .foregroundColor(DesignToken.fgSecondary)
                }

                Section {
                    SecureField("OpenAI API Key", text: $settings.openAIKey)
                        .foregroundColor(DesignToken.fgPrimary)
                    SecureField("Anthropic API Key", text: $settings.anthropicKey)
                        .foregroundColor(DesignToken.fgPrimary)
                } header: {
                    Text("API Keys (cloud mode)")
                        .font(DesignToken.labelCaps())
                        .tracking(0.5)
                        .foregroundColor(DesignToken.fgSecondary)
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("Vault Path", text: $settings.vaultPath)
                            .textFieldStyle(.roundedBorder)
                            .foregroundColor(DesignToken.fgPrimary)
                        Button("Browse\u2026") {
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
                    .foregroundColor(DesignToken.fgPrimary)

                    Picker("Source Language", selection: $settings.sourceLanguage) {
                        Text("Auto").tag("auto")
                        Text("English").tag("en")
                        Text("Cantonese").tag("zh-HK")
                        Text("Mandarin").tag("zh-CN")
                    }
                    .pickerStyle(.segmented)
                    .foregroundColor(DesignToken.fgPrimary)
                } header: {
                    Text("Output")
                        .font(DesignToken.labelCaps())
                        .tracking(0.5)
                        .foregroundColor(DesignToken.fgSecondary)
                }

                Section {
                    Toggle("Calendar Reminders", isOn: $settings.calendarReminders)
                        .foregroundColor(DesignToken.fgPrimary)
                    Toggle("Auto-stop on Event End", isOn: $settings.autoStop)
                        .foregroundColor(DesignToken.fgPrimary)
                    Toggle("Global Shortcut", isOn: $settings.globalShortcutEnabled)
                        .foregroundColor(DesignToken.fgPrimary)
                    if settings.globalShortcutEnabled {
                        KeyboardShortcuts.Recorder("Toggle Recording:", name: .toggleRecording)
                    }
                } header: {
                    Text("Automation")
                        .font(DesignToken.labelCaps())
                        .tracking(0.5)
                        .foregroundColor(DesignToken.fgSecondary)
                }
            }
            .formStyle(.grouped)
            .padding(.top, 8)
            .background(DesignToken.bgBase)

            Spacer()
        }
        .frame(width: 480, height: 560)
        .background(DesignToken.bgBase)
    }
}

private struct ModelStatusRow: View {
    let label: String
    let state: ModelManager.State

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(DesignToken.fgSecondary)
            Spacer()
            switch state {
            case .notReady:
                Text("Not downloaded")
                    .font(.system(size: 11))
                    .foregroundColor(DesignToken.fgTertiary)
            case .preparing(let frac):
                if let frac {
                    Text("\(Int(frac * 100))%")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundColor(DesignToken.fgSecondary)
                } else {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                }
            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(DesignToken.success)
            case .failed(let msg):
                Label("Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(DesignToken.warning)
                    .help(msg)
            }
        }
    }
}
