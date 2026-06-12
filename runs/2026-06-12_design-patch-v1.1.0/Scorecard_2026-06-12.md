# Scorecard — Glyph · v1.1.0 design-patch (run 3) — 2026-06-12

Reconstructed retro. First run to exercise the new **design-iteration Gate C** end-to-end.

## Headline — the design flywheel worked on its first real run
The design-iteration gate built this session did exactly its job: a ux-designer Gate-C audit against the
**two-tier master** (universal canon + Glyph design-language) surfaced a **prioritized patch set + a crafted
elevation** (the selected-card accent stroke), and **0 defects escaped to the user** (qa-editor Gate E: 0
P0/P1). It also **caught a recurring design class** before it shipped.

## Stage log
| Stage | Gate | Result | Notes |
|---|---|---|---|
| 0 Intake | A | ✅ first-pass | scope = design-patch + version bump |
| 2 Design | C | ✅ | audit vs two-tier master → patch set + **edge verdict POSITIVE** ("keeps the edge, craft high") |
| 3 Build | D | ✅ first-pass | clean first try; **L3 auto-regen + L4 SIGN-CHECK held (3rd run)** |
| 4 QA | E | ✅ first-pass | 0 P0/P1; one intentional P2 (tag 5→4px = on-grid) |
| 7 Release | G | ◐ | v1.1.0 committed + **tagged v1.1.0**; main held |

## Defects (all caught at the design gate — escape 0)
| ID | Sev | Defect | Caught | Lesson |
|---|---|---|---|---|
| P1-A | P1 | ModelCard tag = accent on accent tint (3.11:1) | design | **indicator-as-label (RECURRENCE 2)** |
| P1-B | P1 | HelpView sheet missing dark+tint | design | — |
| P2-A | P2 | progress tint hardcoded systemBlue | design | — |
| P2-B | P2 | two off-grid 10px paddings | design | — |
| P2-C | P2 | overlay collapse/expand desync | design | — |
| P2-E | P2 | three raw size-10 fonts | design | — |

## Constraint vs authoring
- These were **latent** issues in the existing app (HelpView, ModelCard, off-token tints) — the new design
  gate surfaced them in one pass. That's the gate paying for itself: it front-loads design debt to Gate C.
- **The recurrence is the signal:** "indicator/accent color used as a label" hit the CaptureModeChip (run-2)
  and the ModelCard tag (run-3) — same class, both P1. The canon §3 has the *law*, but the Gate-C *checklist*
  has no explicit enforced check for it (only "filled-button" fills). → promote.

## Metrics (vs prior runs)
- **Escape-to-user: 0.0** — down 0.25 → 0.20 → **0.0** (best). The design gate caught everything pre-ship.
- **Hard-gate first-pass: 1.0** — clean build + clean QA on the first try.
- **Known promoted-class recurrences (build): 0** — L3/L4/L5 held a 3rd run.
- **Known design-class recurrence: 1** (indicator-as-label) — now being promoted to enforcement.

## Recommendations → promotion target
1. **Indicator-as-label check** (recurred 2×, both P1) → explicit line in `ux-designer-design-qa-checklist.md`
   (Gate C). The strongest promotion this run.
2. Append 3 design decisions to Glyph `design-language.md §5` (ModelCard tag rule; sub-44px backlog closed;
   selected-card accent-stroke signature) — the design master grows (capture).

## Verdict
The self-learning design loop is real and improving: gate caught all, escape rate hit 0, a recurring class
is being codified. Ship v1.1.0. UAT (Gate F) pending the user's eyes on the patched surfaces.
