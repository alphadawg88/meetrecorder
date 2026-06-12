# Scorecard — Glyph · overlay text-containment fix v1.1.2 (run 5) — 2026-06-12

A patch run fixing a user-reported render defect. **UAT-confirmed fixed by the user.**

## The defect
The expanded recording overlay (248px) was too narrow for dot + REC/timer + "System only" chip + Pause +
Stop, so the HStack compressed and the text **wrapped**: "System only" → 3 lines, "Pause" → 2 lines.

## The honest accounting — an escape to the user
- **Born:** the floating-overlay run (v1.x) — the 248px bar shipped with no `lineLimit` and inadequate width.
- **Caught:** now, by the **user** (UAT screenshot) — escape distance ~4 (it persisted through 3 versions).
- **Why the loop missed it:** it is a **render-only** defect — invisible in source, only present in laid-out
  pixels. Every QA pass was source/contrast-level. **2nd render defect to reach the user** (after the v1.1.1
  80px height P3). This is harness **H2** (structure-only QA misses render defects), specific to the floating
  overlay which is never screenshot in QA.

## The fix (built + QA first-pass, UAT-confirmed)
- Expanded width 248 → 336 (sized for the longest state incl. paused).
- CaptureModeChip compact mode (short "Both/Mic/System") in the overlay.
- `lineLimit(1)` + `fixedSize` on chip + Pause/Stop labels; Stop label padded.

## The catch (loop-engineered)
- **Gate-C check added:** "Text containment (RENDER-verify) — fixed-size/compact containers must fit every
  label on one line; screenshot the component; structure review misses this."
- design-language §4: **auto-size-to-content** logged as the robust follow-up.

## Metrics
- **Escape-to-user: 1** this run (the wrapping reached the user) — the escape belongs to the floating-overlay
  run; it surfaced now. Trend interrupted (0.0→0.0→**1 render-escape**). The render gap is the cause.
- The FIX itself: built + QA first-pass, UAT-confirmed. L3/L4/L5 held a 5th run.

## Systemic open item (worth a future fix)
The floating overlay needs a **render check in QA** — neither qa-editor (source-level) nor the main loop (can't
headlessly screenshot an NSPanel) currently provides one; the user is the only render check. Options: a SwiftUI
`ImageRenderer` snapshot test for the overlay views, or a scripted screenshot during a test recording. Until
then, the Gate-C render-verify check + treating the user's screenshot as the gate is the interim.
