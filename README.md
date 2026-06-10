# MeetRecorder

A macOS meeting recorder that captures both microphone and system audio (e.g. Zoom/Teams/Meet calls) simultaneously, then transcribes locally with OpenAI Whisper. No cloud APIs, no ffmpeg, no BlackHole.

## Features

- **Dual-channel recording**: your mic + system audio via [Background Music](https://github.com/kyleneideck/BackgroundMusic) virtual loopback
- **Local transcription**: OpenAI Whisper runs entirely on-device
- **Structured insights**: auto-extracts decisions, action items, and risks
- **Full GUI app**: dark-themed web app bundled as a native macOS .app
- **Menu bar app**: one-click start/stop from the macOS menu bar
- **CLI wrappers**: `meetrecord`, `meetstop`, `meettoggle`, `meetlast`, `meetlist`

## Requirements

- macOS 10.15+
- Python 3.9+ with packages:
  ```bash
  pip3 install sounddevice soundfile numpy openai-whisper flask flask-cors
  ```
- [Background Music](https://github.com/kyleneideck/BackgroundMusic/releases) virtual audio driver installed and running
- Xcode Command Line Tools (for compiling Swift helpers)

## Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/alphadawg88/meetrecorder.git ~/Projects/meetrecorder
cd ~/Projects/meetrecorder
```

### 2. Install

```bash
./install.sh
```

This compiles the Swift helpers and symlinks the CLI wrappers into `~/bin` (add `~/bin` to your PATH if you haven't already).

### 3. Launch the GUI app

```bash
open app/dist/MeetRecorder.app
```

Or run the backend directly and open in your browser:

```bash
cd app && python3 backend.py
# Open http://localhost:8742 in your browser
```

### 4. Use the CLI

```bash
meetrecord --name "client_call"
# ... during the meeting ...
meetstop --transcribe
```

### 5. Find your recordings

All files go to `~/Desktop/recordings/`:

| File | Description |
|------|-------------|
| `*_combined.wav` | Stereo mix: L = mic, R = system audio (transcribed) |
| `*_mic.wav` | Your microphone only |
| `*_system.wav` | System/call audio only |
| `*_transcript.txt` | Raw Whisper transcript |
| `*_insights.md` | Decisions, action items, risks + full transcript |

## MeetRecorder GUI App

The new GUI app is a dark-themed single-page application built on a custom design system. It provides:

### Record Screen
- Large record button with animated pulse when recording
- Live timer
- Dual audio level meters (mic + system)
- Real-time waveform visualization
- "Mic Only" toggle and quick folder access

### Library Screen
- All recordings with waveform thumbnails
- Filter tabs: All / Combined / Mic / System / Transcribed / Untranscribed
- Search
- Per-recording actions: open transcript, delete
- Status badges: Recording / Transcribing / Ready / No transcript

### Transcript Screen
- Full transcript with speaker labels and timestamps
- Live search with highlight
- Insights sidebar: Decisions, Action Items, Risks
- One-click transcription for untranscribed recordings

### Settings Screen
- Output directory
- Audio device selection
- Whisper model selector (tiny/base/small/medium/large)
- Auto-transcribe toggle
- Launch at login toggle

### Design System
See `design/DESIGN_SYSTEM.md` for the complete token specification:
- Color tokens (background scale, foreground scale, semantic colors, channel colors)
- Typography tokens (SF Pro Display, SF Pro Text, SF Mono)
- Spacing, elevation, border, radius, animation tokens
- Component specs (record button, audio meters, waveform, cards, badges, toggles, transcript lines, insight tags)
- Screen layouts and responsive breakpoints

## CLI Reference

| Command | Action |
|---------|--------|
| `meetrecord --name <name>` | Start dual recording, switch output to Background Music |
| `meetstop` | Stop recording, restore original audio output |
| `meetstop --transcribe` | Stop + run Whisper transcription |
| `meettoggle` | Start if stopped, stop+transcribe if running |
| `meetlast` | Transcribe the most recent recording |
| `meetlist [n]` | List recent recordings with timestamps and sizes |

## Menu Bar App

The app lives in your menu bar (no Dock icon). It shows:
- **○** when idle
- **● REC** when recording

Click to open the menu:
- Start Recording
- Stop Recording
- Stop & Transcribe
- Open Recordings Folder

## Project Structure

```
meetrecorder/
├── README.md
├── install.sh
├── design/
│   ├── DESIGN_SYSTEM.md              # Master design system + tokens
│   └── MeetRecorder-Interface-Design.html  # Interactive design artifact v1
├── app/
│   ├── backend.py                    # Flask REST API (bridges frontend to scripts)
│   ├── static/
│   │   └── index.html                # Functional SPA frontend
│   ├── build-app.sh                  # macOS .app bundle builder
│   └── dist/
│       └── MeetRecorder.app/         # Packaged macOS application
├── bin/
│   ├── meetrecord       # Python wrapper: start recording
│   ├── meetstop         # Python wrapper: stop + restore audio
│   ├── meettoggle       # Toggle start/stop
│   ├── meetlast         # Transcribe most recent
│   └── meetlist         # List recordings
└── src/
    ├── python/
    │   ├── dual-record.py      # Dual-channel audio capture
    │   ├── mac-recorder.py     # Single-channel mic recorder
    │   └── mac-transcribe.py   # Whisper + insight extraction
    └── swift/
        ├── MeetRecorderMenuBar.swift  # Menu bar app source
        └── set-default-output.swift   # CoreAudio output switcher
```

## Building the App Bundle

```bash
cd app
./build-app.sh
```

The resulting `app/dist/MeetRecorder.app` can be dragged to `/Applications/` or `~/Applications/`.

## Troubleshooting

### "Background Music not running"
Launch `/Applications/Background Music.app` before recording. The menu bar app will warn you if it's missing.

### "No system audio captured"
Your meeting app (Zoom/Teams/Meet) must use Background Music as its speaker output. The `meetrecord` wrapper switches the system default, but some apps override per-call.

### Audio not restored after a crash
If the recorder crashes and leaves your output stuck on Background Music:
```bash
~/.hermes/scripts/set-default-output "Your Speakers"
```
Or run `meetstop` — it restores audio on every path, even when no recording is found.

### Transcription language wrong
Whisper auto-detects language. If it guesses wrong, you can force a language by editing `mac-transcribe.py` and adding `language="en"` to the `model.transcribe()` call.

## License

MIT
