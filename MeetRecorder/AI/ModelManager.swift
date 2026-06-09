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
    @Published private(set) var downloadedWhisperModels: Set<String> = []
    @Published private(set) var downloadedLLMModels: Set<String> = []
    @Published private(set) var activeWhisperDownload: String? = nil
    @Published private(set) var activeLLMDownload: String? = nil

    var isBusy: Bool {
        if case .preparing = whisper { return true }
        if case .preparing = llm { return true }
        return false
    }

    init() {
        loadPersisted()
    }

    func prepareAll() {
        Task { await prepareWhisper() }
        Task { await prepareLLM() }
    }

    func prepareWhisper() async {
        if case .preparing = whisper { return }
        let name = SettingsStore.shared.whisperModel
        whisper = .preparing(nil)
        activeWhisperDownload = name
        do {
            try await WhisperKitTranscriber.shared.preload()
            downloadedWhisperModels.insert(name)
            persist()
            whisper = .ready
            activeWhisperDownload = nil
        } catch {
            whisper = .failed(error.localizedDescription)
            activeWhisperDownload = nil
        }
    }

    func prepareLLM() async {
        if case .preparing = llm { return }
        llm = .preparing(0)
        let modelID = SettingsStore.shared.localLLMModelID
        do {
            activeLLMDownload = modelID
            try await MLXSummarizer.shared.preload { [weak self] frac in
                Task { @MainActor in self?.llm = .preparing(frac) }
            }
            if !downloadedLLMModels.contains(modelID) {
                downloadedLLMModels.insert(modelID)
                persist()
            }
            llm = .ready
            activeLLMDownload = nil
        } catch {
            llm = .failed(error.localizedDescription)
            activeLLMDownload = nil
        }
    }

    func isWhisperDownloaded(_ name: String) -> Bool {
        downloadedWhisperModels.contains(name)
    }

    func isLLMDownloaded(_ id: String) -> Bool {
        downloadedLLMModels.contains(id)
    }

    func uninstallWhisper(_ name: String) {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let folder = docs.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(name)")
        try? FileManager.default.removeItem(at: folder)
        downloadedWhisperModels.remove(name)
        persist()
        if case .ready = whisper { whisper = .notReady }
    }

    func uninstallLLM(_ id: String) {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let parts = id.split(separator: "/", maxSplits: 1).map(String.init)
        let folderName = parts.count == 2 ? "models--\(parts[0])--\(parts[1])" : "models--\(id)"
        let folder = home.appendingPathComponent(".cache/huggingface/hub/\(folderName)")
        try? FileManager.default.removeItem(at: folder)
        downloadedLLMModels.remove(id)
        persist()
        if case .ready = llm { llm = .notReady }
    }

    private func loadPersisted() {
        if let whisperStr = UserDefaults.standard.string(forKey: "glyphDownloadedWhisper") {
            downloadedWhisperModels = Set(whisperStr.split(separator: ",").map(String.init))
        }
        if let llmStr = UserDefaults.standard.string(forKey: "glyphDownloadedLLM") {
            downloadedLLMModels = Set(llmStr.split(separator: ",").map(String.init))
        }

        // Prune any whisper models whose on-disk folder does not exist.
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let docs = docs {
            var toRemove = Set<String>()
            for name in downloadedWhisperModels {
                let folder = docs.appendingPathComponent("huggingface/models/argmaxinc/whisperkit-coreml/openai_whisper-\(name)")
                if !FileManager.default.fileExists(atPath: folder.path) {
                    toRemove.insert(name)
                }
            }
            downloadedWhisperModels.subtract(toRemove)
        }
    }

    private func persist() {
        let whisperStr = downloadedWhisperModels.joined(separator: ",")
        let llmStr = downloadedLLMModels.joined(separator: ",")
        UserDefaults.standard.set(whisperStr, forKey: "glyphDownloadedWhisper")
        UserDefaults.standard.set(llmStr, forKey: "glyphDownloadedLLM")
    }
}
