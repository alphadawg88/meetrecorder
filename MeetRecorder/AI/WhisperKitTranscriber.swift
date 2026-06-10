import Foundation
import WhisperKit

/// On-device transcription via WhisperKit (Core ML / Apple Neural Engine).
/// Uses large-v3 — the only Whisper variant that handles Cantonese (`yue`)
/// acceptably; turbo/small regress badly on Cantonese. The model is fetched
/// once on first use and cached.
actor WhisperKitTranscriber: Transcriber {
    static let shared = WhisperKitTranscriber()

    private var pipe: WhisperKit?
    private var loadedModelName: String?

    var isLoaded: Bool { pipe != nil }

    /// Release the Whisper model so it isn't held resident while the (larger)
    /// LLM runs, and between meetings. Reloads lazily on next transcribe.
    func unload() {
        if pipe != nil { Log.info("Whisper unload: \(loadedModelName ?? "?")") }
        pipe = nil
        loadedModelName = nil
    }

    /// Download (if needed) and load the selected model. Reloads if the user
    /// changed the model in Settings. Safe to call repeatedly.
    func preload() async throws {
        let name = await SettingsStore.shared.whisperModel
        if pipe != nil, loadedModelName == name { return }
        Log.info("Whisper load START: \(name)")
        pipe = try await WhisperKit(WhisperKitConfig(model: name, download: true))
        loadedModelName = name
        Log.info("Whisper load DONE: \(name)")
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await preload()
        guard let pipe else { throw LocalModelError.notLoaded }

        let forcedLanguage = await Self.whisperLanguage()   // nil = auto
        let options = DecodingOptions(
            task: .transcribe,                       // keep source language (don't translate)
            language: forcedLanguage,
            // When no language is forced, detect it — and with VAD chunking this
            // happens per speech chunk, which is the best Whisper can do for
            // mixed English/Chinese (code-switching) audio.
            detectLanguage: forcedLanguage == nil,
            skipSpecialTokens: true,                 // strip <|...|> control tokens
            withoutTimestamps: true,
            suppressBlank: true,                     // don't emit leading blanks
            // Anti-hallucination thresholds (WhisperKit defaults, set explicitly):
            compressionRatioThreshold: 2.4,          // catches repetition ("Mima mima…")
            logProbThreshold: -1.0,                  // retries low-confidence windows
            noSpeechThreshold: 0.6,                  // skip non-speech
            // KEY: VAD chunking only runs the model on detected speech, so silent
            // stretches no longer hallucinate [BLANK_AUDIO]/[Silence]/filler.
            chunkingStrategy: .vad
        )
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)
        let text = results.map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return Self.cleanArtifacts(text)
    }

    /// Strip residual non-speech artifacts Whisper sometimes emits as literal text
    /// (so they don't pollute the transcript or mislead the summarizer).
    private static func cleanArtifacts(_ text: String) -> String {
        let patterns = ["\\[BLANK_AUDIO\\]", "\\[Silence\\]", "\\[ ?Silence ?\\]",
                        "\\[Pause\\]", "\\[ ?Pause ?\\]", "\\(speaking in foreign language\\)",
                        "\\[speaking in foreign language\\]"]
        var out = text
        for p in patterns {
            out = out.replacingOccurrences(of: p, with: "", options: [.regularExpression, .caseInsensitive])
        }
        // Collapse the whitespace those removals leave behind.
        out = out.replacingOccurrences(of: " +", with: " ", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Map the app's source-language setting to a Whisper language code.
    /// Cantonese auto-detect is unreliable (misclassified as Mandarin), so we
    /// force `yue` when the user selects Cantonese.
    private static func whisperLanguage() async -> String? {
        switch await SettingsStore.shared.sourceLanguage {
        case "en":    return "en"
        case "zh-HK": return "yue"
        case "zh-CN": return "zh"
        default:      return nil   // auto-detect (English / Mandarin)
        }
    }
}

enum LocalModelError: Error, LocalizedError {
    case notLoaded

    var errorDescription: String? {
        switch self {
        case .notLoaded: return "On-device model is not loaded yet."
        }
    }
}
