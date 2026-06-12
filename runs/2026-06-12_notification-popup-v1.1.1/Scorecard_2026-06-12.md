# Scorecard — Glyph · notification-popup refinement v1.1.1 (run 4) — 2026-06-12

Reconstructed retro. A focused design-refinement run on the call-detected notification popup.

## Headline — the design loop's cleanest run yet
The design-iteration gate produced an **ELEVATING** refinement (ux-designer edge verdict), it shipped through
Gate E **first-pass with 0 P0/P1/P2**, and the "loop-engineer the catch" directive was fulfilled *within the
run*: a standing Gate-C check for transient/interrupting panels + a new named signature move.

## Stage log
| Stage | Gate | Result | Notes |
|---|---|---|---|
| 0 Intake | A | ✅ | refine the popup + loop-engineer the catch |
| 2 Design | C | ✅ first-pass | ux-designer refinement vs two-tier master → CallNudgeView v2; **EDGE VERDICT: ELEVATES** |
| 3 Build | D | ✅ first-pass | clean first try; **L3/L4 held (4th run)** |
| 4 QA | E | ✅ first-pass | qa-editor **0 P0/P1/P2**; 2 P3 (1 applied, 1 → UAT) |
| 7 Release | G | ◐ | v1.1.1 committed + **tagged**; main held |

## Defects (both P3, both caught at QA)
| ID | Sev | Defect | Resolution |
|---|---|---|---|
| D1 | P3 | reduce-motion flag read live at dismiss | **Fixed** — captured once at show (symmetric) |
| D2 | P3 | 80px height has thin margin | **Deferred to UAT** spot-check (spec's deliberate tight size) |

## What shipped (the refinement)
- **Information hierarchy:** flat → 3-row (channelMic eyebrow "MIC ACTIVITY" + mic.fill → factual body → actions). Eye order 1→2→3.
- **The monitor feel:** new **"countdown hairline"** — a 2px channelMic bar depleting over the 8s auto-dismiss (reduce-motion gated). The popup now reads as a live, time-bounded monitor, not a frozen alert.
- **Detection legibility:** the trigger source (mic) is named + color-coded via the channel system.
- All in-system, no AA miss (eyebrow 5.72:1, bar 5.23:1, measured).

## The loop learned (self-engineered the catch)
- **Gate-C checklist item 10** (transient/interrupting panels): legible trigger source + visible time-bounded affordance + clear hierarchy → catches this popup-design class on EVERY future notification/nudge/toast.
- **New signature move** "countdown hairline" added to `design-language.md §2` (+ §5 decision) — the design master compounds.

## Metrics (vs prior runs)
- **Escape-to-user: 0.0** (2nd consecutive). Trend: 0.25 → 0.20 → 0.0 → 0.0.
- **Hard-gate first-pass: 1.0** (2nd consecutive). Trend: 0.33 → 0.0 → 1.0 → 1.0.
- **Promoted-guard recurrences: 0** — L3/L4/L5 held a 4th run.

## Verdict
The design half of the loop is now demonstrably stable-and-improving: two consecutive runs at 0 escape /
1.0 first-pass, every refinement elevating, and each run hardening the Gate-C design rubric. UAT (Gate F)
pending the user's eyes on the popup (and the one P3 height spot-check).
