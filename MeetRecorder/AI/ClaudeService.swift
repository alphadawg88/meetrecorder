import Foundation

actor ClaudeService: Summarizer {
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    func process(transcript: String, targetLanguage: String, meetingTitle: String) async throws -> AIOutput {
        let anthropicKey = await SettingsStore.shared.anthropicKey
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(anthropicKey, forHTTPHeaderField: "x-api-key")

        let payload: [String: Any] = [
            "model": "claude-sonnet-4-6",
            "max_tokens": 8192,
            "system": SummaryPrompt.system(targetLanguage: targetLanguage),
            "messages": [
                ["role": "user", "content": SummaryPrompt.user(meetingTitle: meetingTitle, transcript: transcript)]
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

        return try AIOutput.parse(from: text)
    }
}

enum ClaudeError: Error {
    case apiError(String)
    case parseError
}
