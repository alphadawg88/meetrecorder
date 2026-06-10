import SwiftUI
import AppKit

// MARK: - NSColor hex helper

extension NSColor {
    convenience init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        var rgb: UInt64 = 0
        let scanner = Scanner(string: s)
        let success = scanner.scanHexInt64(&rgb)

        let r, g, b, a: CGFloat
        if !success || s.isEmpty {
            self.init(srgbRed: 0.96, green: 0.96, blue: 0.96, alpha: 1)
            return
        }

        switch s.count {
        case 8:
            r = CGFloat((rgb & 0xFF00_0000) >> 24) / 255
            g = CGFloat((rgb & 0x00FF_0000) >> 16) / 255
            b = CGFloat((rgb & 0x0000_FF00) >> 8)  / 255
            a = CGFloat(rgb & 0x0000_00FF)          / 255
        default: // 6-digit RGB
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255
            g = CGFloat((rgb & 0x00FF00) >> 8)  / 255
            b = CGFloat(rgb & 0x0000FF)          / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Design Token v2.0
//
// Dark-first token set. All hex values are absolute — this design system
// always renders on a dark (#0A0A0A) background. There is no light-mode
// dynamic resolution; .preferredColorScheme(.dark) is applied at the root.

enum DesignToken {

    // MARK: Backgrounds
    /// #0A0A0A — solid popover/window background
    static let bgBase    = Color(nsColor: NSColor(hex: "0A0A0A"))
    /// #111111 — cards, panels
    static let bgSurface = Color(nsColor: NSColor(hex: "111111"))
    /// #1A1A1A — inputs, buttons at rest, table rows
    static let bgRaised  = Color(nsColor: NSColor(hex: "1A1A1A"))
    /// #222222 — hover states
    static let bgHover   = Color(nsColor: NSColor(hex: "222222"))
    /// #2A2A2A — pressed states
    static let bgActive  = Color(nsColor: NSColor(hex: "2A2A2A"))

    // MARK: Foregrounds
    /// #E8E8E8 — primary text
    static let fgPrimary   = Color(nsColor: NSColor(hex: "E8E8E8"))
    /// #888888 — secondary text, metadata
    static let fgSecondary = Color(nsColor: NSColor(hex: "888888"))
    /// #555555 — tertiary text, disabled
    static let fgTertiary  = Color(nsColor: NSColor(hex: "555555"))

    // MARK: Semantic
    /// #A100FF — brand purple: nav, focused ring, spinner tint
    static let accent       = Color(nsColor: NSColor(hex: "A100FF"))
    /// #B52AFF — accent hover
    static let accentHover  = Color(nsColor: NSColor(hex: "B52AFF"))
    /// #8A00DB — accent pressed
    static let accentActive = Color(nsColor: NSColor(hex: "8A00DB"))
    /// #00E676 — success / completed
    static let success      = Color(nsColor: NSColor(hex: "00E676"))
    /// #FFAB00 — warning / processing
    static let warning      = Color(nsColor: NSColor(hex: "FFAB00"))
    /// #FF4444 — danger: recording indicator, errors
    static let danger       = Color(nsColor: NSColor(hex: "FF4444"))

    // MARK: Channel colors
    /// #FF50A0 — microphone-only badge
    static let channelMic    = Color(nsColor: NSColor(hex: "FF50A0"))
    /// #05F2DB — system audio-only badge
    static let channelSystem = Color(nsColor: NSColor(hex: "05F2DB"))
    // combined = accent

    // MARK: Typography (static functions returning SwiftUI Font)
    static func display()   -> Font { .system(size: 24, weight: .semibold) }
    static func h1()        -> Font { .system(size: 18, weight: .semibold) }
    static func h2()        -> Font { .system(size: 14, weight: .semibold) }
    static func body()      -> Font { .system(size: 13, weight: .regular) }
    static func bodyMed()   -> Font { .system(size: 13, weight: .medium) }
    static func caption()   -> Font { .system(size: 11, weight: .medium) }
    static func mono()      -> Font { .system(size: 12, weight: .regular).monospaced() }
    static func labelCaps() -> Font { .system(size: 10, weight: .semibold) }

    // MARK: Spacing (8px grid)
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: Radius
    enum Radius {
        static let sm:   CGFloat = 4
        static let md:   CGFloat = 6
        static let lg:   CGFloat = 10
        static let xl:   CGFloat = 14
        static let full: CGFloat = 9999
    }
}

// MARK: - DS compatibility wrapper
//
// Maps legacy DS.Color / DS.Font / DS.Space / DS.Radius call sites to the
// new DesignToken values so existing views compile without modification.

enum DS {

    enum Color {
        static let primary          = DesignToken.fgPrimary
        static let secondary        = DesignToken.fgSecondary
        static let recording        = DesignToken.danger
        static let recordingPressed = DesignToken.danger.opacity(0.80)
        static let success          = DesignToken.success
        static let warning          = DesignToken.warning
        static let error            = DesignToken.danger
        static let surfaceSecondary = DesignToken.bgRaised
        static let divider          = DesignToken.fgTertiary.opacity(0.4)
        static let recordingWash    = DesignToken.danger.opacity(0.08)
        static let warningWash      = DesignToken.warning.opacity(0.12)
        static let successWash      = DesignToken.success.opacity(0.12)
    }

    enum Font {
        static let display    = DesignToken.display()
        static let title      = DesignToken.h2()
        static let body       = DesignToken.body()
        static let bodyMedium = DesignToken.bodyMed()
        static let caption    = DesignToken.caption()
        static let labelCaps  = DesignToken.labelCaps()
    }

    enum Space {
        static let xs: CGFloat = DesignToken.Space.xs
        static let sm: CGFloat = DesignToken.Space.sm
        static let md: CGFloat = DesignToken.Space.md
        static let lg: CGFloat = DesignToken.Space.lg
        static let xl: CGFloat = DesignToken.Space.xl
    }

    enum Radius {
        static let sm:   CGFloat = DesignToken.Radius.sm
        static let md:   CGFloat = DesignToken.Radius.md
        static let lg:   CGFloat = DesignToken.Radius.lg
        static let full: CGFloat = DesignToken.Radius.full
    }
}

// MARK: - .labelCaps() view modifier

extension View {
    /// Applies the label-caps type role (10px/600, uppercase, +0.06em tracking).
    func labelCaps() -> some View {
        self
            .font(DesignToken.labelCaps())
            .tracking(0.6)
            .textCase(.uppercase)
    }
}

// MARK: - Button Styles

/// The single high-emphasis action per state — danger red fill.
/// 32px height, full pill, white label-caps label.
/// Disabled: fgTertiary at 30% opacity.
struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignToken.labelCaps())
            .tracking(0.6)
            .foregroundColor(.white)
            .background(
                isEnabled
                    ? (configuration.isPressed
                        ? DesignToken.danger.opacity(0.80)
                        : DesignToken.danger)
                    : DesignToken.fgTertiary.opacity(0.3)
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Contextual secondary action (e.g. "Record" on an event card).
/// bg = bgHover at rest, bgActive when pressed; primary text.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignToken.labelCaps())
            .tracking(0.6)
            .foregroundColor(isEnabled ? DesignToken.fgPrimary : DesignToken.fgSecondary)
            .padding(.horizontal, DesignToken.Space.md)
            .padding(.vertical, DesignToken.Space.xs)
            .background(
                configuration.isPressed
                    ? DesignToken.bgActive
                    : DesignToken.bgHover
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Icon-only or text-only tertiary action (gear, folder, quit, dismiss).
/// Transparent bg, fgSecondary text. Hover/press fills bgHover at 60%.
/// Radius: sm (4px) per spec — ghost buttons are NOT pills.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignToken.caption())
            .foregroundColor(DesignToken.fgSecondary)
            .padding(DesignToken.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: DesignToken.Radius.sm, style: .continuous)
                    .fill(configuration.isPressed
                          ? DesignToken.bgHover.opacity(0.6)
                          : Color.clear)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Model Card
//
// Used in SettingsView to select and manage on-device models.
// Selection ring uses DesignToken.accent (brand purple).

struct ModelCard: View {
    let id: String
    let name: String
    let tag: String
    let size: String
    @Binding var selected: String
    var isDownloaded: Bool = false
    var isActiveDownload: Bool = false
    var downloadState: ModelManager.State = .notReady
    var onUninstall: (() -> Void)? = nil

    var isSelected: Bool { selected == id }

    private var progressText: String {
        switch downloadState {
        case .preparing(nil):
            return "Downloading…"
        case .preparing(let frac?):
            return "\(Int(frac * 100))%"
        default:
            return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignToken.Space.xs) {
            HStack(spacing: DesignToken.Space.sm + 2) {
                // Selection indicator — accent purple
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? DesignToken.accent : DesignToken.fgSecondary)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DesignToken.Space.xs + 2) {
                        Text(name)
                            .font(DesignToken.body())
                            .fontWeight(.medium)
                            .foregroundColor(DesignToken.fgPrimary)
                        Text(tag)
                            .font(DesignToken.labelCaps())
                            .tracking(0.6)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(DesignToken.accent.opacity(0.12))
                            .foregroundColor(DesignToken.accent)
                            .clipShape(Capsule())
                    }
                    Text(size)
                        .font(DesignToken.caption())
                        .foregroundColor(DesignToken.fgSecondary)
                }

                Spacer()

                if isActiveDownload {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else if isDownloaded {
                    HStack(spacing: DesignToken.Space.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DesignToken.success)
                            .imageScale(.small)
                        Text("Downloaded")
                            .font(DesignToken.caption())
                            .foregroundColor(DesignToken.success)
                        if let onUninstall = onUninstall {
                            Button(action: onUninstall) {
                                Image(systemName: "trash")
                                    .imageScale(.small)
                                    .foregroundColor(DesignToken.fgSecondary)
                            }
                            .buttonStyle(GhostButtonStyle())
                            .help("Remove downloaded model files")
                        }
                    }
                }
            }
            .padding(DesignToken.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignToken.Radius.sm + 2, style: .continuous)
                    .fill(isSelected
                          ? DesignToken.accent.opacity(0.12)
                          : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture { selected = id }

            if isActiveDownload {
                HStack(spacing: DesignToken.Space.xs) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                    Text(progressText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(DesignToken.fgSecondary)
                }
                .padding(.horizontal, DesignToken.Space.sm)
            }
        }
    }
}

// MARK: - Status Badge
//
// Three semantic pills: recording (red tint), processing (amber tint), done (green tint).
// All use label-caps typography. Background is a pale tint (.12 opacity); text is full-strength.
// Full pill (Capsule) signals state, per the radius spec.

struct StatusBadge: View {
    enum Style {
        case recording, processing, done

        var textColor: Color {
            switch self {
            case .recording:  return DesignToken.danger
            case .processing: return DesignToken.warning
            case .done:       return DesignToken.success
            }
        }

        var bgColor: Color {
            switch self {
            case .recording:  return DesignToken.danger.opacity(0.12)
            case .processing: return DesignToken.warning.opacity(0.12)
            case .done:       return DesignToken.success.opacity(0.12)
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text.uppercased())
            .font(DesignToken.labelCaps())
            .tracking(0.6)
            .padding(.horizontal, DesignToken.Space.sm)
            .padding(.vertical, 2)
            .foregroundColor(style.textColor)
            .background(style.bgColor)
            .clipShape(Capsule())
    }
}
