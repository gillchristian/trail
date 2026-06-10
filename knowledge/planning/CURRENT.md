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

### TASK-037 — Rewrite `project-brief.md` + `glossary.md` to match shipped reality

**Source:** BACKLOG (2026-06-10 doc-vs-code audit) — user go-ahead 2026-06-10 to
clear all three audit doc-fix tasks (036/037/038). TASK-036 closed (PR #65,
`7b8455f`).
**Branch:** `docs/task-037-brief-glossary-rewrite`
**Acceptance criteria:**
- [ ] **Brief — backend constraint.** "No backend, ever" (line 13) and "No
  backend / multi-user / sync" (line 28) corrected to the roadmap's agreed
  Layer-0 (offline) / Layer-1 (opt-in Strava sync via cadence) wording
  (`pace-prediction-roadmap.md:296`); the live Strava integration no longer
  contradicts the brief.
- [ ] **Brief — undocumented shipped features.** Add the three: plan-vs-actual
  splits + HR via `ActualGpx` (TASK-016/026); athlete profile + `Predictor` at
  `#/profile` (TASK-017/018/019/020); aid-station CSV import/export via `AidCsv`
  (TASK-031).
- [ ] **Brief — feature 10 + minor drifts.** Map shipped as the `<trail-map>`
  custom element, *not* a JS port (line 56); CSV accepts miles via
  `distance_mi` (vs "km only", line 31 — qualify, keep the UI-display km-only
  intent); `Browser.application` not `.element` (line 38); IDB port is ~100
  lines / 2 stores (races + settings), not ~50 / 1 (line 41).
- [ ] **Glossary — VMH fixed.** Line 29 ("flat-ground speed … km/h") is wrong:
  code uses `verticalRateVmh` = vertical metres/hour of climb
  (`src/AthleteProfile.elm:47`, used as `gain / (vmh*i)` in `Predictor.elm:114`);
  the flat rate is the separate `flatTrailPaceSecPerKm`. Redefine VMH as
  vertical climb rate; add/clarify the flat-pace term.
- [ ] **Glossary — omitted user-visible terms.** Add distance category (S/M/L/XL),
  elevation density, flat-equivalent distance (all shown on race cards).
- [ ] Local CI green (4 gates). Brief still wins conflicts with planning
  (CLAUDE.md) — so any contradiction surfaced gets the brief's wording.
**Notes:** Docs-only. The brief is the most load-bearing doc (wins conflicts).
Keep the "miles" fix precise: CSV *import* accepts `distance_mi`, but the app
displays km only — don't overstate. Out of scope: ADR/CI/MORNING accuracy
(TASK-038).
