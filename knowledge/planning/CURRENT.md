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

### TASK-050 — WI-3 (part 1): three-way merge engine (pure)

**Source:** BACKLOG (coach-collab epic, spec §4)
**Branch:** feat/task-050-merge-engine
**Q2–Q5 resolved (user, 2026-06-15):** Q2 embed `{base,current}` in the `.trail`;
Q3 splits + cover stay owner-only (= the WI-2 boundary); Q4 per-device version
vector (reuses `deviceId`); Q5 dedicated review screen, per-km note pick-one for
v1. → ADR-0011.
**WI-3 split** for verifiability: **this task = the pure merge engine** (correctness
core, fully smoke-testable); the **integration + review UI** is **TASK-052** (entry
point, version/base orchestration, dedicated review screen — verification largely
manual). Mirrors Predictor-then-slider.
**Acceptance criteria (engine only):**
- [x] `Merge.VersionVector` (`Dict String Int`) + `classifyVersions mine theirs →
  Same | FastForward | Behind | Diverged`, `bumpVersion`, `mergeVersions`.
  Verified `smoke:merge`: all four relations (fast-forward ⟺ theirs dominates).
- [x] Typed conflict model (`field3` → `Merged | Conflicted base mine theirs`)
  and `mergePlanningLayer base mine theirs → { merged, conflicts }`: scalars +
  per-km `{time,notes}` three-way; aid set union/remove/per-field three-way by
  id. `merged` defaults conflicts to **mine**; `conflicts` carry key + label +
  mine/theirs. Verified `smoke:merge`.
- [x] `resolve key theirs acc` applies "take theirs" for one conflict; pure
  dispatch, no runtime failure. Verified `smoke:merge` (folding all conflicts to
  theirs flips the field).
- [x] Acceptance scenarios `smoke:merge`: coach km-note + owner aid → **0
  conflicts**, both land; same km note both sides → **1 typed conflict**;
  deterministic; disjoint aid adds → both present; honoured removes; scalar
  three-way; classify relations. All 8 gates green; type-check `Success!` + build
  `✓ built`.
- [x] No `Race`/`.trail`/UI changes (pure engine only) — those are TASK-052.
**Notes:** Course already excluded (WI-2 `PlanningLayer`). `resolve` lets the UI
build the final layer by folding chosen-theirs conflicts onto the mine-default
`merged`, then `withPlanningLayer` onto the local race (course frozen).

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
