# Glyph Build Prompt — Menu Persistence, Local-First Model Browser, Help Panel

## Context

This is a macOS menu-bar meeting recorder app (Glyph). The current implementation uses `MenuBarExtra` with `.window` style. It has local transcription (WhisperKit) and local summarization (MLX Swift) alongside optional cloud APIs (OpenAI Whisper + Anthropic Claude). The UI follows a state-driven architecture (`RecordingPhase`: idle / recording / processing).

All source files are in `MeetRecorder/`.

---

## Requirement 1: Menu Popover Persistence — Push vs Select Buttons

### Problem
The popover currently auto-closes when the user clicks any button or toggle inside it. This breaks the flow for adjusting settings or browsing models.

### Desired Behavior
- **Push buttons** (e.g., Start Recording, Stop Recording, Record on event card, Open in Finder): action fires, popover **stays open**.
- **Select/toggle controls** (e.g., toggles in Settings, model picker): state changes, popover **stays open**.
- Popover **only closes** when the user clicks outside the menu (click-away dismiss).
- The Settings sheet (currently a `.sheet`) can still be modal — that is fine.

### Implementation Approach

The `MenuBarExtra` `.window` style is losing key window status on button interaction. Switch to a **manual `NSPopover`** managed by `AppDelegate` for full control over dismiss behavior.

**In `MeetRecorderApp.swift`:**

1. Remove the `MenuBarExtra` scene entirely.
2. In `AppDelegate`, create and manage an `NSPopover`:
   - `behavior = .transient` — dismisses on click-away, stays open on interaction inside.
   - `animates = true`.
   - Content is a `NSViewController` wrapping the SwiftUI `ContentView` via `NSHostingController`.
3. Add an `NSStatusItem` to the system status bar. Clicking the status item toggles the popover.
4. Use the custom `MenuBarIcon` template image for the status item.
5. When recording starts, swap the status item image to the filled red `waveform.circle.fill` SF Symbol.

**Code sketch for the toggle logic:**

```swift
@objc private func statusItemClicked(_ sender: Any?) {
    if popover.isShown {
        popover.performClose(sender)
    } else {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
```

**Critical:** The `NSPopover` with `behavior = .transient` automatically handles click-away dismiss while keeping the popover open for interactions inside it. This is the standard macOS pattern for persistent menu-bar popovers (e.g., Dropbox, 1Password).

---

## Requirement 2: Local Model Browser with Advantage Tags

### Problem
The current Settings only shows two local LLM options in a `Picker` ("Auto", "Qwen2.5 7B", "Qwen2.5 3B"). Users cannot see what each model is good at.

### Desired Behavior
Replace the `Picker` with a **browsable model list** where each model shows a short 2-word advantage tag. Include both transcription models and summary models.

### Model Catalog

**Summary Models (MLX LLM):**

| Model ID | Display Name | 2-Word Tag | Size | Best For |
|----------|-------------|------------|------|----------|
| `mlx-community/Qwen2.5-7B-Instruct-4bit` | Qwen 2.5 7B | Bilingual best | ~4.2 GB | Chinese + English meetings; best overall |
| `mlx-community/Qwen2.5-3B-Instruct-4bit` | Qwen 2.5 3B | Light & fast | ~1.8 GB | Lighter machines; slightly lower quality |
| `mlx-community/Meta-Llama-3.1-8B-Instruct-4bit` | Llama 3.1 8B | Long context | ~4.5 GB | 90+ min meetings; huge context window |
| `mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit` | DeepSeek R1 7B | Deep reasoning | ~4.5 GB | Best extraction quality; 2× slower |

**Transcription Models (WhisperKit):**

| Model | 2-Word Tag | Size | Best For |
|-------|-----------|------|----------|
| `large-v3` | Most accurate | ~1.5 GB | Cantonese support; noisy audio |
| `small` | Fast & light | ~244 MB | Clean audio; quick processing |

### Implementation

**In `SettingsStore.swift`:**

1. Add `@AppStorage("whisperModel") var whisperModel: String = "large-v3"`.
2. Change `localLLMTier` from a tier string to a full model ID string. Rename to `@AppStorage("localLLMModelID") var localLLMModelID: String = "mlx-community/Qwen2.5-7B-Instruct-4bit"`.
3. Add a migration: if `localLLMTier` exists in AppStorage, map "8b" → Qwen 7B ID, "4b" → Qwen 3B ID, then delete the old key.

**In `MLXSummarizer.swift`:**

1. Replace `static func modelID(for tier: String)` with direct use of `SettingsStore.shared.localLLMModelID`.
2. Remove the RAM-based auto-selection logic (the user now picks explicitly from the browser).

**In `WhisperKitTranscriber.swift`:**

1. Replace hardcoded `modelName = "large-v3"` with `SettingsStore.shared.whisperModel`.

**In `SettingsView.swift`:**

Replace the `Picker("Summary model", ...)` block with a `ModelBrowserSection`:

```swift
Section {
    // Transcription model
    Text("Transcription").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
    ModelCard(id: "large-v3", name: "Whisper large-v3", tag: "Most accurate", size: "~1.5 GB", selected: $settings.whisperModel)
    ModelCard(id: "small", name: "Whisper small", tag: "Fast & light", size: "~244 MB", selected: $settings.whisperModel)

    Divider().padding(.vertical, 4)

    // Summary model
    Text("Summary").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
    ModelCard(id: "mlx-community/Qwen2.5-7B-Instruct-4bit", name: "Qwen 2.5 7B", tag: "Bilingual best", size: "~4.2 GB", selected: $settings.localLLMModelID)
    ModelCard(id: "mlx-community/Qwen2.5-3B-Instruct-4bit", name: "Qwen 2.5 3B", tag: "Light & fast", size: "~1.8 GB", selected: $settings.localLLMModelID)
    ModelCard(id: "mlx-community/Meta-Llama-3.1-8B-Instruct-4bit", name: "Llama 3.1 8B", tag: "Long context", size: "~4.5 GB", selected: $settings.localLLMModelID)
    ModelCard(id: "mlx-community/DeepSeek-R1-Distill-Qwen-7B-4bit", name: "DeepSeek R1 7B", tag: "Deep reasoning", size: "~4.5 GB", selected: $settings.localLLMModelID)
} header: {
    Text("On-device models")
}
```

**Create `ModelCard` view** in `DesignSystem.swift` or inline in `SettingsView.swift`:

```swift
struct ModelCard: View {
    let id: String
    let name: String
    let tag: String
    let size: String
    @Binding var selected: String

    var isSelected: Bool { selected == id }

    var body: some View {
        HStack(spacing: 10) {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? Color(nsColor: .systemBlue) : .secondary)
                .imageScale(.small)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                    Text(tag)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .systemBlue).opacity(0.1))
                        .foregroundColor(Color(nsColor: .systemBlue))
                        .clipShape(Capsule())
                }
                Text(size)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedControlColor).opacity(0.3) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selected = id
        }
    }
}
```

---

## Requirement 3: Help / Readme Toggle

### Desired Behavior
Add a small help button in the popover header that opens a brief help panel explaining how to use Glyph and key caveats.

### Implementation

**In `ContentView.swift` — HeaderView:**

Add a question-mark help button next to the gear/settings button:

```swift
Button(action: { showingHelp.toggle() }) {
    Image(systemName: "questionmark.circle")
        .imageScale(.medium)
}
.buttonStyle(GhostButtonStyle())
.accessibilityLabel("Help")
```

Add `@State private var showingHelp = false` to `ContentView` and attach a sheet:

```swift
.sheet(isPresented: $showingHelp) {
    HelpView()
}
```

**Create `HelpView.swift` in `MeetRecorder/UI/`:**

```swift
import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("How to use Glyph")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpSection(title: "Start Recording", text: "Click the red record button or press the global shortcut. Glyph captures both your microphone and system audio.")

                    helpSection(title: "Stop & Process", text: "Click stop or press the shortcut again. Glyph transcribes and summarizes the meeting automatically.")

                    helpSection(title: "Find Your Notes", text: "Processed meetings appear in the Recent list. Click the arrow to open the vault folder in Finder.")

                    Divider()

                    helpSection(title: "Caveats", text: "On-device transcription handles Cantonese acceptably but may miss nuanced slang. For mission-critical translations, consider enabling a cloud API in Settings. First run downloads ~6 GB of models on Wi-Fi only.")

                    helpSection(title: "Privacy", text: "In on-device mode, zero audio or text leaves your Mac. Cloud mode sends data to OpenAI / Anthropic only when explicitly enabled.")
                }
                .padding(20)
            }

            Spacer()
        }
        .frame(width: 400, height: 420)
    }

    private func helpSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

---

## Requirement 4: Local Model as Default — Cloud Optional

### Problem
Currently `offlineMode` defaults to `false` and `isConfigured` requires both OpenAI and Anthropic API keys. The app is unusable out-of-the-box without cloud keys.

### Desired Behavior
- **Local mode is the default.** Users download and run immediately.
- **Cloud API is an optional enhancement.** Add keys in Settings if you want higher quality (especially for nuanced Cantonese).
- **A small caveat note** in Settings explains the value of cloud (better nuanced translation) but does not push users toward it.
- **Recording is not blocked** when local models are not yet downloaded — instead show a download prompt.

### Implementation

**In `SettingsStore.swift`:**

1. Change `@AppStorage("offlineMode") var offlineMode: Bool = false` → `= true`.
2. Change `isConfigured` logic:

```swift
var isConfigured: Bool {
    // Local mode is always "configured" as a concept; readiness is handled by ModelManager.
    // Cloud mode requires keys.
    if offlineMode { return true }
    return !openAIKey.isEmpty && !anthropicKey.isEmpty
}

/// True if the user has explicitly chosen to use cloud APIs (either by disabling offline mode or adding keys).
var usesCloudAPI: Bool {
    !offlineMode && !openAIKey.isEmpty && !anthropicKey.isEmpty
}
```

**In `ContentView.swift` — ConfigurationBanner:**

Update the banner logic:

```swift
struct ConfigurationBanner: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @StateObject private var models = ModelManager.shared

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: models.whisper == .ready && models.llm == .ready
                  ? "checkmark.circle.fill"
                  : "arrow.down.circle.fill")
                .foregroundColor(models.whisper == .ready && models.llm == .ready
                                 ? Color(nsColor: .systemGreen)
                                 : Color(nsColor: .systemBlue))
                .imageScale(.small)
                .accessibilityHidden(true)

            Text(models.whisper == .ready && models.llm == .ready
                 ? "Ready to record — on-device."
                 : "Download on-device models to begin.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .systemBlue).opacity(0.08))
        )
        .padding(.horizontal, 16)
    }
}
```

**In `ContentView.swift` — IdleView:**

Remove `.disabled(!SettingsStore.shared.isConfigured)` from the Start Recording button. Instead, if models are not ready, trigger model download before starting:

```swift
Button(action: {
    let models = ModelManager.shared
    if models.whisper != .ready || models.llm != .ready {
        models.prepareAll()
    } else {
        recordingManager.startRecording()
    }
}) {
    Label(models.whisper == .ready && models.llm == .ready
          ? "Start Recording"
          : "Download Models",
          systemImage: models.whisper == .ready && models.llm == .ready
          ? "record.circle"
          : "arrow.down.circle")
        .font(.system(size: 13, weight: .semibold))
        .frame(maxWidth: .infinity)
        .frame(height: 32)
}
.buttonStyle(RecordButtonStyle())
```

**In `SettingsView.swift` — reorder and reframe sections:**

1. Move the "On-device models" section to the **top** of the form. It is now the primary configuration.
2. Move the "API Keys (cloud mode)" section to the **bottom**. Add a subtle descriptive text:

```swift
Section {
    SecureField("OpenAI API Key", text: $settings.openAIKey)
    SecureField("Anthropic API Key", text: $settings.anthropicKey)
} header: {
    Text("Cloud enhancement (optional)")
        .font(.system(size: 10, fontWeight: .semibold))
        .tracking(0.5)
} footer: {
    Text("Cloud APIs improve nuanced translation — especially Cantonese slang and idioms. Not required for most meetings.")
        .font(.system(size: 11))
        .foregroundColor(.secondary)
}
```

3. Remove or de-emphasize the `Toggle("On-device mode", ...)` — since local is now the default and only mode unless cloud keys are added. Alternatively, keep it as a simple "Use cloud APIs when available" toggle that auto-detects if keys are present.

Simpler approach: replace the toggle with logic. If API keys are empty, the app always uses local. If keys are present, it can optionally use cloud. Add a `Toggle("Prefer cloud when keys are set", ...)` defaulting to `false`.

Actually, even simpler and cleaner: keep `offlineMode` but rename it to `@AppStorage("preferCloud") var preferCloud: Bool = false`. When `preferCloud` is true AND keys are present, use cloud. Otherwise always local. This removes the cognitive burden of "modes" and frames cloud as an opt-in enhancement.

**Migration plan for `preferCloud`:**
- Read old `offlineMode` key. If it was `false`, set `preferCloud = true` and delete old key.
- Default `preferCloud = false`.

Update `RecordingManager.processAudio`:

```swift
let useCloud = settings.preferCloud && !settings.openAIKey.isEmpty && !settings.anthropicKey.isEmpty
let transcriber: Transcriber = useCloud ? whisperService : localTranscriber
let summarizer: Summarizer = useCloud ? claudeService : localSummarizer
```

---

## Requirement 5: File Structure Updates

1. Create `MeetRecorder/UI/HelpView.swift`.
2. Update `MeetRecorder/UI/DesignSystem.swift` — add `ModelCard` view.
3. Update `MeetRecorder/UI/ContentView.swift` — add help button, update banner, update idle button.
4. Update `MeetRecorder/UI/SettingsView.swift` — replace model picker with model browser, reorder sections.
5. Update `MeetRecorder/Utils/SettingsStore.swift` — default changes, rename keys, migration.
6. Update `MeetRecorder/AI/MLXSummarizer.swift` — use model ID directly.
7. Update `MeetRecorder/AI/WhisperKitTranscriber.swift` — use selectable model.
8. Update `MeetRecorder/Audio/RecordingManager.swift` — use `preferCloud` logic.
9. Rewrite `MeetRecorder/MeetRecorderApp.swift` — manual `NSPopover` + `NSStatusItem`.

---

## Design Constraints

- Keep the 360 px popover width.
- Use only NSColor semantic colors (no hardcoded hex except the recording red).
- SF Pro typography only.
- All buttons must have accessibility labels.
- The 4 px baseline grid from DESIGN.md still applies.
