import AVFoundation

actor MicrophoneCapture {
    private var recorder: AVAudioRecorder?
    // Fresh file per recording so back-to-back sessions don't overwrite each other.
    private var tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mic_\(UUID().uuidString).caf")

    func start() async throws {
        tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("mic_\(UUID().uuidString).caf")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatAppleLossless),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        recorder = try AVAudioRecorder(url: tempURL, settings: settings)
        recorder?.record()
    }

    /// Pause/resume the mic. AVAudioRecorder.pause() halts encoding; record()
    /// resumes appending to the SAME file, so the take stays continuous.
    func setPaused(_ paused: Bool) {
        if paused { recorder?.pause() } else { recorder?.record() }
    }

    func stop() -> URL {
        recorder?.stop()
        return tempURL
    }
}
