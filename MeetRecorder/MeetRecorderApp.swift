import SwiftUI
import Combine
import KeyboardShortcuts
import MLX

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
    private let callDetector = CallDetector()
    // Ticks every second while recording to advance the menu-bar elapsed timer.
    private var menuTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        Log.rotateIfNeeded()
        Log.installExceptionHandler()
        Log.info("Glyph launched — log at ~/Library/Logs/Glyph/glyph.log")
        Self.configureMLXMemory()
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
            .sink { [weak self] isRecording, _ in
                self?.handleStateChange(isRecording: isRecording)
            }
            .store(in: &cancellables)

        configureCallDetector()
    }

    // MARK: - Call detection

    /// Offer to record when any app starts using the mic (a call begins). The
    /// detector is app-agnostic; we gate the prompt on the user's setting and on
    /// Glyph not already being busy (so our own recording never self-prompts).
    private func configureCallDetector() {
        callDetector.isBusy = { [weak self] in
            guard let self else { return true }
            return self.recordingManager.isRecording || !self.recordingManager.processingStage.isEmpty
        }
        callDetector.onCallLikelyStarted = {
            guard SettingsStore.shared.callDetectEnabled else { return }
            NotificationManager.notifyWithStartAction(
                title: "You're in a call",
                body: "Want Glyph to record it? You can dismiss this.",
                identifier: "call-detected"
            )
        }
        callDetector.start()
    }

    // MARK: - MLX memory guard

    /// Cap MLX's GPU buffer cache and overall wired-memory ceiling so on-device
    /// inference can't balloon unified memory and take the whole system down.
    /// Without these, MLX's Metal cache grows unbounded — the dominant cause of
    /// the app inducing system-wide memory pressure on long meetings.
    private static func configureMLXMemory() {
        // Trim the reusable GPU buffer cache aggressively (512 MB).
        MLX.GPU.set(cacheLimit: 512 * 1024 * 1024)
        // Hard ceiling at ~65% of physical RAM so MLX fails gracefully instead
        // of evicting the OS. `relaxed: false` makes allocations past the limit
        // throw rather than over-commit.
        let physical = ProcessInfo.processInfo.physicalMemory
        let ceiling = Int(Double(physical) * 0.65)
        MLX.GPU.set(memoryLimit: ceiling, relaxed: false)
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

    /// Drive the menu-bar ticking timer: run a 1 s timer only while recording, and
    /// refresh the icon immediately on every state change.
    private func handleStateChange(isRecording: Bool) {
        if isRecording {
            if menuTimer == nil {
                menuTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                    Task { @MainActor in self?.refreshStatusIcon() }
                }
            }
        } else {
            menuTimer?.invalidate()
            menuTimer = nil
        }
        refreshStatusIcon()
    }

    private func refreshStatusIcon() {
        let stage = recordingManager.processingStage
        updateStatusIcon(
            isRecording: recordingManager.isRecording,
            processingStage: stage,
            progress: RecordingManager.progress(for: stage)
        )
    }

    private func updateStatusIcon(isRecording: Bool, processingStage: String, progress: Double) {
        guard let button = statusItem.button else { return }
        let isProcessing = !processingStage.isEmpty
        let monoFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)

        if isRecording {
            // Recording: waveform icon + ticking MM:SS in the DS danger red (#FF4444).
            let red = NSColor(hex: "FF4444")
            let elapsed = Self.elapsedString(since: recordingManager.recordingStartTime)
            button.image = NSImage(systemSymbolName: "waveform.circle.fill", accessibilityDescription: "Recording")
            button.contentTintColor = red
            button.attributedTitle = NSAttributedString(
                string: " \(elapsed)",
                attributes: [.font: monoFont, .foregroundColor: red]
            )
            button.toolTip = "Glyph — Recording (\(elapsed))"
        } else if isProcessing {
            // Processing: distinct ellipsis icon + N% in the DS warning amber (#FFAB00).
            let amber = NSColor(hex: "FFAB00")
            button.image = NSImage(systemSymbolName: "ellipsis.circle.fill", accessibilityDescription: "Processing")
            button.contentTintColor = amber
            button.attributedTitle = NSAttributedString(
                string: " \(Int(progress * 100))%",
                attributes: [.font: monoFont, .foregroundColor: amber]
            )
            button.toolTip = processingStage
        } else {
            button.image = NSImage(named: "MenuBarIcon")
            button.image?.isTemplate = true
            button.contentTintColor = nil
            button.attributedTitle = NSAttributedString(string: "")
            button.title = ""
            button.toolTip = nil
        }
    }

    private static func elapsedString(since start: Date?) -> String {
        guard let start else { return "00:00" }
        let total = max(0, Int(Date().timeIntervalSince(start)))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    private var cancellables = Set<AnyCancellable>()
}

extension Notification.Name {
    static let toggleRecording = Notification.Name("toggleRecording")
}

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self("toggleRecording")
}
