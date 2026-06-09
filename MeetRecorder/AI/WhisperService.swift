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

        // Assemble the multipart body on disk and stream the audio file in chunks,
        // so a long recording is never fully loaded into memory.
        let bodyURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("whisper_body_\(UUID().uuidString).tmp")
        FileManager.default.createFile(atPath: bodyURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: bodyURL)
        defer {
            try? handle.close()
            try? FileManager.default.removeItem(at: bodyURL)
        }
        func append(_ string: String) throws {
            // Data(string.utf8) cannot fail, unlike the previous force-unwrapped data(using:).
            try handle.write(contentsOf: Data(string.utf8))
        }

        // model field
        try append("--\(boundary)\(crlf)")
        try append("Content-Disposition: form-data; name=\"model\"\(crlf)\(crlf)")
        try append("whisper-1\(crlf)")

        // optional language field
        if sourceLanguage != "auto" {
            try append("--\(boundary)\(crlf)")
            try append("Content-Disposition: form-data; name=\"language\"\(crlf)\(crlf)")
            try append("\(sourceLanguage)\(crlf)")
        }

        // response_format field
        try append("--\(boundary)\(crlf)")
        try append("Content-Disposition: form-data; name=\"response_format\"\(crlf)\(crlf)")
        try append("text\(crlf)")

        // file field — streamed from disk
        try append("--\(boundary)\(crlf)")
        try append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\(crlf)")
        try append("Content-Type: audio/m4a\(crlf)\(crlf)")
        let audioHandle = try FileHandle(forReadingFrom: audioURL)
        while true {
            let chunk = try audioHandle.read(upToCount: 1 << 20) ?? Data()
            if chunk.isEmpty { break }
            try handle.write(contentsOf: chunk)
        }
        try? audioHandle.close()
        try append(crlf)
        try append("--\(boundary)--\(crlf)")
        try handle.close()

        let (data, response) = try await URLSession.shared.upload(for: request, fromFile: bodyURL)
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
