# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Entry template

```markdown
### TASK-NNN — <title>

**Source:** BACKLOG / parking lot / user request
**Branch:** <kind>/task-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, anything decided while planning.
```

## Active

### TASK-045 — Section-level clock time: make section Time clock (moving + aid rest) so Δ-vs-plan is clock-vs-clock

**Source:** parking lot (unblocked by TASK-039; explicitly deferred by TASK-025) — user request 2026-06-15
**Branch:** fix/task-045-section-clock-time

**Problem.** The section `Δ vs plan` compares actual *clock* time (`sectionActualSeconds`
— real per-km splits, which include the time you stood at an aid) against planned
*moving* time (`sectionSeconds` — sum of per-km moving seconds, no rest). Apples-to-
oranges: rest 5 min at an aid but run exactly on pace and the section still reads ~5 min
"behind plan." This is the section-level version of the bug TASK-025 fixed per km; TASK-025
explicitly left "section-table totals and section-card 'Time' stat" for after the
section-overlap fix (TASK-039, ✓ PR #72, ADR-0004) — which is now in.

**Fix.** Section plan **Time = clock** = `sectionSeconds + sectionAidRest`; **Pace stays
moving**; **Δ vs plan = actual − clock**. The section's aid rest is `Σ aidRestInKm` over the
section's `kmIndices` (rest of aids whose *containing km* — `kmAtDistance` — is in the
section), **not** `followedByAid.restSeconds`: only the former matches how
`sectionActualSeconds` attributes a stoppage (to the km that physically holds the aid, which
the midpoint partition assigns to exactly one section). `followedByAid` would relocate the
same error whenever an aid sits in the first half of its km. Mirrors the km table
(`kmsWithCumulative`: Time = clock, Pace = moving, Cum = running clock).

**Acceptance criteria:**
- [ ] New pure `Planning.sectionAidRest : List AidStation -> Section -> Int` (rest of aids
      whose `kmAtDistance` ∈ `section.kmIndices`), exposed. Verified by extending
      `smoke:sections`: per-section values on a straddling-aid scenario + conservation
      (Σ over sections == total rest). Quote harness output.
- [ ] Section card (`viewSectionDetails`): "Time" stat shows clock; "Δ vs plan" =
      `actual − clock`; Pace stays moving; amber caption when section aid rest > 0
      (mirrors the per-km caption). Verified by code + type-check; browser eyeball recommended.
- [ ] Section table (`sectionsWithCumulative`): "Time" column = clock; "Cum" accumulates
      clock; "Δ vs plan" = `actual − clock`; Pace moving; aid rows become non-additive
      dividers (rest shown as info, not re-added to Cum). Final Cum still == total clock.
- [ ] CSV section-mode (`buildSectionRows`): `section_time` = clock; `cumulative_after_aid`
      = running clock (consistency with the UI + km-mode CSV). Verified by export inspection.
- [ ] Local CI green: gates 1–6 (type-check, build, smoke, smoke:aidcsv, smoke:sections,
      smoke:calibration). Quote outputs.
- [ ] ADR-0008 records the decision (clock = moving + midpoint-attributed rest; why not
      `followedByAid`; show-clock-as-Time vs keep-moving). Parking lot + BACKLOG updated.

**Notes:** Scope is section-level plan time + its Δ. Per-km displays (TASK-025) and
`sectionActualSeconds` (already sums over `kmIndices`) are correct — untouched. The left
`viewSectionCard` is geometry-only (no plan time) — untouched. Browser round-trip with a
linked actual is the one manual check the headless env can't do; recommend it post-merge
alongside the two already-pending manual checks.

---

_(Below: calibration is paused — the two **core continuous rates** are both data-driven:
**TASK-043** climb rate `vmh` (PR #80, `819e9dc`; confirmed on the user's real
data — 616 m/h) and **TASK-044** flat-trail pace (PR #82, `a76db2e`). Both via
the pure `Calibration` module + the `smoke:calibration` gate + the transparent
`#/profile` panel; ADRs 0006/0007.

**Calibration paused here by the user (2026-06-15).** The two core continuous
rates are the agreed stopping point; the remaining fits stay queued and should
be promoted only on a fresh go-ahead. They step up in complexity / scope (and
several are data-gated):
- **Descent technique** — feasible from existing data (descent kms vs the
  flat×Tobler baseline → implied multiplier), but `descentSkill` is an *enum*,
  so calibration means snapping a fitted multiplier to the nearest level (new
  wrinkle vs. the continuous vmh/pace fits).
- **Fatigue slope / climb-fatigue `k`** — need time-binning + a curve fit over
  long runs (`pace(t)`, `vmh(t)`); more involved than the realized-rate fits.
- **Riegel `k`, sustainable-HR-by-duration, decoupling** — *new predictor
  capabilities* (no profile field today) and data-gated (multiple race
  distances / HR streams across durations).

Also still queued: parking-lot items (section-card **Δ-vs-plan** fix — unblocked
by TASK-039; light/dark; multi-language). Two manual checks remain recommended
(headless env can't do them): browser round-trip after the TASK-040 IDB
migration; print-preview of the TASK-042 table.)_
