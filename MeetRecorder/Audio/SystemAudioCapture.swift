import ScreenCaptureKit
import AVFoundation

actor SystemAudioCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var audioInput: AVAssetWriterInput?
    private let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("system_\(UUID().uuidString).m4a")
    private var isReady = false

    func start() async throws {
        let content = try await SCShareableContent.current
        guard let display = content.displays.first else {
            throw CaptureError.noDisplay
        }

        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        assetWriter = try AVAssetWriter(url: tempURL, fileType: .m4a)
        let outputSettings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        audioInput?.expectsMediaDataInRealTime = true
        if let input = audioInput { assetWriter?.add(input) }
        assetWriter?.startWriting()

        stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream?.addStreamOutput(self, type: .audio, sampleHandlerQueue: .global())
        try await stream?.startCapture()
    }

    func stop() -> URL {
        stream?.stopCapture()
        audioInput?.markAsFinished()
        assetWriter?.finishWriting {}
        return tempURL
    }

    nonisolated func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio else { return }
        Task {
            await append(buffer: sampleBuffer)
        }
    }

    private func append(buffer: CMSampleBuffer) async {
        if !isReady {
            assetWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(buffer))
            isReady = true
        }
        if audioInput?.isReadyForMoreMediaData == true {
            audioInput?.append(buffer)
        }
    }
}

enum CaptureError: Error {
    case noDisplay
}
