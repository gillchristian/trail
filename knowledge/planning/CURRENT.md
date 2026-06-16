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

### TASK-049 — Fork-collision-safe aid-station ids

**Source:** BACKLOG (coach-collab epic, spec §4 + ADR-0009 grounding #2)
**Branch:** feat/task-049-fork-safe-aid-ids
**Acceptance criteria:**
- [x] Stable per-device id (`deviceId`, UUID) minted once JS-side
  (`main.js`, localStorage `trail.deviceId`, synchronous → ready at boot) and
  passed to Elm via flags → `Model.deviceId`. The author identity WI-3/WI-4 reuse.
- [x] **New** aid ids are device-tagged (`Merge.mintAidId deviceId seq` →
  `"a"+seq+"-"+first8(deviceId)`) at both minting sites — the aid form
  (`validateAidForm`) and `assignAidIds` (CSV import). Verified `smoke:merge`:
  different-device same-seq → **distinct**; same-device same-seq → deterministic.
- [x] Back-compat: existing `"aN"` ids untouched (no re-id; ancestral aids shared
  across a fork still match); empty deviceId → bare `"aN"`. Verified `smoke:merge`.
- [x] `smoke:merge` extended (mint-aid op, 5 checks); all 8 gates green;
  type-check `Success!` + build `✓ built`.
**Notes:** Reframed from the spec's "add ids" (aids already have ids:
`"a"+aidStationSeq`) to "make them fork-safe" — the shared per-race counter
mints identical ids on both forks (ADR-0009 grounding #2). `deviceId` clears the
3-use bar (aid ids here, conflict attribution in WI-3, author stamping in WI-4),
so building it now is coherent, not premature. `Merge.mintAidId` lives in `Merge`
because its purpose is unambiguous aid-keying for the three-way merge.

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
