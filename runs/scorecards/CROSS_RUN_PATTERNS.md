# Glyph — Cross-Run Patterns

Cross-run defect clusters + trends. Refreshed by `/retro` (Stage 9). Trend tags: improving / regressing /
stable / new / held. Shared LOOP patterns: `~/.claude/knowledge/harness-lessons.md` (H1–H7).

## Clusters (ranked)

| Cluster | Runs seen | Recur | Worst escape | Trend | Note |
|---|---|---|---|---|---|
| **Indicator/accent color used as a LABEL** (design) | run2 (chip), run3 (ModelCard tag) | 2 | caught at design gate | **regressing → promoting** | Both P1, same 3.11:1 class. Canon §3 has the law; Gate-C checklist lacks an explicit check → promote this run. |
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

## Read (trend)
- **Escape-to-user 0.25 → 0.20 → 0.0** — the trend is real and monotonic. Run 3's NEW design-iteration gate
  caught every design defect pre-ship.
- **Hard-gate first-pass 0.33 → 0.0 → 1.0** — clean build + clean QA this run; the maturing guards front-load
  defects to the design gate.
- **L3/L4/L5 held a 3rd run** → L3/L4 are now CLOSED (provenance retained).
- **One design class recurred** (indicator-as-label, both P1) — the only regressing cluster, now being codified
  into the Gate-C checklist. If it recurs after that, escalate to an automated lint.
