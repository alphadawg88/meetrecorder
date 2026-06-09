import Foundation
import MLXLMCommon
import MLXLLM   // links the LLM model factory (resolved via trampoline by loadModelContainer)

/// On-device summarization via MLX (Apple Silicon GPU). Runs a quantized Qwen2.5
/// instruct model — strong English + Chinese, decent Cantonese. Cloud (Claude)
/// stays the higher-quality default; this is the private/offline path.
actor MLXSummarizer: Summarizer {
    static let shared = MLXSummarizer()

    private var container: ModelContainer?
    private var loadedModelID: String?

    /// Download (if needed) and load the model, reporting 0...1 download progress.
    func preload(progress: (@Sendable (Double) -> Void)? = nil) async throws {
        let id = await Self.resolvedModelID()
        if container != nil, loadedModelID == id { return }
        container = try await loadModelContainer(id: id) { p in
            progress?(p.fractionCompleted)
        }
        loadedModelID = id
    }

    func process(transcript: String, targetLanguage: String, meetingTitle: String) async throws -> AIOutput {
        try await preload()
        guard let container else { throw LocalModelError.notLoaded }

        let session = ChatSession(
            container,
            instructions: SummaryPrompt.system(targetLanguage: targetLanguage),
            generateParameters: GenerateParameters(maxTokens: 4096, temperature: 0.2, repetitionPenalty: 1.1)
        )
        let answer = try await session.respond(
            to: SummaryPrompt.user(meetingTitle: meetingTitle, transcript: transcript)
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
