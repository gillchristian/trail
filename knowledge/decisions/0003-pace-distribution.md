# 0003 — Grade-adjusted pace distribution (Tobler-based)

**Date:** 2026-05-15
**Status:** accepted

## Context

The user wants both: (a) a top-down target (total time + per-aid-station rest time) auto-distributed across kilometers using a grade-adjusted pace model, **and** (b) the ability to override any individual kilometer's target time. The constraint: **the per-km times must sum to the target total** (less aid-station rest). Worked example from the user:

> 3 km race, km₁ flat, km₂ +150 m climb, km₃ -150 m descent, target 15:00. A 5 min/km average doesn't survive the terrain: the descent might be 3:30, flat 4:30, climb 7:00. They must add up.

## Decision

### Per-km slope-factor (Tobler-normalised)

For each km segment compute slope `s` = Δele / Δdist. Define a pace multiplier f(s) ≥ 0 by normalising Tobler's hiking function so f(0) = 1:

```
f(s) = exp(3.5 · |s + 0.05|) / exp(3.5 · 0.05)
     = exp(3.5 · |s + 0.05| - 0.175)
```

Properties:
- `f(0) = 1.000` (flat = baseline pace)
- `f(-0.05) ≈ 0.839` (fastest at 5 % downhill — Tobler's optimum)
- `f(+0.10) ≈ 1.687` (10 % climb is 69 % slower)
- `f(-0.10) ≈ 1.191` (10 % descent past optimum, modestly slower than flat)
- `f(±0.20) ≈ 2.397` (20 % grade either way ~ 2.4× flat)

This is *Tobler's hiking function* repurposed: Coros's own algorithm is undocumented, and Tobler is the most widely-cited physiologically-motivated curve. The user already named "Naismith- or Tobler-style" themselves.

### Per-km lock state

Each km in the plan has one of:

```elm
type KmTime
    = Auto                    -- distributed from target
    | Manual Seconds          -- user-entered, sticks
```

Each aid station has a `restTime : Seconds` (default 2:00, user-editable).

### Distribution algorithm

```
total_target          = user input (Seconds)
total_aid             = sum of aid-station restTime
total_locked          = sum of Manual km times
budget_for_auto       = total_target - total_aid - total_locked
sum_factors_for_auto  = sum over Auto kms of (distance_i * f(slope_i))

for each Auto km i:
    t_i = budget_for_auto * (distance_i * f(slope_i)) / sum_factors_for_auto
```

If `budget_for_auto ≤ 0` (locked + aid rest already exceeds target), Auto kms get `0` and the UI shows a clear overshoot indicator. We do **not** silently reduce locked values or rest times.

### User interactions

| User action                           | What happens                                              |
| ------------------------------------- | --------------------------------------------------------- |
| Enters / changes total target time    | Re-distribute across all Auto kms.                        |
| Edits one km's pace/time              | That km becomes `Manual`. Re-distribute remaining Auto.   |
| Resets a km to Auto                   | Re-distribute including it.                               |
| Changes an aid station's rest time    | Re-distribute Auto kms.                                   |
| Edits *every* km to Manual            | Target time becomes derived (= sum). No re-distribution.  |
| Hits "Reset plan"                     | All kms → Auto; target preserved.                         |

The total-time row always shows **current sum vs target**, with the diff highlighted when non-zero. The user is never surprised by hidden re-balancing.

### Section ("tramo") aggregation

A "section" is the contiguous span between two consecutive aid stations (or start↔first AS, last AS↔finish). The section view in the planning table sums:
- distance from contained kms
- gain / loss from contained kms
- target time from contained kms
- the bounding aid station's rest time appears as a separate row, not folded into a section

## Alternatives considered

- **Naismith's rule** (5 km/h flat + 10 min per 100 m climb). Simpler, but flat & descent are not differentiated. Rejected — the user's example explicitly wants descent ≠ flat.
- **Strava GAP curve** (piecewise, descent-fastest around -15 %). Closer to a real trail runner's intuition (the user's own 3:30 down vs 4:30 flat matches this), but the exact curve is undocumented and varies by version. We pick Tobler for transparency; if the user finds the descents *systematically* slow in the distribution, we add a "descent aggressiveness" multiplier in a follow-up ADR.
- **Linear in grade** (`f(s) = 1 + a·s+ + b·s-`). Easy to tune but loses Tobler's smoothness at the optimum. Skipped for now.
- **Locking semantics: redistribute everything when target changes vs. preserve locked.** Preserving locked is intuitively right ("I committed to this 7:00 climb, don't touch it") and matches the user's wording. Chosen.

## Consequences

- The math is purely local — no solver, no iteration. Reorienting on user edits is O(n).
- The slope `s` per km uses `(ele_end - ele_start) / 1000 m`. This *underweights* rolling terrain inside a km (e.g. up 50m then back down 50m looks flat). For night 1 we accept this; a follow-up can switch to "GAP using elevation gain + loss separately" if real planning feels off.
- The "current sum ≠ target" diff in the UI is intentional. We never silently re-balance the user's manual entries.
