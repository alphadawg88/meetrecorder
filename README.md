# MeetRecorder

A lightweight native macOS menu bar app that records system and microphone audio during meetings, transcribes multi-lingual speech (English, Cantonese, Mandarin), translates and summarizes with Claude, and exports structured Markdown memory files for your AI second brain.

## Features

- **Dual Audio Capture**: Records both system audio (Teams, Zoom, Meet) and microphone simultaneously via native ScreenCaptureKit and AVFoundation. No third-party virtual audio driver required.
- **Multi-lingual Transcription**: OpenAI Whisper API with auto-detection for English, Cantonese, and Mandarin.
- **AI Summarization**: Anthropic Claude extracts executive summaries, key takeaways, action items, and detailed notes.
- **Second Brain Export**: Clean Markdown with YAML frontmatter, optimized for RAG querying by Hermes, Claude, or Obsidian.
- **Calendar Integration**: Reads Apple Calendar to detect upcoming meetings, sends native notifications, and auto-stops when events end.
- **Global Shortcut**: One-key toggle to start/stop recording from anywhere.
- **Native SwiftUI**: Minimalist menu bar popover, dark mode compatible, follows Apple HIG. No Electron, no Python runtime.

## Requirements

- macOS 14.0+
- Xcode 15+ (for building from source)
- OpenAI API key (Whisper)
- Anthropic API key (Claude)

## Installation

### Build from Source

```bash
git clone https://github.com/alphadawg88/meetrecorder.git
cd meetrecorder
brew install xcodegen
xcodegen generate
open MeetRecorder.xcodeproj
```

Then press **Cmd+R** to build and run, or **Product > Archive** to create a release build.

## Setup

On first launch, grant these permissions when prompted:

1. **Microphone** -- for recording your voice
2. **Screen Recording** -- required by ScreenCaptureKit to capture system audio
3. **Calendar** -- optional, for meeting reminders and auto-stop

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

Optimized for semantic search and AI agent interrogation.

## Architecture

| Layer | Technology |
|-------|------------|
| App Shell | SwiftUI + MenuBarExtra |
| System Audio | ScreenCaptureKit (SCStream) |
| Microphone | AVAudioRecorder |
| Audio Mixing | AVMutableComposition |
| Transcription | OpenAI Whisper API |
| Summarization | Anthropic Claude API |
| Calendar | EventKit |
| Shortcuts | KeyboardShortcuts |
| Storage | Local Filesystem (.md) |

## Privacy

- Audio is sent to OpenAI Whisper and Anthropic Claude for processing. Files are temporarily stored in `/tmp`.
- API keys stored in UserDefaults for v1. Migrate to Keychain for production hardening.
- No telemetry, no analytics, no third-party trackers.

## License

MIT
