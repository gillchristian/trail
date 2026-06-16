# Local CI

The commands behind "run local CI" in the loop (manifest step 5), the
verification gates (`framework/verification.md` gates 5 and 7), and the PR
cycle (`framework/delivery.md`, profile `pr`, full-cycle step 4). All must
exit 0 before a PR opens.

## Prerequisites

- **Elm 0.19.1 installed globally / on `PATH`.** It is *not* an npm dependency
  of this project — `npm install` will **not** provide it. Gate 1 (`elm make`)
  and gate 2 (`vite-plugin-elm` during the build) both need `elm`, and gates
  4–7 shell out to `npx --no-install elm make` (`scripts/smoke-aid-csv.mjs`,
  `scripts/smoke-sections.mjs`, `scripts/smoke-calibration.mjs`,
  `scripts/smoke-trailsync.mjs`), which by design will not auto-download it. So
  with only `npm install` done, gates 1, 2, and 4–7 all fail until Elm is on
  `PATH`. Install via `npm i -g elm` (pin 0.19.1) or the platform binary.
- **Node pinned to v22** via `.nvmrc` (`nvm use`); the smoke harnesses run on it.

## The gates

| Gate | Command | What it proves |
|---|---|---|
| Type-check | `npx elm make src/Main.elm --output=/dev/null` | The app compiles. In Elm this is the lion's share of correctness. |
| Build | `npm run build` | Vite production build succeeds (catches asset/JS-interop breakage Elm can't see). |
| Storage smoke | `npm run smoke` | IndexedDB round-trips for the v3 schema: the `races`/`gpx` split (GPX in its own row), full vs light (meta) save, orphan-free delete, and the **v2 → v3 migration** of inline `gpxText` — including UTMB-size payloads (`scripts/smoke-storage.mjs`; ADR-0005). **Scope:** still does not cover the `settings` store (athlete profile / Strava token). Mirrors `main.js`'s IDB logic (can't import it), so the two must stay in sync. |
| Aid-CSV smoke | `npm run smoke:aidcsv` | `AidCsv.parse`/`toCsv` behavior via the compiled `Platform.worker` harness (`scripts/smoke-aid-csv.mjs` + `src/AidCsvHarness.elm`). |
| Section-partition smoke | `npm run smoke:sections` | Two `Planning` properties over the real compiled module (`scripts/smoke-sections.mjs` + `src/SectionsHarness.elm`): (a) `sectionsForRace` assigns each km to exactly one section by midpoint, so section gain/loss/Time/cum (and section-mode CSV) never double-count a km straddling an aid distance (ADR-0004); (b) `sectionAidRest` attributes each aid's rest to the one section holding its km — including the first-half-of-km case where that's the *next* section, not `followedByAid` — summing to the course total (ADR-0008, the clock-time `Δ vs plan` fix). Regression guard for the TASK-039 overlap + TASK-045 clock-time bugs. |
| Calibration smoke | `npm run smoke:calibration` | The two calibration fits over the real compiled module (`scripts/smoke-calibration.mjs` + `src/CalibrationHarness.elm`): `Calibration.fitVmh` — gain-weighted climb rate over climb kms (ADR-0006) — and `Calibration.fitFlatPace` — distance-weighted pace over runnable kms `abs slope < 0.04` (ADR-0007). Each: known-input value, the threshold/band cut, no/zero-time skip, and `Nothing` for no data. |
| Trail-sync smoke | `npm run smoke:trailsync` | The `.trail` identity/integrity layer over the real compiled modules (`scripts/smoke-trailsync.mjs` + `src/TrailSyncHarness.elm`; ADR-0010, coach-collab WI-1): `TrailSync.courseHash` is deterministic, tolerant of cosmetic GPX diffs (sub-1m precision + sub-1m ele round equal), and distinct for a different course; `TrailSync.classify` returns the right verdict (Mergeable / DifferentRace / DifferentCourse) and an empty shareId never matches; `ProjectFile` decodes both v1 (no shareId/courseHash → "") and v2, rejects an unknown version, and re-exports v1 as v2 with the identity fields intact. |

Plus the manual smoke test where the task touches UI behavior — the
`verification.md` gates ("it runs", "it does the thing") are not satisfied by
the table above alone.

## What there isn't

- **No lint/format step.** The Elm compiler is the linter; there is no
  `elm-review`/`elm-format` hook. Docs that say "tests + types + lint" predate
  this file — the real set is the table above.
- **No unit-test runner.** No `elm-test`; behavioral coverage lives in the
  smoke harnesses, which drive the real compiled modules.

## Ad-hoc tooling (not a gate)

- `npm run perf:trace -- <file.gpx> <m-per-px>` — parse + Haversine + DP
  pipeline timing against any GPX (`scripts/profile-trace.mjs`). Use when a
  task might regress parse/render performance.
