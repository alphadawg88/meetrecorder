import SwiftUI
import AppKit

// MARK: - Hex Color Helper

extension NSColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r, g, b, a: CGFloat
        switch s.count {
        case 8:
            r = CGFloat((rgb & 0xFF00_0000) >> 24) / 255
            g = CGFloat((rgb & 0x00FF_0000) >> 16) / 255
            b = CGFloat((rgb & 0x0000_FF00) >> 8) / 255
            a = CGFloat(rgb & 0x0000_00FF) / 255
        default:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255
            b = CGFloat(rgb & 0x0000FF) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Design Tokens v2.0
// Derived from DESIGN_SYSTEM.md — dark-first, Hermes Agent aesthetic.

enum DesignToken {
    // Backgrounds
    static let bgBase     = Color(nsColor: NSColor(hex: "#0A0A0A"))
    static let bgSurface  = Color(nsColor: NSColor(hex: "#111111"))
    static let bgRaised   = Color(nsColor: NSColor(hex: "#1A1A1A"))
    static let bgHover    = Color(nsColor: NSColor(hex: "#222222"))
    static let bgActive   = Color(nsColor: NSColor(hex: "#2A2A2A"))

    // Foregrounds
    static let fgPrimary   = Color(nsColor: NSColor(hex: "#E8E8E8"))
    static let fgSecondary = Color(nsColor: NSColor(hex: "#888888"))
    static let fgTertiary  = Color(nsColor: NSColor(hex: "#555555"))

    // Semantic
    static let accent       = Color(nsColor: NSColor(hex: "#A100FF"))
    static let accentHover  = Color(nsColor: NSColor(hex: "#B52AFF"))
    static let accentActive = Color(nsColor: NSColor(hex: "#8A00DB"))
    static let success      = Color(nsColor: NSColor(hex: "#00E676"))
    static let warning      = Color(nsColor: NSColor(hex: "#FFAB00"))
    static let danger       = Color(nsColor: NSColor(hex: "#FF4444"))
    static let info         = Color(nsColor: NSColor(hex: "#05F2DB"))

    // Channels
    static let channelMic    = Color(nsColor: NSColor(hex: "#FF50A0"))
    static let channelSystem = Color(nsColor: NSColor(hex: "#05F2DB"))

    // Typography helpers
    static func display()   -> Font { .system(size: 24, weight: .semibold, design: .default) }
    static func h1()        -> Font { .system(size: 18, weight: .semibold) }
    static func h2()        -> Font { .system(size: 14, weight: .semibold) }
    static func body()      -> Font { .system(size: 13, weight: .regular) }
    static func caption()   -> Font { .system(size: 11, weight: .medium) }
    static func labelCaps() -> Font { .system(size: 10, weight: .semibold) }
}

// MARK: - Button Styles

struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignToken.labelCaps())
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(
                isEnabled
                    ? (configuration.isPressed ? DesignToken.danger.opacity(0.85) : DesignToken.danger)
                    : DesignToken.fgTertiary.opacity(0.3)
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(DesignToken.bgHover)
            .foregroundColor(DesignToken.fgPrimary)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(DesignToken.fgSecondary)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(DesignToken.bgHover.opacity(configuration.isPressed ? 0.6 : 0))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    enum Style {
        case recording, processing, done

        var textColor: Color {
            switch self {
            case .recording: return DesignToken.danger
            case .processing: return DesignToken.warning
            case .done: return DesignToken.success
            }
        }

        var bgColor: Color {
            switch self {
            case .recording: return DesignToken.danger.opacity(0.12)
            case .processing: return DesignToken.warning.opacity(0.12)
            case .done: return DesignToken.success.opacity(0.12)
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text.uppercased())
            .font(DesignToken.labelCaps())
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundColor(style.textColor)
            .background(style.bgColor)
            .clipShape(Capsule())
    }
}
