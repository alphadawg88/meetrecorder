import SwiftUI

/// Which audio channels to capture for a recording. Persisted; the last choice
/// stays selected until changed.
enum AudioSource: String, CaseIterable, Identifiable {
    case both, mic, system

    var id: String { rawValue }

    var label: String {
        switch self {
        case .both:   return "Both"
        case .mic:    return "Mic"
        case .system: return "System"
        }
    }

    /// Capture the local microphone (your voice).
    var capturesMic: Bool { self != .system }
    /// Capture system audio via ScreenCaptureKit (remote participants).
    var capturesSystem: Bool { self != .mic }

    var systemImage: String {
        switch self {
        case .both:   return "waveform.and.mic"
        case .mic:    return "mic"
        case .system: return "speaker.wave.2"
        }
    }

    /// Short label for the in-popover capture-mode chip.
    var chipLabel: String {
        switch self {
        case .both:   return "Mic + System"
        case .mic:    return "Mic only"
        case .system: return "System only"
        }
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("openAIKey") var openAIKey: String = ""
    @AppStorage("anthropicKey") var anthropicKey: String = ""
    @AppStorage("vaultPath") var vaultPath: String = ""
    @AppStorage("targetLanguage") var targetLanguage: String = "en"
    @AppStorage("sourceLanguage") var sourceLanguage: String = "auto"
    @AppStorage("calendarReminders") var calendarReminders: Bool = true
    @AppStorage("autoStop") var autoStop: Bool = false
    @AppStorage("globalShortcutEnabled") var globalShortcutEnabled: Bool = true

    // Which audio channels to capture: mic only, system only, or both. Defaults
    // to both (full meeting). Persisted across launches.
    @AppStorage("audioSource") var audioSource: AudioSource = .both

    // On-device is the default. Cloud APIs are an opt-in enhancement: they are
    // only used when the user prefers them AND both keys are present.
    @AppStorage("preferCloud") var preferCloud: Bool = false

    // Selected on-device transcription model (WhisperKit). large-v3 is the only
    // variant that handles Chinese / mixed English-Chinese acceptably; small &
    // turbo hallucinate badly on non-English. Worth the extra size/latency.
    @AppStorage("whisperModel") var whisperModel: String = "large-v3"
    // Selected on-device summary model (full MLX HuggingFace model id).
    // Defaults to the 3B (~2 GB resident) for a lean baseline that runs on
    // 8/16 GB Macs; users can switch to the 7B in Settings for higher quality.
    @AppStorage("localLLMModelID") var localLLMModelID: String = "mlx-community/Qwen2.5-3B-Instruct-4bit"

    private init() {
        migrate()
    }

    /// One-time migration from the old "modes & tiers" model to local-first.
    private func migrate() {
        let defaults = UserDefaults.standard

        // offlineMode → preferCloud. The old `offlineMode == false` meant the
        // user was on cloud, so that maps to `preferCloud == true`.
        if defaults.object(forKey: "offlineMode") != nil {
            let wasOffline = defaults.bool(forKey: "offlineMode")
            defaults.set(!wasOffline, forKey: "preferCloud")
            defaults.removeObject(forKey: "offlineMode")
        }

        // localLLMTier (auto / 8b / 4b) → full localLLMModelID.
        if let tier = defaults.string(forKey: "localLLMTier") {
            let qwen7B = "mlx-community/Qwen2.5-7B-Instruct-4bit"
            let qwen3B = "mlx-community/Qwen2.5-3B-Instruct-4bit"
            switch tier {
            case "4b": defaults.set(qwen3B, forKey: "localLLMModelID")
            default:   defaults.set(qwen7B, forKey: "localLLMModelID")  // "8b" / "auto" → best
            }
            defaults.removeObject(forKey: "localLLMTier")
        }
    }

    var vaultURL: URL {
        if vaultPath.isEmpty {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            return docs.appendingPathComponent("GlyphVault")
        }
        return URL(fileURLWithPath: vaultPath)
    }

    /// Local mode is always "configured" as a concept; readiness is handled by
    /// ModelManager. Cloud mode requires keys.
    var isConfigured: Bool {
        if !preferCloud { return true }
        return !openAIKey.isEmpty && !anthropicKey.isEmpty
    }

    /// True if the user has opted into cloud APIs and both keys are present.
    var usesCloudAPI: Bool {
        preferCloud && !openAIKey.isEmpty && !anthropicKey.isEmpty
    }
}
