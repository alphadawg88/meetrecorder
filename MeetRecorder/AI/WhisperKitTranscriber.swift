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

    /// Download (if needed) and load the selected model. Reloads if the user
    /// changed the model in Settings. Safe to call repeatedly.
    func preload() async throws {
        let name = await SettingsStore.shared.whisperModel
        if pipe != nil, loadedModelName == name { return }
        pipe = try await WhisperKit(WhisperKitConfig(model: name, download: true))
        loadedModelName = name
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await preload()
        guard let pipe else { throw LocalModelError.notLoaded }

        let options = DecodingOptions(task: .transcribe, language: await Self.whisperLanguage())
        let results = try await pipe.transcribe(audioPath: audioURL.path, decodeOptions: options)
        return results.map(\.text)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
