import Foundation

actor WhisperService: Transcriber {
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    func transcribe(audioURL: URL) async throws -> String {
        let openAIKey = await SettingsStore.shared.openAIKey
        let sourceLanguage = await SettingsStore.shared.sourceLanguage
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let crlf = "\r\n"
        var body = Data()
        func append(_ string: String) {
            body.append(string.data(using: .utf8)!)
        }

        // model field
        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)")
        append("whisper-1\(crlf)")

        // optional language field
        if sourceLanguage != "auto" {
            append("--\(boundary)\(crlf)")
            append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)")
            append("\(sourceLanguage)\(crlf)")
        }

        // response_format field
        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"response_format\"\(crlf)\(crlf)")
        append("text\(crlf)")

        // file field
        let audioData = try Data(contentsOf: audioURL)
        append("--\(boundary)\(crlf)")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\(crlf)")
        append("Content-Type: audio/m4a\(crlf)\(crlf)")
        body.append(audioData)
        append(crlf)
        append("--\(boundary)--\(crlf)")

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let text = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperError.apiError(text)
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}

enum WhisperError: Error {
    case apiError(String)
}
