# Local CI

The commands behind "run local CI" in the loop (manifest step 5), the
verification gates (`framework/verification.md` gates 5 and 7), and the PR
cycle (`framework/delivery.md`, profile `pr`, full-cycle step 4). All must
exit 0 before a PR opens.

## Prerequisites

- **Elm 0.19.1 installed globally / on `PATH`.** It is *not* an npm dependency
  of this project — `npm install` will **not** provide it. Gate 1 (`elm make`)
  and gate 2 (`vite-plugin-elm` during the build) both need `elm`, and gate 4
  shells out to `npx --no-install elm make` (`scripts/smoke-aid-csv.mjs`), which
  by design will not auto-download it. So with only `npm install` done, gates 1,
  2, and 4 all fail until Elm is on `PATH`. Install via `npm i -g elm` (pin
  0.19.1) or the platform binary.
- **Node pinned to v22** via `.nvmrc` (`nvm use`); the smoke harnesses run on it.

## The gates

| Gate | Command | What it proves |
|---|---|---|
| Type-check | `npx elm make src/Main.elm --output=/dev/null` | The app compiles. In Elm this is the lion's share of correctness. |
| Build | `npm run build` | Vite production build succeeds (catches asset/JS-interop breakage Elm can't see). |
| Storage smoke | `npm run smoke` | IndexedDB save/load/delete round-trips for the v1 `races` store, including UTMB-size payloads (`scripts/smoke-storage.mjs`). **Scope:** the `races` store only — *not* the v2 `settings` store (athlete profile / Strava token) nor the DB-version upgrade path. |
| Aid-CSV smoke | `npm run smoke:aidcsv` | `AidCsv.parse`/`toCsv` behavior via the compiled `Platform.worker` harness (`scripts/smoke-aid-csv.mjs` + `src/AidCsvHarness.elm`). |

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
