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

### TASK-047 — WI-1: `.trail` format v2 — identity + integrity guard

**Source:** BACKLOG (coach-collab epic, spec §2)
**Branch:** feat/task-047-trail-identity-guard
**Q1 resolved (user, 2026-06-15):** courseHash = **canonical decoded track**
(rounded lat/lon/ele, tolerant of cosmetic GPX diffs); on courseHash mismatch =
**hard-block** the import. → ADR-0010.
**Acceptance criteria:**
- [x] `Race` gains a stable **`shareId`** distinct from the IDB-key `id`: minted
  JS-side (`main.js` `race.shareId || crypto.randomUUID()`), **preserved on
  import** (import keeps it, only `id` is blanked). New upload → ""→JS mints; v1
  import → ""→mints; v2 import → preserved. Verified: `smoke:trailsync` classify
  + `smoke` "provided shareId is preserved" / "round-trips through IDB".
- [x] `Race` gains **`courseHash`** from the canonical decoded track (lat/lon→5
  dp, ele→nearest m), pure-Elm double-polynomial hash (no crypto/port). Verified
  `smoke:trailsync`: deterministic; cosmetically-different-but-equivalent GPX →
  **same** hash; different course → **different** hash; unparseable → "".
- [x] `.trail` → **v2** (carries the fields); version gate widened to **{1,2}**.
  v1 imports (mints shareId + computes courseHash). Verified `smoke:trailsync`:
  v1 decodes (fields→""), v2 decodes (fields preserved), v3 rejected, v1
  re-exports as v2.
- [x] Pure **guard** `TrailSync.classify` → `Mergeable | DifferentRace |
  DifferentCourse` (+ `verdictMessage`). Verified `smoke:trailsync`: all three
  verdicts + empty-shareId-never-matches.
- [x] New **`smoke:trailsync`** gate (24 checks) over the real compiled modules;
  all six prior gates stay green; type-check `Success!` + build `✓ built`.
- [x] Back-compat: v1 `.trail` decodes (defaults ""); v3 IDB races load (decoder
  defaults); storage smoke + migration still `SMOKE PASSED`.
**Notes:** **Scope boundary** — WI-1 delivers the *data* (format v2) + the *pure
guard*, fully smoke-tested; it does **not** add the "update-from-file" UI or
change the existing import-as-new-race behavior (that path now just stamps the
two fields). The guard is wired in by **TASK-050 (WI-3)**, which adds the merge
entry point that calls classify → merge. Known edge logged for WI-3:
re-importing your own file as-new produces two local races sharing a shareId
(the dedicated update-from-file path is the intended route). `main.js` mints
shareId (`race.shareId || crypto.randomUUID()`); `smoke-storage.mjs` mirror
updated to match.

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
