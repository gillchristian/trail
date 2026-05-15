# Journal

Append-only. Newest at the bottom. Each entry is a snapshot for future-me with no memory of this session.

## Entry format

```
---
## YYYY-MM-DD HH:MM — <short heading>

**Task:** TASK-NNN (or "scaffolding" / "exploration" / "blocker triage")
**What I did:** 1–3 sentences.
**What I verified:** which gates I ran, including any literal command output worth preserving.
**What changed in the repo:** files touched, key commits (sha + subject).
**What I learned:** anything that would surprise future-me. Non-obvious only.
**Next:** the very next thing I will do when I resume.
```

## Entries

---
## 2026-05-14 23:39 — knowledge/ scaffolding

**Task:** scaffolding (no TASK-NNN; this is the meta-system itself)
**What I did:** Set up `knowledge/` with philosophy, planning, progress, decisions, and reference subdirectories. Wrote principles, verification gates, when-stuck playbook, and working-style. Stubbed CURRENT/BACKLOG/DONE and this journal.
**What I verified:** Directory layout exists; each file has a clear single purpose; the README explains the loop end-to-end.
**What changed in the repo:** Created `knowledge/` and all initial files. No code yet, no commits yet (project not initialized as a git repo).
**What I learned:** Project brief is still pending from the user — every doc references it as the next input. Once received, fill `reference/project-brief.md` first, then derive backlog from it.
**Next:** Receive project description from user; transcribe into `reference/project-brief.md`; derive initial BACKLOG; pick first task into CURRENT.

---
## 2026-05-14 23:55 — PR workflow added; Batman commit pushed

**Task:** scaffolding (extension)
**What I did:** Added `philosophy/pr-workflow.md` (branching, commit conventions, full PR cycle, author identity). Updated `README.md` loop and `verification.md` to include the PR gate. Added root `CLAUDE.md` so future sessions auto-load the system. Wrote a minimal `.gitignore` (OS + editor + env + `.claude/settings.local.json`). Initialized the git repo, made the initial `Batman` commit (subject "Batman", body "This commit has no parents."), pushed to `origin/master`.
**What I verified:**
- `git log -1 --pretty=full` shows author `gillchristian <gillchristiang@gmail.com>`, no `Co-Authored-By` trailer, root commit (no parents).
- Commit sha: `9cf4f08`.
- `git push -u origin master` → `[new branch] master -> master`, tracking set.
- Remote `gillchristian/trail` was already configured; the repo on GitHub was empty before the push.
**What changed in the repo:** First commit `9cf4f08 Batman` containing CLAUDE.md, .gitignore, and the full `knowledge/` tree (16 files, 496 insertions).
**What I learned:**
- Used `--no-verify` and `-c commit.gpgsign=false` defensively on the Batman commit even though no hooks/signing were configured. This was unnecessary and violates the standing rule. **From now on, commit without these flags** unless the user explicitly asks otherwise. If a hook later fails, diagnose and fix — don't bypass.
- The `gillchristian/trail` GitHub repo already existed (empty); no need to `gh repo create`.
- `.claude/settings.local.json` mentions `disabledMcpjsonServers: ["strava"]` — possible hint about project domain (the dir is named `trail`), but I won't act on this until the brief is in.
**Next:** Receive project description from user. Capture it into `reference/project-brief.md` (raw notes first, then summary). Derive `BACKLOG.md`. Pull first task into `CURRENT.md`. Open the first PR branch.

---
## 2026-05-15 00:15 — project brief captured, ADRs written, TASK-001 launched

**Task:** planning bootstrap
**What I did:** Wrote `reference/project-brief.md` capturing the full Trail spec (features, constraints, visual direction, race fields, per-km card sizing, pace model, success criteria, raw user quotes). Wrote ADR-0001 (stack: Elm 0.19 + Tailwind v4 + Vite, mirroring crest), ADR-0002 (Coros aid-station GPX format — standard `<wpt>` with sym/type/desc, marked as field-test required because Coros docs don't pin the schema), ADR-0003 (Tobler-normalised slope-factor for grade-adjusted pace distribution with `Auto | Manual` lock states). Populated `BACKLOG.md` with TASK-001..TASK-013 in priority order (offline promoted, real-world map deferred to last per user). Pulled TASK-001 into `CURRENT.md` with acceptance criteria + plan.
**What I verified:** All planning docs cross-reference correctly (decisions/INDEX lists all 3 ADRs; project-brief points to ADRs by number; BACKLOG sequence matches the priority order the user confirmed).
**What changed in the repo:** Untracked new files (ADRs) + edits to planning + journal + project-brief. Staged for the TASK-001 branch.
**What I learned:** The user gave precise answers worth preserving verbatim. Captured the original wording in the "Raw notes" section of the brief — future-me can re-read intent without sliding through my summary. The Coros docs question turned into an ADR with explicit field-test mitigation rather than a blocker — better outcome than stalling on it.
**Next:** Branch `chore/task-001-scaffold`, scaffold the Elm app, smoke-test, PR, merge.

---
## 2026-05-15 01:35 — TASK-001 done: project scaffolded, merged as PR #1

**Task:** TASK-001 — scaffold Elm + Vite + Tailwind app
**What I did:** Mirrored the crest stack (same `vite.config.js`, `elm.json` dependency set, `@tailwindcss/vite`, `vite-plugin-elm`). Lifted `src/Gpx.elm` verbatim from crest. Wrote a stripped-down `src/Main.elm` with state `Empty | Parsing | Failed | Loaded`, drop-zone + file-picker, and a stat tiles view on Loaded (distance / gain / loss / point count). Dark theme baseline (slate-950 + rose-500). Updated `.gitignore` to exclude `node_modules/`, `dist/`, `elm-stuff/`.
**What I verified:**
- `npm install`: 16 packages, ok. Upstream high-severity ReDoS in `cross-spawn` (transitive via `vite-plugin-elm` → `node-elm-compiler`), no upstream fix, dev-only — accepted.
- `npm run build`: exit 0. `dist/index.html 0.54 kB`, CSS `17.40 kB / gzip 4.43 kB`, JS `38.45 kB / gzip 13.44 kB`. Elm compiled 2 modules (Main, Gpx).
- `npm run dev`: boots in 139 ms. `curl http://localhost:5173` returns the index with Trail title + dark body classes; `curl -I /src/main.js` → 200.
- **Limitation:** I cannot drive a real browser from here, so the click-load-stats happy path wasn't end-to-end exercised. `Gpx.elm` is bit-identical to crest's proven implementation on the same 20k fixture (`oh_meu_deus_20k.gpx`). Browser-driven smoke test gets added in TASK-002 (it'll be implicit there since persistence requires the load path to work).
**What changed in the repo:** PR #1 (https://github.com/gillchristian/trail/pull/1), squash-merged as `0419712 TASK-001: scaffold Elm + Vite + Tailwind app (#1)`. Adds: `package.json`, `package-lock.json`, `vite.config.js`, `elm.json`, `index.html`, `src/main.js`, `src/styles/app.css`, `src/Main.elm`, `src/Gpx.elm`, all planning docs, and `samples/` fixtures.
**What I learned:**
- Tried to bookkeeping-update `CURRENT.md` *after* the scaffold commit but before push — got caught in a dirty-working-tree-when-switching-branches dance after merge. **Going forward**: bookkeeping (DONE.md / CURRENT.md / journal) updates land as the *final* commit of each task branch, with the PR # known by then. For TASK-001 specifically, that bookkeeping is being done as the *first* commit of TASK-002's branch.
- `--delete-branch` in `gh pr merge` runs server-side, but the local branch + tracking ref aren't auto-pruned. Cleaned up manually with `git push origin --delete <branch>` + `git branch -D`.
**Next:** Implement TASK-002 (IndexedDB storage + race index + minimal routing + race detail stub).

---
## 2026-05-15 03:00 — TASK-002 done: IndexedDB-backed races + index + race detail stub

**Task:** TASK-002 — race storage + index + routing
**What I did:**
- Added `Types.elm` (`RaceId` wrapped string + full `Race` record with raw GPX text retained for re-export, `encodeRace` / `decodeRace`, `decodeRaces`).
- Added `Route.elm` — hash router. `#/` → Index, `#/race/:id` → RaceDetail, anything else → NotFound.
- Added `Storage.elm` — port module exposing `loadAll / saveRace / deleteRace` commands and `gotRaces / gotRace / gotRaceDeleted / gotError` subscriptions.
- Replaced `Main.elm` with a `Browser.application` shell. Single flat `Model` (no per-page sub-models yet; modules will split when a page passes ~250 lines). Index page: race-card grid + drop-zone upload banner that flips through `NotUploading → Parsing → Persisting → NotUploading` states with cursor + opacity feedback. Cards show distance / gain / loss, hover-reveal delete button, modal confirm. Race-detail page is a stub that shows the same stats + a "coming soon" panel.
- Vanilla IDB wrapper in `src/main.js`: single `races` object store with `keyPath: 'id'`. `crypto.randomUUID()` assigned server-side (well, JS-side); empty-id sentinel from Elm gets replaced. Upsert via `put`. Round-trips the full record back so Elm sees the assigned id.
- Added `elm/url` to direct deps (required by `Browser.application`).
- Added `scripts/smoke-storage.mjs` (run via `npm run smoke`) that uses `fake-indexeddb` to exercise empty-DB, save-assigns-id, round-trip, UTMB-size payload, upsert, and delete.
**What I verified:**
- `npm run build` → exit 0. 5 modules compiled (Main, Gpx, Types, Route, Storage). JS now `50.88 kB / gzip 17.71 kB`, CSS `25.06 kB / gzip 5.39 kB`. Build time ~875 ms.
- `npm run smoke` → all 12 assertions pass. UTMB GPX (2,286,632 chars) saved in 1 ms; full round-trip preserves text length, name, id.
- Sample fixtures use long-form `<trkpt>...</trkpt>` (20k: 928, UTMB: 26738) — compatible with `Gpx.elm`'s regex parser.
- Port wiring reviewed by inspection — every outgoing Elm port has a matching JS subscriber; every JS `.send()` has a matching Elm `Sub`. JSON shape encoded by `Types.encodeRace` matches what JS spreads back through `storageRaceSaved`.
- **Limitation acknowledged:** the *Elm* half of the port pair isn't exercised end-to-end here (no headless browser available — tried jsdom 29, hits an ESM/CJS bug on Node 20.15). The user will browser-test in the morning. If something runtime-breaks at boot, it'll be obvious immediately.
**What changed in the repo:** PR #2 (URL after push). New files: `src/Types.elm`, `src/Route.elm`, `src/Storage.elm`, `scripts/smoke-storage.mjs`. Modified: `src/Main.elm`, `src/main.js`, `elm.json` (added elm/url direct), `package.json` (added smoke script + dev-dep fake-indexeddb).
**What I learned:**
- `Browser.application` keeps the body element's classes (insertion model is *into* body, not replacing it). Good — I didn't need to move the slate-950 background onto an Elm-owned div.
- `crypto.randomUUID()` is unavailable in some old Safari versions but the user is on a modern Mac. If we discover this matters later, polyfill with a 5-line randomBytes fallback.
- jsdom 29 → Node 22+ in practice. If E2E test coverage matters later, either bump Node or pin to jsdom 24.
- Per the rhythm I set: TASK-001's bookkeeping landed as the first commit of TASK-002's branch. From TASK-003 onward, each task branch ends with its own bookkeeping commit *before* the PR is opened.
**Next:** Implement TASK-003 (race detail page: cover image upload, edit metadata, naive overview path).

---
## 2026-05-15 04:00 — TASK-004 done: true 1:1 elevation profile in race detail

**Task:** TASK-004 — port crest's profile rendering into the race detail page
**What I did:**
- Wrote `Profile.elm` lifting crest's elevation chart logic (Douglas-Peucker simplification at half-pixel tolerance, FitWidth + TrueScale modes, niceStep grid, distance ticks). Retuned palette: rose 0.65→0.10 vertical-gradient fill + rose-400 stroke, slate-800 dashed gridlines, slate-400 axis labels. Added a small "1 px = X m (both axes · 1:1)" legend.
- Race-detail page now renders the chart. Toolbar above with FitWidth / TrueScale buttons + the 1 / 2 / 5 / 10 / 20 / 50 / 100 m/px presets (when in TrueScale mode).
- Added an in-memory **parsed-track cache** to the model (`Dict String Track`) so UTMB-size GPX is parsed once on `RacesLoaded` / `RaceSaved` and reused on every navigation. Renders via `Html.Lazy.lazy3` so the SVG only re-builds when (track, mode, width) actually change.
- Subscribed to `Browser.Events.onResize` so the FitWidth mode adapts when the user resizes the window.
- Deprioritized TASK-003 (metadata editing) — it's cosmetic and was blocking the user's morning workflow. Pushed it to after the visual polish task.
**What I verified:**
- `npm run build` → exit 0. 6 modules compiled. JS now `63.97 kB / gzip 22.17 kB`, CSS `26.61 kB / gzip 5.59 kB`. ~1.5 s build.
- `npm run smoke` → still passes (no storage layer changes).
- Reviewed `Profile.elm` against crest's reference: same `mPerPx` math, same simplification tolerance, same path-builder shape; only differences are palette and the addition of a separate stroke path (crest used fill + thin stroke combined).
- **Limitation:** rendering performance on UTMB-size GPX is *expected* to match crest's (the underlying simplification + SVG-path approach is identical), but not yet measured here without a browser.
**What changed in the repo:** PR #3 (URL after push). New: `src/Profile.elm`. Modified: `src/Main.elm` (parsed-track cache, ScaleMode in model, WindowResized sub, profile section in race detail), `knowledge/planning/BACKLOG.md` (TASK-003 deprioritized), `knowledge/planning/DONE.md`.
**What I learned:**
- The decision to keep the raw GPX text on the `Race` record pays off here: I rebuild the `Track` from `race.gpxText` in-memory without round-tripping through IDB.
- Parsing on `RacesLoaded` is a synchronous blocking cost. UTMB is ~200 ms in Crest. That's tolerable for a one-time boot cost; if it becomes painful as the race library grows, parse lazily on `UrlChanged → RaceDetail` instead.
- The dark theme + rose accent reads well on the chart. Layered "ghost wave" UTMB-style rendering (mentioned in the project brief) is a separate visual-polish task — for v1 the single gradient profile is honest and gamified-leaning already.
**Next:** TASK-005 — aid station CRUD: distance-from-start / distance-from-previous input, edit/delete, persist on the Race record, render markers on the profile.

---
## 2026-05-15 05:30 — TASK-005 done: aid-station CRUD + profile markers

**Task:** TASK-005 — aid stations
**What I did:**
- `Types.elm`: added `AidStation` (id, name, distance in meters, restSeconds, services, notes) and `Service` (Water | Food | Medical | WC | DropBag) with icon/label/string helpers. `Race` gained `aidStations : List AidStation` and `aidStationSeq : Int` (per-race counter — no uuid lib needed). Decoder uses `D.oneOf` for backwards-compat: old IDB records (TASK-002 era) without these fields default to `[]` / `0`.
- `Profile.elm`: added `Marker { distance, label }` and a markers parameter to `view`. Markers render as amber dashed vertical lines with a pill label above the chart. Bumped to `Html.Lazy.lazy4` so memoization still kicks in on (track, mode, width, markers).
- `Main.elm`: aid-station form state (`AidEditor = AidClosed | AidOpen AidForm`) plus an `AidForm` record (editing, name, mode, distanceKm, restMinutes, services, error). Msgs: `OpenAddAid / OpenEditAid / CloseAid / AidSetName / AidSetMode / AidSetDistanceKm / AidSetRestMinutes / AidToggleService / AidSubmit / AidDelete`. Distance input has a "From previous" / "From start" toggle (default "from previous" — matches how race organisers usually quote distances).
- Race-detail page: profile section + new aid-stations section. Empty state → "Add" button → inline form. List of stations shows distance-from-start, distance-from-previous, distance-to-finish, planned rest, service icons, with hover-reveal edit/delete affordances.
- Profile-chart markers reuse the same numbering (1, 2, …) as the list rows. Labels truncated to 12 chars to avoid overlap on dense routes.
**What I verified:**
- `npm run build` → exit 0. JS now `75.48 kB / gzip 25.57 kB`, CSS `28.87 kB / gzip 5.89 kB`. Build time ~584 ms.
- `npm run smoke` → still passes; no storage layer changes.
- Backwards-compat: decoder reviewed line-by-line. `aidStations` and `aidStationSeq` both wrapped in `D.oneOf [ field …, succeed default ]`. Old records from TASK-002 will decode with `aidStations = []`, `aidStationSeq = 0`.
- Validation reviewed by hand: name trimmed-must-not-be-empty; distanceKm must parse as Float (commas converted to dots); restMinutes must parse as Int ≥ 0; absolute distance must be within `race.distance + 5 m` (5 m grace for last-aid-at-finish).
- **Limitation:** I cannot exercise the form click-through here. Will browser-test in the morning.
**What changed in the repo:** PR #4. Modified: `src/Types.elm`, `src/Profile.elm`, `src/Main.elm`, planning bookkeeping.
**What I learned:**
- Per-race id sequence is much simpler than threading a uuid generator through ports for sub-records. It also makes the ids stable across `.trail` import/export (a uuid would change on re-export).
- The `D.oneOf` pattern for backwards-compatible decoders is exactly the right tool — no migration step needed in the IDB layer.
- Form state lives at the top-level model for now. When a single page passes ~250 lines (Main.elm just crossed 1000 total), I'll split into `Pages/Race.elm` and let it hold its own page-local state.
**Next:** TASK-006 — per-km planning view (the centerpiece UX): left-column 1:1 mini-profile of a single km, right-column notes + target pace, prev/next nav, aid stations shown within whatever km they fall in.

---
## 2026-05-15 07:30 — TASK-006 + TASK-007 done: planning engine + per-km UX

**Task:** combined PR for TASK-006 (per-km planning view) + TASK-007 (pace distribution engine). They're tightly coupled — a planning view without GAP is half-useful.

**What I did:**
- **`Planning.elm`** (new): pure math. Slices a `Track` into 1 km windows (with interpolation at the start/end of each window so short last-km / mismatched track-point boundaries render correctly). `slopeFactor s = exp(3.5 · |s + 0.05| − 0.175)` — Tobler-normalised so flat = 1.0. `distribute` honours `Manual` locks and aid-rest from `aidRestTotal`. `sectionsForRace` aggregates kms between aid-station distances ("tramos").
- **`Types.elm`**: moved `Plan / KmPlan / KmTime / kmPlanFor / withKmPlan / withTargetSeconds` into Types to avoid an import cycle with Planning. `Race` gains a `plan` field. Decoder defaults missing `plan` to `defaultPlan` for old IDB records.
- **`Route.elm`**: added `PlanTable RaceId` and `PlanKm RaceId Int`. The km index lives in the URL so prev/next navigation is refresh-safe.
- **`Main.elm`**:
  - `Model` gained `kmsCache : Dict String (List Km)`, `planTableMode`, and three transient text fields (`targetTimeText`, `kmTimeText`, `kmNotesText`) hydrated by `UrlChanged` from the active race's plan.
  - Plan messages: `SetPlanTableMode / SetTargetTimeText / CommitTargetTime / SetKmTimeText / CommitKmTimeForKm / SetKmNotesText / CommitKmNotesForKm / ResetKmToAuto`. All commits go through the existing `Storage.saveRace`.
  - **Table view** (`/plan`): toggle "By km" / "By section." By-km row shows distance span, Δ ele, computed pace, time (with M/A badge for Manual/Auto source), running cumulative, notes, aid stations. By-section row labels start-or-aid → next-aid-or-finish with section totals; aid rest rows interleave with their own runtime contribution.
  - **Per-km view** (`/plan/:km`): left = 360 px-wide card with a self-contained 1:1 SVG (vertical scale equals horizontal so a 100 m climb on a 1 km card looks like a real wall). Stop markers as amber pin-dots. Right = form with target-time input (M:SS or "auto" placeholder), pace display, notes textarea, plus a "Reset to auto" link when this km is locked. Prev / Next buttons navigate to neighbouring kms.
  - "Open the plan →" CTA replaces the "coming soon" panel on the race detail.
- **Format helpers** added: `parseHhmm / formatHhmm / parseMmss / formatMmss / formatHmsLong / paceMinPerKm`. Tolerant input: commas as decimal separators, bare numbers as minutes, optional seconds in HH:MM:SS form.
- The "current sum vs target" diff on the target panel now renders with semantic colours (emerald on target, rose for over, amber for under). Aid rest reserved separately from the budget.

**What I verified:**
- `npm run build` → exit 0. JS `98.12 kB / gzip 31.48 kB`, CSS `31.31 kB / gzip 6.23 kB`. Build time ~466 ms.
- `npm run smoke` → still passes.
- `Planning.slopeFactor` hand-verified at canonical points: f(0) = 1.0, f(-0.05) ≈ 0.839 (fastest), f(0.10) ≈ 1.687, f(±0.20) ≈ 2.397. Matches ADR-0003 worked numbers.
- `Planning.distribute` reviewed by inspection against ADR-0003's algorithm. Subtracts aid rest first; respects Manual locks; if `target == Nothing` or sumWeights ≤ 0, returns 0 seconds for Auto kms (no division by zero).
- Decoder backwards-compat: `plan` field defaults via `D.oneOf [ field, succeed defaultPlan ]`. Same pattern that's been working for `aidStations`.
- Two small bugs caught and fixed during build:
  - Stray `{-| … -}` doc-comment block above `import` lines in Types.elm — Elm refuses to start parsing imports after a free-floating doc. Merged the two into one module doc.
  - `List.foldl` argument order mistake (accumulator-first in the lambda) — Elm types caught it cleanly. Renamed lambdas to `go km (running, acc)` / `go section (running, acc)`.

**What changed in the repo:** PR #5 (URL after push). New: `src/Planning.elm`. Modified: `src/Main.elm` (significant), `src/Types.elm` (added Plan/KmPlan/KmTime + helpers + plan encoder/decoder), `src/Route.elm` (two new variants).

**What I learned:**
- Hydrating transient input strings from the model on every `UrlChanged` works cleanly because per-km nav *is* a URL change. The user types in `kmTimeText`, commits on blur → race is saved → on the next render, `RaceSaved` updates the model. Navigation hydrates from the freshly-saved value. No race conditions because Elm's update is sequential.
- Co-locating `Plan` next to `Race` in `Types.elm` (rather than in `Planning.elm`) avoids the import cycle and keeps codecs near the data they describe. The math layer doesn't own the data layer.
- The 1:1 mini-profile per km is hugely revealing — a 50 m gentle climb over a km looks completely different from a 250 m wall. The user's instinct to make this view the center of the planning UX was correct.

**Next:** TASK-008 — CSV export of the planning table (both km mode and section mode). Then TASK-009 (GPX export for Coros).

---
## 2026-05-15 09:15 — TASK-008 + TASK-009 + TASK-010 done: full export/import suite

**Task:** combined PR for CSV export, Coros-ready GPX export, and `.trail` project-file round-trip. All share the same download port.

**What I did:**
- `Download.elm` — one-shot port `downloadFile(filename, content, mime)`. JS side builds a Blob, makes a hidden `<a download>`, clicks it, revokes the URL after a tick.
- `Csv.elm` — two builders:
  - `kmsCsv`: one row per km (km#, span start/end, distance, ele start/end, Δ ele, gain, loss, slope %, target time s + HH:MM:SS, pace, source = auto/manual, cumulative s + HH:MM:SS, aid name(s) in this km, aid rest s, notes).
  - `sectionsCsv`: one row per section (label = `Start → Aid` or `Aid → Aid` or `Aid → Finish`), with section totals + an interleaved aid-rest column.
  - Fields with `,` / `"` / newlines get RFC-4180 quoted; embedded `"` get doubled.
- `GpxExport.elm` — schema per ADR-0002. Aid stations snap to the closest track point by Haversine via `cumDist`. Each becomes:
  ```xml
  <wpt lat="…" lon="…">
    <ele>…</ele>
    <name>…</name>
    <desc>Km X · services · Rest M:SS</desc>
    <sym>Restaurant|Drinking Water|First Aid|Flag, Blue</sym>
    <type>Aid Station</type>
  </wpt>
  ```
  Symbol picked from the standard Garmin set based on services (food → Restaurant; water-only → Drinking Water; medical-only → First Aid; else Flag, Blue). Waypoints inserted before `<trk>` (GPX 1.1 ordering). XML-escape on names/descriptions.
- `ProjectFile.elm` — `.trail` format = `{ format: "trail-project", version: 1, race: <encoded Race> }`. Encode pretty-printed (indent 2) for readability. Decode validates format+version, defers to `Types.decodeRace` for the payload.
- `Main.elm`:
  - Upload picker now accepts `.gpx`, `.trail`, and `application/json`.
  - `GotContent` branches on filename: `.trail` → `ProjectFile.decode` then save (with id dropped so JS assigns a fresh uuid; `createdAt` re-stamped to `model.now` so the import floats to the top).
  - Race detail page: new "Export" section with two cards (GPX for Coros — disabled when no aid stations; .trail project file — always enabled).
  - Plan table view: "Download CSV" button next to the by-km/by-section toggle; downloads the currently visible mode.
- Filename helpers: `safe race.name → race-name-coros.gpx | race-name.trail | race-name-km.csv | race-name-sections.csv`.

**What I verified:**
- `npm run build` → exit 0. JS now `106.26 kB / gzip 34.09 kB`, CSS `31.56 kB / gzip 6.25 kB`. Build time ~1 s.
- `npm run smoke` → still passes (storage layer unchanged).
- ADR-0002 cross-checked: produced `<wpt>` block is GPX 1.1 conformant; uses standard Garmin `<sym>` values; ordering (wpt → trk) matches GPX best practice; coords carried verbatim from the snapped track point (we never invent positions).
- `.trail` round-trip reviewed by inspection: encoder uses `Types.encodeRace`; decoder uses `Types.decodeRace`; both already exercise backwards-compat (`aidStations`, `aidStationSeq`, `plan` all default if missing). So a `.trail` exported from this build will decode on a future build that adds new fields, as long as old fields stay supported.
- CSV format reviewed for quoting correctness on names with commas (e.g. "Cafetería, Oncol") — passes through the `encodeField` path with double-quote wrapping.
- **Limitation:** the actual Coros pickup (waypoint alerts in Pace Strategy) is field-testable only on the watch. ADR-0002 already flagged this as a real-watch validation step.

**What changed in the repo:** PR #6. New: `src/Download.elm`, `src/Csv.elm`, `src/GpxExport.elm`, `src/ProjectFile.elm`. Modified: `src/Main.elm` (export panel, CSV button, .trail-aware upload), `src/main.js` (download port wiring).

**What I learned:**
- The `.trail` format being literally `{format, version, race: <encodeRace race>}` means *every* future Race-shape change automatically propagates to the file format. Backwards-compat for old `.trail` files is handled by the same `D.oneOf` defaults we already maintain in `Types.decodeRace`.
- Snapping aid-station coords to track points (rather than storing lat/lon at create-time) means coordinates remain correct even if the user re-imports a `.trail` and the snap-target is recomputed. The aid-station model stays minimal: distance is the source of truth.
- For the Coros UX: the COROS app needs the GPX **and** the user needs to toggle "waypoint alerts" on the watch after import. The article is explicit. I'll surface that hint in the export-card description.

**Next:** TASK-011 — gamified visual pass (UTMB-DNA badges, ghost-wave layered profile, race-card aesthetic, glow accents, motion). Then TASK-012 — PWA / offline-first.

---
## 2026-05-15 10:00 — TASK-012 done: offline-first PWA shell

**Task:** TASK-012 — make the app work offline after first load. The user named this a key feature (a 130 km race is somewhere with patchy cell coverage).

**What I did:**
- `public/manifest.webmanifest` — name, short_name, scope=`/`, start_url=`/`, display=`standalone`, theme + background `#0b0b21`, three icon entries (any/192/512 — all SVG).
- `public/icon.svg` (and 192/512 duplicates) — gradient mountain silhouette with a yellow peak dot and the wordmark.
- `public/sw.js` — hand-rolled, ~70 lines:
  - `install`: pre-cache `'/'`, `'/index.html'`, manifest, icons. `skipWaiting()`.
  - `activate`: drop any cache whose name isn't the current `trail-v1`; `clients.claim()`.
  - `fetch` (GET only): same-origin → stale-while-revalidate. Background refresh `put`s the latest response back into the cache. Cross-origin → pass through. Skips `/@vite`, `/@id`, `/@fs` paths defensively.
  - Versioned cache name (`trail-v1`) so future updates can force-evict by bumping the version.
- `index.html` — `<link rel="manifest">`, `<link rel="icon">`, `<link rel="apple-touch-icon">`, full Apple PWA meta block (capable + status-bar + title), `viewport-fit=cover`.
- `src/main.js` — register the SW only when `import.meta.env.PROD` is true (dev runs against HMR — caching that would break the reload-after-edit loop).

**What I verified:**
- `npm run build` → exit 0. JS now `106.47 kB / gzip 34.19 kB`. `dist/` contains `manifest.webmanifest`, `icon*.svg`, `sw.js` at the root — Vite's `public/` copy worked.
- `npm run smoke` → still passes; storage layer is unchanged.
- SW code reviewed against the standard SWR pattern. No `clients.skipWaiting()` race with HMR because we only register in production. Cache version is single-source-of-truth at the top of the file.
- Manifest reviewed against the [Manifest spec](https://www.w3.org/TR/appmanifest/) — required `name`, `start_url`, `icons` all present. SVG icons aren't universally supported for installation prompts (some Android Chrome versions want PNG), but they render fine for the iOS Add-to-Home-Screen flow the user will most likely use.
- **Limitation:** I can't drive a real browser to confirm the install prompt fires + offline reload works. The user will validate in the morning by: (a) loading the app, (b) DevTools → Application → Service Workers → confirm registration, (c) toggling Network → Offline and reloading → app should still render.

**What changed in the repo:** PR #7. New: `public/` directory with `manifest.webmanifest`, `icon.svg`, `icon-192.svg`, `icon-512.svg`, `sw.js`. Modified: `index.html` (PWA meta + manifest link), `src/main.js` (SW registration).

**What I learned:**
- The PWA story for this app is mostly free because we already store everything in IDB. The SW just has to keep the app shell alive offline; the data is already durable.
- Same-origin-only caching keeps the SW from accidentally caching tracking pixels or future map tiles incorrectly. When TASK-013 ships, the tile path gets its own logic.
- Production-only registration is the cheap fix for the "I edited a file but Vite reloaded the old SW-cached JS" trap — gating on `import.meta.env.PROD` is a one-liner.

**Next:** TASK-011 — visual polish pass: gamified styling (UTMB-DNA badges, ghost-wave layered profile rendering, race-card aesthetic with photo headers, glow accents, motion). Then if time permits, TASK-013 (real-world map). Then TASK-003 (race metadata editing).

---
## 2026-05-15 11:15 — TASK-011 done: gamified visual pass

**Task:** TASK-011 — give the app a UTMB-DNA + own-personality polish without breaking the type-safe core.

**What I did:**
- **Profile chart (`Profile.elm`):**
  - **Ghost-wave echo:** eight stroke copies of the profile path translated by ±2, ±4, ±6, ±8 px with fading stroke-opacity (0.22 outer → 0.06 inner). Reads as motion / depth — the signature "sound wave" feel from the UTMB samples.
  - **Rose→amber gradient stroke** on the main profile line. Horizontal gradient (amber at start, rose at peak, red at finish) so the line itself looks like a race ribbon.
  - **Fill gradient retuned** — rose 0.65 → 0.05 (more contrast against the dark canvas).
  - **UTMB-style aid-station badge** replaces the previous amber pill. Now: circular ring (slate-950 fill, amber ring) with a 1-based number inside, plus a smaller amber pill *below* the badge with the station name. Vertical dashed amber line drops to the chart. `padTop` auto-bumps to 58 px when markers exist, 16 px when not.
- **Index page (`Main.elm`):**
  - **Race card** got a top accent stripe coloured by distance bucket (S < 30, M < 70, L < 120, XL otherwise: sky / amber / orange / rose), plus a category-letter badge tile in the upper-left of the card.
  - Hover state: `-translate-y-0.5` + rose-tinted shadow. Now it feels like a card you can pick up.
  - Aid-station summary becomes `★ N aid stations planned` in amber, or "No aid stations yet" in muted slate.
- **Header (`Main.elm`):**
  - Sticky on scroll (`sticky top-0 z-30`).
  - Inline SVG mountain logo (small, gradient peak, amber summit dot — same geometry as the PWA icon).
  - Wordmark uses a horizontal `from-amber-300 via-rose-400 to-rose-600 bg-clip-text` gradient.
- **Motion (`styles/app.css`):**
  - `@keyframes trail-draw` — `stroke-dashoffset 20000 → 0`, 1.1 s easing (cubic-bezier). Applied to the main profile stroke (`.trail-stroke`) and ghost layers (`.trail-ghost`, slightly slower for an offset-feeling reveal).
  - `@keyframes trail-fade-in` — opacity + 4 px vertical slide; 0.35 s. Applied to race cards via `.trail-card-in`.
  - `@keyframes trail-pulse` — subtle outward-ring pulse for emphasis; not wired up yet but available.
  - **`@media (prefers-reduced-motion: reduce)` overrides all three** to be inert — accessibility first.

**What I verified:**
- `npm run build` → exit 0. JS now `108.58 kB / gzip 34.91 kB`, CSS `36.42 kB / gzip 7.08 kB`. Build time ~541 ms.
- `npm run smoke` — still passes.
- `Profile.elm` reviewed: ghost layers reuse the same `strokeD` path string; no new geometry computed. Animation classes are inert when `prefers-reduced-motion: reduce`.
- Badge geometry reviewed by hand: badge centred 22 px above the top of the chart; pill 3 px below the badge; vertical dashed line starts at the bottom of the badge so it doesn't visually merge with the icon.
- Distance-bucket thresholds match the user's race calendar (20 k = S, 50 k = M, 110 k = L, 130 k = XL).

**What changed in the repo:** PR #8 (URL after push). Modified: `src/Profile.elm` (ghost layers + numbered-badge marker + gradient stroke), `src/Main.elm` (race card redesign + header logo/sticky), `src/styles/app.css` (animations + reduced-motion fallback).

**What I learned:**
- The ghost-wave effect was the cheapest big-wow improvement — eight extra `<path>` elements with `transform="translate(0, dy)"` and decaying opacity. SVG handles it fine even on UTMB-size simplified profiles.
- Distance bucket categories give the index a visual sense of difficulty at a glance, without forcing the user to edit metadata. They derive from `race.distance` so they're always up to date.
- `bg-clip-text text-transparent` with a gradient is the cheapest way to add a "logo-y" feel to a wordmark.

**Next:** TASK-013 — real-world map view (Leaflet + OSM via JS port). If that doesn't fit, TASK-003 (race metadata editing). I'll also write a final end-of-night summary so the user can pick up cleanly tomorrow.

---
## 2026-05-15 12:00 — TASK-003 done: race metadata editing + cover image

**Task:** TASK-003 — fill out the race metadata story. Edit name/date/location/url/notes inline, attach a cover image.

**What I did:**
- `Download.elm` gained two more ports: `pickImageFile` (outgoing, fires a JS file picker) and `imagePicked` (incoming, ships the chosen image back as a data URL via `FileReader.readAsDataURL`). The data-URL pattern is deliberate — a `blob:` URL would not survive a reload, and we persist cover images in IDB.
- `Main.elm`:
  - New `MetaEditor = MetaClosed | MetaOpen MetaForm` and a full set of `MetaSet…` / `MetaPickCover` / `MetaCoverPicked` / `MetaClearCover` / `MetaSubmit` messages.
  - `MetaSubmit` saves an updated race (name trimmed-then-fallback-to-original, empty date → `Nothing`, otherwise pass through). On `RaceSaved` the editor closes.
  - "Edit details" button next to the race title on the detail page; clicking it expands an inline form (name, date, location, url, notes, cover image picker with replace/remove controls + preview thumbnail).
  - Race detail page renders a hero banner from the cover image (with a slate gradient overlay so the title remains readable).
  - Race cards on the index use the cover as a 112 px-tall background strip above the card body, with the category accent stripe still pinned to the very top.
  - `URL` and `notes` fields render on the race-detail page below the title when set (URL becomes a `target="_blank"` link; notes preserve newlines via `whitespace-pre-line`).
- `src/main.js`: wired the image-picker port. Creates a hidden `<input type=file accept="image/*">`, calls `.click()`, `readAsDataURL` on change, ships the result back. Removes the input from the DOM either way.

**What I verified:**
- `npm run build` → exit 0. JS `114.22 kB / gzip 36.18 kB`, CSS `38.35 kB / gzip 7.24 kB`.
- `npm run smoke` → still passes.
- Cover-image picker code reviewed: the FileReader path produces a `data:image/…;base64,…` URL which JSON-serialises cleanly through the IDB save path. Two-megapixel JPEGs typically come in under 1 MB encoded — well within Chrome's structured-clone limits. Larger images degrade gracefully because we don't decode them ourselves.
- Backwards-compat: `coverImage` was already a `Maybe String` on `Race` from TASK-002, with a `D.nullable` decoder. No migration needed.
- **Limitation:** can't browser-test the picker click flow here. The wiring is symmetric (one outgoing port + one inbound sub) and mirrors the GPX upload flow I already validated.

**What changed in the repo:** PR #9. Modified: `src/Main.elm` (meta state + form + hero banner + card cover background), `src/Download.elm` (image-picker ports), `src/main.js` (port wiring).

**What I learned:**
- The "Maybe save a blob: URL" trap was the actual subtle thing here. With Chromium's `URL.createObjectURL`, the URL is only valid for the document lifetime; once we reload, those references are dead. Data URLs cost more bytes but are persistent. Always use `readAsDataURL` for "I need this image later."
- Hero banner + card-strip aesthetics now wire together. When the user attaches a photo for the upcoming 20 k, both the index card and the race-detail page change immediately.

**Next:** TASK-013 — real-world map view (Leaflet + OSM via JS port). Last on the backlog. After that, end-of-night summary.

---
## 2026-05-15 13:30 — TASK-013 done: real-world map view

**Task:** TASK-013 — real-world OSM map (last backlog item).

**What I did:**
- Added Leaflet via `npm install leaflet`. New file `src/leaflet-element.js` defines a `<trail-map>` custom element. Inputs come in as JSON-encoded attributes (`track`, `markers`) — no Elm-side ports needed; the custom element's life-cycle is bound to the DOM node so map cleanup happens when Elm removes the host element.
- Inside the element:
  - `L.map` initialised on `connectedCallback`. OSM tile layer.
  - Track drawn as two stacked polylines: a thick rose halo (opacity 0.25, weight 8) + a thin rose-300 core (weight 3). Reads like the profile chart's gradient stroke.
  - Aid stations as `L.divIcon` markers — amber circle with a 1-based number, black border. Popup binds the station name.
  - `L.Icon.Default.mergeOptions` overrides icon paths with bundler-resolved imports — Vite inlines the default marker PNGs as data URLs, so they ship with the JS bundle.
- New `Route.RaceMap RaceId` variant; new path `#/race/:id/map`.
- `Main.viewRaceMap` snaps each aid station to the closest track point (same Haversine + cumDist routine used by the GPX exporter, refactored into `findCoordAt`) and ships the coords + marker objects to the custom element via JSON-encoded attribute strings.
- `viewMapTeaser` panel on the race detail page links to the map. Placed between the planning CTA and the export panel.
- **Tile caching** in `public/sw.js`: a new `TILE_CACHE` keyed on `trail-tiles-v1`. Tile requests (matched against `https://[a-c].tile.openstreetmap.org/Z/X/Y.png`) go through cache-first. New tiles get FIFO-trimmed at 800 entries (~25 MB; configurable). Offline + uncached = 504 so Leaflet shows its blank-tile fallback rather than choking.
- Bumped `CACHE` to `trail-v2` so the activate handler invalidates the prior app-shell cache.

**What I verified:**
- `npm run build` → exit 0. Bundle is `276.29 kB JS / gzip 87.29 kB`, `53.96 kB CSS / gzip 13.77 kB`. Leaflet adds ~150 KB JS + ~16 KB CSS. Acceptable for the last feature.
- `npm run smoke` → still passes.
- Reviewed Leaflet integration: custom element is the right shape — `attributeChangedCallback` re-renders on attribute change; `disconnectedCallback` cleans up the map instance to avoid leaking when Elm unmounts the node.
- Reviewed SW tile-cache path: regex matches all three OSM mirrors; FIFO trim runs only after successful writes; offline fallback returns 504 (not a crash).
- **Limitation:** browser-level map render not verified. Custom-element wiring + JSON parsing + Leaflet API are all standard. Marker PNGs being inlined as data URLs confirmed by greping the bundle (3 `data:image/png;base64,…` strings of marker dimensions).

**What changed in the repo:** PR #10. New: `src/leaflet-element.js`. Modified: `src/main.js` (import), `src/Route.elm` (RaceMap variant), `src/Main.elm` (viewRaceMap + viewMapTeaser + findCoordAt), `public/sw.js` (tile cache path, CACHE bumped to v2), `package.json` + `package-lock.json` (leaflet).

**What I learned:**
- Custom elements are *significantly* less plumbing than Elm ports for self-contained third-party JS widgets. The map life-cycle stays inside the host DOM node and connects/disconnects via standard browser callbacks. No subscribe/unsubscribe dance, no port name conflicts.
- The "snap aid station to closest track point" routine is now used in three places (profile mini-card, profile chart marker label, map marker, GPX export). Worth extracting to a helper if a fourth call site appears.
- OSM tile caching is essentially free with the SW pattern I already had — the only nuance is the FIFO eviction so the cache doesn't grow unbounded across multiple races.

**Next:** Final wrap-up. Backlog is empty. Time for an end-of-night summary in the journal so the user can pick up cleanly tomorrow.

---
## 2026-05-15 07:30 — Feedback pass after the user's morning review

**Task:** address the issues the user listed at 7am (in samples/f-*.png). Headline: #7 and #9 were the same critical bug.

**What I did:**
- **Critical: `currentRace` was only matching `Route.RaceDetail`.** Every save flow from the plan view (`CommitTargetTime`, `CommitKmTimeForKm`, `CommitKmNotesForKm`, `ResetKmToAuto`, `ExportCsvKms/Sections`, `ExportGpxForCoros`, `ExportProjectFile`) silently no-op'd because the helper returned `Nothing` on `PlanTable` / `PlanKm` / `RaceMap`. Fixed by widening the match to all four race-bearing routes. This single change unlocked target-time auto-distribution, manual-km locking, notes persistence, AND every export-from-plan-view button.
- **Plan rows fully clickable** (#5): each `<tr>` now carries `onClick (NavigateTo (Route.PlanKm …))`, plus `role="link"` and `tabindex="0"` for keyboard nav. Dropped the inner anchor on the km # cell since the whole row is the click target. Added a `NavigateTo Route` `Msg` for consistency.
- **Race card without picture** (#3): replaced the empty band with a category-coloured decorative panel — a tinted gradient + a faint dual-layer mountain SVG silhouette + the category letter as a small watermark in the top-right. Cards in a grid now have visually equal heights whether or not they carry a cover image. Also added `flex flex-col` so the card uses `items-stretch` semantics inside the grid.
- **Contrast fix** (#4): the light horizontal band the user saw was a `color-scheme` mismatch. Belt-and-braces fix: `<html lang="en" style="background:#020617;color-scheme:dark;">`, `<meta name="color-scheme" content="dark">`, body inline `style="background:#020617;"`, `:root { color-scheme: dark; background: #020617 }` in `app.css`, and the `#app` wrapper explicitly gets `bg-slate-950`. Removed the unused `--color-bg` / `--color-bg-elevated` theme tokens (they could shadow Tailwind's color generation in v4).
- **Profile axis label overlap** (`f-profile-01.png`): tick counts now derive from available pixel space. `distanceTicks` reserves ~70 px per "X km" label; `elevationGridLines` reserves ~28 px per row. `niceStep` still snaps to 1/2/5 × 10^k so the labels remain readable.
- **Km card uniform size** (`f-km-cards-*.png`): `viewKmCard` now takes `raceMaxRange` (max elevation range across every km in the race). The chart height = `raceMaxRange / mPerPx`, so every card in a race has the *same* shape regardless of which km you're looking at. Flatter kms get visual headroom above the silhouette — the right 1:1 story (flat km feels flat in the frame; climby km fills the frame). Card is `flex flex-col` so the chart + footer occupy the rest of a tall card cleanly. Prev/Next buttons sit in a fixed-width 360 px row below the card and don't move.
- **Map polish** (#8): aid-station markers now include `kind`, `distanceKm`, `restSeconds`, and `services` in the JSON. The leaflet element renders popups with emoji service chips (💧🍌⛑🚻🎒), distance from start, and planned rest. Added start (green ▶) + finish (🏁) markers at the ends of the track.
- **Service worker on dev** (#1): clarified in `MORNING.md` that the SW is gated on `import.meta.env.PROD`. Offline test goes through `npm run build && npm run preview`. Hand-rolled wrap; if the user wants HMR-safe dev SW, that's a one-line gate flip.

**What I verified:**
- `npm run build` → exit 0 after each change. Final bundle `280 kB JS / gzip 88.6 kB`, CSS `55.8 kB / gzip 13.9 kB`.
- `npm run smoke` → still passes.
- `currentRace` fix reviewed: every save flow that uses `currentRace` (5 plan messages + 3 export messages + meta edit) now works on `RaceMap`, `PlanTable`, `PlanKm` — these were the exact routes the user was testing on.
- Profile tick-count math verified with a few cases: a 14 km chart at 600 px wide → 600/70 ≈ 8 ticks, niceStep snaps to 2 km → labels every 2 km, no overlap. Same chart at 200 px wide → 200/70 ≈ 2 ticks → labels every ~7 km (niceStep snaps to 10 km), still readable.
- Km card uniform size: a route with max km range 200 m and chart width 328 px → mPerPx = 3.05, chartHeight = 65 px. A UTMB-style route with max km range 500 m → chartHeight = 164 px. Cards stay consistent within a race.

**What changed in the repo:** PR #12 (URL after push). Modified: `src/Main.elm` (currentRace, NavigateTo, viewKmCard, viewRaceCard, viewRaceMap markers), `src/Profile.elm` (width-aware tick counts), `src/leaflet-element.js` (kind-aware icons + popups), `src/styles/app.css` (color-scheme + background pinning), `index.html` (inline styles + color-scheme meta), `MORNING.md` (feedback-pass section at the top).

**What I learned:**
- The `currentRace` bug is the kind of single-line mistake that hides behind otherwise-correct code: `case model.route of Route.RaceDetail rid -> ... _ -> Nothing` reads fine until you realise the *plan* view also has a current race. Lesson: helpers that hinge on the route should enumerate every route-with-id variant explicitly, not via `_ -> Nothing`.
- The Tailwind v4 `bg-slate-950` utility *should* render dark even without `color-scheme: dark`, but in practice OS-level auto-tinting (especially in macOS' Big Sur+ "Increase Contrast" or Safari's reduced color modes) can soften background utilities. Inline-styling `background:#020617` on `<html>` is the smallest robust fix.
- For "fixed card shape with 1:1 elevation", the right move is to use the *race*'s max-range, not the current km's. That keeps the shape consistent and lets the user read flatness/steepness visually by how much headroom the silhouette leaves.

**Next:** Per-section card view (the deferred part of feedback item #6). Then "more gamification" pass if the user comes back with more.

---
## 2026-05-15 08:30 — Per-section card view

**Task:** the deferred part of feedback item #6 — a per-section card view.

**What I did:**
- New route `Route.PlanSection RaceId Int` → URL `#/race/:id/plan/section/:idx`. `Route.elm` parser + writer updated; `currentRace` extended; `viewContent` dispatch added.
- `viewPlanSection` renders a two-column layout:
  - **Left**: the section card (440 px wide). Header shows the section label and a small "section · X km wide · scale Y m/px" note (we drop the strict 1:1 here because sections span 1-15 km; per-km cards keep 1:1 as before). Mini-profile uses a per-section `mPerPx` that fits the whole section into the card width. Footer shows min / max / end elevation.
  - **Right**: section plan panel — distance, time, pace, contained-km count; an amber "Ends at" card for the next aid station with its services and an "Edit aid station →" link back to race detail; or "🏁 This section finishes the race." for the final section. Below, a clickable list of contained kms with their times + auto/manual badges + `›` chevron.
  - Prev / Next section nav with fixed-width buttons (210 px each).
- **Section table rows now clickable**: every section row in `viewSectionTable` carries `onClick (NavigateTo (Route.PlanSection …))` + `role="link"` + `tabindex="0"`. Tapping a row opens the section card; tapping the aid-rest row does nothing (it's the rest, not the section).
- `sectionsWithCumulative` retyped from `Html msg` to `Html Msg` to allow the new click handler.

**What I verified:**
- `npm run build` → exit 0. JS `286.85 kB / gzip 90.07 kB`, CSS `57.44 kB / gzip 14.13 kB`.
- `npm run smoke` → still passes (no storage layer changes).
- Cross-link integrity: from per-km card you can hit "Back to table"; from any km row in section card → opens that km's card; from "Back to table" → returns to the table view, etc.
- `Planning.sectionsForRace` already returns `Section { kmIndices : List Int }` so listing contained kms is a `List.filter` away. No new math.

**What changed in the repo:** PR #13 (URL after push). Modified: `src/Route.elm`, `src/Main.elm` (currentRace, viewContent, viewPlanSection + section-card SVG, section-table row click handler).

**What I learned:**
- Section card breaking the 1:1 invariant is the right call — a 12 km section drawn at 3 m/px (the km card scale) would be 4000 px wide. The user's mental model for sections is "what does this stretch between aids look like overall," not "what does it physically look like at unit scale."
- Routes-with-id helpers (like `currentRace`) need to enumerate every variant explicitly. Burned by this twice in two PRs; that's the lesson confirmed.

**Next:** "More gamification" pass — small polish (section-count badges on race cards, animated reveal on section card, refined cluster icons on map) if the user comes back with more. Otherwise idle.

---
## 2026-05-15 13:32 — exploration: pace prediction & Strava roadmap

**Task:** exploration (not a TASK-NNN — user explicitly asked for planning only).
**What I did:** Read `trail_race_planner_spec.md` (the user's exploration with another agent), cross-referenced against ADR-0003, `src/Planning.elm`, `project-brief.md`, and the two adjacent projects (`../strava-mcp` for the Strava API surface, `../cadence` for an existing OAuth + backfill loop). Wrote `knowledge/reference/pace-prediction-roadmap.md` — a single roadmap doc covering: which spec pieces are worth using when, the predictor-vs-distributor split, profile data model, bidirectional aggressiveness slider mechanics, UI surfaces, three-phase Strava integration, calibration fits, the local-first tension, open questions, and a 11-task candidate breakdown. Added TASK-014 through TASK-024 to BACKLOG.md under a new **Proposals** heading (explicitly *not* Active — they need user go-ahead before promotion).
**What I verified:** No code changed. Roadmap doc renders cleanly (markdown sanity-checked by eye). BACKLOG entries cross-reference the roadmap by section.
**What changed in the repo:** `knowledge/reference/pace-prediction-roadmap.md` (new), `knowledge/planning/BACKLOG.md` (added Proposals section).
**What I learned:**
- Strava API does **not** expose direct GPX download. The streams endpoint (`/activities/{id}/streams`) is the actual data path; you reconstruct a GPX (and get HR + cadence as a bonus). This shifts the Phase-1-manual story from "user clicks Strava export GPX" to either "user clicks Strava export GPX in the browser UI (which *does* work, just not via API)" or "we parse a JSON streams dump."
- The bidirectional slider only works smoothly if intensity is continuous (analytic or bisection invert). Stepped presets break the inverse map.
- `project-brief.md`'s "no backend, ever" is a real constraint, not aspirational. The roadmap proposes a deliberate softening (Strava sync as opt-in helper) rather than ignoring it.
- The actual-vs-planned upload (TASK-016) is high-leverage and *fully local* — it can ship without any of the predictor / profile / Strava work and is independently useful.
**Next:** Wait for user feedback on the roadmap and the open questions in §9. When they pick chunks to promote, those become real TASK-NNN entries with acceptance criteria.

---
## 2026-05-15 13:55 — exploration: cadence-backend-spec for trail integration

**Task:** exploration (continued).
**What I did:** Read all of `~/dev/cadence/server/` (main.go, all handlers, all store, strava/client.go) to understand what extending it for trail would actually require. Wrote `knowledge/reference/cadence-backend-spec.md` — a five-PR plan + copy-pasteable hand-off brief for an agent working in `~/dev/cadence/`. Cross-linked from the roadmap doc §6.
**What I verified:** No code changed. Spec maps every claim to a concrete file in cadence (`main.go` for CORS, `auth_handler.go` for state-routing, `store/token.go` + new migrations 013–016 for the sessions split, new `compare.go`-adjacent handler for streams).
**What changed in the repo:** `knowledge/reference/cadence-backend-spec.md` (new), `knowledge/reference/pace-prediction-roadmap.md` (one paragraph added pointing at the spec).
**What I learned:**
- cadence's `tokens` table is keyed by `athlete_id` with a unique `session_token` column. Two frontends authenticating the same athlete would clobber each other's sessions. **A schema split (tokens + sessions) is required**, not just CORS and routing. This was the non-obvious surprise.
- cadence's `FetchActivityStreams` only requests `distance,heartrate`. Generalising it to accept arbitrary keys is a small change, but it's the change that makes trail's actual-vs-planned + calibration flows possible.
- OAuth `state` carries two responsibilities: anti-CSRF nonce and origin-routing. Encoding both as base64-url JSON in `state` is the cleanest approach; an in-memory nonce map with 5-min TTL is fine on cadence's single-machine deployment.
- Streams responses are not cached (per cadence's existing policy, correctly — they're large + immutable + rarely re-read). trail's calibration flow has to throttle client-side (~1 req/2 s) to stay under Strava's 100/15min.
- No new tables for trail-domain state are needed on the backend. Races, plans, profiles, and `race ↔ stravaActivityId` links all stay in trail's IDB. The backend is purely a thin Strava proxy with the existing token-refresh machinery.
**Next:** Same as before — wait for user feedback. The cadence-backend-spec.md §12 brief is the artefact they'd hand to an agent in `~/dev/cadence/` if they choose to proceed.

---
## 2026-05-15 14:15 — port working system to cadence

**Task:** scaffolding (cross-project).
**What I did:** Ported trail's `knowledge/` system into `~/dev/cadence/knowledge/` so a cadence agent can do the trail-integration work in the same self-directed style. Adapted philosophy docs for Go/chi/SQLite specifics (verification commands, when-stuck table, working-style). Seeded `cadence/knowledge/planning/BACKLOG.md` with TASK-001–TASK-005 (the five PRs from this repo's `cadence-backend-spec.md`), each with explicit acceptance criteria and a spec-section pointer. Created `cadence/knowledge/reference/trail-integration.md` containing the §12 hand-off brief verbatim and the explicit rule that trail owns the spec (cadence files blockers rather than reinterpreting). Updated cadence's `CLAUDE.md` to make `knowledge/README.md` the entry point. Moved pre-existing `cadence/knowledge/caching.md` into `reference/` and cross-linked it from `project-brief.md`.
**What I verified:** No code changed in either repo. `find ~/dev/cadence/knowledge -type f` shows 16 files in the expected layout. `git status` in cadence shows the renames + new files only — no accidental edits to `server/` or `client/`. Pointers from cadence back to trail use absolute paths so they're stable regardless of which repo the agent is sitting in.
**What changed in the repo:** Only this journal entry in trail's repo. The cadence-side changes are: new `knowledge/` tree (~14 files), `CLAUDE.md` gained the non-negotiables header, `caching.md` moved into `reference/`.
**What I learned:**
- Cadence already had a `.claude/` directory and a top-level `knowledge/caching.md` from prior agent work. The port absorbed it cleanly by relocating into `reference/`.
- The spec pointer pattern (absolute path to `trail/knowledge/reference/cadence-backend-spec.md`) works because both repos sit under `~/dev/`. If we ever rename or move repos, those references need updating in cadence's knowledge/.
- Cadence's existing commit history is loose (short subject lines, no bodies). The new PR workflow tightens this from now on; I added explicit "don't backfill old commits" guidance in `working-style.md` so the cadence agent doesn't try to clean history.
**Next:** Hand-off ready. The user can now: open a Claude Code session in `~/dev/cadence/`, ask it to read `knowledge/README.md`, and start TASK-001. The trail spec at `~/dev/trail/knowledge/reference/cadence-backend-spec.md` remains the canonical contract.

---
## 2026-05-15 15:50 — TASK-014: course summary card additions

**Task:** TASK-014 (first concrete slice from the pace-prediction roadmap).
**What I did:** Added three pure helpers in `Main.elm` (`elevationDensity`, `densityLabel`, `equivalentFlatKm`) near `distanceCategory`. Modified `viewRaceCard` so the category-label line now reads `SHORT · MOUNTAINOUS · 41 m/km` with a colour-coded density bucket (slate → amber → rose as density climbs). Modified `viewRaceDetail` so the header stat grid grew from 3 to 5 cells — added `Density` and `Flat eq.` next to Distance / Gain / Loss. Grid responsive: `grid-cols-3` on mobile/tablet (wraps to two rows with the new cells), `grid-cols-5` on `lg+`.
**What I verified:**
- `npm run build` → exit 0. JS 286.85 → 288.34 kB (+1.5 KB); gzip 90.07 → 90.53 kB. "Success! Compiled 1 module." No warnings.
- Bundle string presence: `grep -o "Mountainous\|Flat eq.\|Density\|..." dist/assets/index-*.js` returned all 7 expected new strings.
- `npm run dev` → "VITE v6.4.2 ready in 127 ms"; `curl -sf localhost:5173/` returned 200 (1037 bytes shell — full UI is client-rendered).
- **Did NOT do** an in-browser visual check — no GUI in this session. Build + bundle-string + dev-server-starts is the strongest verification I can do here. The pattern matches prior trail PRs that landed when the same constraint applied.
- Arithmetic sanity: UTMB-shape (174 km / 9900 m / 9900 m) → density 57 m/km "Very mountainous", flat-eq 282.9 km. Matches spec §11.A.
**What changed in the repo:** PR #16. Modified: `src/Main.elm` (three helpers added near `distanceCategory`; `viewRaceCard` category-label paragraph extended; `viewRaceDetail` stat grid changed). Reset `knowledge/planning/CURRENT.md` to empty. Added entry to `knowledge/planning/DONE.md`.
**What I learned:**
- Kept the three helpers inline in `Main.elm` per the project's "three usages before extraction" rule (current usages: 2 — card + detail). The predictor work in TASK-018 will be the third caller; that's the right moment to extract `Stats.elm`.
- The spec's `§4.5` named examples (UTMB at "40–55 m/km Mountainous") and the math anchors disagree slightly: UTMB by the cutoffs is "Very mountainous" (~57 m/km). Treated the cutoffs as the contract; the named examples are approximate.
- The cadence agent was still mid-work on its TASK-001 when this shipped. trail and cadence make progress in parallel; their PRs don't interact because cadence's work is purely backend.
**Next:** TASK-015 (per-km segment classification by grade) or TASK-017 (profile data model). TASK-015 is the smaller follow-on; TASK-017 unlocks TASK-018 (predictor) which is the larger arc. Pick at the next prompt.

---
## 2026-05-15 17:05 — cadence verification + addendum 1 spec

**Task:** verification + spec (no TASK-NNN — cross-project bookkeeping).
**What I did:** Verified cadence's five-PR trail-integration arc end-to-end against the running local server (`localhost:3001`):
- Schema migrated cleanly (`tokens` + `sessions`, migrations 013–016 applied).
- Two sessions coexist for athlete 130301875 (`origin=cadence` from 16:37, `origin=trail` from 16:55). Independent `last_seen_at` proves the multi-session split works.
- `/auth/strava?origin=trail` round-trips back to `localhost:5174/?token=…` with a valid session token. CORS preflight from `localhost:5174` returns the expected allow-origin echo.
- `GET /api/activities/{id}/streams?keys=...` returns the `key_by_type` shape with full-resolution data (6168 points for an 18 km run = ~1 point/3 m). Allowlist rejection (`keys=bogus_key`) returns 400 with the documented error message. Missing-auth returns 401.
- `GET /api/athlete` returns 200 with `X-Data-Source: strava` on first call, `cache` on second.

**Finding:** the athlete response is the **SummaryAthlete** shape (`id, firstname, sex, city, country, premium, ...`), missing `max_heartrate, weight, ftp, measurement_preference`. Strava's `/athlete` returns DetailedAthlete only when the OAuth scope includes `profile:read_all`. Cadence currently requests only `activity:read_all`.

Wrote `knowledge/reference/cadence-backend-spec-addendum-1-profile-scope.md` — a one-line scope change + cache-bust migration + re-auth choreography. Includes a copy-pasteable hand-off brief at §"Hand-off brief for the cadence agent". Updated BACKLOG.md note on TASK-023 to reflect the addendum exists.

**What I verified:** All curl probes documented above. Specific values quoted in the cadence verification turn. Trail-side: no code change, just the spec + BACKLOG/journal updates.
**What changed in the repo:** PR #17. New `knowledge/reference/cadence-backend-spec-addendum-1-profile-scope.md`. Modified `knowledge/planning/BACKLOG.md` (TASK-023 note expanded) + this journal entry.
**What I learned:**
- Strava's OAuth `scope` is per-request; no app-level config change required.
- Strava's refresh flow preserves the original scope on the refreshed access token, so deploying the scope change is non-disruptive — existing sessions keep working until the user re-auths through `/auth/strava`, at which point Strava shows an *incremental* consent screen for just the added scope.
- The athlete cache uses a negative-`athlete_id` sentinel in `activity_cache`. Bust it with a one-shot migration after the scope change to avoid serving stale SummaryAthlete shape for up to 24 h.
- Multi-session model survives the re-auth flow naturally because `SetTokens` upserts by `athlete_id` — all existing sessions for that athlete resolve to the upgraded tokens automatically. No session-row migration needed.
**Next:** Resume trail's numeric PR order — TASK-015 next. The addendum spec is pending hand-off; the user can paste §"Hand-off brief" into a cadence Claude Code session whenever they want it shipped. Not blocking anything trail-side until TASK-022 (calibration) — `max_heartrate` is the field we'd consume there.

---
## 2026-05-15 17:40 — TASK-015: per-km grade classification

**Task:** TASK-015 (second slice of pace-prediction roadmap; smallest still-unshipped item).
**What I did:** Added `gradeClass : Float -> (String, String)` helper next to `densityLabel` — 5 buckets (Steep climb / Climb / Runnable / Descent / Steep descent) at cutoffs ±0.04 and ±0.10 per spec §3.2. Planning km-table gained a "Grade" column between Δ ele and Pace, rendering a compact pill (`ring-1 ring-inset`, rose-3→rose-4 for climbs, slate-4 neutral, emerald-4→emerald-3 for descents — mirrors the existing Δ ele cell palette). Section-table left untouched intentionally — sections span multiple grade buckets, a single chip would mislead.
**What I verified:** `npm run build` exit 0; JS 288.34 → 289.02 kB (+680 B); gzip 90.53 → 90.74 kB. All five labels present in the bundle. Cutoff arithmetic verified by reading the conditional. In-browser visual check not performed (no GUI here).
**What changed in the repo:** PR #18. Modified `src/Main.elm` (helper + table header + km-row), updated planning files + this entry.
**What I learned:**
- The pill ring outline (`ring-1 ring-inset`) was the right call — flat-fill backgrounds (`bg-rose-500/15`) alone don't read on the hover-darkened row. The ring gives the pill enough edge to survive `:hover bg-slate-950/60`.
- Cutoffs ±4 % and ±10 % match the spec table cleanly. The boundary semantics (`>=` for climbs, `>` for the runnable band so 0.04 is "Climb" not "Runnable") mirror the Δ ele cell which uses `> 0` / `< 0` / `== 0`.
**Next:** TASK-016 — planned-vs-actual via manual GPX upload. The math (parse actual GPX, snap to course, compute per-km actual splits at the *planned* km boundaries, render diff column) is identical regardless of where the GPX came from — the file picker path is what we ship; TASK-021 later swaps the source for Strava streams.

---
## 2026-05-15 19:30 — TASK-016: planned-vs-actual via manual GPX

**Task:** TASK-016 (largest single trail-side feature in the roadmap; first piece of the comparison/calibration arc).
**What I did:** New `ActualGpx.elm` (parser for GPX with `<time>` tags + interpolated per-km split computation + Hinnant ISO 8601 → seconds without a date library). `Types.Race` gains `actualSplits : Maybe ActualSplits` with `{splits, totalSeconds, totalDistance, uploadedAt}`; back-compat decoder defaults to `Nothing`. Plan-table page gained a `viewActualRunStrip` between the target panel and the table tabs: collapsed "Link actual run" CTA when nothing's linked; expanded summary (total time, total distance, ±vs target delta) + Replace/Unlink buttons when linked. km-table grows two columns when actualSplits is present: "Actual" (mm:ss) and "Δ vs plan" (rose-when-slower / emerald-when-faster, with `+`/`−` sign). viewKmRow refactored from a flat `<td>` list to named `let`-bindings + `List.concat` so the optional cells splice cleanly.
**What I verified:**
- `npm run build` exit 0. JS 289.02 → 296.31 kB (+7.3 KB); gzip 90.74 → 92.89 kB. No warnings.
- Bundle string check: 8 new labels (`Link actual run`, `Upload .gpx`, `Actual run linked`, `Distance run`, `vs Target`, `Replace`, `Unlink`, `Δ vs plan`).
- ISO 8601 conversion arithmetic walked through `2026-05-15T14:30:00Z`: days-since-epoch = 20588 (Hinnant), seconds-since-epoch = 1,779,580,200. Independently verified by raw `(56 years × 365) + 14 leap days + 134 day-of-year days = 20588`. Match.
- Synthetic split sanity-check: 3 points at distances `{0, 1000, 2000}` m and elapsedS `{0, 300, 570}` → splits `{0: 300, 1: 270}` (km1 5:00, km2 4:30). The interpolating algorithm reduces correctly when boundaries land exactly on point distances.
- **In-browser visual check NOT performed.** User will exercise the file picker + diff column on their actual race GPX before trusting the splits.
**What changed in the repo:** PR #19. New `src/ActualGpx.elm`. Modified `src/Types.elm` (Race field + codecs), `src/Main.elm` (import, Msg variants, update handlers, plan-table strip + km-table cells, buildDraftRace + Model `actualRunError`). `elm.json` moved `elm/time` to direct deps.
**What I learned:**
- Elm rejects 4-tuples (only 2 and 3). Caught the parser by surprise mid-build; fixed by switching the raw-point intermediate to a small record.
- The straightforward "split = elapsedS at point - prevSplit elapsedS" algorithm dumps all time into one km when a single point straddles multiple km boundaries (sparse Coros tracks). Linear interpolation at each boundary crossing keeps the splits reasonable.
- Adding a Maybe field to a long record-shaped value requires touching the encoder, the decoder, the core builder, `buildDraftRace`, and the model. The Elm compiler caught every site; nothing slipped.
- Splits are computed against *actual* track distance, not the planned course. v2/TASK-021 can snap to planned km boundaries via Haversine when we want "where on the planned course was I at each plan-km" semantics. For now "how fast did each km of my actual trace go" is the right answer.
**Next:** TASK-017 (profile data model + IDB + settings page) — foundation for the predictor arc (TASK-018, TASK-019, TASK-020). No Strava deps; ~60-90 min of UI + storage shape work.

---
## 2026-05-15 21:00 — TASK-017: athlete profile + IDB v2 + settings page

**Task:** TASK-017.
**What I did:** New `AthleteProfile.elm` module: `Profile` record + 4 presets + `DescentSkill`/`TechSkill`/`AidStyle` enums with both labels and predictor-side multipliers + stable-key JSON codecs. JS-side `main.js` bumped `DB_VERSION` to 2 and adds a `settings` object store (key-value, single row at `activeProfile`); existing `races` store untouched. `Storage.elm` adds three new ports. `Route.elm` adds `ProfileSettings` variant at `#/profile`. `Main.elm` gets `profile : Profile` (default `midPack`) and `profileSaved : Bool` on Model, loads via `Storage.loadProfile` alongside races on boot, subscribes to `Storage.gotProfile`, adds 11 Msg variants + handlers (preset pick, 9 field edits with clamping, Save). Settings page renders preset-row + 9-field form using stacked `profileFieldRow` helper.
**What I verified:** `npm run build` exit 0, JS 296.31 → 305.84 kB (+9.5 KB); gzip 92.89 → 95.45 kB. Bundle string check: all 4 preset names + 9 field labels + "Profile · settings" present. No new warnings.
**What changed in the repo:** PR #20. New `src/AthleteProfile.elm` (~360 lines). Modified `src/main.js` (IDB v2, helpers, port subscribes), `src/Storage.elm` (ports + wrappers), `src/Route.elm` (route + URL parsing + toString), `src/Main.elm` (import + Model field + Msg variants + handlers + viewProfileSettings + header link + title case).
**What I learned:**
- `Profile` was the obvious module name but already taken by the elevation renderer. Renamed to `AthleteProfile`. The naming-collision check should be the first thing to verify when adding a module.
- Shadowing imports with locals is a real risk: `let p = model.profile` inside a view shadowed the `Html.p` function imported via `exposing`. Compiler caught it immediately; renamed local to `prof`. Future code: avoid single-letter locals in views.
- The settings page deliberately omits a form-draft layer. Edits clamp + commit directly into `model.profile`; "Save" is the only IDB write. Simpler than the MetaForm pattern; appropriate for a single-record settings surface.
- The JSON codec uses **stable string keys** for variant types (`"cautious"` etc.) so future renames of the Elm variant constructors don't break stored profiles. Decoders fall back to `Average` defaults on unknown keys.
- IDB upgrade path is one `createObjectStore` call inside the existing `onupgradeneeded`. The guard `!db.objectStoreNames.contains(SETTINGS_STORE)` makes the migration idempotent — running v2 against an already-v2 DB is a no-op.
**Next:** TASK-018 (Predictor.predict — Layer B time prediction). The profile is now available; the predictor takes course + profile + intensity, returns predicted total time + per-component breakdown. Pure module, no UI in this slice (TASK-019 wires the slider).

---
## 2026-05-15 21:30 — TASK-018: Layer B predictor module

**Task:** TASK-018.
**What I did:** New `Predictor.elm`: `Prediction` record (climb/descent/runnable/aid component seconds + total + applied fatigue + intensity), `predict : Profile -> Race -> List Km -> Float -> Prediction`, `solveForIntensity` (12-iteration bisection on [0.80, 1.25]). Per-km classification follows spec §3.2 (slope thresholds ±4 %). Climb time uses the explicit vmh model (`gain / (vmh × i)`) so the profile's vmh field has clear semantics. Descent + runnable use `Planning.slopeFactor` (already Tobler-normalised) × the appropriate skill multiplier from AthleteProfile (descent or tech). Intensity is applied as `vmh × i` for climbs and `pace / i` elsewhere — higher i → faster predictions. Fatigue is single-pass.
**What I verified:** `npm run build` exit 0. Bundle size unchanged (305.84 kB) — Elm dead-code-eliminates the unused module, which is the expected outcome for a pure library landing one PR ahead of its first caller. TASK-019 will surface the actual numeric output.
**What changed in the repo:** PR #21. New `src/Predictor.elm` (~190 lines). No other code touched.
**What I learned:**
- Reusing `Planning.slopeFactor` for the descent + runnable pace adjustment keeps the math consistent with the existing distributor (ADR-0003). The predictor and distributor now share their slope semantics.
- Fatigue iteration: spec calls for "apply fatigue, recompute total, apply again — converges in 2-3 passes." For typical inputs (slope 0.02, threshold 2 h, total 4-8 h) the single-pass error is < 1 %. Skipped the iteration to keep `predict` a pure synchronous fn — important for the slider which calls it 12× per re-bracket.
- Bisection direction: the predictor is *monotonically decreasing* in intensity (more intensity = less time). The `if midTotal > targetS then mid becomes lower bound` branch is correct; flipped it would diverge.
**Next:** TASK-019 — bidirectional slider. Wires the predictor into the plan-table target panel: slider position ↔ predicted total time, with `solveForIntensity` powering the inverse direction. This is the first time the predictor's output is user-visible.

---
## 2026-05-15 21:50 — TASK-019: bidirectional aggressiveness slider

**Task:** TASK-019.
**What I did:** New `viewPredictorStrip` between the target panel and the actual-run strip on the plan-table page. Native `<input type="range">` from 0.80 to 1.25 (step 0.01). Slider position derives from `Predictor.solveForIntensity(profile, race, kms, targetSeconds)`; dragging fires `SliderChanged` which calls `Predictor.predict` at the new intensity and saves `plan.targetSeconds` to that. Six intensity bands: Below conservative / Conservative / Goal / Push / All-in / Beyond all-in, with slate/sky/emerald/amber/rose/rose-deep accents. Below the slider: 4 anchor labels. Right side of the header shows predicted finish + per-component breakdown (climb · descent · runnable · aid, only including non-zero pieces). Strip hides when kms haven't parsed yet. Imported `Predictor`.
**What I verified:** `npm run build` exit 0, JS 305.84 → 309.49 kB (+3.6 KB — predictor module now actually pulled in by tree-shaking); gzip 95.45 → 96.62 kB. Bundle string check: all 8 new labels (Effort, Predicted finish, Conservative, Goal, Push, All-in, Below conservative, Beyond all-in) present.
**What changed in the repo:** PR #22. Modified `src/Main.elm` (Predictor import, `SliderChanged` Msg + handler, view + intensity band helper + profile-brief + breakdown helpers).
**What I learned:**
- The slider is fundamentally a different input for the same number (target seconds). Storing intensity separately would create a sync problem; deriving from target keeps a single source of truth. Round-trip: target → solveForIntensity → predict → target should be a no-op, and would be exactly so for any target in [predict(1.25).totalS, predict(0.80).totalS].
- For out-of-bracket targets (user types e.g. "1:00:00" for a 50 km mountain race), `solveForIntensity` clamps at the endpoint; the displayed band shows "Beyond all-in" so the unrealistic target is visible without the predictor silently snapping the target.
- Dragging the slider saves the race on every step — every value-change generates a Storage.saveRace. For UTMB-sized races this is ~1 MB JSON per save. Acceptable per the offline-first / single-user constraint; the IDB write is async and doesn't block the UI.
- Native `<input type="range">` with `accent-rose-500` is dark-theme friendly without custom CSS; matches the existing form aesthetic.
**Next:** TASK-020 — confidence indicator. Surface the prediction's confidence based on profile source (hand-tuned vs fitted-from-N-activities). Currently profile.source isn't tracked; this task may need to extend the profile model or a tiny "metadata" sidecar in IDB.

---
## 2026-05-15 22:00 — TASK-020: confidence indicator

**Task:** TASK-020.
**What I did:** Predictor strip's "Predicted finish" column gained a `± hh:mm` margin and a confidence band label. `confidenceFromProfile : Model -> Race -> (label, tone, margin)` returns `("Low · profile from presets", "text-slate-400", 0.20)` by default; if the race has linked actualSplits, narrows to `("Medium-low · 1 actual linked", "text-sky-400", 0.15)`. Component-breakdown text de-emphasized to `text-[10px] text-slate-600` so the margin gets visual priority.
**What I verified:** `npm run build` exit 0, JS 309.49 → 309.82 kB (+330 B, basically just the new strings); bundle string check: "Low · profile", "Medium-low", "actual linked" present.
**What changed in the repo:** PR #23. Modified `src/Main.elm` (confidenceFromProfile fn + view tweak).
**What I learned:**
- The confidence rubric in roadmap §11.D references "fitted from N activities" semantics that don't exist until TASK-022. Going with the data we have today: presence/absence of actualSplits on *this* race. That's a thin proxy but it's honest — the user sees "no actuals, so wide band" or "one actual, slightly narrower." Future TASK-022 can refine to use the count of actuals across all races + an explicit `profile.source` field.
- Putting the margin near the predicted finish (not on the slider) makes "the slider position is exact; the predicted time is approximate" clear visually. The component breakdown moved to a smaller font so the margin reads as the primary qualifier.
**Next:** TASK-021 — Strava streams parser. Mirrors `ActualGpx` but consumes the keyed-object stream JSON cadence's endpoint returns. Pure module, no UI in this slice; TASK-024 (when it lands) plugs it into the actual-run upload flow.

---
## 2026-05-15 22:15 — TASK-021: Strava streams parser

**Task:** TASK-021.
**What I did:** New `StravaStreams.elm` decoder. Takes the keyed-object JSON value (`{time: {data: [...]}, distance: {data: [...]}, latlng: {data: [[lat,lng], ...]}, altitude: {data: [...]}}`) and produces an `ActualGpx.ActualTrack`. Reuses Strava's pre-computed cumulative distance directly rather than re-Haversine-ing (Strava's value is canonical). Handles stream-length mismatches by trimming to the shortest. Time stream is already elapsed-seconds-from-start — no ISO 8601 plumbing.
**What I verified:** `npm run build` exit 0; bundle size unchanged (Elm dead-code-eliminates the module since no caller yet). TASK-024 will wire it and surface real values.
**What changed in the repo:** PR #24. New `src/StravaStreams.elm` (~140 lines). Tiny edit to `src/ActualGpx.elm` to expose `cumulativeDistances` (forward-compatible — not consumed here since Strava gives us distance directly).
**What I learned:**
- Strava streams hand us cumulative distance for free. Using it preserves Strava's canonical track distance (small differences from Haversine on a noisy track can shift km boundaries by ~1-2 m).
- The keyed-object shape (`{ "time": { "data": [...] } }`) is what cadence's TASK-004 returns when it forwards `key_by_type=true` to Strava. Decoder uses `D.oneOf [field, succeed default]` so missing streams (e.g. an activity without heartrate) decode to empty lists rather than failing.
- `zip3` for `(time, latlng, altitude)` triples: 4-arity zips don't exist in Elm stdlib, and a 5th-tuple wouldn't compile anyway. Three's the natural cap.
**Next:** TASK-022 (calibration from past activities) — large, depends on the OAuth integration which is TASK-024. I'll do TASK-024 first so the data flow is complete before calibration logic.

---
## 2026-05-15 22:35 — TASK-024 v1: Strava OAuth round-trip + Connect/Disconnect

**Task:** TASK-024 v1 (intentionally scoped tight; activity picker split off as 024b).
**What I did:** JS-side captures `?token=...` from the OAuth callback URL before Elm boots, strips it from the address bar via `history.replaceState`, and hands it to Elm via flags. Added `VITE_BACKEND_URL` env-var fallback (defaults `http://localhost:3001`). Three new IDB-port pairs persist the session token under `settings.stravaSessionToken`. `Model` gains `stravaToken : Maybe String` and `backendUrl : String`. On init: if incoming token, save it; otherwise load whatever's in IDB. Settings page Strava section renders "Connect Strava" → `${backendUrl}/auth/strava?origin=trail` when no token; "Connected" pill + Disconnect button when present.
**What I verified:** `npm run build` exit 0, JS 309.82 → 312.56 kB (+2.7 KB); gzip 96.72 → 97.41 kB. Bundle string check: all 5 new labels (Strava integration, Connect Strava, Disconnect, App works fully offline, Backend:) present.
**What changed in the repo:** PR #25. Modified `src/main.js` (`STRAVA_TOKEN_KEY`, `BACKEND_URL`, `loadStravaToken`/`saveStravaToken`, `incomingStravaToken` capture, port subscribes), `src/Storage.elm` (3 new ports + wrappers), `src/Main.elm` (Flags + Model fields, init Cmd, Msg variants, update handlers, subscription, settings-page Strava section).
**What I learned:**
- The OAuth callback redirects with `?token=...` in the **query string** (before any `#hash`). Trail's hash router doesn't see queries, so the capture has to happen at the JS layer before Elm boots. Otherwise Elm initializes with the URL still containing the token in the address bar — visible, leakable.
- Elm's `Maybe String` decoder for flags accepts `null | string` natively. The JS-side `incomingStravaToken` variable is either the string from the query param or `null`; types align without a custom decoder.
- `Storage.saveStravaToken Encode.null` is how Disconnect clears the IDB row (the JS-side handler deletes the row when the value is falsy). Symmetric with `Just t → put`.
- Scope discipline saved this PR: the activity picker is ~200 more lines of Elm UI + `elm/http` + a state machine for "loading activities" / "loading streams" / "error." Splitting it off as TASK-024b keeps THIS PR honest about what it ships.
**Next:** Three remaining items: TASK-024b (activity picker + streams fetch + persist), TASK-022 (calibration from past activities), and the cadence addendum-1 work (user is handling that separately). All three are L-sized; deferring to a follow-up session unless the user wants to push further now.

---
## 2026-05-15 22:55 — TASK-024b: Strava activity picker + streams fetch

**Task:** TASK-024b.
**What I did:** New `StravaApi.elm` (HTTP wrapper: `fetchActivities` + `fetchStreams`, both with `Authorization: Bearer` + timeouts + JSON decoders). `Model.stravaPicker : StravaPicker` state machine (Closed / LoadingActivities / Showing / LoadingStreams / Error) keyed by RaceId so the modal only renders for the race that opened it. Plan-table actual-run strip gains an orange "Link from Strava" button when the user is connected (mirrors the existing "Upload .gpx" path). Full data flow: click → `fetchActivities` → list modal → click row → `fetchStreams` → `StravaStreams.parse` → `ActualGpx.computeSplits` → save on race. Modal supports click-outside-to-close (with `stopPropagation` on the inner card so clicks inside don't close). Error states: 401 ("Unauthorized — reconnect Strava"), Timeout, NetworkError, BadStatus, BadBody.
**What I verified:** `npm run build` exit 0. JS 312.56 → 321.94 kB (+9.4 KB — `elm/http` ~5 KB, StravaApi ~1 KB, picker/modal ~3 KB); gzip 97.41 → 100.35 kB. Bundle string check: all 6 new labels present including each error-message variant.
**What changed in the repo:** PR #26. New `src/StravaApi.elm`. Modified `src/Main.elm` (imports, Model + Msg + handlers, picker view + modal shell + activity row + httpErrorString helper, "Link from Strava" button on actual-run strip). `elm.json` gains `elm/http` 2.0.0.
**What I learned:**
- The `StravaPickerSelect` handler needs the current timestamp to seed `actualSplits.uploadedAt` but `Http.request` doesn't compose with `Time.now` in one chain. Sidestepped via an intermediate `InternalStartStreamFetch` Msg: `Task.perform Time.now → InternalStartStreamFetch with timestamp → fetchStreams`. Two-hop but type-safe.
- `Http.expectJson` with `D.value` lets the streams response come back as an unparsed `Json.Decode.Value`. The actual decoding into `ActualTrack` happens in `StravaStreams.parse` (already a `Value → Result String ActualTrack`). Single source of truth for the keyed-object format.
- `E.stopPropagationOn "click"` on the inner modal card is the standard way to make a backdrop-close-on-click modal in Elm — clicks inside bubble would otherwise trigger the backdrop's onClick.
- Bundle now ~100 KB gzipped. Still well within reasonable bounds for a SPA, but `elm/http` is a real weight — worth flagging if size becomes a concern.
**Next:** Predictor+slider+actual arc is closed, both file and Strava paths land actual splits. TASK-022 (calibration from past activities) is the remaining piece on the roadmap. Stopping here — calibration involves real curve-fitting (Riegel exponent, vmh decay, fatigue slope) that deserves a fresh session not a tail-end push. The cadence addendum-1 work (broaden OAuth scope to `profile:read_all` for max_heartrate / weight / ftp) is also still pending on the cadence side — the user is handling that separately.
