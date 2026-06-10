---
version: alpha
name: Glyph
description: A native macOS menu bar utility for meeting capture. Invisible when idle, precise when active, and respectful of the user's cognitive space.
colors:
  primary: "#1D1D1F"
  secondary: "#6E6E73"
  tertiary: "#D70015"
  on-primary: "#FFFFFF"
  on-tertiary: "#FFFFFF"
  success: "#1A6B2E"
  warning: "#8A4500"
  surface: "#FFFFFF"
  surface-secondary: "#F5F5F7"
  divider: "#E5E5EA"
typography:
  display:
    fontFamily: SF Pro
    fontSize: 20px
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "-0.02em"
  title:
    fontFamily: SF Pro
    fontSize: 15px
    fontWeight: 600
    lineHeight: 1.3
    letterSpacing: "-0.01em"
  body:
    fontFamily: SF Pro
    fontSize: 13px
    fontWeight: 400
    lineHeight: 1.4
  caption:
    fontFamily: SF Pro
    fontSize: 11px
    fontWeight: 400
    lineHeight: 1.3
    letterSpacing: "0.01em"
  label-caps:
    fontFamily: SF Pro
    fontSize: 10px
    fontWeight: 600
    letterSpacing: "0.06em"
    textTransform: uppercase
rounded:
  sm: 4px
  md: 8px
  lg: 12px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 12px
  lg: 16px
  xl: 24px
components:
  button-primary:
    backgroundColor: "{colors.tertiary}"
    textColor: "{colors.on-tertiary}"
    typography: "{typography.label-caps}"
    rounded: "{rounded.full}"
    padding: "10px 16px"
  button-primary-hover:
    backgroundColor: "#E0312A"
    textColor: "{colors.on-tertiary}"
  button-secondary:
    backgroundColor: "{colors.surface-secondary}"
    textColor: "{colors.primary}"
    typography: "{typography.label-caps}"
    rounded: "{rounded.full}"
    padding: "8px 12px"
  button-secondary-hover:
    backgroundColor: "{colors.divider}"
    textColor: "{colors.primary}"
  button-ghost:
    backgroundColor: "{colors.surface-secondary}"
    textColor: "{colors.secondary}"
    typography: "{typography.caption}"
    rounded: "{rounded.sm}"
    padding: "4px 6px"
  button-ghost-hover:
    backgroundColor: "{colors.divider}"
    textColor: "{colors.primary}"
  meeting-card:
    backgroundColor: "{colors.surface-secondary}"
    textColor: "{colors.primary}"
    rounded: "{rounded.md}"
    padding: "10px 12px"
  list-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.primary}"
    rounded: "{rounded.sm}"
    padding: "6px 8px"
  list-row-hover:
    backgroundColor: "{colors.surface-secondary}"
    textColor: "{colors.primary}"
  status-badge-recording:
    backgroundColor: "#FDECEB"
    textColor: "{colors.tertiary}"
    rounded: "{rounded.full}"
    padding: "2px 8px"
  status-badge-processing:
    backgroundColor: "#FEF3E2"
    textColor: "{colors.warning}"
    rounded: "{rounded.full}"
    padding: "2px 8px"
  status-badge-done:
    backgroundColor: "#E8F5EC"
    textColor: "{colors.success}"
    rounded: "{rounded.full}"
    padding: "2px 8px"
---

## Overview

MeetRecorder is a background utility, not a foreground application. Its visual
identity must disappear into the macOS menu bar ecosystem. The design language
is **invisible utility**: zero chrome, zero decoration, maximum information
density per pixel. When idle, the user should forget it exists. When recording,
the state should be unmistakable at 3 metres. When processing, progress should
be honest and calm — never anxious.

The app follows Apple Human Interface Guidelines without imitation. We use
native SwiftUI primitives, system materials, and semantic colors so that the
interface adapts automatically to light mode, dark mode, and accessibility
settings. No custom widgets where a `.pickerStyle(.segmented)` will do.

## Colors

- **Primary (#1D1D1F):** Headlines, active text, and primary labels. Maps to
  `NSColor.label` in implementation.
- **Secondary (#6E6E73):** Timestamps, metadata, placeholders, and disabled
  states. Maps to `NSColor.secondaryLabel`.
- **Tertiary (#D70015):** The recording signal. Used exclusively for the
  Start/Stop recording action and the live recording indicator.
- **Surface (#FFFFFF):** Primary backgrounds. On macOS this is best
  implemented with `.background(.ultraThinMaterial)` so that wallpaper
  tints bleed through naturally.
- **Surface-secondary (#F5F5F7):** Elevated cards, hover states, and
  secondary containers.
- **Success (#1A6B2E):** Completion states — exported files, successful
  transcription, checkmarks.
- **Warning (#8A4500):** Processing, pending, and non-blocking errors.
- **Divider (#E5E5EA):** 1px hairlines. Use `Divider()` or
  `NSColor.separator` in code; never hard-code the hex.

## Typography

SF Pro at every size. Weight and color carry hierarchy, not font family.

- **Display (20 px / 600 wt):** Used once — the live timer during recording.
  Monospaced digits (`monospacedDigit()`) to prevent jitter as numbers change.
- **Title (15 px / 600 wt):** Section headers inside the popover and the
  meeting name in the recording card.
- **Body (13 px / 400 wt):** Default reading size for all content.
- **Caption (11 px / 400 wt):** Timestamps, file paths, shortcut hints.
- **Label-caps (10 px / 600 wt / +0.06em):** Buttons and status badges.
  Uppercase by convention. The extra tracking keeps small caps readable.

## Layout

The popover is a fixed 360 px wide — wide enough for readable meeting titles,
narrow enough to avoid modal fatigue. Height is elastic, capped at ~560 px
before scrolling.

Spacing follows an 8 px grid halved:

- `xs` (4 px): icon-to-text padding inside list rows.
- `sm` (8 px): internal padding inside cards.
- `md` (12 px): gaps between related controls (e.g., button + progress stack).
- `lg` (16 px): section breaks (header to content, content to list).
- `xl` (24 px): rare; used only when the window expands to show settings.

All content sits 16 px from the window edges. No full-bleed elements except
the top window chrome.

## Elevation & Depth

Zero drop shadows. Depth is communicated exclusively through:

1. **Material layers** — `.ultraThinMaterial` for the window, `.thinMaterial`
   for elevated cards (upcoming meeting, recording state).
2. **Dividers** — 1 px `NSColor.separator` lines between logical sections.
3. **Color temperature** — secondary surfaces are slightly warmer/cooler than
   the base, never lifted with shadows.

This preserves the native macOS aesthetic and avoids the "web app in a menu
bar" look.

## Shapes

- **sm (4 px):** List rows, small buttons, text field corners.
- **md (8 px):** Cards (upcoming meeting, recording status), progress bars.
- **lg (12 px):** The popover window corners themselves.
- **full (9999 px):** Primary actions and status badges only. Full pills
  signal "action" or "state", not "container".

## Components

### button-primary
The single high-emphasis action per state. Red background, white uppercase
label, full pill. Height is 32 px (compact control size). Disabled state
uses `NSColor.systemGray` at 50 % opacity, not a custom hex.

### button-secondary
Used for contextual shortcuts ("Record" on a calendar event card). Gray
background, primary text, full pill, 28 px height. Never appears without a
primary button nearby to establish hierarchy.

### button-ghost
Icon-only or text-only tertiary actions: "Open folder", "Settings gear",
"Dismiss". Transparent background, secondary text. On hover, the background
fills with `surface-secondary`. No border.

### meeting-card
The upcoming-event container. 8 px rounded rectangle, `surface-secondary`
background, 10 px internal padding. Contains a title, time range, and a
secondary button aligned to the trailing edge.

### list-row
History entries. 4 px rounding, `surface` background, 6 px vertical padding.
On hover, background becomes `surface-secondary`. Leading icon shows status
(done / processing / error); trailing action is a ghost button.

### status-badge-*
Three semantic pills: recording (red tint), processing (amber tint), done
(green tint). All use `label-caps` typography at 10 px. The background is
a pale tint of the semantic color; the text is the full-strength color.

## Do's and Don'ts

- **Do** rely on `NSColor` semantic equivalents so that dark mode, high
  contrast, and accent-color changes are free.
- **Do** animate state transitions with `.animation(.easeInOut(duration: 0.2))`.
  The popover should feel alive, not like a static web page.
- **Do** use monospaced digits for all timers, durations, and timestamps to
  prevent layout shift.
- **Don't** use `.red` or `.blue` directly in SwiftUI. Bind to the token
  system so that the DESIGN.md remains the single source of truth.
- **Don't** add shadows, glows, or blurs beyond system materials.
- **Don't** show more than one primary button on screen at a time. If two
  actions compete, downgrade the less frequent one to `button-secondary`.
- **Don't** use the tertiary red for anything other than recording state.
  It is a reserved signal.
