# Glyph — Design Language (per-product)

The concrete expression of Glyph's UI. **Inherits the universal master**
`~/.claude/knowledge/product-design-canon.md` (ethos, contrast laws, component discipline, iteration
rubric, the decision-log mechanism). This file holds only what is Glyph-specific. Iterated at Gate C
(`/design-review`). Updated append-only.

## 0. How the ethos is expressed in Glyph
The universal principles (canon §1), as Glyph chooses to express them:
- **Unobtrusive** → always-on menu-bar utility; the floating overlay collapses after 6s; the menu-bar icon
  is the primary always-on path. Never a destination app.
- **Restraint** → **dark-first absolute** (forced dark, near-black grounds) so the 3 semantic + 3 channel
  colors read at full strength. No light-mode variant.
- **Honest signals** → pulsing red dot = recording; amber = paused; collapsed pill + live clock = active.
- **Thorough** → monospaced timer, 1px panel stroke, pill `accessibilityLabel`, reduce-motion pulse gate,
  the `isPaused` auto-collapse guard.
- **Edge earns trust** → the channel-color system + crafted pill geometry + calibrated shadow.

## 1. Tokens (Glyph v2.0)
### Backgrounds (elevation = lighter) — never skip a level
```
bgBase #0A0A0A · bgSurface #111111 · bgRaised #1A1A1A · bgHover #222222 · bgActive #2A2A2A
```
### Foreground (verified on bgRaised)
```
fgPrimary #E8E8E8 (14.20:1) · fgSecondary #888888 (4.91:1) · fgTertiary #555555 (2.80:1, disabled only — AA fail)
```
### Semantic — NOT interchangeable (canon §3 laws)
| Token | Hex | Ratio (bgRaised) | Use |
|---|---|---|---|
| `danger` | #FF4444 | 5.11:1 | dots, StatusBadge text, error text. **NOT a button fill.** |
| `dangerButton` | #D70015 | 5.38:1 (white-on-fill) | filled button bg (RecordButtonStyle) ONLY. |
| `dangerButtonPressed` | #B00011 | — | pressed dangerButton only. |
| `warning` | #FFAB00 | 9.18:1 | paused state, long-session timer, processing badge. |
| `success` | #00E676 | — | done badge, shield. |
| `accent` | #A100FF | 3.28:1 | tints/focus rings/progress ONLY. **Never as label text** (fails 4.5:1). |
### Channel colors — semantic only (canon §3 "indicator ≠ label")
```
channelMic #FF50A0 (5.72:1) · channelSystem #05F2DB (12.21:1) · combined = accent #A100FF
```
Chip rule: the channel color rides the **icon + bg tint**; the chip **label is `fgPrimary`** (13.5:1).
Never repurpose channel colors for non-audio concepts.
### Type · Space · Radius
```
display24 · h1 18 · h2 14 · body13 · bodyMed13 · caption11 · labelCaps10 · mono12
xs4 sm8 md12 lg16 xl24   |   radius sm4 md6 lg10 xl14 full9999
```
### The `.dark` + `.tint` rule
Every surface carries `.preferredColorScheme(.dark).tint(DesignToken.accent)` — **sheets and NSPanels set
their own** (they don't inherit from the popover root).

## 2. Signature moves (the edge — protect & reuse)
| Signature | Rule |
|---|---|
| **Dark-first absolute** | No light fallback; set `.preferredColorScheme(.dark)+.tint(accent)` on every surface. |
| **Channel-color system** | mic-pink / system-teal / combined-purple; only on `CaptureModeChip`/audio indicators (icon+tint, not label). |
| **Monospaced live timer** | `.monospacedDigit()` always; 13/11px overlay, display24 in RecordingView. |
| **Pulsing-but-calm dot** | 8px, danger red / paused amber, 1.8s easeInOut scale 1.0→1.4 op 1.0→0.6, reduce-motion gated. |
| **Pill geometry for state** | Capsule = state/action/channel; rounded-rect = panels/cards. |
| **Floating overlay — present but tiny** | collapsed 104×30, expanded 248×64; `.floating` level, not over fullscreen; 6s auto-collapse; freeze on pause; saved position; anchor bottom-right grow up+left. |
| **Label-caps micro-type** | 10px/semibold +0.6 tracking uppercase; status labels + section headers + button labels. |
| **bgHover 1px panel border** | 1px strokeBorder bgHover on bgRaised floating panels (decorative edge). |
| **Shadow black 72% / radius 16** | `.shadow(.black.opacity(0.72), radius16, y8)`; `panel.hasShadow=false`. One per surface. |
| **Countdown hairline** | 2px bar at the bottom edge of a TIME-BOUNDED floating panel; bar = the channel/semantic token that triggered it (channelMic for the mic nudge), track = bgHover; depletes right→left over the auto-dismiss duration; **omitted under reduce-motion**. Only on transient auto-dismiss panels, never persistent surfaces. |

## 3. Component instances
- **RecordButtonStyle** — primary; `dangerButton` #D70015 fill, white label, 32px. One per state.
- **SecondaryButtonStyle** — bgHover→bgActive, fgPrimary, ~26px (Pause/Resume/contextual Record).
- **GhostButtonStyle** — transparent→bgHover.opacity(0.6), fgSecondary (gear/folder/quit/Not now).
- **StatusBadge** — recording(danger, **0.08 tint** → 4.74:1) / processing(warning) / done(success); label-caps, Capsule.
- **CaptureModeChip** — channel icon+tint, fgPrimary label; popover + overlay; dims 40% when paused (label still reads).
- **RecordingOverlayView** — expanded/collapsed/paused panel family (sizes above).
- **CallNudgeView** — 280×60 toast, 8s auto-dismiss, never during recording; `mic.fill` channelMic icon; Record(primary)/Not now(ghost).
- *Target-size note:* overlay/popover buttons are below 44px (accepted dense-format deviation; `.contentShape` mitigates) — see decision log.

## 4. Open design backlog
- **Overlay should auto-size to content width** (robust fix) — the expanded bar is a fixed 336px sized for the longest label/state; a content-driven width would survive any future label/locale change without a re-measure. (deferred; current fix = fixed width + lineLimit + compact chip.)
- **Focus-ring on overlay buttons** should use accent, not system blue — VERIFY in UAT; fix only if system-blue rings observed (P2-D, v1.1.0).
- **HistoryRow completed/failed** — icon+color carries the signal (passes color-only rule); a tooltip/a11y label would strengthen it. (deferred)
- **UpcomingEventCard empty state** — idle layout feels loose when no event; a light "No events today" ghost row would anchor it. (deferred)
- **ProcessingView stage text** — uncontrolled backend string; define canonical stage labels + max length → copywriter. (deferred)
- *Closed v1.1.0:* sub-44px target deviation (logged §5); collapse/expand animation desync (instant synced swap).

## 5. Accrued design decisions (append-only)

### 2026-06-10 — Dark-first v2.0 migration
**Decision:** absolute dark-only system, sRGB hex absolutes, `NSColor(hex:)`.
**Why:** meetings/screen-share contexts + menu-bar utility; dark reduces noise, semantic colors read max-contrast without a light variant.

### 2026-06-10 — Channel-color system
**Decision:** mic #FF50A0, system #05F2DB, combined accent.
**Why:** chip is scannable across popover+overlay — color tells the mode without reading the label.

### 2026-06-10 — CaptureModeChip as shared component
**Decision:** one `CaptureModeChip` reused in RecordingView/ProcessingView/RecordingOverlayView.
**Why:** single source of truth; no popover↔overlay divergence.

### 2026-06-10 — Floating overlay brief locked
**Decision:** fixed sizes 248×64 / 104×30 / 280×60; `.floating` (not over fullscreen); 6s auto-collapse; freeze on pause; save drag position.
**Why:** maximally unobtrusive during screen-share; fixed sizes prevent jitter; paused-freeze preserves the signal; position persistence cuts friction.

### 2026-06-10 — dangerButton #D70015 (AA fix)
**Decision:** added dangerButton/Pressed alongside danger.
**Why:** white on #FF4444 = 3.2:1 (fail); white on #D70015 = 5.38:1 (pass). Indicator #FF4444 stays for dots/text. Two tokens, two contexts.

### 2026-06-10 — Sheets need own `.dark`+`.tint`
**Decision:** SettingsView/HelpView carry their own modifiers.
**Why:** SwiftUI sheet isolation — otherwise OS light theme + system-blue tint leaks in.

### 2026-06-10 — PulseModifier calibration
**Decision:** scale 1.4 / opacity 0.6 / 1.8s easeInOut / reduce-motion gate.
**Why:** reads "live" not "urgent"; <1s = anxiety, >1.5 scale = eye-pull; reduce-motion mandatory (WCAG 2.3.3).

### 2026-06-12 — Chip label legibility + REC/badge state-color
**Decision:** chip label → fgPrimary (channel color on icon+tint only); recording StatusBadge tint 0.12→0.08 (4.74:1); overlay "REC" label → danger red (was grey).
**Why:** accent-on-tint label was 3.11:1 (fail) — superseded the earlier "accept as UI-component exception"; an AA miss is fixed, not grandfathered. Status labels read at the weight of the state they name.

### 2026-06-12 — v1.1.0 patch: ModelCard tag follows the indicator≠label rule
**Decision:** `ModelCard` tag `Text` → `fgPrimary` (accent stays on the capsule tint + selection circle), not accent.
**Why:** accent-on-accent-tint = 3.11:1 (AA fail) — the SAME class as the chip label. Codified into the Gate-C checklist this run so it can't recur a 3rd time.

### 2026-06-12 — v1.1.0 patch: selected ModelCard gains a 1px accent stroke (new signature)
**Decision:** the selected state = accent.0.12 fill **+ a 1px accent `strokeBorder`** (the "border-as-signal" move, reused from the panel border).
**Why:** the fill-only wash was too subtle on dark — a first-time user could miss their selection. The stroke makes "I chose this" unmistakable for ~2 lines of code. Added as a protected signature move.

### 2026-06-12 — v1.1.2 fix: overlay text containment (no wrap)
**Decision:** expanded overlay 248→336px; CaptureModeChip gains a `compact` mode (short label "Both/Mic/System") used in the overlay; chip label + Pause/Stop labels get `lineLimit(1)` + `fixedSize`; Stop label gains sm h-padding (RecordButtonStyle has none — it's full-width in the popover).
**Why:** the 248px bar was too narrow for dot+REC+timer+"System only"+Pause+Stop, so the HStack compressed and text wrapped ("Syste/m/only", "Pau/se"). Sized for the longest state (paused: "PAUSED"+"Resume"+"System") with slack. RENDER defect — escaped because the floating overlay was never screenshot in QA → added Gate-C "text containment (render-verify)" check.

### 2026-06-12 — CallNudgeView v2: three-row hierarchy + countdown hairline
**Decision:** popup → 280×80; added a channelMic **eyebrow** row ("MIC ACTIVITY" labelCaps + mic.fill, 5.72:1) above the body; body made factual ("Meeting in progress. Record this session?"); added the **countdown hairline** (2px channelMic bar depleting on a bgHover track over the 8s auto-dismiss, reduce-motion → omitted); panel fade also reduce-motion gated in OverlayController.
**Why:** the old popup read generic — flat hierarchy (body did triple duty), icon-only detection source, and an invisible 8s dismiss. The eyebrow gives a 1st→2nd→3rd eye order + names the trigger via the channel-color system; the hairline makes transience legible without urgency (anti-annoyance). New signature move "countdown hairline" added §2. All in-system; no AA miss.

### 2026-06-12 — Sub-44px dense-format target deviation: formally CLOSED
**Decision:** RecordButtonStyle 32px (popover full-width 360px tap area) + compact overlay buttons accepted; `.contentShape(Rectangle())` mitigation in place. Backlog item closed.
**Why:** full-width tap surface compensates in the popover; the overlay's compact size is a deliberate unobtrusive-first trade-off. Not worth growing the overlay fixed sizes.
