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
- [x] **Brief — backend constraint.** "No backend, ever" (line 13) and "No
  backend / multi-user / sync" (line 28) corrected to the roadmap's agreed
  Layer-0 (offline) / Layer-1 (opt-in Strava sync via cadence) wording
  (`pace-prediction-roadmap.md:296`); the live Strava integration no longer
  contradicts the brief.
- [x] **Brief — undocumented shipped features.** Added a "shipped beyond the
  original list" section: plan-vs-actual splits + HR via `ActualGpx` (TASK-016/026);
  athlete profile + `Predictor` at `#/profile` (TASK-017..020); aid-station CSV
  import/export via `AidCsv` (TASK-031).
- [x] **Brief — feature 10 + minor drifts.** Map = `<trail-map>` custom element,
  *not* a JS port (line 56); CSV accepts miles via `distance_mi` (qualified, UI
  stays km-only); `Browser.application` not `.element` (line 38); IDB port ~100
  lines / 2 stores (races + settings), not ~50 / 1 (line 41).
- [x] **Glossary — VMH fixed.** Redefined as vertical climb rate (m of
  ascent/hour), with `climb = gain / (VMH × intensity)` — verified
  `verticalRateVmh` at `src/AthleteProfile.elm:47`, used at `Predictor.elm:114`;
  added **flat trail pace** (`flatTrailPaceSecPerKm`) as the distinct flat rate.
- [x] **Glossary — omitted user-visible terms.** Added distance category (S/M/L/XL),
  elevation density, flat-equivalent distance (all shown on race cards).
- [x] Local CI green (4 gates: elm make "Success!", build "✓ built in 1.01s",
  smoke "SMOKE PASSED", smoke:aidcsv "PASS"). Brief wording used wherever it
  conflicted with stale text (brief wins per CLAUDE.md).
**Notes:** Docs-only. The brief is the most load-bearing doc (wins conflicts).
Keep the "miles" fix precise: CSV *import* accepts `distance_mi`, but the app
displays km only — don't overstate. Out of scope: ADR/CI/MORNING accuracy
(TASK-038).
