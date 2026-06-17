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

### TASK-056 — WI-3 (part 2): merge integration + suggestion-review UI (ships LAST)

**Source:** BACKLOG (coach-collab arc; absorbs the dropped TASK-052). The arc's final piece — wire the TASK-050 engine into the app *and* build the human review surface.
**Branch:** `feat/task-056-merge-ui` (to create).
**Depends on:** TASK-050 (engine ✓), TASK-054 (identity / person-named labels ✓), TASK-055 (home owner view ✓). Design reference: `reference/merge-review-prototype.html` (take the UX/layout, not the markup; its "Coach" role labels are the seat-relative bug WI-5 fixes → person names).
**GATED on Q-U1–Q-U5** (spec "Shared open questions") — *resolving with the user this session before implementing*, as Q1–Q5 / Q-I1–Q-I3 were. **ADR pending:** promote the §2.2 merge-UI reframe (suggestions / person-not-role / card list / no red-green) to an ADR when built.

**Open questions to resolve first:** Q-U1 placement (modal vs wide drawer) · Q-U2 default stance (forced per-card choice vs pre-select "you") · Q-U3 same-field note overlap (pick-one vs hand-merge textarea; carried from engine Q5) · Q-U4 confirm-on-dismiss (only when picks exist? + copy) · Q-U5 course-anchored renderer = explicit v2 (v1 cards already carry km/location).

**Acceptance criteria (spec §2.6) — to finalize once Q-U land:**
- [ ] **Integration:** persist `mergeBase : PlanningLayer` + `version : VersionVector` on `Race`; `.trail` carries `{ base, current, version }` (Q2, additive — `D.oneOf` defaults, no format bump); bump `version[deviceId]` on each local plan/aid/metadata commit; set/advance `mergeBase` at share/merge points. *(Smoke the version bump + base persistence; manual round-trip.)*
- [ ] **Entry point:** importing a `.trail` whose `shareId` matches an existing local race (courseHash matches per WI-1) routes to **merge**, not import-as-new; `classifyVersions` → FastForward applies directly (no UI), Diverged → review, Behind → no-op, Same → no-op; handle the dup-shareId self-reimport edge. *(Manual: the 4 classify branches.)*
- [ ] **Review surface:** only the true-collision residue shown + a one-line "M other changes from `<name>` were added automatically" reassurance; **two equal, person-named options** per card (You / `<name>`, no red/green, identity tint + ring/check), forced per-card choice (per Q-U2), Apply enabled only once every card is resolved. *(Manual.)*
- [ ] **Apply path:** `Merge.resolve` fold → `withPlanningLayer` → save → bump version → emit WI-4 `Merged` entries (person-named via the directory). **Keep my version** + close both reject the whole import with no state change; confirm only when picks exist (per Q-U4). *(Manual.)*
- [ ] Labels resolve via the WI-5 directory (nothing hardcoded "coach"/"athlete"); each card carries km/location (forward-compat for the Q-U5 v2 renderer); single-column / mobile-safe. *(Manual.)*
- [ ] Headless gates green (engine paths smoke-covered where pure); the import→classify→review→apply flow verified in-browser (like the feed/flows).

**Notes:** ships LAST per the locked build order. `authorId` (TASK-054) is the foundation for person-named `Merged` labels. Write per-type merge/apply concretely (the engine already exists); the UI is new. Mobile-first, single column (never side-by-side).

---

**Arc state (2026-06-17):** companion spec ingested (#104) → TASK-052 dropped, folded into TASK-056 (#106) → Q-I1–Q-I3 resolved + **ADR-0012**. Build order TASK-054 ✓ → TASK-055 ✓ → **TASK-056 (active, LAST)**. Done: TASK-046–051, 053, 054, **055** ✓. **Q-U1–Q-U5 gate TASK-056** — resolving with the user now.

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
