# Local CI

The commands behind "run local CI" in the loop (`README.md` step 5), the
verification gates (`philosophy/verification.md` gate 8), and the PR cycle
(`philosophy/pr-workflow.md` step 4). All must exit 0 before a PR opens.

## The gates

| Gate | Command | What it proves |
|---|---|---|
| Type-check | `npx elm make src/Main.elm --output=/dev/null` | The app compiles. In Elm this is the lion's share of correctness. |
| Build | `npm run build` | Vite production build succeeds (catches asset/JS-interop breakage Elm can't see). |
| Storage smoke | `npm run smoke` | IndexedDB schema + save/load/delete round-trips, including UTMB-size payloads (`scripts/smoke-storage.mjs`). |
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
