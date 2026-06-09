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
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
            .background(.ultraThinMaterial)

            Form {
                // MARK: - On-device models (primary)
                Section {
                    Text("Transcription")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ModelCard(id: "large-v3",
                              name: "Whisper large-v3",
                              tag: "Most accurate",
                              size: "~1.5 GB",
                              selected: $settings.whisperModel)
                    ModelCard(id: "small",
                              name: "Whisper small",
                              tag: "Fast & light",
                              size: "~244 MB",
                              selected: $settings.whisperModel)

                    Divider().padding(.vertical, 4)

                    Text("Summary")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)

                    ModelCard(id: "mlx-community/Qwen2.5-7B-Instruct-4bit",
                              name: "Qwen 2.5 7B",
                              tag: "Bilingual best",
                              size: "~4.2 GB",
                              selected: $settings.localLLMModelID)
                    ModelCard(id: "mlx-community/Qwen2.5-3B-Instruct-4bit",
                              name: "Qwen 2.5 3B",
                              tag: "Light & fast",
                              size: "~1.8 GB",
                              selected: $settings.localLLMModelID)
                    ModelCard(id: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit",
                              name: "Llama 3.1 8B",
                              tag: "Long context",
                              size: "~4.5 GB",
                              selected: $settings.localLLMModelID)
                    ModelCard(id: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit",
                              name: "DeepSeek R1 7B",
                              tag: "Deep reasoning",
                              size: "~4.5 GB",
                              selected: $settings.localLLMModelID)

                    Divider().padding(.vertical, 4)

                    ModelStatusRow(label: "Transcription · WhisperKit", state: models.whisper)
                    ModelStatusRow(label: "Summary · MLX", state: models.llm)

                    Button(models.isBusy ? "Downloading…" : "Download / load on-device models") {
                        models.prepareAll()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(models.isBusy)
                } header: {
                    Text("On-device models")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                }

                // MARK: - Output
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

                // MARK: - Automation
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

                // MARK: - Cloud enhancement (optional, at bottom)
                Section {
                    Toggle("Prefer cloud when keys are set", isOn: $settings.preferCloud)

                    if settings.preferCloud {
                        SecureField("OpenAI API Key", text: $settings.openAIKey)
                        SecureField("Anthropic API Key", text: $settings.anthropicKey)
                    }
                } header: {
                    Text("Cloud enhancement (optional)")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(0.5)
                } footer: {
                    Text("Cloud APIs improve nuanced translation — especially Cantonese slang and idioms. Not required for most meetings.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(.top, 8)

            Spacer()
        }
        .frame(width: 480, height: 640)
    }
}

private struct ModelStatusRow: View {
    let label: String
    let state: ModelManager.State

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11))
            Spacer()
            switch state {
            case .notReady:
                Text("Not downloaded")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            case .preparing(let frac):
                if let frac {
                    Text("\(Int(frac * 100))%")
                        .font(.system(size: 11))
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                } else {
                    ProgressView().controlSize(.small).scaleEffect(0.7)
                }
            case .ready:
                Label("Ready", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .systemGreen))
            case .failed(let msg):
                Label("Failed", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(nsColor: .systemOrange))
                    .help(msg)
            }
        }
    }
}
