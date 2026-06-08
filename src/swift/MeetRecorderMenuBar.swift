import Cocoa

// MARK: - Meeting Recorder Menu Bar App
//
// Production-hardened rewrite. Key fixes over the original:
//  - No retain cycle: Timer uses [weak self] and is invalidated on terminate.
//  - All UI mutation happens on the main thread.
//  - Recording-state detection is centralized, race-tolerant, and cached so the
//    1 Hz poll and the click handlers agree on a single source of truth.
//  - Process launch is wrapped in do/catch (Process.run throws on modern macOS;
//    the deprecated .launch() crashes on failure). Failures surface as an alert.
//  - Background Music absence is detected up front and the user is warned instead
//    of silently producing an empty/one-sided recording.
//  - Version-safe icon: SF Symbol template image on macOS 11+, emoji fallback below.
//  - SIGTERM/atexit handler stops any in-flight recording so we don't orphan the
//    Python recorder (which would leave the system output stuck on Background Music).
//  - NSStatusItem is retained for the app lifetime and explicitly released on quit.

final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: Stored properties

    private var statusItem: NSStatusItem?
    private var pollTimer: Timer?

    // Menu item references (so we never index by position, which is fragile).
    private let startItem  = NSMenuItem(title: "Start Recording",
                                        action: #selector(startRecording),
                                        keyEquivalent: "r")
    private let stopItem   = NSMenuItem(title: "Stop Recording",
                                        action: #selector(stopRecording),
                                        keyEquivalent: "s")
    private let transItem  = NSMenuItem(title: "Stop & Transcribe",
                                        action: #selector(stopAndTranscribe),
                                        keyEquivalent: "t")

    // Cached recording flag, only ever read/written on the main thread.
    private var cachedRecording = false

    // Debounce flag: while a start/stop shell command is in flight we ignore
    // further clicks to avoid the rapid-double-click race (two recorders, or a
    // stop racing a start).
    private var commandInFlight = false

    // Paths (single source of truth).
    private let pidFile = "/tmp/meetrecord.pid"
    private var recordingsDir: String { NSHomeDirectory() + "/Desktop/recordings" }

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        let menu = NSMenu()
        // Keep selectors pointed at self; positions no longer matter.
        startItem.target = self
        stopItem.target = self
        transItem.target = self
        menu.addItem(startItem)
        menu.addItem(stopItem)
        menu.addItem(transItem)
        menu.addItem(NSMenuItem.separator())

        let openItem = NSMenuItem(title: "Open Recordings Folder",
                                  action: #selector(openRecordings),
                                  keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu

        refreshState()           // initial paint
        startPolling()

        // Stop any in-flight recording if the process is killed (SIGTERM) or
        // exits normally. atexit covers normal terminate(); the signal source
        // covers SIGTERM/SIGINT without using async-unsafe APIs in a handler.
        installTerminationGuards()
    }

    func applicationWillTerminate(_ notification: Notification) {
        teardown()
    }

    private func teardown() {
        pollTimer?.invalidate()
        pollTimer = nil
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    // MARK: Polling

    private func startPolling() {
        // [weak self] breaks the Timer -> closure -> self retain cycle.
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
        // Keep firing while menus are tracking / during run-loop modal states.
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    // MARK: Recording-state detection (single source of truth)

    /// Reads the PID file and checks the process is alive. Pure function, no UI.
    private func isRecording() -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: pidFile),
              let raw = try? String(contentsOfFile: pidFile, encoding: .utf8) else {
            return false
        }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let pid = Int32(trimmed), pid > 0 else {
            return false
        }
        // kill(pid, 0): 0 == alive & signalable; errno EPERM also means it exists.
        if kill(pid, 0) == 0 { return true }
        return errno == EPERM
    }

    /// Recompute state and repaint UI. Always marshals onto the main thread.
    private func refreshState() {
        let recording = isRecording()
        let apply = { [weak self] in
            guard let self else { return }
            self.cachedRecording = recording
            self.render(recording: recording)
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    // MARK: Rendering

    private func render(recording: Bool) {
        guard let button = statusItem?.button else { return }

        if #available(macOS 11.0, *) {
            let symbolName = recording ? "record.circle.fill" : "record.circle"
            let desc = recording ? "Recording" : "Idle"
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: desc) {
                image.isTemplate = true   // tint follows menu-bar appearance (dark/light)
                button.image = image
                button.title = ""
            } else {
                // SF Symbol unexpectedly unavailable: fall back to text.
                button.image = nil
                button.title = recording ? "● REC" : "○"
            }
        } else {
            // Pre-Big Sur: no systemSymbolName. Use a plain glyph.
            button.image = nil
            button.title = recording ? "● REC" : "○"
        }

        button.toolTip = recording ? "Recording in progress — click to stop" : "Not recording"

        startItem.title = recording ? "Recording Active" : "Start Recording"
        startItem.isEnabled = !recording && !commandInFlight
        stopItem.isEnabled  = recording && !commandInFlight
        transItem.isEnabled = recording && !commandInFlight
    }

    // MARK: Actions

    @objc private func startRecording() {
        // Guard against double-clicks and starting while already recording.
        guard !commandInFlight, !cachedRecording else { return }

        if !backgroundMusicAvailable() {
            let proceed = warnBackgroundMusicMissing()
            if !proceed { return }
        }
        runShell("meetrecord", actionLabel: "start recording")
    }

    @objc private func stopRecording() {
        guard !commandInFlight, cachedRecording else { return }
        runShell("meetstop", actionLabel: "stop recording")
    }

    @objc private func stopAndTranscribe() {
        guard !commandInFlight, cachedRecording else { return }
        runShell("meetstop --transcribe", actionLabel: "stop & transcribe")
    }

    @objc private func openRecordings() {
        let fm = FileManager.default
        let path = recordingsDir
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true)
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: Background Music detection

    /// True if a process named "Background Music" is running (pgrep -x).
    private func backgroundMusicAvailable() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "Background Music"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            // If we can't even run pgrep, don't block the user; assume present.
            return true
        }
    }

    /// Returns true if the user chose to proceed anyway.
    private func warnBackgroundMusicMissing() -> Bool {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Background Music not running"
        alert.informativeText = """
        System audio is captured through the Background Music virtual device, \
        which does not appear to be running. If you continue, the recording may \
        contain only your microphone (no call/system audio).

        Launch Background Music first for a full dual-channel recording.
        """
        alert.addButton(withTitle: "Record Anyway")
        alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    // MARK: Shell execution

    /// Returns the project root: MEETRECORDER_ROOT env var, or ~/Projects/meetrecorder, or ~/bin fallback.
    private var projectRoot: String {
        if let env = ProcessInfo.processInfo.environment["MEETRECORDER_ROOT"],
           !env.isEmpty {
            return env
        }
        let fallback = NSHomeDirectory() + "/Projects/meetrecorder"
        let fm = FileManager.default
        if fm.fileExists(atPath: fallback + "/bin/meetrecord") {
            return fallback
        }
        return NSHomeDirectory() + "/bin"
    }

    /// Runs a user-bin command via login-like PATH. Async; repaints on completion.
    private func runShell(_ command: String, actionLabel: String) {
        commandInFlight = true
        render(recording: cachedRecording)   // disable menu items immediately

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        let root = projectRoot
        let home = NSHomeDirectory()
        task.arguments = ["-lc", "export PATH=\"\(root)/bin:\(home)/bin:$PATH\"; \(command)"]
        task.standardOutput = FileHandle.nullDevice
        // Redirect stderr to a log file so errors are visible for debugging.
        let logPath = "\(home)/Desktop/recordings/menubar.log"
        let fm = FileManager.default
        let recordingsDir = "\(home)/Desktop/recordings"
        if !fm.fileExists(atPath: recordingsDir) {
            try? fm.createDirectory(atPath: recordingsDir, withIntermediateDirectories: true)
        }
        if !fm.fileExists(atPath: logPath) {
            fm.createFile(atPath: logPath, contents: nil, attributes: nil)
        }
        if let fh = FileHandle(forWritingAtPath: logPath) {
            _ = fh.seekToEndOfFile()
            task.standardError = fh
        }

        // Re-enable + repaint when the helper finishes. Hop to main thread.
        task.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.commandInFlight = false
                self.refreshState()
            }
        }

        do {
            try task.run()
        } catch {
            commandInFlight = false
            refreshState()
            presentError("Could not \(actionLabel)",
                         detail: error.localizedDescription)
        }
    }

    private func presentError(_ message: String, detail: String) {
        let apply = {
            let alert = NSAlert()
            alert.alertStyle = .critical
            alert.messageText = message
            alert.informativeText = detail
            alert.addButton(withTitle: "OK")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    // MARK: Termination guards

    private func installTerminationGuards() {
        // Normal quit path.
        registerAtExit { [weak self] in
            // atexit runs on the thread calling exit(); keep it minimal & sync.
            self?.stopRecordingSynchronously()
        }

        // SIGTERM (e.g. `kill` / logout). Use a GCD signal source so the actual
        // work runs on a normal queue, not inside an async-signal-unsafe handler.
        signal(SIGTERM, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        src.setEventHandler { [weak self] in
            self?.stopRecordingSynchronously()
            self?.teardown()
            NSApp.terminate(nil)
        }
        src.resume()
        sigtermSource = src
    }

    private var sigtermSource: DispatchSourceSignal?

    /// Best-effort synchronous stop used on the way out. Restores audio output.
    private func stopRecordingSynchronously() {
        guard isRecording() else { return }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        let root = projectRoot
        let home = NSHomeDirectory()
        task.arguments = ["-lc", "export PATH=\"\(root)/bin:\(home)/bin:$PATH\"; meetstop"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            // Nothing more we can do at exit; swallow.
        }
    }
}

// Small helper so we can pass a Swift closure to atexit (which is C and takes a
// bare function pointer). We stash the closure in a global and register a trampoline.
private var _atexitClosure: (() -> Void)?
private func registerAtExit(_ body: @escaping () -> Void) {
    _atexitClosure = body
    atexit {
        _atexitClosure?()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
app.setActivationPolicy(.accessory)   // menu-bar only, no Dock icon
let delegate = AppDelegate()
app.delegate = delegate
app.run()
