import XCTest
import SwiftUI
import AppKit
@testable import Glyph

/// Render/snapshot eval for the floating overlay views.
///
/// WHY THIS EXISTS: the overlay is a floating NSPanel that QA never screenshots,
/// so render-only defects (text wrap / clip / truncation, blank render) escaped to
/// the user twice (v1.1.1 height clip, v1.1.2 text wrap). These tests give the loop
/// a render gate: they measure the *natural* content size the views need and assert
/// it fits the declared `OverlaySize`, and they smoke-render the real views to catch
/// blank / crashed output.
///
/// MEASUREMENT NOTE: each view applies its fixed `.frame(...)` INSIDE its own body,
/// so hosting the real view returns the clamped frame, not the natural content size.
/// We therefore measure *probes* that mirror the inner content (same real components,
/// tokens and styles) without the outer frame. The probes are documented mirrors —
/// keep them in sync with the source views they name.
@MainActor
final class OverlaySnapshotTests: XCTestCase {

    // MARK: - Natural-size helper

    /// The intrinsic size SwiftUI wants for a view, unclamped by any outer `.frame`.
    private func naturalSize<V: View>(_ view: V) -> CGSize {
        let host = NSHostingView(rootView: view)
        host.layoutSubtreeIfNeeded()
        return host.fittingSize
    }

    // MARK: - Containment: expanded recording overlay (the proven defect class)

    func test_expandedRow_recording_fitsPanel() {
        let required = expandedRowRequiredWidth(paused: false)
        XCTAssertLessThanOrEqual(
            required, OverlaySize.expanded.width,
            "Recording row needs \(required)pt but the expanded overlay is only \(OverlaySize.expanded.width)pt — content would clip/wrap."
        )
    }

    func test_expandedRow_paused_fitsPanel() {
        // Paused is the WIDEST state per the design note: "PAUSED" + "Resume" + "System".
        let required = expandedRowRequiredWidth(paused: true)
        XCTAssertLessThanOrEqual(
            required, OverlaySize.expanded.width,
            "Paused row (widest state) needs \(required)pt but the expanded overlay is only \(OverlaySize.expanded.width)pt — content would clip/wrap."
        )
    }

    /// The v1.1.2 regression, proven from layout: the paused row genuinely needs more
    /// than the OLD 248pt width (so the old size clipped it) and fits the NEW 336pt.
    /// If this ever stops holding, the guard has lost its discriminating power.
    func test_pausedRow_provenRegression_248WouldHaveClipped() {
        let required = expandedRowRequiredWidth(paused: true)
        XCTAssertGreaterThan(
            required, 248,
            "Paused row needs only \(required)pt — the old-248pt regression can no longer be demonstrated; revisit the guard."
        )
        XCTAssertLessThanOrEqual(required, OverlaySize.expanded.width)
    }

    /// Measure the expanded-row natural width using the REAL components/tokens/styles.
    /// MIRROR of `RecordingOverlay.expandedBar` — keep in sync. The real bar has a
    /// `Spacer(minLength: DS.Space.xs)` between chip and buttons; Spacer makes the
    /// HStack greedy (unbounded fittingSize), so we drop it here and add its minLength
    /// back as a constant.
    private func expandedRowRequiredWidth(paused: Bool) -> CGFloat {
        let probe = HStack(spacing: DS.Space.sm) {
            Circle().fill(DesignToken.danger).frame(width: 8, height: 8)   // indicatorDot
            VStack(alignment: .leading, spacing: 1) {
                Text(paused ? "PAUSED" : "REC")
                    .font(DesignToken.labelCaps())
                    .tracking(0.6)
                Text("1:01:01")   // widest timer (h:mm:ss), monospaced
                    .font(.system(size: 13, weight: .regular).monospacedDigit())
            }
            CaptureModeChip(source: .system, compact: true)   // widest compact label ("System")
            // Spacer(minLength: DS.Space.xs) intentionally dropped — added back below.
            Button(paused ? "Resume" : "Pause") {}
                .buttonStyle(SecondaryButtonStyle())
                .lineLimit(1)
                .fixedSize()
            Button {} label: { Text("Stop").padding(.horizontal, DS.Space.sm) }
                .buttonStyle(RecordButtonStyle())
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.horizontal, DS.Space.md)

        return naturalSize(probe).width + DS.Space.xs   // + dropped Spacer minLength
    }

    // MARK: - Containment: call-detected nudge toast

    func test_callNudge_contentFitsToast() {
        // MIRROR of CallNudgeView's inner VStack — keep in sync. Drop the actions-row
        // leading Spacer() so the content is measurable (Spacer → greedy width).
        let probe = VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: DS.Space.xs + 2) {
                Image(systemName: "mic.fill")
                    .imageScale(.small)
                    .foregroundColor(DesignToken.channelMic)
                Text("MIC ACTIVITY").labelCaps()
                    .foregroundColor(DesignToken.channelMic)
            }
            Text("Meeting in progress. Record this session?")
                .font(DesignToken.body())
                .foregroundColor(DesignToken.fgPrimary)
                .lineLimit(1)
            HStack(spacing: DS.Space.xs) {
                Button("Not now") {}.buttonStyle(GhostButtonStyle())
                Button("Record") {}.buttonStyle(RecordButtonStyle())
            }
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)

        let size = naturalSize(probe)
        XCTAssertLessThanOrEqual(
            size.width, OverlaySize.toast.width,
            "Nudge content needs \(size.width)pt wide but the toast is only \(OverlaySize.toast.width)pt — the body would truncate."
        )
        XCTAssertLessThanOrEqual(
            size.height, OverlaySize.toast.height,
            "Nudge content needs \(size.height)pt tall but the toast is only \(OverlaySize.toast.height)pt — content would clip."
        )
    }

    // MARK: - Smoke render: the REAL views must produce a non-blank image

    func test_callNudge_rendersNonBlank() throws {
        let view = CallNudgeView(onRecord: {}, onDismiss: {})
        let cg = try renderCGImage(view)
        assertNonBlank(cg, label: "CallNudgeView")
    }

    func test_recordingOverlay_rendersNonBlank() throws {
        let rm = RecordingManager()
        rm.recordingStartTime = Date(timeIntervalSinceNow: -3661)   // ~1:01:01 elapsed
        let view = RecordingOverlayView(requestSize: { _ in }).environmentObject(rm)
        let cg = try renderCGImage(view)
        assertNonBlank(cg, label: "RecordingOverlayView")
    }

    // MARK: - Render helpers

    private func renderCGImage<V: View>(_ view: V) throws -> CGImage {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        let cg = renderer.cgImage
        return try XCTUnwrap(cg, "ImageRenderer produced no image")
    }

    /// Fail if the image is fully transparent or a single flat colour (white-on-white,
    /// empty render). Draws into a known RGBA8 context and scans for alpha + variance.
    private func assertNonBlank(_ cg: CGImage, label: String) {
        let w = cg.width, h = cg.height
        XCTAssertGreaterThan(w, 0); XCTAssertGreaterThan(h, 0)
        let bytesPerRow = w * 4
        var buf = [UInt8](repeating: 0, count: bytesPerRow * h)
        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buf, width: w, height: h, bitsPerComponent: 8,
            bytesPerRow: bytesPerRow, space: cs,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return XCTFail("\(label): could not create bitmap context") }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))

        var maxAlpha: UInt8 = 0
        var rMin: UInt8 = 255, rMax: UInt8 = 0
        var gMin: UInt8 = 255, gMax: UInt8 = 0
        var bMin: UInt8 = 255, bMax: UInt8 = 0
        var i = 0
        while i < buf.count {
            let r = buf[i], g = buf[i+1], b = buf[i+2], a = buf[i+3]
            if a > maxAlpha { maxAlpha = a }
            if r < rMin { rMin = r }; if r > rMax { rMax = r }
            if g < gMin { gMin = g }; if g > gMax { gMax = g }
            if b < bMin { bMin = b }; if b > bMax { bMax = b }
            i += 4
        }
        XCTAssertGreaterThan(maxAlpha, 0, "\(label): rendered fully transparent (nothing drawn).")
        let hasVariance = (rMax > rMin) || (gMax > gMin) || (bMax > bMin)
        XCTAssertTrue(hasVariance, "\(label): rendered a single flat colour (possible white-on-white / empty).")
    }
}
