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

### TASK-043 — Calibrate climb rate (`vmh`) from linked actual runs

**Source:** First split of TASK-022 (calibration), promoted 2026-06-15 (batch
task 5 of 5; 039/040/041/042 shipped — PRs #72/#74/#76/#78). TASK-022 is the
parent epic; the roadmap (§7) says "split into per-fit subtasks" ordered by
value-per-effort, and **vertical rate is #1** — it replaces the hand-set
`verticalRateVmh`, the core climb-time input (`climb = gain / (vmh × i)`).

**Why this slice.** Roadmap §9's "open questions" are mostly resolved by shipped
work (one global profile, continuous slider, loud confidence, actual-as-column,
hybrid local-first). The one genuinely open question — calibration transparency
(#7) — the roadmap answers itself: *show which activities, let the user opt in*.
Adopt that (ADR). The vmh fit needs only data we already have: each linked
race's per-km course gain (`Planning.computeKms`, cached in `model.kmsCache`) +
its `actualSplits.splits` (per-km seconds). No new Strava fetching.

**Approach.**
- New pure module `Calibration.elm` — `fitVmh : List { kms : List Km, splits :
  Dict Int Int } -> Maybe VmhFit`, where a climb km (gain ≥ threshold, e.g.
  ≥ 30 m) contributes its gain + actual seconds; `fittedVmh = Σ climbGain /
  (Σ climbSeconds / 3600)` (gain-weighted = realized climb rate). Returns the
  fit + contributing climb-km / race counts (for confidence + transparency), or
  `Nothing` when there's no qualifying climb data.
- Profile page (`#/profile`): a "Calibrate from your runs" panel. With ≥1 linked
  actual: "Fitted climb rate **X m/h** from N climbs across M runs (current Y).
  [Apply]" + the contributing races listed. With none: a "link an actual run to
  calibrate" hint. Apply → set `profile.verticalRateVmh`, save (reuse the
  existing profile-save path).

**Acceptance criteria:**
- [ ] `Calibration.fitVmh` returns the gain-weighted climb rate over climb kms
  across linked runs, the contributing counts, and `Nothing` for no climb data.
- [ ] **Verified by a `smoke:calibration` harness** (pure, like `smoke:sections`)
  driving the real compiled `fitVmh` over synthetic linked runs — assert the
  fitted vmh for known inputs, the no-data case, and the climb-threshold cut.
- [ ] Profile page shows the fitted vmh + provenance (which/how many runs) and an
  Apply button that updates + persists `verticalRateVmh`; degrades to a hint when
  no actuals are linked.
- [ ] On-screen wiring verified as far as headless allows (build, port/UI present);
  the visual/click path flagged for a manual check (env can't drive the Elm UI).
- [ ] ADR for the calibration methodology (gain-weighted fit, climb threshold,
  transparency/opt-in, confidence from data volume).
- [ ] All local-CI gates green (incl. the new calibration smoke).

**Notes.** Delivers the single highest-value calibration fit. **TASK-044**
(flat-trail-pace calibration, same data path) is queued; the further fits
(climb-fatigue `k`, Riegel, sustainable-HR-by-duration, descent technique,
decoupling) stay in roadmap §7 as future sub-tasks — several are gated on more
data (multiple races / distance range) and should be promoted only with user
appetite. Report calibration status to the user after this ships.
