# 0006 — Calibrate climb rate (`vmh`) from linked runs: gain-weighted, transparent

**Date:** 2026-06-15
**Status:** accepted

## Context

The predictor's climb time is `gain / (vmh × intensity)` (ADR-0003), where `vmh`
(`AthleteProfile.verticalRateVmh`) is the athlete's vertical climb rate. Until
now it's hand-set or a population-tier default. The pace-prediction roadmap (§7)
lists data-driven fits to replace those defaults, ordered by value-per-effort,
with **vertical rate first** — and §9's lone open calibration question
(transparency) the roadmap answers itself: show the user what changed and let
them opt in. This is TASK-043, the first split of the calibration epic
(TASK-022).

Trail already holds the data needed: every race linked to an actual run stores
per-km actual times (`ActualSplits.splits`), and the course's per-km ascent
comes from `Planning.computeKms` (cached in `model.kmsCache`). No new Strava
fetching is required.

## Decision

Fit `vmh` as the **realized climb rate**: over every "climb km" (course gain
≥ 30 m) that has a positive recorded actual time, sum the ascent and the time,
then `vmh = Σ gain / (Σ seconds / 3600)`. This is gain-weighted by construction
— a long sustained climb counts more than a brief rise — and needs no
regression. The fit is a pure function (`Calibration.fitVmh`) returning the
value plus the contributing climb-km / run counts; `Nothing` when no km clears
the threshold with a time.

It's surfaced **transparently and opt-in** on the profile page: the fitted value,
how many climbs/runs it came from, the current value, and the names of the
contributing runs, behind an explicit "Apply to vertical rate" button. Nothing
changes the profile until the user clicks.

## Alternatives considered

- **Per-duration-bin vmh** (roadmap's "vmh per activity duration bin"). More
  faithful to fade over long efforts, but that *is* the separate climb-fatigue
  fit (`vmh(t)`); folding it in here would conflate two fits. Deferred to a
  later sub-task.
- **Climb detection from raw altitude/time streams.** More precise climb
  segmentation, but trail persists only the per-km `ActualSplits`, not the raw
  streams — it would require re-fetching and storing streams. The per-km
  granularity is enough for a baseline rate. Deferred.
- **Apply automatically / silently.** Rejected on the roadmap's transparency
  call — calibration changes predictions, so the user should see and approve it.
- **Persist provenance (`ProfileSource = Fitted from N`).** The profile has no
  source field today (the confidence indicator derives from race links, not the
  profile). Showing provenance at apply-time is enough for v1; a persisted
  source can come with the later fits if useful.

## Consequences

- The single most impactful calibration: the core climb-rate input becomes
  data-driven instead of a guess, with honest provenance.
- Accuracy tracks data volume; the panel shows the counts so the user can judge.
  The roadmap's confidence rubric (≈5 quality activities for ±15 %) isn't
  enforced as a gate yet — surfaced, not gated.
- Establishes the pattern the sibling fits reuse: a pure `Calibration.*` fit +
  a harness (`smoke:calibration`) + a transparent apply panel. TASK-044
  (flat-trail-pace) is the next instance.
- The 30 m climb-km threshold is a tuning constant (`Calibration.climbGainThreshold`);
  revisit if real data shows it admits too much flat running or too few climbs.
