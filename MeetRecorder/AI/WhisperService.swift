import Foundation

actor WhisperService {
    private let endpoint = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

    func transcribe(audioURL: URL) async throws -> String {
        let settings = await SettingsStore.shared
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(settings.openAIKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)
".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name="model"

".data(using: .utf8)!)
        body.append("whisper-1
".data(using: .utf8)!)

        if let lang = settings.sourceLanguage, lang != "auto" {
            body.append("--\(boundary)
".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name="language"

".data(using: .utf8)!)
            body.append("\(lang)
".data(using: .utf8)!)
        }

        body.append("--\(boundary)
".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name="response_format"

".data(using: .utf8)!)
        body.append("text
".data(using: .utf8)!)

        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)
".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name="file"; filename="audio.m4a"
".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a

".data(using: .utf8)!)
        body.append(audioData)
        body.append("
".data(using: .utf8)!)
        body.append("--\(boundary)--
".data(using: .utf8)!)

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
