# MeetRecorder

A native macOS menu bar app that captures both microphone and system audio during meetings, transcribes with OpenAI Whisper, summarizes with Anthropic Claude, and exports structured Markdown memory files.

## Features

- **Dual Audio Capture**: Records system audio (Teams, Zoom, Meet) and microphone simultaneously via native ScreenCaptureKit and AVFoundation. No third-party virtual audio driver required.
- **Multi-lingual Transcription**: OpenAI Whisper API with auto-detection for English, Cantonese, and Mandarin. Optional on-device WhisperKit for offline use.
- **AI Summarization**: Anthropic Claude extracts executive summaries, key takeaways, action items, and detailed notes. Optional local MLX Swift LLM for offline summarization.
- **Second Brain Export**: Clean Markdown with YAML frontmatter, optimized for RAG querying by Hermes, Claude, or Obsidian.
- **Calendar Integration**: Reads Apple Calendar to detect upcoming meetings, sends native notifications, and auto-stops when events end.
- **Global Shortcut**: One-key toggle to start/stop recording from anywhere.
- **Native SwiftUI**: Minimalist menu bar popover, dark mode compatible, follows Apple HIG.

## Design System

The app is built on a custom token-based design system defined in `design/DESIGN_SYSTEM.md`.

- **Dark-first**: `#0A0A0A` base, `#111111` surfaces, `#1A1A1A` raised elements
- **Accent**: `#A100FF` (brand purple)
- **Semantic**: `#FF4444` danger/recording, `#00E676` success, `#FFAB00` warning, `#05F2DB` info
- **Typography**: SF Pro Display / SF Pro Text / SF Mono
- **Spacing**: 4px base unit (4, 8, 12, 16, 24, 32, 48)

## Requirements

- macOS 14.0+
- Xcode 15+ (for building from source)
- OpenAI API key (Whisper)
- Anthropic API key (Claude)

## Build

```bash
./build.sh
```

This installs `xcodegen` if needed, generates the Xcode project, and opens it. Press **Cmd+R** to build and run, or **Product > Archive** to create a release build.

## Setup

On first launch, grant these permissions when prompted:

1. **Microphone** — for recording your voice
2. **Screen Recording** — required by ScreenCaptureKit to capture system audio
3. **Calendar** — optional, for meeting reminders and auto-stop

Open **Settings** from the menu bar and enter:
- OpenAI API Key
- Anthropic API Key
- Preferred vault output path
- Target language (English or Chinese)

## Usage

- **Start/Stop**: Click the waveform icon in the menu bar, or press your configured global shortcut.
- **Calendar Events**: If a meeting starts within 5 minutes, a native notification appears. Tap "Record" to auto-name the file.
- **Auto-Stop**: Enable in Settings to stop recording when the calendar event ends.
- **Output**: Markdown files saved to your vault as `YYYY-MM-DD_HH-MM_Meeting_Title.md`.

## Markdown Output Format

```yaml
---
date: 2026-06-08T10:00:00Z
duration: 00:45
title: Weekly Standup
tags: ["meeting", "standup"]
source_language: auto-detected
target_language: en
---
```

Sections:
1. Executive Summary
2. Key Takeaways & Action Items
3. Detailed Notes
4. Translated Transcript
5. Raw Original Transcript

## Architecture

| Layer | Technology |
|-------|------------|
| App Shell | SwiftUI + MenuBarExtra |
| System Audio | ScreenCaptureKit (SCStream) |
| Microphone | AVAudioRecorder |
| Audio Mixing | AVMutableComposition |
| Transcription | OpenAI Whisper API / WhisperKit |
| Summarization | Anthropic Claude API / MLX Swift |
| Calendar | EventKit |
| Shortcuts | KeyboardShortcuts |
| Storage | Local Filesystem (.md) |

## Project Structure

```
meetrecorder/
├── README.md
├── build.sh                    # Build script: xcodegen + open Xcode
├── project.yml                 # xcodegen project spec
├── design/
│   ├── DESIGN_SYSTEM.md        # Master design system + tokens
│   └── AppIcon.svg             # App icon source
├── MeetRecorder/
│   ├── MeetRecorderApp.swift   # App entry point
│   ├── UI/
│   │   ├── ContentView.swift   # Main popover UI
│   │   ├── DesignSystem.swift  # Tokens, colors, button styles
│   │   └── SettingsView.swift  # Settings sheet
│   ├── Audio/
│   │   ├── RecordingManager.swift
│   │   ├── SystemAudioCapture.swift
│   │   ├── MicrophoneCapture.swift
│   │   └── AudioMixer.swift
│   ├── AI/
│   │   ├── WhisperService.swift
│   │   ├── WhisperKitTranscriber.swift
│   │   ├── ClaudeService.swift
│   │   ├── MLXSummarizer.swift
│   │   ├── ModelManager.swift
│   │   └── Providers.swift
│   ├── Calendar/
│   │   └── CalendarManager.swift
│   ├── Export/
│   │   └── MarkdownExporter.swift
│   ├── Models/
│   │   └── MeetingRecord.swift
│   ├── Utils/
│   │   ├── SettingsStore.swift
│   │   └── NotificationManager.swift
│   └── Assets.xcassets/
└── tools/
    └── render_icons.swift
```

## Privacy

- Audio is sent to OpenAI Whisper and Anthropic Claude for processing. Files are temporarily stored in `/tmp`.
- API keys stored in UserDefaults for v1. Migrate to Keychain for production hardening.
- No telemetry, no analytics, no third-party trackers.

## License

MIT
