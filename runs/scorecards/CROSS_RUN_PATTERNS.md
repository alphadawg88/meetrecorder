# Glyph — Cross-Run Patterns

Cross-run defect clusters + trends. Refreshed by `/retro` (Stage 9). Trend tags: improving / regressing /
stable / new. Shared LOOP-layer patterns live in `~/.claude/knowledge/harness-lessons.md` (H1–H6).

## Clusters (ranked by escape severity)

| Cluster | Runs seen | Recur | Worst escape | Trend | Note |
|---|---|---|---|---|---|
| **Build-tooling signing DR flip** (L4) | memory 2026-06-10, this run | 2 | to user (twice) | **regressing** | "Fixed" 06-10 via project.yml, recurred 06-11 via `_build_check.sh` re-sign. No automated guard → keeps escaping. **Top promotion.** |
| **New file not registered before build** (L3) | this run | 1 | caught at build | new | Deterministic; cheap to automate in the build script. |
| **Ambient affordance → destructive action** (L5) | this run | 1 | caught at QA | new | Design/intent class; promote to the design checklist so Gate C catches it. |
| **Lifecycle teardown omitted** (D2) | this run | 1 | caught at QA | new | Minor; watch — promote only if it recurs. |

## Run index
| Run | Date | Defects | Escaped-to-user | Hard-gate first-pass |
|---|---|---|---|---|
| awareness + call-detect | 2026-06-11 | 4 | 1 (D4/L4) | 0.33 |

## Read
- One regressing cluster (L4) — and it's the only one reaching the user. Everything else is caught at its gate.
- The QA gate is healthy (P1/P2 caught pre-release). The weak layer is **build-tooling** (no Gate-D automation yet).
- Baseline established this run; escape-rate / first-pass trends become meaningful from run 2.
