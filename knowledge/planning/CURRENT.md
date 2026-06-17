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

### TASK-055 — Home view: personal vs others' + filter by person

**Source:** BACKLOG (coach-collab arc, companion spec §1.5) — pulled in on the TASK-054 close (build order: 054 → **055** → 056).
**Branch:** `feat/task-055-home-owner-view` (to create).
**Depends on:** TASK-054 ✓ (`Race.owner`, `me`, the directory, `Identity.resolveName` all shipped).

**Acceptance criteria (spec §1.5):**
- [ ] Home view distinguishes **personal** from **someone else's** races by **`owner`, not last-editor** — a race you own that your coach edited still reads as yours. *(Manual: import a race as "someone else", confirm it lands in the others' group; edit one of your own, confirm it stays personal.)*
- [ ] "Personal" = `owner == me.userId` **or** unstamped (`owner == ""`) **or** no identity yet (`me == Nothing`) — so a solo user's unshared local races all read as personal and the others' grouping stays empty (no empty scaffolding for the common case). *(Manual: fresh/solo instance shows exactly today's layout.)*
- [ ] When others' races exist, the view **filters / groups by person** on `owner`, labelled from the directory (`Identity.resolveName`) — nothing hardcoded "coach"/"athlete". On a coach's device every athlete plan reads as someone-else's, filterable by athlete and separated from the coach's own. *(Manual: with ≥1 others' race, the person filter/grouping appears and works.)*
- [ ] **Composes with the existing Plans/Executions split** (TASK-028) without regressing it. *(Manual: both cuts still work.)*
- [ ] Headless gates green; the owner-based split + person filter verified in-browser (home view isn't headlessly exercisable, like the feed/flows).

**Design notes (to settle when implementing):** keep the common solo path byte-identical to today (no person UI until an others'-owned race exists); decide filter-chips vs per-person sections then. `owner == ""` is **personal** (unstamped local races are yours), not "unknown". Home view consumes `owner` read-only — no new stamping here (that's TASK-054's job, done).

---

**Arc state (2026-06-17):** companion spec ingested (#104) → TASK-052 dropped, folded into TASK-056 (#106) → Q-I1–Q-I3 resolved + **ADR-0012**. Build order TASK-054 ✓ → **TASK-055 (active)** → TASK-056 (last). Done: TASK-046–051, 053, **054** ✓. **Q-U1–Q-U5 still gate TASK-056** — resolve with the user before that surface.

**Recommended in-browser checks (standing, pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview; TASK-045 section table/card with a linked actual.

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
- **Coach-collab arc:** engine + feed shipped (TASK-046–051, 053). Now in the
  identity/UI strand — TASK-054 (WI-5) active; then TASK-055 (home), TASK-056
  (merge UI, last). **Q-U1–Q-U5 gate TASK-056** — resolve with the user before
  that surface.
