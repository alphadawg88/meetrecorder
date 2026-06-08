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

    var vaultURL: URL {
        if vaultPath.isEmpty {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return docs.appendingPathComponent("MeetRecorderVault")
        }
        return URL(fileURLWithPath: vaultPath)
    }

    var isConfigured: Bool {
        !openAIKey.isEmpty && !anthropicKey.isEmpty
    }
}
