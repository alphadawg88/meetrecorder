# Glyph — Cross-Run Patterns

Cross-run defect clusters + trends. Refreshed by `/retro` (Stage 9). Trend tags: improving / regressing /
stable / new / held. Shared LOOP-layer patterns live in `~/.claude/knowledge/harness-lessons.md` (H1–H7).

## Clusters (ranked)

| Cluster | Runs seen | Recur | Worst escape | Trend | Note |
|---|---|---|---|---|---|
| **Build-tooling signing DR flip** (L4) | run1, **not run2** | 2 | to user | **held ✓** | Promoted run1 (SIGN-CHECK). Fired & passed in run2 — did NOT recur. → toward CLOSED. |
| **New file not registered before build** (L3) | run1, **not run2** | 1 | caught at build | **held ✓** | Promoted run1 (auto-xcodegen). run2 added 2 files; no scope error. → toward CLOSED. |
| **Ambient affordance → destructive action** (L5) | run1, **not run2** | 1 | caught at QA | **held ✓** | Promoted to design checklist run1. Overlay buttons explicit; pill only expands. Held. |
| **Per-session state not reset → poisons next session** (L8) | run2 | 1 | caught at QA | **new** | D1 (silent blank recording) + D2 (stale recorder). Lifecycle-hygiene class. |
| **Indicator color reused as button fill → fails AA** (design) | run2 | 1 | to user | **new** | D5. Detected twice but deferred not blocked. → design checklist + block-don't-defer. |

## Run index
| Run | Date | Defects | Escaped-to-user | Hard-gate first-pass | Promoted-guard recurrences |
|---|---|---|---|---|---|
| awareness + call-detect | 2026-06-11 | 4 | 1 (L4) | 0.33 | n/a (baseline) |
| floating-overlay | 2026-06-11 | 5 | 1 (D5 contrast) | 0.0 | **0** ✓ |

## Read (trend)
- **The flywheel is working:** all 3 guards promoted in run 1 (L3/L4/L5) **held in run 2 — zero recurrence.** The regressing L4 cluster from run 1 is now arrested.
- **Escape-to-user 0.25 → 0.20** (improving). Both run-2 escapes are NEW classes, now promoted.
- **First-pass stays 0** — features are complex and the gates are catching real defects pre-release (the system is doing its job; first-pass will rise as the new guards mature).
- Two new clusters to watch: per-session-state hygiene (L8) and button-fill contrast. If either recurs in run 3, escalate enforcement.
