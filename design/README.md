# Glyph Design System

This folder contains all design assets, research, and specifications for Glyph — a native macOS menu bar utility for meeting capture.

## Files

| File | Purpose |
|------|---------|
| `DESIGN.md` | Google DESIGN.md token spec. Colors, typography, spacing, component definitions. Lint-clean, ready for codegen. |
| `UI-REDESIGN.md` | Complete SwiftUI redesign document. State-driven architecture (`RecordingPhase`), custom button styles, accessibility labels. |
| `LOCAL-LLM-RESEARCH.md` | Local model stack research. WhisperKit for transcription, MLX Swift for summarization. Model recommendations with RAM footprints. |
| `BUILD_PROMPT.md` | **Actionable build spec for the next development phase.** Menu persistence (NSPopover), local-first model browser with advantage tags, help panel, cloud-as-optional. |
| `ICON_CONCEPTS.html` | Interactive concept board. 5 name options and 4 icon directions explored during the design phase. |
| `UI_PREVIEW.html` | Interactive HTML prototype of the 360 px popover. Toggle between Idle, Recording, and Processing states. |
| `ICON_GLYPH_PREVIEW.html` | Visual preview of The Capture icon at all macOS sizes (16 pt – 512 pt) and menu bar contexts. |
| `RENAME_CHECKLIST.md` | Step-by-step checklist for completing the rebrand from MeetRecorder to Glyph in source code and Xcode project. |

## Icon Assets

Production icon assets live in the Xcode asset catalog:

```
MeetRecorder/Assets.xcassets/
  AppIcon.appiconset/AppIcon.svg      → 1024×1024 app icon
  MenuBarIcon.imageset/MenuBarIcon.svg → 18×18 template icon
```

**The Capture**: A circle containing a waveform — the universal record symbol infused with audio identity. Strong recognition at all scales.

## Design Principles

1. **Invisible utility** — Zero chrome when idle. The app lives in the menu bar, not the Dock.
2. **State-first layout** — One primary action per state (idle/recording/processing). No generic forms.
3. **Native materials** — NSColor semantic equivalents, SF Pro typography, vibrancy where appropriate.
4. **Respect cognitive space** — No notifications during recording. No modals. No confirmation dialogs.
5. **Local-first, cloud-optional** — On-device models are the default. Cloud APIs are an opt-in enhancement for users who need the absolute best nuanced translation.
6. **Persistent popover** — Interactions inside the popover do not dismiss it. Only click-away closes. Users can browse settings and models without losing context.
