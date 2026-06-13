# LOOP Audit Report

Evals for the workflow, not the app.

## Verdict

**LOOP-P0: F1 escape rate trend is rising**

### Ship-Rule Checklist
- ✗ F1 trend ≤ horizontal
- ✓ F3 recurrence_after_promotion == 0
- ✓ F3 no silent guard drops

## F1: Containment

| Run | Escape Rate | Trend Flag |
|-----|-------------|-----------|
| 2026-06-11_awareness-calldetect | 25.00% | 📈 |
| 2026-06-11_floating-overlay | 20.00% | 📈 |
| 2026-06-12_design-patch-v1.1.0 | 0.00% | 📈 |
| 2026-06-12_notification-popup-v1.1.1 | 0.00% | 📈 |
| 2026-06-12_overlay-text-containment-v1.1.2 | 100.00% | 📈 |

**Trend:** rising | **Mean escape distance:** 1 | **Max:** 4

## F2: Gate Efficacy

| Gate | Catch Count | First-Pass Rate | Toothless? |
|------|-------------|-----------------|-----------|
| A | 0 | 100.0% | ⚠ YES |
| B | 0 | 100.0% | ⚠ YES |
| C | 6 | 75.0% | No |
| D | 1 | 50.0% | No |
| E | 8 | 50.0% | No |
| ESCAPED | 2 | − | No |
| F | 1 | 100.0% | No |
| G | 0 | 100.0% | ⚠ YES |

## F3: Guard Durability

| Guard | Held Streak |
|-------|-------------|
| L3 | 4 |
| L4 | 4 |
| L5 | 4 |
| L8 | 3 |
| design:button-fill-contrast | 3 |
| design:indicator-as-label | 2 |

## F4: Blind-Spot Candidates (Human Confirm)

| Run | Defect | Severity | Title | Layer | Gate | Recurrence? |
|-----|--------|----------|-------|-------|------|-------------|
| 2026-06-11_awareness-calldetect | D4 | P1 | Signing dual-cert DR flip → TCC permissi… | BUILD | ESCAPED | ⚠ |
| 2026-06-11_floating-overlay | D5 | P2 | White Stop label on #FF4444 = 3.41:1 (fa… | DESIGN | F | − |
| 2026-06-12_overlay-text-containment-v1.1.2 | D1 | P1 | Expanded overlay text wraps — 'System on… | DESIGN | ESCAPED | − |

## F5: Calibration

| Run | FPS Rate | Escaped | Note |
|-----|----------|---------|------|
| 2026-06-12_overlay-text-containment-v1.1.2 | 100.0% | 1 | Internal gates clean but user hit a defect — verify bar or escape belongs to prior run. |

## F6: Cost vs Learning

| Rework Counts | Value |
|---|---|
| Run 0 | 3 |
| Run 1 | 3 |
| Run 2 | 0 |
| Run 3 | 0 |
| Run 4 | 1 |

**Ceremony series:** [0, 3, 5, 6, 6] (distinct promoted guards)
**Bloat flag:** 🚩 YES — growing ceremony, flat/rising escape
**Escape trend:** rising

## Instrumentation Gaps (F3)

Lessons mentioned in defects but never in `promoted_guards_that_held` (invisible to audit):
- render-containment

## Recommendations

- **Gate strength review:** escape rate is rising; audit internal gate criteria.
- **Gate audit:** A, B, G are toothless (100% first-pass, 0 catches); verify scope or merge upstream.
- **Guard visibility:** 1 lesson(s) not instrumented in promoted_guards_that_held; add explicit flag in next run.
- **Blind-spot audit:** 3 candidate(s); verify if internal gates should have caught them.
- **Ceremony review:** guard count growing but escape rate flat/rising; trim or tighten existing guards.
