# Glyph — Cross-Run Patterns

Cross-run defect clusters + trends. Refreshed by `/retro` (Stage 9). Trend tags: improving / regressing /
stable / new / held. Shared LOOP patterns: `~/.claude/knowledge/harness-lessons.md` (H1–H7).

## Clusters (ranked)

| Cluster | Runs seen | Recur | Worst escape | Trend | Note |
|---|---|---|---|---|---|
| **Render-only defect escaped (overlay never screenshot in QA)** | run4 (80px height P3), run5 (text wrap) | 2 | **to user** | **PROMOTED ✓ (render gate built run6)** | Source/contrast QA can't see layout/wrap/clip; the floating NSPanel is never rendered in QA → the user was the only render check (harness H2). Gate-C "text containment (render-verify)" added run5; **run6 built the enforced fix** — `GlyphTests/OverlaySnapshotTests.swift` (containment + smoke + regression), wired into `_build_check.sh` Gate-E. **Guard proven to fire** (overlay→248 ⇒ 3 tests fail "needs 303pt"). Awaiting first live catch. |
| **Indicator/accent color used as a LABEL** (design) | run2 (chip), run3 (ModelCard tag) | 2 | caught at design gate | **promoted ✓** | Both P1, 3.11:1. Gate-C checklist check added run3; held since. |
| **Build-tooling signing DR flip** (L4) | run1; held run2, run3 | 2 | — | **held ✓✓** | Promoted run1; held twice. CLOSED. |
| **New file not registered** (L3) | run1; held run2, run3 | 1 | — | **held ✓✓** | Promoted run1; held twice. CLOSED. |
| **Ambient affordance → destructive** (L5) | run1; held run2, run3 | 1 | — | **held ✓✓** | Overlay + patch buttons all explicit. Held. |
| **Per-session state poisons next session** (L8) | run2 | 1 | caught at QA | promoted | coding-handbook §5; watch for recurrence. |
| **Indicator color as button FILL** (design) | run2 | 1 | to user | promoted | dangerButton; checklist line added run2. Held run3. |

## Run index
| Run | Date | Kind | Defects | Escaped-to-user | Hard-gate first-pass | Promoted-guard recurrences |
|---|---|---|---|---|---|---|
| awareness + call-detect | 2026-06-11 | feature | 4 | 1 | 0.33 | n/a |
| floating-overlay | 2026-06-11 | feature | 5 | 1 | 0.0 | 0 |
| design-patch v1.1.0 | 2026-06-12 | design-patch | 6 | **0** | **1.0** | 0 |
| notification-popup v1.1.1 | 2026-06-12 | design-refinement | 2 (both P3) | **0** | **1.0** | 0 |
| overlay text-containment v1.1.2 | 2026-06-12 | patch | 1 | **1** (render escape) | 1.0 | 0 |
| render-snapshot-eval | 2026-06-13 | test-infra | 6 (all engine-constraint, build-caught) | **0** | 0.67 | 0 |

## Read (trend)
- **Escape-to-user 0.25 → 0.20 → 0.0 → 0.0 → 1.0 → 0.0** — the run5 spike was the v1.1.2 render escape (born run2, surfaced run5); run6 recovered to 0 AND added the enforced render gate. **Verdict: PASS.** The earlier "rising → LOOP-P0" was a trend-classifier artifact (least-squares fit dominated by the lone spike); **RESOLVED 2026-06-13 (human-gated):** `loop_audit.py` now uses the **Theil-Sen** estimator (median of pairwise slopes, outlier-resistant) → this series reads "falling" while a genuine sustained rise still trips LOOP-P0 (verified `[0,.1,.2,.3,.4]`→rising). Not a bar-loosening: the discriminating power is preserved, only the spike-and-recover is correctly read.
- **Hard-gate first-pass 0.33 → 0.0 → 1.0 → 1.0** — two consecutive clean-build + clean-QA runs; the maturing
  guards front-load defects to the design gate. The design half of the loop is now stable-and-improving.
- **L3/L4/L5 held a 3rd run** → L3/L4 are now CLOSED (provenance retained).
- **One design class recurred** (indicator-as-label, both P1) — the only regressing cluster, now being codified
  into the Gate-C checklist. If it recurs after that, escalate to an automated lint.
