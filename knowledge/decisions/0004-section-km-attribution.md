# 0004 — Section km-attribution: midpoint partition, not pro-rating

**Date:** 2026-06-15
**Status:** accepted

## Context

A "section" is the run between two consecutive aid-station distances (see
ADR-0003 for the per-km distribution this builds on). `Planning.sectionsForRace`
groups the 1 km windows into sections and sums their gain/loss; callers
(`Main.elm`, `Csv.elm`) additionally sum per-km plan **seconds** and actual
seconds over each section's `kmIndices`. Aid stations sit at arbitrary
distances, so a 1 km window frequently *straddles* an aid distance `b` (starts
before it, ends after it). Each straddling km must be attributed to a section —
the question is how.

The original code used an overlap test (`km.distStart < b && km.distEnd > a`),
which placed a straddling km in **both** adjacent sections. That double-counted
its gain/loss (section table + card) and its seconds (section Time, the
cumulative column, the actual-vs-plan Δ, and section-mode CSV). This was the
TASK-039 bug.

## Decision

Attribute each km to **exactly one** section by its **midpoint**: the km joins
the half-open boundary interval `[a, b)` that contains `(distStart + distEnd) / 2`.
This partitions the km set across sections — no km in two sections, none dropped
— so every per-km quantity (gain, loss, plan seconds, actual seconds) sums to
its whole-course total with no double-count. A straddling km's full value is
attributed to whichever side holds its center.

## Alternatives considered

- **Pro-rate the straddling km across the boundary** (split its gain/loss/seconds
  by the fraction on each side). Marginally more accurate, but: per-km *plan
  seconds* are an indivisible unit the distributor assigns to a whole km, so
  splitting them means re-deriving rather than slicing; and pro-rating gain/loss
  honestly needs the km's elevation re-sampled at the split point, not a linear
  share of the km total. High complexity for sub-km accuracy that planning
  doesn't need. Rejected — but the door is open if section accuracy ever matters
  more than it does today.
- **Assign by the km's start (`distStart ∈ [a, b)`)** instead of its midpoint.
  Also a clean partition, but a km that's 90 % past the aid would still count
  against the pre-aid section. Midpoint is the fairer whole-km rule and matches
  the intent the old `sumKmField` comment already described ("center falls
  inside the range").

## Consequences

- Section gain/loss/Time/cum and section-mode CSV are now internally consistent:
  section sums equal the course totals. Guarded by `scripts/smoke-sections.mjs`
  (a straddling-aid scenario fails loudly if the overlap test ever returns).
- Section stats carry a bounded whole-km approximation at each aid (≤ one km's
  gain/loss/seconds attributed to one side rather than split). Acceptable for
  planning; revisit via pro-rating only if a concrete need appears.
- This unblocks the still-parked **section-card Δ-vs-plan** moving-vs-clock fix,
  which needed a correct section partition underneath it before it could be done
  cleanly.
