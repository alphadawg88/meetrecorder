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
            guard SettingsStore.shared.globalShortcutEnabled else { return }
            NotificationCenter.default.post(name: .toggleRecording, object: nil)
        }

        buildPopover()
        buildStatusItem()

        // Inject calendar manager after both are ready.
        recordingManager.inject(calendarManager: calendarManager)

        // Request calendar access at launch.
        calendarManager.requestAccess()

        // Observe recording and processing states to update the status-bar icon + progress.
        Publishers.CombineLatest(recordingManager.$isRecording, recordingManager.$processingStage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording, stage in
                self?.updateStatusIcon(
                    isRecording: isRecording,
                    processingStage: stage,
                    progress: RecordingManager.progress(for: stage)
                )
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
        // Right-click (or control-click) opens a small menu with Quit; left-click toggles the popover.
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showContextMenu(from: button)
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Quit Glyph", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        menu.popUp(positioning: nil,
                   at: NSPoint(x: 0, y: button.bounds.height + 4),
                   in: button)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func updateStatusIcon(isRecording: Bool, processingStage: String, progress: Double) {
        guard let button = statusItem.button else { return }
        let isProcessing = !processingStage.isEmpty
        if isRecording {
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
            button.contentTintColor = .systemRed
            button.title = ""
        } else if isProcessing {
            button.image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Processing")
            button.contentTintColor = .systemOrange
            button.title = " \(Int(progress * 100))%"
            button.toolTip = processingStage
        } else {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.title = ""
            button.toolTip = nil
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
