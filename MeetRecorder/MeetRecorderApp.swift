import SwiftUI
import KeyboardShortcuts

@main
struct MeetRecorderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var recordingManager = RecordingManager()
    @StateObject private var calendarManager = CalendarManager()

    var body: some Scene {
        MenuBarExtra("MeetRecorder", systemImage: recordingManager.isRecording ? "waveform.circle.fill" : "waveform.circle") {
            ContentView()
                .environmentObject(recordingManager)
                .environmentObject(calendarManager)
                .frame(width: 360)
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
