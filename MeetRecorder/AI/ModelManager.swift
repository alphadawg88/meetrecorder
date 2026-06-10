import Foundation
import Combine

/// Drives first-run download + readiness of the on-device models for the
/// Settings UI. The provider actors own the actual models; this just
/// orchestrates preloading and publishes status for the UI.
@MainActor
final class ModelManager: ObservableObject {
    static let shared = ModelManager()

    enum State: Equatable {
        case notReady
        case preparing(Double?)   // nil = indeterminate
        case ready
        case failed(String)
    }

    @Published var whisper: State = .notReady
    @Published var llm: State = .notReady

    var isBusy: Bool {
        if case .preparing = whisper { return true }
        if case .preparing = llm { return true }
        return false
    }

    func prepareAll() {
        Task { await prepareWhisper() }
        Task { await prepareLLM() }
    }

    func prepareWhisper() async {
        if case .preparing = whisper { return }
        whisper = .preparing(nil)   // WhisperKit download has no fine-grained progress here
        do {
            try await WhisperKitTranscriber.shared.preload()
            whisper = .ready
        } catch {
            whisper = .failed(error.localizedDescription)
        }
    }

    func prepareLLM() async {
        if case .preparing = llm { return }
        llm = .preparing(0)
        do {
            try await MLXSummarizer.shared.preload { [weak self] frac in
                Task { @MainActor in self?.llm = .preparing(frac) }
            }
            llm = .ready
        } catch {
            llm = .failed(error.localizedDescription)
        }
    }
}
