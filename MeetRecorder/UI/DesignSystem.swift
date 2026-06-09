import SwiftUI
import AppKit

// MARK: - Color helpers
//
// Per DESIGN.md, hierarchy comes from NSColor semantic colors so light/dark/
// high-contrast adapt for free. The hex initializer is only used for the one
// reserved signal (recording red pressed-state) that has no exact semantic twin.

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
        default: // treat as 6-digit RGB
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255
            b = CGFloat(rgb & 0x0000FF) / 255
            a = 1
        }
        self.init(srgbRed: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Button styles

/// The single high-emphasis action per state — the reserved recording red.
struct RecordButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .background(
                isEnabled
                    ? (configuration.isPressed
                        ? Color(nsColor: NSColor(hex: "#E0312A"))
                        : Color(nsColor: .systemRed))
                    : Color(nsColor: .systemGray).opacity(0.4)
            )
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Contextual action (e.g. "Record" on a calendar card). Never appears alone.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.2))
            .foregroundColor(.primary)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

/// Icon/text-only tertiary action (gear, open folder, dismiss).
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(nsColor: .quaternaryLabelColor)
                        .opacity(configuration.isPressed ? 0.15 : 0))
            )
            .contentShape(Rectangle())
    }
}

// MARK: - Model card

struct ModelCard: View {
    let id: String
    let name: String
    let tag: String
    let size: String
    @Binding var selected: String

    var isSelected: Bool { selected == id }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? Color(nsColor: .systemBlue) : .secondary)
                .imageScale(.small)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name)
                        .font(.system(size: 12, weight: .medium))
                    Text(tag)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(nsColor: .systemBlue).opacity(0.1))
                        .foregroundColor(Color(nsColor: .systemBlue))
                        .clipShape(Capsule())
                }
                Text(size)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Color(nsColor: .selectedControlColor).opacity(0.3) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selected = id
        }
    }
}

// MARK: - Status badge

struct StatusBadge: View {
    enum Style {
        case recording, processing, done

        var textColor: Color {
            switch self {
            case .recording: return Color(nsColor: .systemRed)
            case .processing: return Color(nsColor: .systemOrange)
            case .done: return Color(nsColor: .systemGreen)
            }
        }

        var bgColor: Color {
            switch self {
            case .recording: return Color(nsColor: .systemRed).opacity(0.1)
            case .processing: return Color(nsColor: .systemOrange).opacity(0.1)
            case .done: return Color(nsColor: .systemGreen).opacity(0.1)
            }
        }
    }

    let text: String
    let style: Style

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(0.5)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .foregroundColor(style.textColor)
            .background(style.bgColor)
            .clipShape(Capsule())
    }
}
