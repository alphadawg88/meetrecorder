import SwiftUI
import KeyboardShortcuts

@main
struct GlyphApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var calendarManager = CalendarManager()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(recordingManager)
                .environmentObject(calendarManager)
                .frame(width: 360)
        } label: {
            // Custom template mark (auto-tinted for light/dark); the filled SF
            // Symbol signals the active/recording state.
            if recordingManager.isRecording {
                Image(systemName: "waveform.circle.fill")
            } else {
                Image("MenuBarIcon")
            }
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationManager.register()
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) {
            NotificationCenter.default.post(name: .toggleRecording, object: nil)
        }
    }
}

extension Notification.Name {
    static let toggleRecording = Notification.Name("toggleRecording")
}

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}
