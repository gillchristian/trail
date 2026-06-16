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

### TASK-048 — WI-2: course-freeze invariant (planning-layer / course boundary)

**Source:** BACKLOG (coach-collab epic, spec §3)
**Branch:** feat/task-048-course-freeze
**Acceptance criteria:**
- [x] New `Merge` module defines the freeze structurally: `Race` splits into a
  frozen **course** (gpxText + distance/gain/loss + courseHash) and a mergeable
  **`PlanningLayer`** (name/date/location/url/notes + aidStations/aidStationSeq +
  plan). `planningLayer : Race -> PlanningLayer` + `withPlanningLayer :
  PlanningLayer -> Race -> Race` (keeps the **local** course + identity +
  owner-only fields verbatim). The surface WI-3 merges within.
- [x] **Course can't change through the merge path, by construction.** Verified
  `smoke:merge`: feeding a planning layer from a *different* course →
  gpxText/courseHash/distance/gain/loss (+ id/shareId/createdAt/coverImage/
  actualSplits) all stay local; name/date/location/url/notes/aids/plan come from
  source.
- [x] Round-trip identity `withPlanningLayer (planningLayer r) r == r` — verified
  `smoke:merge` (gpxText/courseHash/name/aids/plan/shareId preserved).
- [x] New `smoke:merge` gate (25 checks) over the real compiled `Merge` module;
  all 7 prior gates green; type-check `Success!` + build `✓ built`.
- [x] The "different course → rejected on import" half is already shipped + tested
  in WI-1 (`TrailSync.classify` DifferentCourse + `smoke:trailsync`) — referenced,
  not re-done.
**Notes:** Light task (spec calls it "guard + exclusion"). The *enforcement* of
"merge can't touch the course" is the `withPlanningLayer` reassembly: WI-3
produces a merged `PlanningLayer` and rebuilds the race through it, so track
points are never a merge input/output. Per-field merge *policy* within the layer
(e.g. coverImage handling, last-write vs conflict) is WI-3's call (partly Q3) —
WI-2 only fixes the boundary. `Merge` is seeded here and grown by WI-3.

---

## Standing reminders (not active tasks)

- **Calibration is paused (user, 2026-06-15).** The two core continuous rates
  shipped (TASK-043 vmh, TASK-044 flat pace); the harder roadmap §7 fits
  (descent / fatigue / Riegel / sustainable-HR / decoupling) stay queued —
  promote only on a fresh go-ahead.
- **Three manual checks recommended** (headless env can't do them): browser
  round-trip after the TASK-040 IDB migration; print-preview of the TASK-042
  table; section table/card with a **linked actual** for TASK-045 (clock Time,
  Actual − Time = Δ, monotonic Cum ending at total clock).
- **After TASK-046:** the epic continues with TASK-047 (WI-1), where **Q1**
  (courseHash input + mismatch behavior) must be resolved with the user first.
