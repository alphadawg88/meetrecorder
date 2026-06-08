import Foundation

actor ClaudeService {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func process(transcript: String, targetLanguage: String, meetingTitle: String) async throws -> AIOutput {
        let settings = await SettingsStore.shared
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(settings.anthropicKey, forHTTPHeaderField: "x-api-key")

        let languageInstruction = targetLanguage == "zh"
            ? "Use Traditional Chinese for Cantonese context, Simplified Chinese for Mandarin context."
            : "Use English."

        let systemPrompt = """
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

        let payload: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 8192,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": "Meeting Title: \(meetingTitle)

Transcript:
\(transcript)"]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown"
            throw ClaudeError.apiError(text)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let first = content.first,
              let text = first["text"] as? String else {
            throw ClaudeError.parseError
        }

        let cleanJSON = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let outputData = cleanJSON.data(using: .utf8)!
        return try JSONDecoder().decode(AIOutput.self, from: outputData)
    }
}

enum ClaudeError: Error {
    case apiError(String)
    case parseError
}
