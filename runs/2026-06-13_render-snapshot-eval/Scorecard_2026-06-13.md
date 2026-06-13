# Scorecard — Glyph · render-snapshot-eval (run 6) — 2026-06-13

A test-infra run that closes the **F4 render blind-spot** the loop-audit surfaced: builds an automated
render gate for the floating overlay so render-only defects (wrap/clip/truncation) can't escape to the user
a third time.

## What was built
- `GlyphTests` target + `GlyphTests/OverlaySnapshotTests.swift` — 6 tests: **containment** (natural size of
  the expanded row + nudge vs declared `OverlaySize`, via `NSHostingView.fittingSize` on the real components),
  **smoke** (`ImageRenderer` the real views → non-blank), **regression proof** (paused row >248pt, ≤336pt).
- Wired into `_build_check.sh` as **Gate-E** (isolated `.build_dd`, hardened-runtime off for the test host
  only — the dev `build/` app stays hardened, TCC untouched).

## Defects — all engine/test-host constraints, born+caught at build, 0 escaped
6 setup failures, each fixed and the reasoning baked into `project.yml`/`_build_check.sh` comments:
arm64-only (MLX) · empty test module name · ENABLE_TESTABILITY · don't re-link SPM packages (host-only deps) ·
TEST_HOST/BUNDLE_LOADER · hardened-runtime library validation (D6, P1 — the subtle one: a hardened host
rejects a team-less self-signed `.xctest`). **Engine constraint vs authoring:** all 6 are engine/tooling
constraints (xcodegen/Xcode test-host sharp edges), not product-code authoring defects.

## Guard proven to fire (empirical)
Mutated `OverlaySize.expanded` → 248: 3 containment tests **failed** ("Paused row needs 303.0pt but the
expanded overlay is only 248.0pt"). Reverted → 336: **6/6 pass**. Source reverted, git-clean.

## Loop movement
- **Escape-to-user: 0** (recovered from the run5 v1.1.2 render spike) — and the render class now has a real gate.
- **F3 instrumentation gap 1 → 0:** `render-containment` is now an enforced, machine-visible guard (streak 1).
- `loop_audit.py` refined this run: `engine_constraint: true` defects are excluded from the instrumentation-gap
  list (one-time structural fixes baked into config aren't guards-that-hold-across-runs). Advisory metric only;
  does not touch the ship rule.

## Open (human-gated)
- **F1 trend classifier** still reads the spike-and-recover escape series `[…,1.0,0]` as "rising" → LOOP-P0.
  Proposed (not auto-applied): an outlier-tolerant / latest-vs-baseline trend signal. The loop never tunes its
  own ship rule without confirm.
- **Mirror-probe drift:** containment uses probes mirroring `expandedBar`/the nudge (views apply their fixed
  `.frame` internally). Robust follow-up = extract a shared unframed content view both app and test measure.
