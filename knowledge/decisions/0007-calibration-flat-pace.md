# 0007 — Calibrate flat-trail pace from runnable kms

**Date:** 2026-06-15
**Status:** accepted

## Context

The sibling of ADR-0006's climb-rate fit. The predictor's runnable-km time is
`flatTrailPaceSecPerKm × Tobler(slope) × techMult / intensity`, where
`flatTrailPaceSecPerKm` is the athlete's pace on flat moderate trail — until now
hand-set or a population default. TASK-044 fits it from the same linked-run data
(per-km course slope + distance + actual times), following ADR-0006's
realized-rate method.

## Decision

A km is **runnable** when the predictor itself treats it as such — `abs slope <
0.04` (`Predictor.elm`) — and has a positive distance and recorded time. Over
those kms, `fitFlatPace = Σ distance / Σ time`, inverted to seconds per km
(distance-weighted realized pace). Surfaced as a second row in the same
transparent, opt-in calibrate panel on `#/profile` (`CalibrateFlatPace` sets
`flatTrailPaceSecPerKm`). Defining "runnable" by the predictor's own slope band
keeps the fit and the model consistent.

## Alternatives considered

- **Tobler-normalize each km** (`Σ time / Σ (dist × slopeFactor slope)`) to
  strip the residual grade effect of gentle rollers inside the band. Marginally
  more accurate, but the realized raw pace over `|slope| < 0.04` kms is already
  close (the band's Tobler factor is ~0.87–1.15 and largely cancels across a
  distance-weighted mix of gentle up/down), and it matches ADR-0006's "raw
  realized rate, no model back-out" method. Noted as the refinement if real data
  shows bias.
- **Back out `intensity`/`techMult`** from the observed pace. Those are the
  athlete's own and unknown per past run; baking them into the fitted base is
  acceptable for a baseline (the field already means "the athlete's flat pace").
- **A different slope band than the predictor's.** Rejected — matching
  `Predictor.elm`'s ±0.04 keeps fit and use coherent.

## Consequences

- Completes the two core predictor rates (climb + flat) as data-driven fits;
  same pure-fit + harness (`smoke:calibration`) + transparent-apply pattern as
  ADR-0006.
- A net-flat-but-rolling km (gentle net slope, high within-km gain) is counted
  as runnable here *and* as a climb km by the vmh fit — intentional: its net
  pace informs flat pace, its ascent informs climb rate. Harmless overlap.
- `runnableSlopeThreshold` (0.04) is pinned to the predictor's constant; if that
  band ever changes, change both together.
