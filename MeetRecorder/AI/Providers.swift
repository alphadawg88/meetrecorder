import Foundation

// MARK: - Provider protocols
//
// These two seams let RecordingManager swap between the cloud services
// (WhisperService / ClaudeService) and the on-device services
// (WhisperKitTranscriber / MLXSummarizer) based on the Offline-mode setting,
// without knowing which is which.

/// Produces a raw transcript from a mixed audio file.
protocol Transcriber {
    func transcribe(audioURL: URL) async throws -> String
}

/// Turns a transcript into structured meeting notes.
protocol Summarizer {
    func process(transcript: String, targetLanguage: String, meetingTitle: String) async throws -> AIOutput
}

// MARK: - Shared prompt
//
// The cloud summarizer (Claude) and the on-device summarizer (Qwen3) use the
// exact same instructions and output schema so their results are comparable.

enum SummaryPrompt {
    static func system(targetLanguage: String) -> String {
        let languageInstruction = targetLanguage == "zh"
            ? "Use Traditional Chinese for Cantonese context, Simplified Chinese for Mandarin context."
            : "Use English."
        return """
You are a world-class executive assistant specializing in meeting intelligence.
Analyze the meeting transcript and produce structured JSON.

Rules:
1. The transcript may contain English, Cantonese, and/or Mandarin. Detect languages automatically.
2. Translate and summarize into \(targetLanguage) (\(languageInstruction)).
3. Identify clear action items with owners if mentioned.
4. Output ONLY valid JSON with no markdown formatting.

Output schema:
{
  "executive_summary": "2-3 sentence summary",
  "key_takeaways": ["bullet 1", "bullet 2"],
  "action_items": [{"task": "...", "owner": "...", "due_date": "..."}],
  "detailed_notes": "Comprehensive notes by topic",
  "translated_transcript": "Full transcript translated to \(targetLanguage)"
}
"""
    }

    static func user(meetingTitle: String, transcript: String) -> String {
        """
Meeting Title: \(meetingTitle)

Transcript:
\(transcript)
"""
    }
}

// MARK: - Lenient parsing shared by both summarizers

extension AIOutput {
    /// Parse model output into `AIOutput`, tolerating ```json fences and surrounding prose.
    static func parse(from text: String) throws -> AIOutput {
        var cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // If the model wrapped the JSON in prose, extract the outermost { ... }.
        if let start = cleaned.firstIndex(of: "{"), let end = cleaned.lastIndex(of: "}"), start < end {
            cleaned = String(cleaned[start...end])
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AIOutput.self, from: Data(cleaned.utf8))
    }

    /// Last-resort fallback so a malformed on-device response still yields a usable note
    /// (raw text preserved) rather than throwing and losing the whole run.
    static func rawFallback(_ text: String, transcript: String) -> AIOutput {
        AIOutput(
            executiveSummary: "On-device model did not return structured JSON; raw response preserved in Detailed Notes.",
            keyTakeaways: [],
            actionItems: [],
            detailedNotes: text,
            translatedTranscript: transcript
        )
    }
}
