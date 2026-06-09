# Glyph — User Acceptance Test (UAT) Checklist

**Build under test:** Glyph 1.0.1 (Debug), branch `fix/qa-bug-sweep-2026-06-09`
**Date:** 2026-06-09  ·  **Tester:** Alfred Wong
**App location:** `build/Build/Products/Debug/Glyph.app` (currently launched)

> Glyph is a menu-bar-only app (no Dock icon). The icon sits at the **top-right** of the screen.
> Mark each case **PASS / FAIL / BLOCKED** and add a note. Anything FAIL → report back and it routes to a fix.

---

## 0. Prerequisites & setup

Before testing, decide which mode you're validating. Glyph has two:
- **On-device (Offline):** WhisperKit transcription + MLX (Qwen) summarization. No keys; requires one-time model download (multi-GB).
- **Cloud:** OpenAI Whisper + Anthropic Claude. Requires both API keys in Settings.

| ID | Prerequisite | Done? |
|----|--------------|:-----:|
| P1 | Grant **Microphone** permission when prompted (first record) | ☐ |
| P2 | Grant **Screen Recording** permission (System Settings → Privacy → Screen Recording → Glyph) — needed for system-audio capture | ☐ |
| P3 | Grant **Calendar** permission when prompted at launch | ☐ |
| P4 | For Cloud mode: enter OpenAI + Anthropic keys in Settings | ☐ |
| P5 | For Offline mode: download models from the popover (one-time) | ☐ |

> Note: macOS Screen Recording permission changes usually require quitting and relaunching Glyph to take effect.

---

## 1. App lifecycle & menu bar

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 1.1 | Look at the top-right menu bar | Glyph icon (waveform/glyph) is visible | ☐ | |
| 1.2 | **Left-click** the icon | Popover opens (header "Glyph", a Start/Download button, footer) | ☐ | |
| 1.3 | Click away / left-click again | Popover dismisses | ☐ | |
| 1.4 | **★ NEW — Right-click** (or Control-click) the icon | A small menu appears with **"Quit Glyph"** (⌘Q) | ☐ | |
| 1.5 | **★ NEW** — Click "Quit Glyph" from that menu | App fully quits; icon disappears from menu bar; no Glyph process left | ☐ | |
| 1.6 | **★ NEW** — Relaunch, open popover, click the **power icon** in the footer (bottom-right) | App quits the same way | ☐ | |
| 1.7 | Confirm only **one** Glyph runs at a time | Activity Monitor shows a single Glyph process (the duplicate-instance issue) | ☐ | |

*(★ = new "exit/close from the menu" feature added this session — primary acceptance item.)*

---

## 2. Settings & persistence

Open Settings via the **gear** icon in the popover header.

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 2.1 | Toggle **Prefer Cloud** on/off | Setting holds; UI reflects cloud vs on-device | ☐ | |
| 2.2 | Enter then re-open Settings | API keys + language choices persist across reopen | ☐ | |
| 2.3 | Change **source / target language** | Choice is saved | ☐ | |
| 2.4 | **★ Global shortcut toggle = OFF**, then press the recording hotkey | Recording does **NOT** start (toggle now actually gates the hotkey) | ☐ | *Validates P1-3 fix* |
| 2.5 | **★ Global shortcut toggle = ON**, press the hotkey | Recording starts/stops | ☐ | *Validates P1-3 fix* |
| 2.6 | Quit and relaunch Glyph | All settings persisted across restart | ☐ | |

---

## 3. On-device model download & uninstall (Offline mode)

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 3.1 | In Offline mode with no models, open popover | "Download Models" button + config banner shown | ☐ | |
| 3.2 | Click **Download Models** | Progress bar(s) show Whisper + LLM downloading; completes to "Ready" | ☐ | |
| 3.3 | After download, button becomes **Start Recording** and shows "Ready — on-device" | ☐ | |
| 3.4 | **★** Uninstall a Whisper model (Settings trash button), check `~/Documents/huggingface/models/argmaxinc/...` | Files are actually deleted (disk space freed) — not orphaned | ☐ | *Validates P1-5 path fix* |
| 3.5 | **★** Manually delete the model cache folder, relaunch Glyph | App does NOT falsely show "Downloaded ✓"; prompts to re-download | ☐ | *Validates P1-6 reconcile fix* |

---

## 4. Recording → processing → export (core flow)

This is the heart of the app. Run a short real recording (e.g. play a YouTube clip + talk into the mic for ~30s).

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 4.1 | Click **Start Recording** | Menu-bar icon turns red (waveform); popover shows live elapsed timer + "REC" badge | ☐ | |
| 4.2 | Speak into mic AND play system audio (video/music) for ~30s | Both captured (verify in 4.7 the transcript has both voices) | ☐ | |
| 4.3 | Click **Stop Recording** | Icon turns orange; "Finalizing audio…" then progress % climbs | ☐ | |
| 4.4 | Watch processing stages | Transcribing → Summarizing/Analyzing → Export, with % in menu bar | ☐ | |
| 4.5 | Wait for completion | Entry appears in **Recent** list with green check | ☐ | |
| 4.6 | Click the **open-in-Finder** arrow on the history row | Finder opens the vault folder containing the `.md` | ☐ | |
| 4.7 | Open the exported `.md` | Contains transcript + summary; both mic + system audio content present | ☐ | |
| 4.8 | **★** Check the `.md` YAML frontmatter at the top | `source_language:` shows your actual setting (not always "auto-detected"); `duration:` is quoted and valid | ☐ | *Validates P3-2 fix* |

---

## 5. Resilience / fixed-bug edge cases

These validate the P0/P2 fixes. Some need deliberate fault injection — do what you can.

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 5.1 | **★** Record a **long** session (10+ min) in Cloud mode and let it transcribe | Completes without memory spike / crash (audio is now streamed, not loaded whole) | ☐ | *Validates P0-2 streaming fix* |
| 5.2 | **★** In Cloud mode, force a malformed/odd transcript (e.g. very short / silent recording) | You still get the transcript saved — a parse hiccup no longer throws away the whole result | ☐ | *Validates P2-5 Claude fallback* |
| 5.3 | **★** Deny Screen Recording permission, then record | System-audio capture **fails loudly** (error surfaced) rather than silently producing an empty track; recording state resets cleanly | ☐ | *Validates P0-3 startWriting fix* |
| 5.4 | **★** Start recording then immediately stop after 1–2s, repeat back-to-back 3× | No leftover temp files pile up in the temp dir; each run independent | ☐ | *Validates P2-2 cleanup + fresh-file fix* |
| 5.5 | **★** Cancel/fail a start (e.g. revoke mic mid-attempt) | UI returns to idle; no orphaned `mic_*.caf` / `system_*.m4a` left behind | ☐ | *Validates P2-2 fix* |

> 5.1–5.3 are the highest-value acceptance items — they cover the three P0 data-loss/crash fixes. If you can only do a few, do these.

---

## 6. Calendar integration

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 6.1 | **★** With Calendar permission granted, add a calendar event starting in <5 min | Upcoming-event card appears in the popover with a **Record** button | ☐ | *Validates P1-1 wiring — feature was dead before* |
| 6.2 | **★** ~5 min before the event | A "Meeting Starting Soon" notification fires **once** (not repeatedly every minute) | ☐ | *Validates P1-2 once-only notify* |
| 6.3 | Click **Record** on the event card | Recording starts, titled with the event name | ☐ | |
| 6.4 | **★** With **Auto-stop** ON, record an event and let it pass its end time | Recording auto-stops at event end + "Meeting Ended" notification | ☐ | *Validates P1-1 (auto-stop depends on calendar)* |
| 6.5 | Deny calendar permission | App still works for manual recording; no crash, no console spam | ☐ | |

---

## 7. Global keyboard shortcut

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 7.1 | Set a recording shortcut in Settings | Shortcut displays in the footer as a key-cap | ☐ | |
| 7.2 | Press the shortcut (popover closed) | Toggles recording on/off globally | ☐ | |
| 7.3 | (See 2.4/2.5) Shortcut respects the enable toggle | ☐ | |

---

## 8. Visual / polish

| ID | Test step | Expected result | Result | Note |
|----|-----------|-----------------|:------:|------|
| 8.1 | **★** Observe the recording red (button pressed state, REC badge) | Correct warm red `#E0312A` — NOT orange-shifted | ☐ | *Validates blue-channel hex fix* |
| 8.2 | **★** Check the app icon in Finder (Get Info on Glyph.app) & menu bar | Proper rendered icon at all sizes — no missing/blurry/placeholder icon | ☐ | *Validates AppIcon PNG fix* |
| 8.3 | Light mode AND dark mode | Popover text readable in both; no white-on-white or invisible elements | ☐ | |
| 8.4 | Help (?) and Settings (gear) sheets open and close | Both present correct content | ☐ | |

---

## Sign-off

| Area | Result |
|------|:------:|
| 1. Lifecycle & Quit (★ new) | ☐ PASS / ☐ FAIL |
| 2. Settings & persistence | ☐ PASS / ☐ FAIL |
| 3. Model download/uninstall | ☐ PASS / ☐ FAIL |
| 4. Core record→export flow | ☐ PASS / ☐ FAIL |
| 5. Resilience (P0 fixes) | ☐ PASS / ☐ FAIL |
| 6. Calendar | ☐ PASS / ☐ FAIL |
| 7. Keyboard shortcut | ☐ PASS / ☐ FAIL |
| 8. Visual / polish | ☐ PASS / ☐ FAIL |

**Overall UAT verdict:** ☐ ACCEPTED  ☐ ACCEPTED WITH ISSUES  ☐ REJECTED

**Blocking issues found:**
_(list FAIL case IDs + what happened)_

---

### Minimum viable UAT (if short on time)
Run these 8 first — they cover the new feature + the highest-risk fixes:
**1.4, 1.5** (Quit), **4.1–4.7** (core flow), **5.1** (long recording), **5.3** (system-audio failure), **6.1** (calendar card), **8.2** (app icon).
