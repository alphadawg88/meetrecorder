# Scorecard — Glyph · floating-overlay run (run 2) — 2026-06-11

Reconstructed retro. Governed by `~/.claude/knowledge/product-loop-framework.md`.

## Headline — the flywheel worked
**All three promoted guards from run 1 fired / held this run, zero recurrence:**
- **L3** (auto-`xcodegen`): the build's first failure was a real compile error, NOT "cannot find scope" — the project auto-regenerated for the 2 new files. ✓
- **L4** (`SIGN-CHECK`): asserted `Authority=Glyph Local Signing` on every build. ✓ No permission loop.
- **L5** (destructive-intent): the overlay's Stop/Record/Pause are explicit labelled buttons; the collapsed pill only expands. qa-editor confirmed no passive trigger. ✓

The escapes this run were **new classes**, not repeats — which is exactly what an improving loop looks like.

## Stage log
| Stage | Gate | Result | Notes |
|---|---|---|---|
| 0 Intake | A | ✅ | overlay scope + "always-on?" resolved (on-while-recording, collapsible) |
| 1 Arch | B | ✅ | pause ADR: mic native pause, system-audio drop-buffers, freeze-aware elapsed |
| 2 Design | C | ◐ deferred-defect | ux-designer brief good; **AA-contrast finding was deferred, not blocked** → became D5 |
| 3 Build | D | ◐ 2nd-pass | CaptureModeChip private (caught at build); L3+L4 guards fired ✓ |
| 4 QA | E | ◐ 2nd-pass | caught **P1** (stop-while-paused silent) + 3×P2; all fixed |
| 9 Retro | — | this | |

## Defects (born → caught)
| ID | Sev | Defect | Born→Caught | Escape | Lesson |
|---|---|---|---|---|---|
| D1 | P1 | Stop-while-paused → next recording silently blank | build → qa | 1 | **L8 (new)** |
| D2 | P2 | Stale recorder after stop → resume corrupts file | build → qa | 1 | L8 |
| D3 | P2 | didMove observer never removed (leak) | build → qa | 1 | — (WATCH) |
| D4 | P2 | Panel resize no screen clamp | build → qa | 1 | — |
| D5 | P2 | White Stop label on #FF4444 = 3.41:1 (fails AA) | **design → uat (user required)** | **2** | **design:button-fill-contrast (new)** |

## Constraint vs authoring pattern
- **Authoring (us):** D1/D2 (per-session state not reset → poisons next session) — a lifecycle-hygiene class. D5 (reused an indicator color as a button fill).
- **Process gap:** D5 was *detected twice* (design brief + QA) but **deferred** instead of blocked, despite the checklist's own "AA miss blocks delivery" rule. The miss wasn't detection — it was enforcement.

## Metrics (vs run 1)
- **Escape-to-user: 0.20** (1/5) — down from 0.25. ↓ improving.
- **Known promoted-class recurrences: 0** — the run-1 guards held. ✓
- **Hard-gate first-pass: 0.0** — build + QA each took a 2nd pass (complex feature; gates caught real defects, which is the point).
- Rework: 3.

## Recommendations → promotion target
1. **L8 — per-session state-reset hygiene** (covers D1+D2) → product ledger + a regression test (start→pause→stop→start→assert non-empty). [BUILD]
2. **Button-fill contrast rule** (D5) → line in `ux-designer-design-qa-checklist.md`: a semantic/indicator color that passes as text-on-dark does NOT auto-pass as a button FILL with a white label — verify label-on-fill separately; an AA miss BLOCKS (don't defer). [DESIGN]
3. Mark **L3/L4** verified-held this run → toward CLOSED.

## Verdict
Loop is improving: promoted guards held, escape rate down, only new classes leaked — and both are now being promoted. Gate F (UAT) pending the user's live overlay test.
