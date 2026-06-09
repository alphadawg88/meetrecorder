import SwiftUI
import AppKit

// MARK: - NSColor hex helper
//
// The hex initializer is needed only for the one reserved signal that has no
// exact semantic twin: the recording-red pressed state (#E0312A / #FF5F55).
// Everything else goes through DS.Color semantic tokens below.

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

// MARK: - Design System tokens
//
// Single source of truth. All UI files import this enum rather than
// sprinkling .system(size:13…) and Color(nsColor: .systemRed) literals.
//
// Mapping rationale (per DESIGN.md):
//   • primary / secondary / divider → NSColor semantic: free dark/high-contrast
//   • surface / surface-secondary   → .background / .controlBackgroundColor (semantic)
//   • recording (#D70015 light)     → dynamic NSColor resolving to #D70015 in light
//                                     and macOS systemRed (#FF453A) in dark; matches
//                                     the HTML preview's @media dark rule exactly.
//   • success / warning             → semantic systemGreen / systemOrange so the tint
//                                     adapts in dark mode (the spec hex values are
//                                     light-only reference points, not absolute).

enum DS {

    // MARK: Color tokens
    enum Color {
        /// Primary text — headlines, active labels. → NSColor.labelColor
        static let primary   = SwiftUI.Color(nsColor: .labelColor)
        /// Secondary text — metadata, timestamps, disabled. → NSColor.secondaryLabelColor
        static let secondary = SwiftUI.Color(nsColor: .secondaryLabelColor)

        /// THE reserved signal: recording action + live indicator ONLY.
        /// Light: #D70015 (spec exact). Dark: systemRed (#FF453A, macOS standard).
        static let recording = SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 1.0, green: 0.271, blue: 0.227, alpha: 1) // #FF453A
                : NSColor(srgbRed: 0.843, green: 0.0, blue: 0.082, alpha: 1) // #D70015
        })

        /// Pressed state of recording button (darker shade).
        /// Light: #E0312A. Dark: #FF5F55.
        static let recordingPressed = SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return isDark
                ? NSColor(srgbRed: 1.0, green: 0.373, blue: 0.333, alpha: 1) // #FF5F55
                : NSColor(srgbRed: 0.878, green: 0.192, blue: 0.165, alpha: 1) // #E0312A
        })

        /// Completion / success. → NSColor.systemGreen (adapts in dark)
        static let success  = SwiftUI.Color(nsColor: .systemGreen)
        /// Processing / warning. → NSColor.systemOrange (adapts in dark)
        static let warning  = SwiftUI.Color(nsColor: .systemOrange)
        /// Error / failed state. → NSColor.systemRed (adapts in dark). Distinct
        /// from `recording`, which stays the reserved capture signal.
        static let error    = SwiftUI.Color(nsColor: .systemRed)

        /// Window surface. → .ultraThinMaterial (set at the container level)
        /// For fills, use .background(.ultraThinMaterial) directly.

        /// Elevated cards, hover states. → NSColor.controlBackgroundColor
        static let surfaceSecondary = SwiftUI.Color(nsColor: .controlBackgroundColor)

        /// 1 px hairlines. → .separator (never hard-code).
        static let divider = SwiftUI.Color(nsColor: .separatorColor)

        // Semantic tints for status badges (pale bg + full text).
        // Using dynamic opacity on the semantic base so they adapt in dark mode.
        static let recordingWash = recording.opacity(0.10)
        static let warningWash   = warning.opacity(0.10)
        static let successWash   = success.opacity(0.10)
    }

    // MARK: Typography tokens
    //
    // SF Pro at every size. Weight + color carry hierarchy.
    // Label-caps tracking: +0.06em at 10px = 0.6 SwiftUI tracking points.
    enum Font {
        /// Display 20/600: live timer only. Always use .monospacedDigit().
        static let display = SwiftUI.Font.system(size: 20, weight: .semibold)

        /// Title 15/600: section headers, meeting name.
        static let title   = SwiftUI.Font.system(size: 15, weight: .semibold)

        /// Body 13/400: default reading size.
        static let body    = SwiftUI.Font.system(size: 13, weight: .regular)

        /// Body medium 13/500: list titles, slightly elevated.
        static let bodyMedium = SwiftUI.Font.system(size: 13, weight: .medium)

        /// Caption 11/400: timestamps, paths, shortcut hints.
        static let caption = SwiftUI.Font.system(size: 11, weight: .regular)

        /// Label-caps 10/600 + uppercase: buttons, status badges, section headers.
        /// Apply via .labelCaps() view modifier to add tracking + uppercase.
        static let labelCaps = SwiftUI.Font.system(size: 10, weight: .semibold)
    }

    // MARK: Spacing tokens (8px grid halved)
    enum Space {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }

    // MARK: Radius tokens
    enum Radius {
        /// 4px: list rows, small buttons, text fields.
        static let sm: CGFloat  = 4
        /// 8px: cards, progress bars.
        static let md: CGFloat  = 8
        /// 12px: popover window corners.
        static let lg: CGFloat  = 12
        /// 9999px: primary actions + status badges only.
        static let full: CGFloat = 9999
    }
}

// MARK: - .labelCaps() view modifier
//
// Applies the label-caps type role: uppercase text + tracking for readability.
// Usage: Text("CAPTURE").labelCaps()

extension View {
    /// Applies the label-caps type role (10px/600, uppercase, +0.06em tracking).
    func labelCaps() -> some View {
        self
            .font(DS.Font.labelCaps)
            .tracking(0.6)
            .textCase(.uppercase)
    }
}

// MARK: - Button Styles

/// The single high-emphasis action per state — the reserved recording red.
/// 32px height, full pill, white label-caps label.
/// Disabled: systemGray at 40% opacity.
struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.labelCaps)
            .tracking(0.6)
            .foregroundColor(.white)
            .background(
                isEnabled
                    ? (configuration.isPressed
                        ? DS.Color.recordingPressed
                        : DS.Color.recording)
                    : Color(nsColor: .systemGray).opacity(0.4)
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Contextual secondary action (e.g. "Record" on an event card).
/// 28px height, full pill, surface-secondary bg, primary text.
/// Never appears without a primary button nearby to establish hierarchy.
struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.labelCaps)
            .tracking(0.6)
            .foregroundColor(isEnabled ? DS.Color.primary : DS.Color.secondary)
            .padding(.horizontal, DS.Space.md)
            .padding(.vertical, DS.Space.xs)
            .background(
                configuration.isPressed
                    ? DS.Color.divider
                    : DS.Color.surfaceSecondary
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Icon-only or text-only tertiary action (gear, folder, quit, dismiss).
/// Transparent bg, secondary text. Hover/press fills surface-secondary.
/// Radius: sm (4px) per spec — ghost buttons are NOT pills.
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Font.caption)
            .foregroundColor(DS.Color.secondary)
            .padding(DS.Space.xs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                    .fill(configuration.isPressed
                          ? DS.Color.divider
                          : Color.clear)
            )
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Model Card
//
// Used in SettingsView to select and manage on-device models.
// Selection ring uses system accent color; downloaded/progress state is inline.

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
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            HStack(spacing: DS.Space.sm + 2) {
                // Selection indicator — system blue adapts automatically
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? Color(nsColor: .systemBlue) : DS.Color.secondary)
                    .imageScale(.small)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Space.xs + 2) {
                        Text(name)
                            .font(DS.Font.body)
                            .fontWeight(.medium)
                            .foregroundColor(DS.Color.primary)
                        Text(tag)
                            .font(DS.Font.labelCaps)
                            .tracking(0.6)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color(nsColor: .systemBlue).opacity(0.10))
                            .foregroundColor(Color(nsColor: .systemBlue))
                            .clipShape(Capsule())
                    }
                    Text(size)
                        .font(DS.Font.caption)
                        .foregroundColor(DS.Color.secondary)
                }

                Spacer()

                if isActiveDownload {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                } else if isDownloaded {
                    HStack(spacing: DS.Space.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(DS.Color.success)
                            .imageScale(.small)
                        Text("Downloaded")
                            .font(DS.Font.caption)
                            .foregroundColor(DS.Color.success)
                        if let onUninstall = onUninstall {
                            Button(action: onUninstall) {
                                Image(systemName: "trash")
                                    .imageScale(.small)
                                    .foregroundColor(DS.Color.secondary)
                            }
                            .buttonStyle(GhostButtonStyle())
                            .help("Remove downloaded model files")
                        }
                    }
                }
            }
            .padding(DS.Space.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.sm + 2, style: .continuous)
                    .fill(isSelected
                          ? Color(nsColor: .selectedControlColor).opacity(0.25)
                          : Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture { selected = id }

            if isActiveDownload {
                HStack(spacing: DS.Space.xs) {
                    ProgressView()
                        .controlSize(.mini)
                        .scaleEffect(0.7)
                    Text(progressText)
                        .font(.system(size: 10).monospacedDigit())
                        .foregroundColor(DS.Color.secondary)
                }
                .padding(.horizontal, DS.Space.sm)
            }
        }
    }
}

// MARK: - Status Badge
//
// Three semantic pills: recording (red tint), processing (amber tint), done (green tint).
// All use label-caps typography. Background is a pale tint; text is full-strength.
// Full pill (Capsule) signals state, per the radius spec.

struct StatusBadge: View {
    enum Style {
        case recording, processing, done

        var textColor: Color {
            switch self {
            case .recording:  return DS.Color.recording
            case .processing: return DS.Color.warning
            case .done:       return DS.Color.success
            }
        }

        var bgColor: Color {
            switch self {
            case .recording:  return DS.Color.recordingWash
            case .processing: return DS.Color.warningWash
            case .done:       return DS.Color.successWash
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text.uppercased())
            .font(DS.Font.labelCaps)
            .tracking(0.6)
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 2)
            .foregroundColor(style.textColor)
            .background(style.bgColor)
            .clipShape(Capsule())
    }
}
