# LOOP Audit Report

Evals for the workflow, not the app.

## Verdict

**PASS**

### Ship-Rule Checklist
- ✓ F1 trend ≤ horizontal
- ✓ F3 recurrence_after_promotion == 0
- ✓ F3 no silent guard drops

## F1: Containment

| Run | Escape Rate | Trend Flag |
|-----|-------------|-----------|
| 2026-06-11_awareness-calldetect | 25.00% | 📉 |
| 2026-06-11_floating-overlay | 20.00% | 📉 |
| 2026-06-12_design-patch-v1.1.0 | 0.00% | 📉 |
| 2026-06-12_notification-popup-v1.1.1 | 0.00% | 📉 |
| 2026-06-12_overlay-text-containment-v1.1.2 | 100.00% | 📉 |
| 2026-06-13_render-snapshot-eval | 0.00% | 📉 |

**Trend:** falling | **Mean escape distance:** 0.79 | **Max:** 4

## F2: Gate Efficacy

| Gate | Catch Count | First-Pass Rate | Toothless? |
|------|-------------|-----------------|-----------|
| A | 0 | 100.0% | ⚠ YES |
| B | 0 | 100.0% | ⚠ YES |
| C | 6 | 75.0% | No |
| D | 6 | 40.0% | No |
| E | 9 | 60.0% | No |
| ESCAPED | 2 | − | No |
| F | 1 | 100.0% | No |
| G | 0 | 100.0% | ⚠ YES |

## F3: Guard Durability

| Guard | Held Streak |
|-------|-------------|
| L3 | 5 |
| L4 | 5 |
| L5 | 5 |
| L8 | 4 |
| design:button-fill-contrast | 4 |
| design:indicator-as-label | 3 |
| render-containment | 1 |

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
| Run 5 | 6 |

**Ceremony series:** [0, 3, 5, 6, 6, 7] (distinct promoted guards)
**Bloat flag:** No
**Escape trend:** falling

## Recommendations

- **Gate audit:** A, B, G are toothless (100% first-pass, 0 catches); verify scope or merge upstream.
- **Blind-spot audit:** 3 candidate(s); verify if internal gates should have caught them.
