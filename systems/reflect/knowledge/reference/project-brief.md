# Project brief — Reflect · STUB

## What it is

**Reflect** is the **Reflect** leg of the product arc **Plan (trail) → Execute (track) → Reflect**:
the post-hoc analysis/learning system that turns executed runs into insight.

**Status: stub — scope not yet defined.** Unlike track (whose MVP is designed), reflect's scope is
genuinely open. This brief records what's *known* + an explicit Unknowns list, and deliberately does
**not** invent a backlog. A scope blocker is logged in `progress/blockers.md`.

## What's known

- It's the third leg of the arc: it consumes execution data (track's `.trace` runs, and/or trail
  plans-vs-actuals) and produces reflection / analysis / learning.
- It inherits the repo-wide delivery ceiling; branch `reflect/`, ids `REFLECT-`.
- Cross-system data would arrive via the shared contracts in `knowledge/reference/specs/`
  (`.trace` once track defines it; `.trail` from trail).

## Unknowns (resolve with the user before any backlog)

- **Scope / purpose:** what does "reflect" actually *do*? Trends over time? Coaching feedback?
  A calibration loop back into trail's predictor? Something else?
- **Inputs:** `.trace` (track — not yet specified) and/or trail's plan-vs-actual? Strava (via gateway)?
- **Surface:** a standalone app? a view inside trail/track? a generated report?
- **Audience:** the runner, a coach, both?
- **Overlap with trail's existing calibration:** trail already calibrates `vmh`/flat-pace from past
  runs (see trail's `Calibration`/`Predictor`). Does reflect subsume/extend that, or is it distinct?

## Out of scope (for the stub)

- No code, no build target. **No invented backlog** — the scope question gates everything.

## Next

Resolve the Unknowns with the user (BLOCKER-001). Until then this stays a stub.
