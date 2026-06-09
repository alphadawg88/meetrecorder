import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("How to use Glyph")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(GhostButtonStyle())
            }
            .padding(20)
            .background(.ultraThinMaterial)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    helpSection(title: "Start Recording", text: "Click the red record button or press the global shortcut. Glyph captures both your microphone and system audio.")

                    helpSection(title: "Stop & Process", text: "Click stop or press the shortcut again. Glyph transcribes and summarizes the meeting automatically.")

                    helpSection(title: "Find Your Notes", text: "Processed meetings appear in the Recent list. Click the arrow to open the vault folder in Finder.")

                    Divider()

                    helpSection(title: "Caveats", text: "On-device transcription handles Cantonese acceptably but may miss nuanced slang. For mission-critical translations, consider enabling a cloud API in Settings. First run downloads ~6 GB of models on Wi-Fi only.")

                    helpSection(title: "Privacy", text: "In on-device mode, zero audio or text leaves your Mac. Cloud mode sends data to OpenAI / Anthropic only when explicitly enabled.")
                }
                .padding(20)
            }

            Spacer()
        }
        .frame(width: 400, height: 420)
    }

    private func helpSection(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
            Text(text)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
