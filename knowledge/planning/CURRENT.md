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
**Q-U1–Q-U5 resolved (user, 2026-06-17) → ADR-0013:** **modal** (not drawer) · **forced per-card choice** (nothing pre-selected; Apply enables only when all resolved) · same-km-note overlap = **hand-merge textarea** (editable, pre-filled with both — *not* pick-one; the one departure from the spec default) · confirm-on-dismiss **only when picks exist** · course-anchored renderer = explicit **v2** (v1 cards carry km/location). The §2.2 reframe (review *suggestions*, person-named, no red/green) is now ADR-0013.

**Acceptance criteria (spec §2.6, Q-U-resolved):**
- [ ] **Integration:** persist `mergeBase : PlanningLayer` + `version : VersionVector` on `Race`; `.trail` carries `{ base, current, version }` (Q2, additive — `D.oneOf` defaults, no format bump); bump `version[deviceId]` on each local plan/aid/metadata commit; set/advance `mergeBase` at share/merge points. *(Smoke the version bump + base round-trip; manual.)*
- [ ] **Entry point:** importing a `.trail` whose `shareId` matches an existing local race (courseHash matches per WI-1) routes to **merge**, not import-as-new; `classifyVersions` → FastForward applies directly (no UI), Diverged → review modal, Behind → no-op, Same → no-op; handle the dup-shareId self-reimport edge. *(Manual: the 4 classify branches.)*
- [ ] **Review surface (modal):** only the true-collision residue shown + a one-line "M other changes from `<name>` were added automatically" reassurance; **two equal, person-named options** per card (You / `<name>`, no red/green, identity tint + ring/check), **forced** choice, Apply enabled only once every card is resolved; a same-km-note card is an **editable textarea** pre-filled with both versions. *(Manual.)*
- [ ] **Apply path:** fold `Merge.resolve` (+ a custom-value set for hand-merged notes) → `withPlanningLayer` → save → bump version → emit WI-4 `Merged` entries (person-named via the directory). **Keep my version** + close reject the whole import with no state change; confirm only when picks exist. *(Manual.)*
- [ ] Labels resolve via the WI-5 directory (nothing hardcoded "coach"/"athlete"); each card carries km/location (forward-compat for the v2 renderer); single-column / mobile-safe. *(Manual.)*

**Slice plan (verifiability-first, mirroring WI-3/WI-5):**
1. ✓ **Slice 1 — merge state on `Race` + `.trail`** (PR #121, `f330d68`): moved `PlanningLayer` `Merge`→`Types`, added `Race.mergeBase : Maybe PlanningLayer` + `Race.version : Dict String Int` (codecs, ride `raceMetaFields`, `D.oneOf` defaults); `commitRaceEdit` bumps version on a real layer change; export records `mergeBase` (share point); `smoke:trailsync` extended (version + nested ancestor round-trip). Headless-verified, inert + back-compat, main.js untouched.
2. **Slice 2 — entry point + classify + apply + the review modal (browser-verified — NEXT):** route a matching-`shareId` import to `classifyVersions` (FastForward auto-applies; Diverged opens the **modal**; Behind/Same no-op); the review modal (cards + the **hand-merge textarea** for same-km notes + forced choice + the reassurance line + Apply / Keep-my-version exits, confirm-on-dismiss only when picks exist); the apply path (`Merge.resolve` fold **+ a custom-value set for hand-merged notes** → `withPlanningLayer` → save → bump version → emit `Merged` feed entries, person-named). Held for the user's in-browser check, like the feed/flows.

**Notes:** ships LAST. `authorId` (TASK-054) is the foundation for person-named `Merged` labels. Engine exists (TASK-050) — the UI + the custom-value note apply are new. Mobile-first, single column.

---

**Arc state (2026-06-17):** companion spec ingested (#104) → TASK-052 dropped, folded into TASK-056 (#106) → Q-I1–Q-I3 resolved + **ADR-0012**. Build order TASK-054 ✓ → TASK-055 ✓ → **TASK-056 (active, LAST)**. Done: TASK-046–051, 053, 054, **055** ✓. **Q-U1–Q-U5 resolved (2026-06-17) → ADR-0013**; TASK-056 building in two slices (integration plumbing, then the review modal).

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
