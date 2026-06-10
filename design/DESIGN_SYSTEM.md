# MeetRecorder Design System v2.0

## 1. Design Principles

1. **Dark-first, always.** The app lives in the background during meetings. Every surface must be low-luminance to avoid screen glare.
2. **One-glance status.** A user must know whether they are recording, paused, or idle without reading text.
3. **Action proximity.** The most frequent action (toggle record) is the largest, most saturated element on screen.
4. **Information hierarchy through density.** Active content is high-contrast and high-density; chrome is receded.
5. **Motion with purpose.** Animations only indicate state change (recording pulse, level meters, waveform scroll). No decorative motion.

## 2. Color Tokens

### 2.1 Background Scale
| Token | Hex | Usage |
|-------|-----|-------|
| `--bg-base` | `#0A0A0A` | Deepest background, window chrome |
| `--bg-surface` | `#111111` | Cards, panels, modals |
| `--bg-raised` | `#1A1A1A` | Inputs, buttons at rest, table rows |
| `--bg-hover` | `#222222` | Hover states on interactive surfaces |
| `--bg-active` | `#2A2A2A` | Active/pressed states |
| `--bg-overlay` | `rgba(0,0,0,0.72)` | Modal backdrops, toasts |

### 2.2 Foreground Scale
| Token | Hex | Usage |
|-------|-----|-------|
| `--fg-primary` | `#E8E8E8` | Headings, primary text, labels |
| `--fg-secondary` | `#888888` | Body text, descriptions, timestamps |
| `--fg-tertiary` | `#555555` | Placeholder text, disabled, metadata |
| `--fg-inverse` | `#0A0A0A` | Text on accent-colored backgrounds |

### 2.3 Semantic Colors
| Token | Hex | Usage |
|-------|-----|-------|
| `--accent` | `#A100FF` | Primary brand, active nav, focused ring |
| `--accent-hover` | `#B52AFF` | Accent hover |
| `--accent-active` | `#8A00DB` | Accent pressed |
| `--accent-glow` | `rgba(161,0,255,0.35)` | Accent shadows, glow effects |
| `--success` | `#00E676` | Transcription complete, saved, healthy |
| `--success-dim` | `rgba(0,230,118,0.15)` | Success backgrounds |
| `--warning` | `#FFAB00` | Warnings, pending, processing |
| `--warning-dim` | `rgba(255,171,0,0.15)` | Warning backgrounds |
| `--danger` | `#FF4444` | Recording indicator, errors, destructive |
| `--danger-dim` | `rgba(255,68,68,0.15)` | Danger backgrounds |
| `--info` | `#05F2DB` | Info tags, system channel badge |
| `--info-dim` | `rgba(5,242,219,0.15)` | Info backgrounds |

### 2.4 Channel Colors (Audio Meters)
| Token | Hex | Usage |
|-------|-----|-------|
| `--channel-mic` | `#FF50A0` | Microphone channel meter, mic track badge |
| `--channel-system` | `#05F2DB` | System audio channel meter, system track badge |
| `--channel-combined` | `#A100FF` | Combined stereo track badge |

## 3. Typography Tokens

| Token | Family | Size | Weight | Line-Height | Letter-Spacing | Usage |
|-------|--------|------|--------|-------------|----------------|-------|
| `--font-display` | SF Pro Display | 32px | 700 | 1.1 | -0.02em | Hero titles |
| `--font-h1` | SF Pro Display | 24px | 600 | 1.2 | -0.01em | Screen titles |
| `--font-h2` | SF Pro Display | 18px | 600 | 1.3 | 0 | Section headers |
| `--font-h3` | SF Pro Display | 14px | 600 | 1.4 | 0.01em | Card titles, table headers |
| `--font-body` | SF Pro Text | 13px | 400 | 1.5 | 0.01em | Body text, descriptions |
| `--font-caption` | SF Pro Text | 11px | 500 | 1.4 | 0.02em | Badges, timestamps, metadata |
| `--font-mono` | SF Mono | 12px | 400 | 1.4 | 0 | Durations, file sizes, code |
| `--font-nav` | SF Pro Display | 11px | 500 | 1 | 0.05em | Bottom nav labels |

## 4. Spacing Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--space-1` | 4px | Tight internal padding, icon gaps |
| `--space-2` | 8px | Button internal padding, row gaps |
| `--space-3` | 12px | Card internal padding |
| `--space-4` | 16px | Panel padding, section gaps |
| `--space-5` | 24px | Screen edge padding |
| `--space-6` | 32px | Major section separation |
| `--space-7` | 48px | Hero spacing |

## 5. Elevation & Shadow Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--shadow-sm` | `0 1px 2px rgba(0,0,0,0.4)` | Buttons, badges |
| `--shadow-md` | `0 4px 12px rgba(0,0,0,0.5)` | Cards, popovers |
| `--shadow-lg` | `0 8px 32px rgba(0,0,0,0.6)` | Modals, toasts |
| `--shadow-glow-accent` | `0 0 20px var(--accent-glow)` | Recording button glow |
| `--shadow-glow-danger` | `0 0 20px rgba(255,68,68,0.35)` | Recording active glow |

## 6. Border & Radius Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--radius-sm` | 4px | Badges, small buttons |
| `--radius-md` | 6px | Inputs, tags |
| `--radius-lg` | 10px | Cards, panels |
| `--radius-xl` | 14px | Modals, large cards |
| `--radius-full` | 999px | Pills, record button |
| `--border-subtle` | 1px solid `#222222` | Card borders, dividers |
| `--border-focus` | 1px solid var(--accent) | Focused input border |

## 7. Animation Tokens

| Token | Value | Usage |
|-------|-------|-------|
| `--duration-fast` | 150ms | Hover states, color transitions |
| `--duration-normal` | 250ms | Expand/collapse, nav transitions |
| `--duration-slow` | 400ms | Modal open/close, page transitions |
| `--ease-default` | `cubic-bezier(0.4, 0, 0.2, 1)` | Standard transitions |
| `--ease-bounce` | `cubic-bezier(0.34, 1.56, 0.64, 1)` | Record button press |

## 8. Component Specifications

### 8.1 Record Button (Primary Action)
- **Idle state:** 80x80px circle, `--bg-raised` fill, `--border-subtle`, `--fg-primary` inner circle icon (24px)
- **Hover:** Scale 1.05, `--shadow-md`
- **Recording state:** `--danger` fill, pulsing glow `--shadow-glow-danger`, inner icon = square (stop)
- **Recording pulse:** `@keyframes pulse { 0%,100%{box-shadow:0 0 0 0 rgba(255,68,68,0.4)} 50%{box-shadow:0 0 0 12px rgba(255,68,68,0)} }`, duration 2s, infinite
- **Transition:** `--duration-normal` `--ease-bounce`

### 8.2 Audio Level Meter
- **Container:** 8px wide, `--radius-full`, height varies, `--bg-base` track
- **Fill:** Gradient from `--success` (bottom) through `--warning` (mid) to `--danger` (top)
- **Segments:** 24 segments, 2px gap, segment height 4px
- **Animation:** 60ms decay, instant rise
- **Dual meter layout:** Two meters side by side, 12px gap. Left = `--channel-mic`, Right = `--channel-system`

### 8.3 Waveform Visualizer
- **Canvas:** Full-width, 64px height, `--bg-surface` background
- **Wave color:** `--fg-secondary` at 40% opacity
- **Recording wave color:** `--accent` at 60% opacity
- **Update rate:** 30fps during recording
- **Scroll:** Horizontal scroll-left at 50px/s during recording

### 8.4 Recording Card (Library)
- **Container:** `--bg-surface`, `--radius-lg`, `--border-subtle`, `--shadow-sm`
- **Hover:** `--bg-hover`, `--shadow-md`, border-color `#333333`
- **Layout:** Horizontal flex. Left = waveform thumbnail (80x40px). Center = title + metadata. Right = actions + status badge.
- **Waveform thumbnail:** Mini canvas render of first 3 seconds
- **Status badge:** Pill, `--font-caption`, uppercase, letter-spacing 0.05em
  - Recording: `--danger-dim` bg, `--danger` text, pulsing dot
  - Transcribing: `--warning-dim` bg, `--warning` text, spinner
  - Ready: `--success-dim` bg, `--success` text
  - No transcript: `--bg-active` bg, `--fg-tertiary` text
- **Track type badge:** Pill, small
  - Combined: `--accent-glow` bg, `--accent` text
  - Mic: `--channel-mic` at 20% opacity bg, `--channel-mic` text
  - System: `--channel-system` at 20% opacity bg, `--channel-system` text

### 8.5 Transcript Line
- **Container:** `--bg-surface`, `--radius-md`, padding `--space-3`
- **Speaker label:** `--font-caption`, `--accent` color, uppercase, 60px width
- **Timestamp:** `--font-mono`, `--fg-tertiary`, 60px width
- **Text:** `--font-body`, `--fg-secondary`
- **Highlight:** `--warning-dim` background on key phrases
- **Selected:** `--border-focus` left border (3px)

### 8.6 Insight Tag
- **Container:** Pill, `--radius-full`, `--font-caption`, uppercase
- **Decision:** `--accent-glow` bg, `--accent` text, icon = diamond
- **Action:** `--success-dim` bg, `--success` text, icon = check-circle
- **Risk:** `--danger-dim` bg, `--danger` text, icon = alert-triangle
- **Topic:** `--info-dim` bg, `--info` text, icon = hash

### 8.7 Toggle Switch
- **Track:** 40x20px, `--radius-full`, `--bg-active` at rest, `--accent` when on
- **Thumb:** 16x16px circle, `--fg-primary`, 2px inset from track edge
- **Transition:** `--duration-fast`

### 8.8 Bottom Navigation
- **Container:** `--bg-base` with `--border-subtle` top border, height 56px
- **Item:** Vertical stack (icon 20px + label `--font-nav`), centered
- **Active:** `--accent` icon + text
- **Inactive:** `--fg-tertiary` icon + text
- **Hover:** `--fg-secondary`

## 9. Screen Specifications

### 9.1 Record Screen (Default/Home)
- **Layout:** Centered column, max-width 480px
- **Elements top to bottom:**
  1. App logo (24px, `--accent`) + title "MeetRecorder" (`--font-h1`)
  2. Recording timer (`--font-mono`, 48px, `--fg-primary`)
  3. Record button (80px circle, centered)
  4. Status text (`--font-caption`, `--fg-secondary`)
  5. Dual audio meters (two 8px bars, 120px tall, centered)
  6. Waveform canvas (full width, 80px tall, `--radius-lg`)
  7. Quick actions row: "Mic Only" toggle, "Open Folder" button

### 9.2 Library Screen
- **Layout:** Full-width list, max-width 720px centered
- **Header:** "Recordings" (`--font-h1`) + count badge + filter/search bar
- **Filter tabs:** All / Combined / Mic / System / Transcribed / Untranscribed
- **List:** Recording cards stacked vertically, `--space-2` gap
- **Empty state:** Illustration + "No recordings yet" + "Start your first recording" CTA
- **Actions per card:** Play, Transcribe, Open in Folder, Delete (danger)

### 9.3 Transcript Screen
- **Layout:** Two-pane on desktop (transcript left 60%, insights right 40%). Stack on mobile.
- **Header:** Recording title + back button + export actions
- **Transcript pane:** Scrollable list of transcript lines
- **Search bar:** Sticky top, `--bg-raised`, `--radius-md`
- **Insights pane:** Collapsible sections (Decisions, Action Items, Risks)
- **Playhead:** Vertical line at current playback position, synced with audio player

### 9.4 Settings Screen
- **Layout:** Full-width form, max-width 560px centered
- **Sections:**
  1. **Output:** Directory picker, filename pattern
  2. **Audio:** Default mic device dropdown, system device dropdown, samplerate
  3. **Transcription:** Whisper model selector (tiny/base/small/medium/large), auto-transcribe toggle, language selector
  4. **Shortcuts:** Keyboard shortcut config (non-editable display for now)
  5. **System:** Launch at login toggle, menu bar icon style, update check
- **Section header:** `--font-h2` with `--fg-secondary` divider line
- **Input style:** `--bg-raised`, `--radius-md`, `--border-subtle`, focus = `--border-focus`

## 10. Responsive Breakpoints

| Name | Width | Behavior |
|------|-------|----------|
| Mobile | < 640px | Single column, bottom nav, full-width cards |
| Tablet | 640-1024px | Two columns where applicable, side nav |
| Desktop | > 1024px | Three-column transcript layout, persistent sidebar |

## 11. Assets & Iconography

- **Icon set:** SF Symbols (macOS native) or Phosphor Icons (web fallback)
- **Icon size standard:** 20px UI, 24px actions, 16px inline
- **Recording states:**
  - Idle: `record.circle`
  - Recording: `record.circle.fill` (tinted `--danger`)
  - Paused: `pause.circle.fill`
- **File types:**
  - Combined: `waveform`
  - Mic: `mic.fill`
  - System: `speaker.wave.2.fill`

## 12. Z-Index Scale

| Layer | Z-Index | Elements |
|-------|---------|----------|
| Base | 0 | Page content |
| Elevated | 10 | Cards, sticky headers |
| Floating | 100 | Dropdowns, tooltips |
| Overlay | 1000 | Modal backdrop |
| Modal | 1010 | Modal content |
| Toast | 1100 | Notifications |
| Critical | 9999 | Error banners |
