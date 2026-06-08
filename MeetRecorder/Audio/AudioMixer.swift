import AVFoundation

enum AudioMixer {
    static func mix(micURL: URL, systemURL: URL) async throws -> URL {
        let composition = AVMutableComposition()

        guard let micTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid),
              let sysTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw MixError.trackCreationFailed
        }

        let micAsset = AVURLAsset(url: micURL)
        let sysAsset = AVURLAsset(url: systemURL)

        let micDuration = try await micAsset.load(.duration)
        let sysDuration = try await sysAsset.load(.duration)
        let duration = max(CMTimeGetSeconds(micDuration), CMTimeGetSeconds(sysDuration))
        let cmDuration = CMTimeMakeWithSeconds(duration, preferredTimescale: 600)

        if let micAudioTrack = try await micAsset.loadTracks(withMediaType: .audio).first {
            try micTrack.insertTimeRange(CMTimeRange(start: .zero, duration: micDuration), of: micAudioTrack, at: .zero)
        }
        if let sysAudioTrack = try await sysAsset.loadTracks(withMediaType: .audio).first {
            try sysTrack.insertTimeRange(CMTimeRange(start: .zero, duration: sysDuration), of: sysAudioTrack, at: .zero)
        }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("mixed_\(UUID().uuidString).m4a")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw MixError.exportSessionFailed
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: .zero, duration: cmDuration)

        await exportSession.export()
        if exportSession.status == .completed {
            return outputURL
        } else {
            throw MixError.exportFailed(exportSession.error)
        }
    }
}

enum MixError: Error {
    case trackCreationFailed
    case exportSessionFailed
    case exportFailed(Error?)
}
