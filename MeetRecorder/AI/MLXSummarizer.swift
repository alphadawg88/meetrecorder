import Foundation
import MLX
import MLXLMCommon
import MLXLLM   // links the LLM model factory (resolved via trampoline by loadModelContainer)

/// On-device summarization via MLX (Apple Silicon GPU). Runs a quantized Qwen2.5
/// instruct model — strong English + Chinese, decent Cantonese. Cloud (Claude)
/// stays the higher-quality default; this is the private/offline path.
actor MLXSummarizer: Summarizer {
    static let shared = MLXSummarizer()

    private var container: ModelContainer?
    private var loadedModelID: String?

    /// Cap the transcript fed to the model. The KV-cache grows with context
    /// length, so an uncapped multi-hour transcript can blow GPU memory and
    /// crash. ~48k chars ≈ 12k tokens — comfortably inside Qwen2.5's window.
    private static let maxTranscriptChars = 48_000

    /// Release the loaded model and reclaim its GPU memory. Called between
    /// meetings / on memory pressure so the model isn't pinned for the whole
    /// app lifetime.
    func unload() {
        if container != nil { Log.info("MLX LLM unload: \(loadedModelID ?? "?")") }
        container = nil
        loadedModelID = nil
        MLX.GPU.clearCache()
    }

    /// Download (if needed) and load the model, reporting 0...1 download progress.
    func preload(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let id = await Self.resolvedModelID()
        if container != nil, loadedModelID == id { return }
        Log.info("MLX LLM load START: \(id)")
        container = try await loadModelContainer(id: id) { p in
            progress?(p.fractionCompleted)
        }
        loadedModelID = id
        Log.info("MLX LLM load DONE: \(id)")
    }

    func process(transcript: String, targetLanguage: String, meetingTitle: String) async throws -> AIOutput {
        try await preload()
        guard let container else { throw LocalModelError.notLoaded }

        // Trim the per-meeting KV-cache spike back down once generation finishes,
        // whether it succeeds or throws.
        defer { MLX.GPU.clearCache() }

        // Bound the context so a very long meeting can't exhaust GPU memory.
        let capped = transcript.count > Self.maxTranscriptChars
            ? String(transcript.prefix(Self.maxTranscriptChars))
            : transcript
        if capped.count < transcript.count {
            Log.warn("Transcript capped \(transcript.count) → \(capped.count) chars before LLM")
        }

        let session = ChatSession(
            container,
            instructions: SummaryPrompt.system(targetLanguage: targetLanguage),
            generateParameters: GenerateParameters(maxTokens: 4096, temperature: 0.2, repetitionPenalty: 1.1)
        )
        let answer = try await session.respond(
            to: SummaryPrompt.user(meetingTitle: meetingTitle, transcript: capped)
        )

        // Small local models occasionally wrap or malform JSON — degrade gracefully.
        do {
            return try AIOutput.parse(from: answer)
        } catch {
            return AIOutput.rawFallback(answer, transcript: transcript)
        }
    }

    private static func resolvedModelID() async -> String {
        await SettingsStore.shared.localLLMModelID
    }
}
