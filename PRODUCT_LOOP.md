# Glyph (meetrecorder) — Product Loop state

Resume anchor + gate ledger + decision log. Governed by `~/.claude/knowledge/product-loop-framework.md`.

## Current position
- **Active stage:** 9 Retro (awareness + call-detect run) → then 7 Release (merge `fix/qa-bug-sweep-2026-06-09` → `main`)
- **Open gate:** G — branch pushed as backup; full merge to `main` pending (UAT passed)
- **Stage mask for the current run:** full (0–9)
- **Current run:** `runs/2026-06-11_awareness-calldetect/`

## Gate ledger (this run: awareness + call-detect)
| Gate | Owner | Status | Date | Notes / evidence |
|------|-------|--------|------|------------------|
| A · Scope | main loop | ✅ | 2026-06-10 | 2 features; call-detect ON by default |
| B · Architecture | deep-thinker (inline) | ✅ | 2026-06-10 | CoreAudio DeviceIsRunningSomewhere + debounce + isBusy guard |
| C · Design review | ux-designer | ✅ | 2026-06-10 | v2.0 dark tokens; chip/cue/menu-bar/notification brief |
| D · Build green | main loop | ◐→✅ | 2026-06-10 | failed first (xcodegen), then clean; checkpoint commits |
| E · QA | qa-editor | ◐→✅ | 2026-06-10 | P1+P2 found & fixed (commit d433171); no open P0/P1 |
| F · Acceptance (UAT) | user | ✅ | 2026-06-11 | live call; `glyph.log` fire-once, no self-prompt, 1h51m |
| G · Deploy ready | main loop | ◐ | 2026-06-11 | branch pushed; main merge pending (HUMAN-CONFIRM) |

## Decision log
- 2026-06-10 — Call-detect ON by default (+ Settings off-switch) — discoverability over caution — commit 16a1ae6
- 2026-06-10 — v2.0 dark-first design system + DS compat wrapper — keep all existing views compiling — 218914f
- 2026-06-11 — One signing identity (`Glyph Local Signing`) end-to-end — kill the dual-cert DR flip — `_build_check.sh` (local)

## Carryover / known issues
- Gate G open: merge `fix/qa-bug-sweep-2026-06-09` → `main` after this retro.
- P3 cosmetics deferred: untranslated 兩岸 in EN summary; stray `  - ` in Detailed Notes.
- Open framework build items (global): Gate-D/G hooks via `/update-config`; product-loop scorecard contracts.

## Pre-flight (read before each run)
Read top OPEN lessons in `~/.claude/knowledge/product-loop-lessons.md` (BUILD/PROCESS/DESIGN) +
`~/.claude/knowledge/harness-lessons.md` (shared LOOP). Guard against them. After the run, `/retro`.
