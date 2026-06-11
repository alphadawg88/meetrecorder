# Scorecard — Glyph · awareness + call-detect run — 2026-06-11

Reconstructed retro (no live `metrics.json` existed). Governed by `~/.claude/knowledge/product-loop-framework.md`.

## Stage log
| Stage | Gate | Result | Notes |
|---|---|---|---|
| 0 Intake | A | ✅ first-pass | 2 features scoped via 2 questions; call-detect ON by default chosen |
| 1 Architecture | B | ✅ first-pass | CoreAudio `kAudioDevicePropertyDeviceIsRunningSomewhere` + 10s debounce + `isBusy` guard (inline ADR) |
| 2 Design | C | ✅ first-pass | ux-designer brief; v2.0 dark tokens held; chip / long-session cue / menu-bar timer / notification copy |
| 3 Build | D | ◐ 2nd-pass | CallDetector.swift + edits; **failed first** (xcodegen not regenerated → "cannot find CallDetector"); green after regen |
| 4 QA | E | ◐ 2nd-pass | qa-editor found **P1 + P2**; gate **held**; fixed → re-passed |
| 6 UAT | F | ✅ first-pass | live call 11:00; `glyph.log`: fire-once, no self-prompt, debounce held, clean 1h51m capture |
| 7 Release | G | ◐ partial | branch pushed to remote (backup); `main` held pending merge |
| 8 Operate | — | ⚠ incident | **signing permission-loop** → PATCH sub-loop → dual-cert root cause → fixed `_build_check.sh` |

## Defects (ranked, born → caught)
| ID | Sev | Defect | Born → Caught | Escape | Root cause | Lesson |
|---|---|---|---|---|---|---|
| D4 | P1 | Signing dual-cert DR flip → TCC re-prompt loop | build-tooling → **operate (user)** | **4 (worst)** | `_build_check.sh` re-signed with old cert after xcodebuild | **L4 (recurrence)** |
| D1 | P1 | Notification body-tap silently records | build → qa | 1 | delegate keyed on `category`, not the explicit action | L5 |
| D2 | P2 | CoreAudio listeners not torn down on quit | build → qa | 1 | no `applicationWillTerminate` | — |
| D3 | P2 | Build "cannot find CallDetector in scope" | build → build | 0 | new file, xcodegen not regenerated | L3 |

## Engine/process constraint vs authoring pattern
- **Process/tooling (not the author):** D3 (build script doesn't regenerate the project) and D4 (build script re-signs with a conflicting cert) are both **`_build_check.sh` defects** — the tooling created the failure. These are the automatable wins.
- **Authoring pattern (us):** D1 (routing intent wrong) and D2 (lifecycle teardown omitted) — caught correctly at the QA gate.

## Metrics
- **Escape-to-user rate: 0.25** (1 of 4 — D4 reached the user; the other 3 were caught at their gate).
- **Hard-gate (D/E/F) first-pass: 0.33** (only UAT first-passed; build + QA each took a second pass).
- **Rework: 3** · **Known-class recurrences: 1** (L4 perm-loop, 2nd time).
- **The signal:** the *only* escape to the user is a **recurrence of a class with no automated guard**. The QA gate worked (caught both P1/P2 before release); the gap is the **build-tooling layer**, which has no Gate-D automated check.

## Recommendations (ranked → promotion target)
1. **Automate the signing-Authority assertion** (kills D4's class) → add to Glyph `_build_check.sh` [Gate-D check]. **Highest ROI — it's the only thing that escaped to the user, and twice.**
2. **Regenerate the project before building** (kills D3's class) → `xcodegen generate` step in `_build_check.sh` [Gate-D pre-check].
3. **Codify the destructive-action intent rule** (kills D1's class) → line in `ux-designer-design-qa-checklist.md` [Gate-C].
4. **Capture the new operating lesson** (relaunch-mid-use) → `harness-lessons.md` H7.

## Verdict
Feature shipped and UAT-validated. The loop's QA gate did its job (P1/P2 caught pre-release). The escape that reached the user (signing loop) is a **build-tooling** gap with a deterministic, automatable fix — promote it so it can't escape a third time.
