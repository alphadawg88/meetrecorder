import SwiftUI
import Combine
import KeyboardShortcuts

@main
struct GlyphApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible window scene — the app lives entirely in the status bar.
        Settings {
            EmptyView()
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var recordingManager = RecordingManager()
    private var calendarManager = CalendarManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        NotificationManager.register()
        KeyboardShortcuts.onKeyUp(for: .toggleRecording) {
            NotificationCenter.default.post(name: .toggleRecording, object: nil)
        }

        buildPopover()
        buildStatusItem()

        // Inject calendar manager after both are ready.
        recordingManager.inject(calendarManager: calendarManager)

        // Observe recording state to swap the status-bar icon.
        recordingManager.$isRecording
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                self?.updateStatusIcon(isRecording: isRecording)
            }
            .store(in: &cancellables)
    }

    // MARK: - Popover

    private func buildPopover() {
        popover = NSPopover()
        popover.behavior = .transient      // dismisses on click-away, stays open on inside interaction
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 520)

        let contentView = ContentView()
            .environmentObject(recordingManager)
            .environmentObject(calendarManager)

        popover.contentViewController = NSHostingController(rootView: contentView)
    }

    // MARK: - Status item

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.image = NSImage(named: "MenuBarIcon")
        button.image?.isTemplate = true
        button.action = #selector(statusItemClicked(_:))
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateStatusIcon(isRecording: Bool) {
        guard let button = statusItem.button else { return }
        if isRecording {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
            button.contentTintColor = .systemRed
        } else {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.contentTintColor = nil
        }
    }

    private var cancellables = Set<AnyCancellable>()
}

extension Notification.Name {
    static let toggleRecording = Notification.Name("toggleRecording")
}

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}
