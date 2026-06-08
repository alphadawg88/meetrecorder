import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("openAIKey") var openAIKey: String = ""
    @AppStorage("anthropicKey") var anthropicKey: String = ""
    @AppStorage("vaultPath") var vaultPath: String = ""
    @AppStorage("targetLanguage") var targetLanguage: String = "en"
    @AppStorage("sourceLanguage") var sourceLanguage: String = "auto"
    @AppStorage("calendarReminders") var calendarReminders: Bool = true
    @AppStorage("autoStop") var autoStop: Bool = false
    @AppStorage("globalShortcutEnabled") var globalShortcutEnabled: Bool = true

    // On-device / Offline processing (cloud remains the default).
    @AppStorage("offlineMode") var offlineMode: Bool = false
    // Local LLM size tier: "auto" (pick by RAM), "8b", or "4b".
    @AppStorage("localLLMTier") var localLLMTier: String = "auto"

    var vaultURL: URL {
        if vaultPath.isEmpty {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return docs.appendingPathComponent("GlyphVault")
        }
        return URL(fileURLWithPath: vaultPath)
    }

    var isConfigured: Bool {
        !openAIKey.isEmpty && !anthropicKey.isEmpty
    }
}
