import AVFoundation

enum AudioMixer {
    /// Combine the captured channels into a single m4a. Either source may be nil
    /// (mic-only / system-only); at least one must be present. The output is
    /// always m4a so the transcription path gets a consistent, cloud-compatible
    /// format regardless of which channels were captured.
    static func mix(micURL: URL?, systemURL: URL?) async throws -> URL {
        let composition = AVMutableComposition()
        var insertedAny = false

        func add(_ url: URL) async throws {
            let asset = AVURLAsset(url: url)
            let duration = try await asset.load(.duration)
            guard let sourceTrack = try await asset.loadTracks(withMediaType: .audio).first,
                  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                return
            }
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: sourceTrack, at: .zero)
            insertedAny = true
        }

        if let micURL { try await add(micURL) }
        if let systemURL { try await add(systemURL) }
        guard insertedAny else { throw MixError.trackCreationFailed }

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("mixed_\(UUID().uuidString).m4a")
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw MixError.exportSessionFailed
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a

        await exportSession.export()
        if exportSession.status == .completed {
            // Only delete the source recordings once the output is safely written —
            // otherwise a failed export would destroy the only copy of the audio.
            if let micURL { try? FileManager.default.removeItem(at: micURL) }
            if let systemURL { try? FileManager.default.removeItem(at: systemURL) }
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
