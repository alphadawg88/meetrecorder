import AppKit
import SwiftUI
import Combine

/// Owns the floating on-screen overlays: the live-recording panel (shown only
/// while recording) and the transient call-detected nudge. Both are borderless,
/// non-activating NSPanels that float above normal windows on the active space
/// (deliberately NOT over fullscreen apps — the menu bar stays the always-on path).
@MainActor
final class OverlayController {
    private unowned let recordingManager: RecordingManager

    private var recordingPanel: NSPanel?
    private var nudgePanel: NSPanel?
    private var nudgeDismiss: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()

    private let edgeInset: CGFloat = 24
    private let positionKey = "glyphOverlayPosition"

    init(recordingManager: RecordingManager) {
        self.recordingManager = recordingManager
        // Show/hide the recording overlay as recording starts/stops.
        recordingManager.$isRecording
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] recording in
                recording ? self?.showRecordingOverlay() : self?.hideRecordingOverlay()
            }
            .store(in: &cancellables)
    }

    // MARK: - Recording overlay

    private func showRecordingOverlay() {
        guard recordingPanel == nil else { return }
        let panel = makePanel(size: OverlaySize.expanded)
        let root = RecordingOverlayView(requestSize: { [weak self] size in
            self?.resize(panel, to: size)
        })
        .environmentObject(recordingManager)
        panel.contentView = NSHostingView(rootView: root)
        positionAtAnchor(panel, size: OverlaySize.expanded)
        panel.orderFrontRegardless()
        recordingPanel = panel
    }

    private func hideRecordingOverlay() {
        if let p = recordingPanel {
            NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: p)
        }
        recordingPanel?.orderOut(nil)
        recordingPanel = nil
    }

    // MARK: - Call nudge

    /// Show the transient "meeting detected — record?" toast. Auto-dismisses in 8s.
    func showCallNudge() {
        guard nudgePanel == nil, !recordingManager.isRecording else { return }
        let panel = makePanel(size: OverlaySize.toast)
        let root = CallNudgeView(
            onRecord: { [weak self] in
                self?.dismissCallNudge()
                self?.recordingManager.startRecording()
            },
            onDismiss: { [weak self] in self?.dismissCallNudge() }
        )
        panel.contentView = NSHostingView(rootView: root)
        positionAtAnchor(panel, size: OverlaySize.toast, useSaved: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 1
        }
        nudgePanel = panel

        let work = DispatchWorkItem { [weak self] in self?.dismissCallNudge() }
        nudgeDismiss = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: work)
    }

    func dismissCallNudge() {
        nudgeDismiss?.cancel(); nudgeDismiss = nil
        guard let panel = nudgePanel else { return }
        nudgePanel = nil
        NotificationCenter.default.removeObserver(self, name: NSWindow.didMoveNotification, object: panel)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 0
        }, completionHandler: { panel.orderOut(nil) })
    }

    // MARK: - Panel factory + geometry

    private func makePanel(size: CGSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false               // SwiftUI draws the shadow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        // Persist position after the user drags the panel.
        NotificationCenter.default.addObserver(
            self, selector: #selector(panelMoved(_:)),
            name: NSWindow.didMoveNotification, object: panel
        )
        return panel
    }

    /// Resize keeping the bottom-right corner anchored (grows up + left), clamped
    /// to the visible screen so collapse/expand near an edge can't drift off-screen.
    private func resize(_ panel: NSPanel, to size: CGSize) {
        let f = panel.frame
        var newOrigin = NSPoint(x: f.maxX - size.width, y: f.minY)
        if let vis = NSScreen.main?.visibleFrame {
            newOrigin.x = min(max(newOrigin.x, vis.minX), vis.maxX - size.width)
            newOrigin.y = min(max(newOrigin.y, vis.minY), vis.maxY - size.height)
        }
        panel.setFrame(NSRect(origin: newOrigin, size: size), display: true, animate: false)
    }

    /// Place at the saved position (recording overlay only), or the bottom-right
    /// corner. The nudge toast always uses the default corner (`useSaved: false`).
    private func positionAtAnchor(_ panel: NSPanel, size: CGSize, useSaved: Bool = true) {
        guard let screen = NSScreen.main else { return }
        let vis = screen.visibleFrame
        var origin: NSPoint
        if useSaved, let saved = savedPosition() {
            origin = saved
        } else {
            origin = NSPoint(x: vis.maxX - size.width - edgeInset, y: vis.minY + edgeInset)
        }
        // Clamp into the visible frame (handles display changes / unplugged monitor).
        origin.x = min(max(origin.x, vis.minX), vis.maxX - size.width)
        origin.y = min(max(origin.y, vis.minY), vis.maxY - size.height)
        panel.setFrameOrigin(origin)
    }

    @objc private func panelMoved(_ note: Notification) {
        guard let panel = note.object as? NSWindow, panel == recordingPanel else { return }
        let o = panel.frame.origin
        UserDefaults.standard.set(["x": o.x, "y": o.y], forKey: positionKey)
    }

    private func savedPosition() -> NSPoint? {
        guard let d = UserDefaults.standard.dictionary(forKey: positionKey),
              let x = d["x"] as? CGFloat, let y = d["y"] as? CGFloat else { return nil }
        return NSPoint(x: x, y: y)
    }
}
