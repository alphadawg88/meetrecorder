import SwiftUI
import AppKit

// MARK: - Fixed overlay sizes (per the art-direction brief — no auto-size, no jitter)

enum OverlaySize {
    static let expanded  = CGSize(width: 248, height: 64)
    static let collapsed = CGSize(width: 104, height: 30)
    static let toast     = CGSize(width: 280, height: 80)
}

// MARK: - Live recording overlay (STATE 1)
//
// Persistent-but-tiny floating panel shown ONLY while recording. Expanded shows
// status + timer + capture mode + Pause/Resume + Stop; collapses to a pill after
// 6s of no interaction; a paused take freezes the clock and never auto-collapses.

struct RecordingOverlayView: View {
    @EnvironmentObject var recordingManager: RecordingManager
    @AppStorage("audioSource") private var audioSource: AudioSource = .both
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Ask the host NSPanel to resize to a fixed size, keeping its corner anchored.
    let requestSize: (CGSize) -> Void

    @State private var expanded = true
    @State private var hovering = false
    @State private var collapseWork: DispatchWorkItem?

    private var paused: Bool { recordingManager.isPaused }

    var body: some View {
        Group {
            if expanded {
                expandedBar
            } else {
                collapsedPill
            }
        }
        .frame(width: (expanded ? OverlaySize.expanded : OverlaySize.collapsed).width,
               height: (expanded ? OverlaySize.expanded : OverlaySize.collapsed).height)
        .background(
            RoundedRectangle(cornerRadius: expanded ? DesignToken.Radius.lg : DesignToken.Radius.full, style: .continuous)
                .fill(DesignToken.bgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: expanded ? DesignToken.Radius.lg : DesignToken.Radius.full, style: .continuous)
                        .strokeBorder(DesignToken.bgHover, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.72), radius: 16, x: 0, y: 8)
        )
        .contentShape(Rectangle())
        .onHover { h in
            hovering = h
            if h { cancelAutoCollapse() } else { scheduleAutoCollapse() }
        }
        .onAppear { scheduleAutoCollapse() }
        .onChange(of: expanded) { _, _ in
            requestSize(expanded ? OverlaySize.expanded : OverlaySize.collapsed)
        }
        .onChange(of: paused) { _, isPaused in
            // Paused state must stay visible — never auto-collapse while paused.
            if isPaused { expand() } else { scheduleAutoCollapse() }
        }
        .preferredColorScheme(.dark)
        .tint(DesignToken.accent)
    }

    // MARK: Expanded

    private var expandedBar: some View {
        HStack(spacing: DS.Space.sm) {
            indicatorDot
            VStack(alignment: .leading, spacing: 1) {
                Text(paused ? "PAUSED" : "REC")
                    .font(DesignToken.labelCaps())
                    .tracking(0.6)
                    // Match the state: danger red for REC (like the dot), warning
                    // amber for PAUSED — not neutral grey (the status label should
                    // read at the weight of the state it names).
                    .foregroundColor(paused ? DesignToken.warning : DesignToken.danger)
                timerText
            }
            CaptureModeChip(source: audioSource)
                .opacity(paused ? 0.4 : 1)

            Spacer(minLength: DS.Space.xs)

            Button(paused ? "Resume" : "Pause") { recordingManager.togglePause() }
                .buttonStyle(SecondaryButtonStyle())
                .contentShape(Rectangle())
                .accessibilityLabel(paused ? "Resume recording" : "Pause recording")
            Button("Stop") { recordingManager.stopRecording() }
                .buttonStyle(RecordButtonStyle())
                .contentShape(Rectangle())
                .accessibilityLabel("Stop recording")
        }
        .padding(.horizontal, DS.Space.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Glyph recording overlay")
    }

    // MARK: Collapsed

    private var collapsedPill: some View {
        HStack(spacing: DS.Space.xs) {
            indicatorDot
            timerText
        }
        .padding(.horizontal, DS.Space.sm)
        .contentShape(Rectangle())
        .onTapGesture { expand() }
        .accessibilityLabel("Glyph recording, \(timerString). Activate to expand controls.")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Shared bits

    private var indicatorDot: some View {
        Circle()
            .fill(paused ? DesignToken.warning : DesignToken.danger)
            .frame(width: 8, height: 8)
            .modifier(PulseModifier(active: !paused && !reduceMotion))
            .accessibilityHidden(true)
    }

    private var timerText: some View {
        TimelineView(.periodic(from: recordingManager.recordingStartTime ?? Date(), by: 1)) { _ in
            Text(timerString)
                .font(.system(size: expanded ? 13 : 11, weight: .regular).monospacedDigit())
                .foregroundColor(paused ? DesignToken.fgSecondary : DesignToken.fgPrimary)
        }
    }

    private var timerString: String {
        Self.format(recordingManager.elapsed())
    }

    static func format(_ total: TimeInterval) -> String {
        let s = max(0, Int(total))
        let h = s / 3600, m = (s % 3600) / 60, sec = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, sec)
                     : String(format: "%02d:%02d", m, sec)
    }

    // MARK: Auto-collapse (6s idle; never while paused or hovering)

    private func expand() {
        // Instant swap (no content animation): the SwiftUI content and the NSPanel
        // frame (onChange → requestSize) change together, so neither clips the other.
        // An animated content change inside an instantly-resized panel desyncs.
        expanded = true
        scheduleAutoCollapse()
    }

    private func scheduleAutoCollapse() {
        cancelAutoCollapse()
        guard !paused, !hovering else { return }
        let work = DispatchWorkItem {
            guard !hovering, !paused else { return }
            expanded = false
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 6, execute: work)
    }

    private func cancelAutoCollapse() {
        collapseWork?.cancel()
        collapseWork = nil
    }
}

// MARK: - Call-detected nudge (STATE 2)
//
// Transient toast shown when a call is detected and Glyph is NOT recording.
// Calm one-line nudge + Record / Not now. Auto-dismisses after 8s.

struct CallNudgeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onRecord: () -> Void
    let onDismiss: () -> Void

    // Auto-dismiss countdown (1→0 over 8s). Drives the bottom "countdown hairline".
    @State private var countdown: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            // Eyebrow — names the detection source via the channel-color system
            // (mic → channelMic). labelCaps clears AA at 5.72:1.
            HStack(spacing: DS.Space.xs + 2) {
                Image(systemName: "mic.fill")
                    .imageScale(.small)
                    .foregroundColor(DesignToken.channelMic)
                    .accessibilityHidden(true)
                Text("MIC ACTIVITY")
                    .labelCaps()
                    .foregroundColor(DesignToken.channelMic)
            }
            // Body — the offer (factual, not "looks like")
            Text("Meeting in progress. Record this session?")
                .font(DesignToken.body())
                .foregroundColor(DesignToken.fgPrimary)
                .lineLimit(1)
            // Actions — one primary (Record) + ghost dismiss
            HStack(spacing: DS.Space.xs) {
                Spacer()
                Button("Not now") { onDismiss() }
                    .buttonStyle(GhostButtonStyle())
                    .accessibilityLabel("Dismiss")
                Button("Record") { onRecord() }
                    .buttonStyle(RecordButtonStyle())
                    .accessibilityLabel("Start recording this meeting")
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .frame(width: OverlaySize.toast.width, height: OverlaySize.toast.height, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignToken.Radius.lg, style: .continuous)
                .fill(DesignToken.bgRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignToken.Radius.lg, style: .continuous)
                        .strokeBorder(DesignToken.bgHover, lineWidth: 1)
                )
                // Countdown hairline (bottom edge); omitted under reduce-motion.
                .overlay(alignment: .bottom) {
                    if !reduceMotion { countdownBar }
                }
                .clipShape(RoundedRectangle(cornerRadius: DesignToken.Radius.lg, style: .continuous))
                .shadow(color: .black.opacity(0.72), radius: 16, x: 0, y: 8)
        )
        .preferredColorScheme(.dark)
        .tint(DesignToken.accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Meeting detected via microphone activity. Record or dismiss. Auto-dismisses.")
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 8)) { countdown = 0 }
        }
    }

    // 2px depleting bar: channelMic over a bgHover track. Position = the signal
    // (the bar's the only motion; it reads "this will resolve", not "act now").
    private var countdownBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(DesignToken.bgHover)
                Rectangle().fill(DesignToken.channelMic)
                    .frame(width: max(0, geo.size.width * countdown))
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

// MARK: - Pulse (slow 1.8s; disabled under reduce-motion)

private struct PulseModifier: ViewModifier {
    let active: Bool
    @State private var on = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active && on ? 1.4 : 1.0)
            .opacity(active && on ? 0.6 : 1.0)
            .animation(active ? .easeInOut(duration: 0.9).repeatForever(autoreverses: true) : nil, value: on)
            .onAppear { if active { on = true } }
            .onChange(of: active) { _, a in on = a }
    }
}
