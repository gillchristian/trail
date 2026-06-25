# 0008 — Section plan time is clock time (moving + midpoint-attributed aid rest)

**Date:** 2026-06-15
**Status:** accepted

## Context

TASK-025 made the **per-km** plan time *clock* time (moving pace × distance **plus**
the aid rest scheduled in that km), so a per-km `Δ vs plan` compares like-for-like
against the actual split (which is elapsed/clock time — it already contains any time
spent stationary at an aid). It explicitly left the **section** level alone: *"Section-table
totals and section-card 'Time' stat untouched (would need pre-existing section-overlap
fix first; logged in parking lot)."*

That overlap fix shipped as TASK-039 / ADR-0004 (each km now belongs to exactly one
section, by midpoint). Until then, the section `Δ vs plan` compared planned **moving**
seconds (`Σ` per-km moving over the section's `kmIndices`) against actual **clock**
seconds (`sectionActualSeconds`, `Σ` real per-km splits) — apples-to-oranges: rest 5 min
at an aid but run exactly on pace and the section still read ~5 min "behind plan." With a
correct partition now underneath, the section can carry clock time the same way a km does.

## Decision

A section's plan **Time = clock = `sectionMoving + sectionAidRest`**; **Pace stays
moving**; **`Δ vs plan = actual − clock`**. New pure helper
`Planning.sectionAidRest aids section` returns the rest of every aid whose **containing km**
(`kmAtDistance a.distance`) is one of the section's `kmIndices`. This is the section-level
lift of TASK-025's per-km clock model, applied to the section table, the section card, and
the section-mode CSV (`section_time`, `cumulative_after_aid`).

The attribution is **by the aid's km, not by `followedByAid`**. `sectionActualSeconds`
sums the actual per-km splits over `kmIndices`, so a stoppage lands in whichever km
physically held the aid — and the midpoint partition puts that km in exactly one section.
Charging the plan's rest to the *same* km/section is the only rule that makes plan-clock
and actual-clock consistent in every case.

## Alternatives considered

- **Use `followedByAid.restSeconds`** (the aid a section ends at). Simpler and obvious, but
  *wrong about half the time*: an aid at distance `b` lives in km `floor(b/1000)`, whose
  midpoint is `…+500`. When `b`'s fractional part is < 500 m (aid in the first half of its
  km), that km — and so the aid's stoppage in the actual — belongs to the section **after**
  `b`, not the one that ends at `b`. `followedByAid` would charge the plan rest to the
  ending section while the actual charges the next one, reintroducing the same
  moving-vs-clock error, just relocated. (Smoke scenario E pins this: aid 3300 → `[300, 0,
  **600**]`, not `[300, 600, 0]`.)
- **Keep section Time = moving, fix only the Δ** (compute clock internally just for the
  comparison). Lowest-risk, but the table puts Time, Actual and Δ in adjacent columns, so a
  moving Time next to a clock Actual reads as "why isn't Δ = Actual − Time?" — and TASK-025
  explicitly deferred making the *Time stat itself* clock. Rejected for coherence + that
  stated intent; the headline number should be the one the Δ is taken against, exactly as
  per-km Target is.
- **Pro-rate a straddling km's rest across the boundary.** Same trade-off ADR-0004 already
  rejected: whole-km attribution is simpler and reversible; sub-km accuracy isn't needed.

## Consequences

- The section `Δ vs plan` is clock-vs-clock: run exactly on planned moving pace and rest
  exactly the planned amount and **every** section's Δ is 0 (it used to show a phantom
  deficit equal to the section's aid rest). Per-km behavior is unchanged.
- Section Time, the running **Cum** column, and the CSV's `section_time` /
  `cumulative_after_aid` are all clock time and internally consistent with the km level and
  with the actual splits. Summed over the course they still equal total moving + total aid
  rest (`= aidRestTotal`), because each aid's km is in exactly one section.
- The section table's aid rows become **non-additive dividers**: the rest is folded into the
  owning section's clock Time, so the divider shows the aid (and its rest) as context only
  and no longer adds to Cum. A short table footer + the section-card caption state that Time
  is clock and Pace is moving (mirrors TASK-025's per-km caption).
- A bounded whole-km approximation remains (ADR-0004): when an aid sits in the first half of
  its km its rest is attributed to the *next* section, which can put it one section away
  from the divider row that names it. Acceptable for planning; the attribution is the one
  that matches the actual. Guarded by `npm run smoke:sections` (scenarios E/F drive the real
  `Planning.sectionAidRest`: per-section values, the first-half/second-half split, the
  no-rest default, and `Σ == total`).
</content>
</invoke>
