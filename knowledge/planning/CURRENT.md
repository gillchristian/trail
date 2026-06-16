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

### TASK-053 — Backfill `.trail` identity for pre-existing races (at export)

**Source:** user bug report 2026-06-16 — existing races export as v2 with an
empty `courseHash` (and `shareId`): the WI-1 decoder defaults both to `""` and
nothing backfilled races already in IDB.
**Branch:** fix/task-053-backfill-identity
**Decision (with user):** backfill **at download/export**, not on load —
computing `courseHash` needs a GPX re-parse, so hashing every race on load would
add a hitch the home page doesn't have today; only the shared race needs
identity. Persist it so the round-trip guard matches later.
**Acceptance criteria:**
- [x] Pure `TrailSync.ensureIdentity : Race -> Race` fills `shareId` (seeded from
  the race's stable IDB `id` when empty) + `courseHash` (computed from gpxText
  when empty); a race that already has both is unchanged. Verified `smoke:trailsync`
  (backfilled from id + gpx; already-stamped preserved).
- [x] `ExportProjectFile` exports the *stamped* race and, when it changed,
  persists it via `saveRaceMeta` (light — no GPX re-ship). Verified type-check +
  build; **pending user in-browser confirm** (old race's `.trail` carries
  non-empty `shareId` + `courseHash`).
- [x] All 8 gates green; type-check `Success!` + build `✓ built`.
**Notes:** `shareId` seeded from `id` (a UUID) is a clean unique+stable seed —
they coincide initially for backfilled races but diverge after any import (id
regenerates, shareId preserved), consistent with ADR-0010. New races still get a
JS-minted UUID shareId at full save; this only backfills the pre-WI-1 ones.

---

_(coach-collab arc still **paused at the verified seam** (2026-06-15) below
TASK-053. The headlessly-verifiable core is shipped and green:
**TASK-046** (brief) ✓, **047** WI-1 identity/guard ✓, **048** WI-2 course freeze
✓, **049** fork-safe aid ids ✓, **050** WI-3 merge **engine** ✓ — ADRs 0009/0010/0011,
gates `smoke:trailsync` + `smoke:merge`.

**Why paused (not blocked-by-effort):** the two remaining items are a different
verification class — their value is interactive **browser** behavior I can't drive
headlessly, and TASK-052's base/version orchestration is stateful distributed
logic where "it compiles" ≠ "it's correct." Shipping them compile-only would be
"should-work code I haven't run" (`when-stuck.md`). They're fully specced + ADR'd,
ready to resume:
- **TASK-052** — WI-3 part 2: merge integration + dedicated review UI (persist
  `mergeBase`+`version`, `.trail` carries `{base,current,version}`, bump on edit,
  import→merge entry point, review screen). Q2–Q5 already resolved.
- **TASK-051** — WI-4: structured change-history feed.

**Recommended in-browser checks** (headless env can't do them):
- **Coach-collab arc:** upload a GPX → export `.trail` → confirm it carries
  `shareId` + `courseHash` (v2); a v1 `.trail` still imports; add an aid →
  device-tagged id.
- **Standing (pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview;
  TASK-045 section table/card with a linked actual.)_

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
