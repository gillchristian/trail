# Local CI

The commands behind "run local CI" in the loop (manifest step 5), the
verification gates (`framework/verification.md` gates 5 and 8), and the PR
cycle (`framework/delivery.md`, profile `pr`, full-cycle step 4). All must
exit 0 before a PR opens.

## Prerequisites

- **Elm 0.19.1 — a dev dependency** (`elm@0.19.1-6` in `package.json`: the npm
  wrapper that downloads the 0.19.1 compiler binary on install — TASK-057).
  A plain `npm install` / `npm ci` drops it at `node_modules/.bin/elm`, so every
  gate works from a clean checkout with **no global Elm**: gate 1 and the smoke
  harnesses (`scripts/smoke-aid-csv.mjs`, `scripts/smoke-sections.mjs`,
  `scripts/smoke-calibration.mjs`, `scripts/smoke-trailsync.mjs`,
  `scripts/smoke-merge.mjs`, `scripts/smoke-changelog.mjs`,
  `scripts/smoke-identity.mjs`) call `npx --no-install elm`, which resolves the
  local binary, and gate 2's `vite-plugin-elm` spawns `elm` off the
  `node_modules/.bin` that `npm run` puts on `PATH`. This is also what makes the
  Vercel/CI build pass — before TASK-057, `npm install` did not provide `elm`
  and the cloud build died with `spawn elm ENOENT`. A globally-installed Elm
  still works as a fallback but is no longer required.
- **Node pinned to v22** via `.nvmrc` (`nvm use`); the smoke harnesses run on it.

## The gates

| Gate | Command | What it proves |
|---|---|---|
| Type-check | `npx elm make src/Main.elm --output=/dev/null` | The app compiles. In Elm this is the lion's share of correctness. |
| Build | `npm run build` | Vite production build succeeds (catches asset/JS-interop breakage Elm can't see). |
| Storage smoke | `npm run smoke` | IndexedDB round-trips for the **v5 schema**: the `races`/`gpx` split (GPX in its own row), full vs light (meta) save, orphan-free delete, the **WI-5 `identity` store** (the `{me, directory}` bundle round-trips; empty/`null` until the first mint — TASK-054), the **v2 → v3 + v3 → v4 migrations**, and the **v4 → v5 self-heal** of a DB left at v4 *without* the identity store (interrupted upgrade / dev HMR) — reopening re-runs the additive migration with no data loss, and `loadIdentity` degrades to `null` rather than throwing while the store is absent — all including UTMB-size payloads (`scripts/smoke-storage.mjs`; ADR-0005). **Scope:** still does not systematically cover the `settings` store (athlete profile / Strava token). Mirrors `main.js`'s IDB logic (can't import it), so the two must stay in sync. |
| Aid-CSV smoke | `npm run smoke:aidcsv` | `AidCsv.parse`/`toCsv` behavior via the compiled `Platform.worker` harness (`scripts/smoke-aid-csv.mjs` + `src/AidCsvHarness.elm`). |
| Section-partition smoke | `npm run smoke:sections` | Two `Planning` properties over the real compiled module (`scripts/smoke-sections.mjs` + `src/SectionsHarness.elm`): (a) `sectionsForRace` assigns each km to exactly one section by midpoint, so section gain/loss/Time/cum (and section-mode CSV) never double-count a km straddling an aid distance (ADR-0004); (b) `sectionAidRest` attributes each aid's rest to the one section holding its km — including the first-half-of-km case where that's the *next* section, not `followedByAid` — summing to the course total (ADR-0008, the clock-time `Δ vs plan` fix). Regression guard for the TASK-039 overlap + TASK-045 clock-time bugs. |
| Calibration smoke | `npm run smoke:calibration` | The two calibration fits over the real compiled module (`scripts/smoke-calibration.mjs` + `src/CalibrationHarness.elm`): `Calibration.fitVmh` — gain-weighted climb rate over climb kms (ADR-0006) — and `Calibration.fitFlatPace` — distance-weighted pace over runnable kms `abs slope < 0.04` (ADR-0007). Each: known-input value, the threshold/band cut, no/zero-time skip, and `Nothing` for no data. |
| Trail-sync smoke | `npm run smoke:trailsync` | The `.trail` identity/integrity layer over the real compiled modules (`scripts/smoke-trailsync.mjs` + `src/TrailSyncHarness.elm`; ADR-0010, coach-collab WI-1): `TrailSync.courseHash` is deterministic, tolerant of cosmetic GPX diffs (sub-1m precision + sub-1m ele round equal), and distinct for a different course; `TrailSync.classify` returns the right verdict (Mergeable / DifferentRace / DifferentCourse) and an empty shareId never matches; `ProjectFile` decodes both v1 (no shareId/courseHash → "") and v2, rejects an unknown version, and re-exports v1 as v2 with the identity fields intact (incl. `owner`, which likewise defaults to "" on v1 and round-trips — WI-5 / TASK-054); the v2 doc carries the denormalized name **`people`** (`Identity.subsetFor` over owner + change authors) — decode recovers them, v1 defaults to none, and a re-export denormalizes the owner back into `people` (WI-5 / TASK-054); the v2 doc carries the **WI-3 merge state** — `version` (the version vector) + `mergeBase` (the merge ancestor, a nested `PlanningLayer`) — decode recovers both, v1 defaults to empty/none, and they survive a re-export (TASK-056 / ADR-0013); and `TrailSync.ensureIdentity` backfills a pre-existing race's empty shareId (seeded from its id) + courseHash (from the GPX) at export while leaving an already-stamped race unchanged (TASK-053). |
| Changelog smoke | `npm run smoke:changelog` | The `Changelog` change-history engine over the real compiled module (`scripts/smoke-changelog.mjs` + `src/ChangelogHarness.elm`; coach-collab WI-4 / TASK-051). The two-way `diff` emits the right typed `ChangeDescriptor` for each planning-layer change (aid add/remove/move/rename/retime, km note add/edit/clear, km pace set/change/clear, race rename/date) and **nothing** for non-taxonomy changes (target time, location, url, notes) so the feed isn't spammed; entries round-trip through the codec (in `Types`); and `union` merges two histories conflict-free by `entryId` (dedupe + timestamp order). |
| Identity smoke | `npm run smoke:identity` | The pure `Identity` core over the real compiled module (`scripts/smoke-identity.mjs` + `src/IdentityHarness.elm`; coach-collab WI-5 / TASK-054, ADR-0012). The name **last-write-wins** register (`learn` / `mergeDirectory`): a strictly-newer `nameUpdatedAt` wins, an older or tied one is ignored (importing a stale file never reverts a name); the import **decision** (`decideImport` — only a file you own imports silently) and the **mint discipline** (`resolveOwnership` — *yourself* adopts the file's owner id and never mints; *someone-else* with no identity mints-then-reviews; else reviews as me); `subsetFor` (the ids a `.trail` denormalizes); and the `me` + directory codecs round-trip. Pure — IDB persistence + the prompt/link-action flows land with the integration slice. |
| Merge smoke | `npm run smoke:merge` | The `Merge` module over the real compiled code (`scripts/smoke-merge.mjs` + `src/MergeHarness.elm`; coach-collab WI-2/WI-3). **Course freeze:** `withPlanningLayer (planningLayer source) local` keeps the **local** race's frozen course (gpxText + distance/gain/loss + courseHash) and identity/owner-only fields (id, shareId, createdAt, coverImage, actualSplits) verbatim while taking the planning layer from `source` — so a merge cannot alter track points by construction — plus round-trip identity. **Fork-safe aid ids (TASK-049):** `mintAidId deviceId seq` is deterministic per (device, seq), distinct across devices for the same seq, bare `"aN"` for empty deviceId. **Three-way merge engine (TASK-050 / ADR-0011):** `mergePlanningLayer base mine theirs` — disjoint coach-note + owner-aid → 0 conflicts both landing; same km note both sides → 1 typed conflict that `resolve` flips to theirs; deterministic; disjoint aid adds → both present; honoured removes; scalar three-way; and `classifyVersions` over the version vector → Same / FastForward / Behind / Diverged. |

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
