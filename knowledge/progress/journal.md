# Journal

Append-only. Newest at the bottom. Each entry is a snapshot for future-me with no memory of this session.

## Entry format

```
---
## YYYY-MM-DD HH:MM — <short heading>
   (HH:MM may be dropped only if the heading text alone makes the entry
   findable from a DONE.md pointer — multi-entry days usually need it)

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

---
## 2026-05-15 23:05 — session closeout

**Task:** end-of-session sweep.
**What I did:** Ten PRs shipped in this session, closing the pace-prediction roadmap arc end-to-end **except** TASK-022 (calibration). Summary:

| PR | Task | Summary |
|---|---|---|
| #15 | docs | Roadmap + cadence-backend-spec, exploration entries. |
| #16 | TASK-014 | Course summary card additions (density bucket + flat-eq). |
| #17 | docs | Cadence-spec addendum 1 (broaden OAuth scope to `profile:read_all`). |
| #18 | TASK-015 | Per-km grade classification chip. |
| #19 | TASK-016 | Planned-vs-actual upload (manual GPX). |
| #20 | TASK-017 | Athlete profile + IDB v2 + settings page. |
| #21 | TASK-018 | Predictor.predict — Layer B time model (pure module). |
| #22 | TASK-019 | Bidirectional aggressiveness slider. |
| #23 | TASK-020 | Predictor confidence indicator. |
| #24 | TASK-021 | Strava streams parser (pure module). |
| #25 | TASK-024 v1 | Strava OAuth round-trip + Connect/Disconnect. |
| #26 | TASK-024b | Strava activity picker + streams fetch + persist. |

Bundle progression: 286 kB → 322 kB JS / 90 kB → 100 kB gzip. New modules: `AthleteProfile`, `ActualGpx`, `Predictor`, `StravaStreams`, `StravaApi`. New IDB store: `settings` (carries `activeProfile` and `stravaSessionToken`). New routes: `#/profile`.

**What I verified across the session:**
- Every PR: `npm run build` exit 0, bundle string check for user-visible labels.
- No in-browser visual checks (no GUI in this session). Every PR description and journal entry flags this explicitly.
- Arithmetic spot-checks for the math (ISO 8601 → epoch, split interpolation, predictor signs, bisection direction).

**What's pending (NOT done):**
- **TASK-022** — Calibration from past activities. Real work: throttled multi-activity streams fetch, climb-segment identification, vmh / fatigue slope / HR-curve fitting, "what changed and why" UX. Deserves a fresh session; curve-fitting is error-prone enough that doing it as a 13th sequential PR risks subtle bugs.
- **Cadence addendum 1** — One-line scope change in cadence. User is handling.
- **TASK-022 dep on addendum 1** — Calibration *can* run without `max_heartrate` (it'd fit vmh + fatigue without HR-derived zones); the scope change unlocks the HR side. Either order works.

**What I learned across the session:**
- Per-PR scope discipline (`one logical unit`) survived even at the tail. Splitting TASK-024 into v1 (auth) + b (picker) saved real complexity.
- Elm-side: shadowing `Html.p` with `let p = ...`, 4-tuple rejection, `Maybe ActualSplits` requires extending every encoder/decoder/buildDraftRace site. Each gotcha caught by the compiler on first build — the trail Elm setup pays for itself.
- "Source-agnostic" architecture: `ActualGpx.ActualTrack` shared between the file-picker path (TASK-016) and the Strava-streams path (TASK-024b) meant the diff column code wrote itself the second time.
- Build-only verification is honest but limited. Every PR description includes the "in-browser visual check not performed" line; the user knows where the gap is.

**Working-tree state at session close:**
- Master synced to `0d1109f` (PR #26 merge).
- `package.json` still carries the user's local `vite --port 5174` change — uncommitted, left alone per the one-PR-one-logical-unit rule.
- `trail_race_planner_spec.md` (the user's exploration artefact) is still untracked at the repo root; user's call whether to commit/move/delete.

**Next session priorities (if/when picked up):**
1. User visual-smoke each shipped feature; file bugs as PRs.
2. TASK-022 — calibration — design pass + implementation. Probably a 90-min focused session.
3. (Optional) Cadence-side addendum 1 if not already shipped by the cadence agent.
4. Polish items in the parking lot (descent-aggressiveness slider, per-km gain/loss for slope-factor, etc.).

---
## 2026-05-15 23:25 — hotfix: stack overflow in StravaStreams.zip3

**Task:** bugfix (visual-smoke from user found it).
**What I did:** User reported `RangeError: Maximum call stack size exceeded` during the streams parse on an ~18 km activity (Strava streams come back with ~6 000 sample points). Followed by "Loading recent activities also gets stuck" — the zombie symptom after an uncaught Elm-runtime exception. Root cause: `zip3` in `StravaStreams.elm` was the classic non-TCE recursive cons pattern `(x, y, z) :: zip3 xs ys zs` — Elm's TCE only kicks in when the recursive call is the *last* expression returned, and with a leading cons it isn't. Fix: accumulator-and-reverse so the recursive call IS tail-position. **Both reported bugs resolve from this one fix** — the streams crash killed the Elm runtime mid-frame; subsequent Msgs (including the activity-list response) were dropped, so the picker stayed at "Loading recent activities" indefinitely. Page reload would have unstuck it; the real fix is no crash.
**What I verified:**
- `npm run build` exit 0. JS 321.94 → 322.02 kB (+80 B for the helper).
- Audited other new modules for the same anti-pattern: `cumulativeDistances` and `computeSplits` use `List.foldl` (safe), `crossBoundaries` is tail-recursive (recursive call is the last expression in the if-branch), `bisect` is tail-recursive. No other recursive-cons builders.
- Server-side curl already verified `/api/activities?days=60` returns 29 decode-clean activities in ~450 ms; the picker bug was purely client-side.
**What changed in the repo:** PR #28. Modified `src/StravaStreams.elm` only — `zip3` now delegates to `zip3Help xs ys zs []` which accumulates then reverses.
**What I learned:**
- Elm TCE is precise: it works on **self-recursive functions in tail position only**. `f x :: g rest` is not tail position because the cons happens after `g` returns. The trail rule for hot-path list builders: accumulator + final `List.reverse`, always.
- An uncaught exception in the Elm runtime is silent-fatal: no error banner, the DOM stays as last-rendered, all subsequent ports + subscriptions stop firing. Reload is the only recovery. Worth remembering when debugging "frozen UI" reports.
- The bug was latent until streams hit a real Strava activity. The build verified types but never exercised the 6 000-point path. **Visual-smoke catches what build-only-verification cannot** — exactly the constraint flagged in every PR description this session.
**Next:** Resume the previous closeout — TASK-022 still deferred for fresh-session work.

---
## 2026-05-15 23:50 — perf: slider lag + sparkline render cost

**Task:** perf bugfix (user-reported after first visual-smoke).
**What I did:** Two related performance fixes.

1. **Slider lag (drag-time IDB writes).** Each `oninput` event on the predictor slider triggered `Storage.saveRace`, which serialises the full race JSON — including the gpxText field which is up to ~3 MB for UTMB. Dragging the slider produced 30+ input events per second × 3 MB per save = the laggy feel even on 20 k races. Fix: separate `SliderInput` (live, no IDB) from `SliderCommit` (on `change` event, one IDB write). New `sliderDraft : Maybe Float` on Model carries the in-flight value; the predictor strip reads `sliderDraft` if `Just`, otherwise derives from saved target via `solveForIntensity`. Slider HTML wires `E.onInput SliderInput` + `E.on "change" (D.map SliderCommit E.targetValue)`.

2. **Index page slow (sparkline re-downsampling).** Every navigation to `/` ran `raceSparkline` for each cover-less race, which walked the full track (~26 k points for UTMB) through 4 list passes to downsample to 240 coords. ~100 ms per UTMB card per render on average hardware. Fix: cache the downsampled `(x, y)` coords keyed by raceId in a new `sparklineCoords : Dict String (List (Float, Float))` on Model. Computed once at parse time (`sparklineCoordsForTrack` uses a single tail-recursive `List.foldl` over `track.cumDist` + `track.points` with a stride-and-keep predicate). `viewRaceCard` / `viewCoverSparkline` / `raceSparkline` now take the cached coords directly; per-render work is just building a 240-point SVG path string (~1 ms).

**What I verified:**
- `npm run build` exit 0. JS 322.02 → 322.61 kB (+580 B for the cache machinery + slider draft). Gzip 100.38 → 100.62 kB.
- Hooked the new cache into all three lifecycle paths: `RacesLoaded` (initial build), `RaceSaved` (incremental insert), `RaceDeleted` (`Dict.remove`).
- The slider's `value` attribute now reflects `sliderDraft` during drag — Elm doesn't fight the native drag because the model tracks the user's position in real-time.
**What changed in the repo:** PR #29. Modified `src/Main.elm` only — added `sliderDraft` + `sparklineCoords` model fields, the `sparklineCoordsForTrack` helper, the `buildSparklineCache` + `cacheSparkline` updaters, split `SliderChanged` into `SliderInput` + `SliderCommit`, refactored `viewRaceCard` / `viewCoverSparkline` / `raceSparkline` to read from the cache.
**What I learned:**
- The slider lag root cause was not the math (predict on UTMB is < 2 ms); it was the JSON-serialise-then-IDB-write of the gpxText field. Future refactor: separate gpxText into its own IDB row so plan-only saves don't re-ship the GPX. Out of scope here; flagging for the parking lot.
- Caching computed-once values is much cheaper than reaching for `Html.Lazy` when the inputs aren't referentially stable (Dict.get returns a fresh `Maybe` every call). Cache the data; let the view be small and cheap on each render.
- The cumulative-distance + point stride loop is now a single foldl pass — was four passes previously. Even uncached it'd be ~4× faster, but caching makes the re-render free.
**Next:** Still the same as the closeout — TASK-022 deferred, visual smoke pending on the remaining shipped features. The gpxText-as-separate-row refactor is a tracked follow-up.

---
## 2026-05-16 00:05 — fix: target-time input tracks the slider drag

**Task:** small UX bugfix.
**What I did:** User reported that the Target Time input stayed stale during slider drag — only the Predicted Finish updated. The visible-but-stale value made focus/blur on the field re-commit the old number via `CommitTargetTime`. Fix: in `SliderInput`, also call `Predictor.predict` at the drafted intensity and set `model.targetTimeText = formatHhmm prediction.totalS`. `SliderCommit` does the same on release. Predict is < 2 ms for UTMB, so doing it per input event is fine — only the IDB save is heavy, and that still stays on SliderCommit.
**What I verified:** `npm run build` exit 0, JS 322.61 → 322.81 kB (+200 B for the now-shared compute path in both handlers). No new warnings.
**What changed in the repo:** PR #30. Modified `src/Main.elm` only — extended `SliderInput` to compute the prediction + update `targetTimeText`; `SliderCommit` also sets it on save so the two inputs stay locked even if the user releases outside the range.
**What I learned:**
- Two displays of the same derived value (target time number + slider position) need to update in lockstep or focus events on either one will surface the desynchronisation. The slider-as-derived approach (intensity ↔ target via `solveForIntensity`) is right; the bug was forgetting that `targetTimeText` is a *third* display of the same value.
- Predict is cheap enough to run per input event. Save is what was expensive. Keep that split clear when sketching event handlers.
**Next:** Same as before — TASK-022 deferred, visual smoke pending.

---
## 2026-05-16 00:30 — feat: Strava picker search over full backfilled history

**Task:** UX follow-up — user wanted to link a November-2025 activity but the picker only showed the past 60 days.
**What I did:** Added a search input at the top of the Strava picker modal. When the field is empty, the picker uses the existing `fetchActivities` (60-day recent list). When the user types, the picker switches to cadence's `/api/activities/search?q=...` endpoint, which is the FTS5-trigram-indexed search over the *full* backfilled activity history (cadence had 431 activities cached, 388 of them runs — the user's full library is there). New `StravaApi.searchActivities` decodes the search-response envelope (`{activities: [...], total, ...}`). New `StravaPickerSetSearch RaceId String` Msg updates the search field and fires the appropriate fetch on every keystroke. The picker heading flips to "Search Strava activities" while a query is active; empty-result text adapts ("No activities match this search" vs "Try searching"). Search field uses a small `⌕` icon and the existing dark-input style.
**What I verified:**
- Probed `/api/activities/search` first: 388 runs in the cache, backfill complete, the same response shape as `/api/activities` wrapped in `{activities, total, limit, offset}`. "morning" returned 28 hits going back to August 2025 — confirms the user's November activity is reachable.
- `npm run build` exit 0. JS 322.81 → 324.03 kB (+1.2 KB); gzip 100.65 → 100.95 kB. Bundle string check: 4 new labels present.
- Picker state machine unchanged; the search field is held at the top level of Model (`stravaPickerSearch : String`) so it survives the loading-state transitions. Cleared on `OpenStravaPicker` and `StravaPickerClose`.
**What changed in the repo:** PR #31. `src/StravaApi.elm` gained `searchActivities` + a tiny `percentEncode` (covers the practical hazards: `%`, space, `&`, `#`, `?`, `+`, `"`). `src/Main.elm` gained the Msg variant, the update handler, the Model field, and the new search-input view helper.
**What I learned:**
- No debounce on keystroke-fires-HTTP. For typical typing the responses arrive between keystrokes; if cadence ever got slow, an out-of-order race could briefly show the wrong query's results. Mitigation (tag-the-request) deferred until it actually bites.
- Cadence's FTS5 endpoint is exactly the same shape as the recent endpoint inside an envelope — the existing `activityDecoder` works against the inner array unchanged. Wrapping the decoder is one line.
- The picker UX has two coexisting modes (recent / search) but they share the same state machine, just with different fetch sources. Holding the search string at the top level of Model keeps the state variants clean.
**Next:** Visual smoke remains pending. TASK-022 (calibration) still deferred.

---
## 2026-05-16 01:15 — feat: Actual + Δ vs plan everywhere, labeled aid markers on cards

**Task:** UX gap-fill — user noted Δ vs plan only appeared in the km table.
**What I did:** Four extensions, all gated on `race.actualSplits /= Nothing` (and per-km/per-section availability):

1. **Section table** — `viewSectionTable` + `sectionsWithCumulative` now insert "Actual" + "Δ vs plan" columns between Section time and Cum when actuals are linked. Aid-rest rows insert two extra `—` cells to keep column alignment. Section actual is the sum of contained-km actuals; if any contained km is missing from `actualSplits` (partial coverage on a DNF, for example), the section cell shows `—` instead of a misleading partial sum.
2. **Per-km card form** — `viewKmForm` gains a 2-col grid below Target/Pace showing Actual + Δ when the km has a linked split. Two fallback states: actuals linked but km not in trace ("…this km isn't in its trace"); no actuals at all (renders nothing).
3. **Per-section card stats** — `viewSectionDetails` gains an Actual + Δ row below the main 4-col stats grid. Same partial-coverage rule as the section table.
4. **Labeled aid markers on per-km and per-section cards** — `viewKmCardStop` and the new `viewSectionCardEndAid` render the Profile.elm-style pill (amber rounded rect with the aid name) above a dashed line. Per-km bumps `chartTopPad` from 14 to 34 when stops exist; per-section card bumps the same way when `followedByAid` is `Just`. Pill x is clamped so it stays inside the card edges even when the aid is near the start/end.

Shared helpers added: `sectionActualSeconds : Race -> List Int -> Maybe Int` (returns `Nothing` for no actuals or any-km-missing) and `viewSignedDeltaCell : Int -> Html msg` (the +mm:ss / −mm:ss / on-target tone-coded span, factored out so the four call sites share one implementation).
**What I verified:** `npm run build` exit 0. JS 324.03 → 327.09 kB (+3 KB); gzip 100.95 → 101.73 kB. Bundle string check: all 3 new labels ("Δ vs plan" — used in two places — and both fallback messages).
**What changed in the repo:** PR #32. Modified `src/Main.elm` only — five view fns extended (`viewKmCard`, `viewSectionCard`, `viewKmForm`, `viewSectionDetails`, `viewSectionTable`), three new helpers (`sectionActualSeconds`, `viewSignedDeltaCell`, `viewSectionCardEndAid`), `viewKmCardStop` rewritten to render the pill.
**What I learned:**
- The "any km missing → show —" rule beats "sum what's there" because the diff column needs the same denominator on both sides. Partial sums make the section look faster than reality.
- The aid-station pill on the km card needed `cardWidth` for edge-clamping (otherwise an aid near the start of the km would have its pill bleed off the left). Passing `cardWidth` down through the marker fn rather than computing it inline keeps the geometry locally consistent.
- The section card had no markers before this; adding the terminal-aid pill makes the "Ends at" panel feel anchored to the silhouette rather than floating below it. Earlier sections (where `followedByAid` is `Just`) get the marker; the last section ("→ Finish") gets the existing 🏁 panel only.
**Next:** Visual smoke. TASK-022 still deferred.

---
## 2026-05-18 — chore: knowledge whiteboard area + queue 4 follow-up tasks

**Task:** chore — set up `knowledge/whiteboard/`; record two open discussions; queue TASK-025..028 in `BACKLOG.md`.
**What I did:** User had a five-item brainstorm (home page UX, drop-area loading state, pace/aid-station bug, profile management, training-as-analysis). Three items got "build it" answers (pace bug, home split, skeleton drop area) plus one new small task (HR data on linked actuals). Two items got "record and keep thinking" answers (profile management, training-mode vs. planner). The user surfaced that we don't have a place for in-flight discussions and asked for a "working desk / ideation area / whiteboard" — hence `knowledge/whiteboard/`. New files: `whiteboard/README.md` (purpose, lifecycle, distinction from ADRs/backlog/brief), `whiteboard/profile-management.md` (full record of the snapshot-vs-hard-link debate; the user's longitudinal-tracking argument is the load-bearing one), `whiteboard/training-as-analysis.md` (resolved: trail stays a planner; analysis features must "sharpen planning" or stay out; HR-on-linked-actuals is the one admitted action). Updated `knowledge/README.md` Layout + key-docs sections to list `whiteboard/`. Added TASK-025..028 to `BACKLOG.md` (pace bug → HR display → skeleton loading → home split, in execution order).
**What I verified:**
- `npm run build` exit 0 (`dist/assets/index-DHcPyE6_.js 327.09 kB / gzip 101.73 kB` — unchanged from PR #32 since this PR is docs-only).
- File presence: `ls knowledge/whiteboard/` shows three files (README + two discussion entries). `grep -n "whiteboard" knowledge/README.md` returns two hits (Layout + key-docs index).
- `BACKLOG.md` reads cleanly; the four new tasks are in the Active section under the existing completed tasks, marked `[ ]` with size estimates.
**What changed in the repo:** doc-only. New `knowledge/whiteboard/` (3 files). Edits to `knowledge/README.md`, `knowledge/planning/CURRENT.md`, `knowledge/planning/BACKLOG.md`, `knowledge/progress/journal.md`. No code touched.
**What I learned:**
- The whiteboard is a real gap in the system. ADRs are for decisions made; backlog is for decided work; the brief is for what we're building. There was nowhere for "we discussed this, here's what we considered, no action yet." Naming: "whiteboard" beat "ideation" / "desk" / "discussions" — it evokes ephemeral, in-progress, not-yet-canonical.
- The user's framing on profile management ("snapshot + soft link, source of truth lives in the race") is the right shape and the load-bearing argument is longitudinal tracking — *"you can view a race from 2 years ago with a 'Push hard' profile, but now that could be just a normal profile since you've grown as a runner."* That's a strictly stronger reason than the hard-link breakage problem; recording it for next-time.
- For training-mode: the test "can I write a one-line sentence connecting this to better future race plans?" is a useful rule of thumb to keep in the whiteboard entry as a future scope-creep filter.
**Next:** Pull TASK-025 (pace bug) into `CURRENT.md` and start the next branch.

---
## 2026-05-18 — fix: per-km Target = clock time, Pace stays moving (TASK-025)

**Task:** TASK-025 — fix the apples-to-oranges Δ vs plan bug visible in `samples/aid-station.png`.
**What I did:** The screenshot showed a km containing a 1-min aid station with Target 6:11 / Pace 6:11/km / Actual 7:14 / Δ +1:03. Diagnosed: `result.seconds` (from `Planning.distribute`) is moving time only (aid rest is subtracted from `budget` before allocation), the Target field displayed moving, the Actual came from the GPS as clock time, so Δ subtracted moving from clock — apples-to-oranges. The runner was only 3 seconds slow, not 63. Fix: the display layer now folds in-km aid rest into Target; Pace stays moving / distance. Underlying distribution math unchanged. Manual-input parser converts clock→moving on commit (`Manual (max 0 (typed − kmRest))`), and echoes clock back (`formatMmss (stored + kmRest)`).

Touched sites: per-km card (Target placeholder + Δ vs plan + an amber caption when stopRestInKm > 0), km table (Time column + Δ vs plan + drop the "+" prefix from the aid-stop notes line), per-section card's contained-km list (Time per km), `Csv.buildKmRows` (`target_time_s` / `target_time` now clock). New helper `aidRestInKm : List AidStation -> Int -> Int` uses `Planning.kmAtDistance` so each aid is attributed to exactly one km (no double-count at exact km boundaries). The per-km card's `stopsInKm` filter was unified onto the same convention.
**What I verified:**
- `npm run build` exit 0. JS 327.09 → 327.51 kB (+420 B); gzip 101.73 → 101.91 kB.
- Bundle-string check: `"Target time is clock time"` present (1), `"at the aid station"` present (1).
- Math sketch: total clock at race level = `sum_auto(moving) + sum_manual(moving_stored) + sum_all(kmRest) = (T − aidRestSum − manualSum) + manualSum + aidRestSum = T`. Holds for any mix of Auto / Manual kms.
- Edge case: Manual time typed < in-km aid rest → `max 0` clamps stored seconds to 0; echo shows the rest itself; user notices and re-types.
- Edge case: km with no aid → `stopRest = 0`, no behavior change.
- **Visual smoke not performed** (no GUI in this session). User to confirm on `samples/aid-station.png` km: Target 7:11, Pace 6:11/km, Δ +0:03, caption visible.
**What changed in the repo:** PR #34, merged `0f316fb`. Modified `src/Main.elm` (helper + hydrate + commit + 3 view sites) and `src/Csv.elm` (km-mode export).
**What I learned:**
- The bug existed because two different mental models for "Target time per km" co-existed in the codebase: distribute()'s allocation said "moving only" but the watch / user said "clock time". Whenever those models read the same number, one is wrong. The fix anchors the display side to the user's model.
- During the scoping I noticed a *separate* pre-existing bug in `Planning.sectionsForRace`: the overlap test `km.distStart < b && km.distEnd > a` puts a km straddling an aid into both adjacent sections. The section-table `sectionSeconds`, the section-card "Time" stat, and the cumulative-after-section column all double-count that km. Logged in the parking lot; fix wants its own task because (a) it interacts with the section-card's own moving-vs-clock Δ bug and (b) the right shape (pro-rate by overlap distance? assign to the section the km's center is in?) is a design call.
- Build-only verification continues — I'm honest about it in the PR description. The user's screenshot is the acceptance artefact.
**Next:** TASK-026 (HR display on linked actuals) is next.

---
## 2026-05-18 — feat: avg HR per km on linked actuals (TASK-026)

**Task:** TASK-026 — surface average heart rate per km on linked actuals. Only analysis-side feature admitted from the brainstorm; the "must sharpen planning" rule is in `knowledge/whiteboard/training-as-analysis.md`.
**What I did:** Wired HR end-to-end. `ActualPoint` gains `hr : Maybe Int`. `StravaStreams.parse` decodes the `heartrate` stream (cadence already requests it). The old `zip3 times ll ele` helper is replaced by a direct tail-recursive walker `buildPointsHelp` that consumes four parallel streams without needing a 4-tuple (Elm forbids those — caught us before in journal 2026-05-15 18:00). New `ActualGpx.computeHrPerKm : ActualTrack -> Maybe (Dict Int Int)` averages per km via `floor (cumDist / 1000)` (matches `Planning.kmAtDistance`). `Types.ActualSplits` gains `hrPerKm : Maybe (Dict Int Int)`; encoder writes it; decoder back-compats via `D.oneOf [..., D.succeed Nothing]`. Both ActualSplits construction sites (file upload + Strava streams) call `computeHrPerKm` and persist the result. Per-km card grid flips 2-col → 3-col with an Avg HR cell (shows '—' for kms without samples so the layout doesn't shift across navigation). Km table adds an "Avg HR" column gated on `hrPerKm /= Nothing`.
**What I verified:**
- `npm run build` exit 0. JS 327.51 → 329.33 kB (+1.82 kB); gzip 101.91 → 102.38 kB.
- Bundle-string check: `"Avg HR"` present (1, deduped across two sites), `"bpm"` present (2), `"hrPerKm"` present (1 — encoder/decoder).
- Back-compat sanity: `decodeActualSplits` uses `D.oneOf [D.field "hrPerKm" ..., D.succeed Nothing]`. Old saved actuals lack the field and fall through to `Nothing`. Re-linking via the Strava picker recomputes.
- Edge case: HR sensor absent → `raw.heartrate = []` → `sliceAlignMaybe (List.map Just []) len = List.repeat len Nothing` → no point has hr → `computeHrPerKm` returns `Nothing`. ✓
- Edge case: HR sensor mid-activity dropout → `sliceAlignMaybe` pads trailing samples with `Nothing`, average over the live samples only. ✓
- **Visual smoke not performed.** User has to re-link a Strava activity with HR data to see the new UI.
**What changed in the repo:** PR #35, merged `68cb869`. Modified `src/ActualGpx.elm` (helper + ActualPoint field), `src/StravaStreams.elm` (decoder + buildPoints walker), `src/Types.elm` (ActualSplits + encoder/decoder), `src/Main.elm` (per-km card + km table + both construction sites).
**What I learned:**
- The "4-tuple banned, cons-after-recur kills TCE" duo is now a known trap in this codebase. Both bit us in the previous Strava streams work (journal 2026-05-15 23:25); writing `buildPointsHelp` as a direct walker with the accumulator-cons pattern sidesteps both at once. Worth noting as a stable idiom for parallel-stream merging.
- Back-compat for IDB-persisted records is dirt-cheap when the new field has a meaningful default (`Nothing`). `D.oneOf [..., D.succeed default]` is the one-liner. No migration code; no schema version bump.
- Layout-stability matters more than I expected. First pass collapsed the per-km card grid from 3-col to 2-col on kms without HR samples (the if-Just was on the per-km HR rather than the activity-level HR). When the user navigates between kms with and without samples, the entire card jumps. Switched the gating to activity-level `hrPerKm /= Nothing` and used "—" for missing per-km values. Smooth.
**Next:** TASK-027 — skeleton/pulse loading state on the home-page drop area.

---
## 2026-05-18 — feat: pulse + skeleton on home drop area while parsing (TASK-027)

**Task:** TASK-027 — give the home drop area visual feedback while a large GPX is being processed. User specifically picked pulse + skeleton over a spinner ("out of fashion").
**What I did:** Two-part change. (1) New `StartParse fileName content` Msg moves the synchronous `isProjectFile` branch + `ProjectFile.decode` / `Gpx.parseGPX` logic out of `GotContent`. `GotContent` now only flips `upload = Parsing fileName` and dispatches `StartParse` via `Task.perform (\_ -> ...) (Process.sleep 1)`. The sleep yields to the renderer so the Parsing UI paints before the synchronous parse blocks. (2) `viewUploadBanner` splits into `viewUploadIdle` / `viewUploadSkeleton`. The skeleton variant renders the label + sub caption + three slate-700 skeleton bars (h-3, varying widths), no clickable button. The outer container adds `animate-pulse` whenever `disabled` is True (Parsing or Persisting). Status copy tightened: "Processing X… / Crunching the track — this can take a moment on a long course."
**What I verified:**
- `npm run build` exit 0. JS 329.33 → 329.87 kB (+540 B); gzip 102.38 → 102.50 kB.
- Bundle-string check: `"Processing"`, `"Crunching the track"`, `animate-pulse` class string — all present once.
- `Process` import added; no unused-import warning.
- `Task.perform (\_ -> StartParse ...) (Process.sleep 1)` discharges the deferred work via the standard Task pipeline. Process.sleep returns `Task Never ()`, so no error-handling burden.
- Edge case: user drops while a parse is in progress. New `GotFiles` overwrites the upload state and queues a fresh StartParse. The earlier in-flight `Process.sleep` will still fire its own StartParse with the *old* content, but model.upload will reflect the *new* file. Slight inconsistency on the failure path (error attributed to wrong filename) but probability is low and behavior was the same before this PR. Out of scope.
- **Visual smoke not performed.** User to verify by dropping a UTMB-size GPX and confirming the dashed banner pulses with three skeleton bars before and after the parse freeze.
**What changed in the repo:** PR #36, merged `bd6038b`. Modified `src/Main.elm` only (+47/-11 lines).
**What I learned:**
- The freeze-without-feedback bug was structural, not stylistic: even with the perfect skeleton animation, the renderer would never have drawn it without the deferred-parse trick. The bug = "we set the state and immediately starve the runtime before render." Process.sleep 1 is the cheapest fix; longer-term the parser itself wants to move off the main thread (port to JS, or a Worker). Tracked indirectly via the brief's "Performance target" line.
- `animate-pulse` plus skeleton bars is a stable Tailwind idiom; the bars don't need their own animation, the container's pulse propagates via opacity-on-element-tree.
- Resisted the urge to make the skeleton bars look like a race card preview. The race grid lives *below* the banner — fake-card-in-banner would mislead.
**Next:** TASK-028 — home page split into Plans / Executions sections.

---
## 2026-05-18 — feat: split home page into Plans / Executions (TASK-028)

**Task:** TASK-028 — last item from the 2026-05-18 brainstorm. User wanted a cut between races with a linked actual and races without.
**What I did:** New `viewRaceSections : Model -> List Race -> Html Msg` partitions via `List.partition (\r -> r.actualSplits /= Nothing) races`. Each non-empty group renders a `viewRaceSection` with heading + count + sub caption + the existing `viewRaceGrid` underneath. Sort: `comparePlans` orders by `race.date` ascending with `Just` before `Nothing`, ties broken by `createdAt` desc; `compareExecutions` orders by `actualSplits.uploadedAt` desc. Section heading is a flex row with `<h2 text-lg font-semibold text-slate-200>` + `<span text-sm text-slate-500 tabular-nums>` count + `<span text-xs text-slate-600>` sub caption. Empty sections hidden entirely. Existing "No races yet" empty state still covers the both-empty case.
**What I verified:**
- `npm run build` exit 0. JS 329.87 → 330.92 kB (+1.05 kB); gzip 102.50 → 102.83 kB.
- Bundle-string check: `"Plans"` ×2 (heading + class fragment), `"Executions"` ×1, `"Courses you've prepared"` ×1, `"Runs you came back from"` ×1.
- Sort ordering reasoned through manually: dated plans first (asc), undated cluster last (createdAt desc); executions newest-uploaded first.
- **Visual smoke not performed.** User to verify with a mixed race list that both sections render and sort correctly.
**What changed in the repo:** PR #37, merged `4b8b2ae`. `src/Main.elm` only — +81 lines for the partition / sort / section render; existing `viewRaceGrid` kept as the cards-row component.
**What I learned:**
- The right cut wasn't past-vs-future (my first instinct) but linked-vs-unlinked (the user's correction). Past-vs-future depends on `Date.today` and conflates the user's intent ("which of these do I plan from vs. revisit logs of"). Linked-vs-unlinked mirrors the data model and is calendar-free.
- Resisted adding an emerald accent or Δ-as-headline to Executions cards. The section heading is the structural cue; layering visual differentiation on top would be loud and would need a per-card refactor that wasn't asked for.
**Next:** Session-level wrap-up. Brainstorm fully closed out; `CURRENT.md` empty.

---
## 2026-05-18 — session wrap

Five PRs in sequence from the brainstorm in this session:

| # | Task | Theme |
|---|---|---|
| #33 | chore | New `knowledge/whiteboard/` area for in-flight discussions + queue TASK-025..028 |
| #34 | TASK-025 | Pace bug: per-km Target is clock time, Pace stays moving |
| #35 | TASK-026 | Avg HR per km on Strava-linked actuals |
| #36 | TASK-027 | Pulse + skeleton loading state on the home drop area |
| #37 | TASK-028 | Split home page into Plans / Executions |

Bundle progression across the session: 327.09 kB → 330.92 kB JS (+3.83 kB), 101.73 kB → 102.83 kB gzip (+1.10 kB). New modules: none — all changes additive to existing modules (`Main`, `Csv`, `Types`, `ActualGpx`, `StravaStreams`). New IDB shape: `ActualSplits.hrPerKm : Maybe (Dict Int Int)` with back-compat decoder.

**Brainstorm framework that emerged.** The user surfaced that we needed a place to record in-flight discussions that aren't yet ADRs / backlog / brief edits. `knowledge/whiteboard/` is now the home for that, with two seed entries:

- `whiteboard/profile-management.md` — design open; load-bearing argument is *longitudinal tracking* (snapshot the profile into the race; soft-link only). Six design questions listed for next time.
- `whiteboard/training-as-analysis.md` — resolved: trail stays a planner; analysis features admitted only if they sharpen planning. HR-on-linked-actuals is the one feature admitted; training-mode-from-Strava is explicitly deferred.

**Pre-existing bugs surfaced during this session, logged in parking lot, not fixed:**
- `Planning.sectionsForRace` overlap test: a km that straddles an aid distance lands in *both* adjacent sections, so section table totals + section card "Time" stat double-count it. Section card Δ vs plan still has the moving-vs-clock apples-to-oranges bug at the section level (same class as the per-km bug fixed in TASK-025). Both fixes want one task because the right shape (pro-rate by overlap distance? assign to the section the km's center is in?) is a design call.

**Verification gap that the user knows about:** every PR description in this session flags `Visual smoke not performed`. The user is the source of truth for visual smoke; the build-only verification catches type errors and the bundle-string checks confirm new labels reached the bundle.

**Next session priorities (if/when picked up):**
1. Visual smoke each shipped feature — pace bug, HR display, skeleton, sections. File any visual bugs as `fix/` PRs.
2. Section-overlap bug (parking lot) — design + implementation, probably an M task with care taken around pro-rate.
3. TASK-022 (calibration from past activities) still deferred from the previous session.
4. The two whiteboard entries (profile management, training-as-analysis) are tagged "re-open when the user has more opinions" — no scheduled work.

---
## 2026-05-18 — fix: Executions sort by race.date desc, not uploadedAt

**Task:** user feedback after PR #37 shipped — Executions should sort by race date (newest first), not by `actualSplits.uploadedAt`. Symmetric with Plans (race date asc, soonest first).
**What I did:** `compareExecutions` rewritten to mirror `comparePlans` with `compare db da` (descending). Dated executions cluster before undated; undated tie-break by `uploadedAt` desc via new `compareUploadedAtDesc` helper.
**What I verified:** `npm run build` exit 0. JS 330.92 → 331.11 kB (+190 B). Visual smoke deferred to the user.
**What changed in the repo:** PR #39, merged `b73f4f6`. `src/Main.elm` only (+25 lines).
**What I learned:** premature inference on my part. "When did I log this run?" (uploadedAt) is a different question than "when did this race happen?" (race.date). The user reads the home page by the latter axis; the former is implementation detail. Symmetric axes (date asc vs date desc) read more cleanly than two different axes.
**Next:** Same as the previous session-wrap entry — visual smoke pending; section-overlap bug still parked.

---
## 2026-05-18 — fix: chunked SVG path so long-track profile renders end-to-end (TASK-029)

**Task:** TASK-029 — user loaded Cocodona 250 (~400 km, 36 746 trkpts) and the elevation profile at 10 m/px stopped mid-track. Screenshot: `samples/profile-interrupted.png` (removed in the closeout chore — it's in PR #41's history if needed).
**What I did:** Diagnosed in two steps. Wrote a Node-side mirror of the Elm pipeline (`scripts/profile-trace.mjs`) and a headless Elm `Platform.worker` with the actual `src/Gpx.elm` to compare outputs. Both produced identical numbers — 1 195 simplified points after `Gpx.simplify` at 5 m tolerance, last point at d=393 467 m (the very end of the track). So the truncation isn't in Elm. The culprit is browser SVG rendering: a single `<path>` element whose drawn extent exceeds a soft per-element limit (~16-20 k px in Chromium) gets clipped at roughly half its width. UTMB at 10 m/px is 17 500 px and renders fine; Cocodona at 39 400 px exceeds the limit.

Fix: new `chunkByXExtent : Float -> List (Float, Float) -> List (List (Float, Float))` in `src/Profile.elm` splits the coord list into chunks no wider than 10 000 px each. Adjacent chunks share their boundary point so the rendered line stays visually continuous. The `view` function emits one `<path>` per chunk for the area fill, one per chunk for the stroke, and uses `List.concatMap ghostLayers` to fan the sound-wave ghost variants across chunks.
**What I verified:**
- `npm run build` exit 0. JS 331.11 → 331.59 kB (+480 B); gzip 102.86 → 102.96 kB.
- Pipeline mirror: `scripts/profile-trace.mjs samples/cocodona_250.gpx 10` produces 1 195 simplified points reaching the end. The Elm-side `Platform.worker` (in a scratch dir `/tmp/elm-diag/`, not committed) produces identical output with the real `Gpx.elm`. Confirms the bug is browser-only.
- Chunk arithmetic: 39 400 / 10 000 ≈ 4 chunks for Cocodona; 17 500 / 10 000 ≈ 2 chunks for UTMB; ~1 chunk for any track under ~10 000 px (no-op for the common case).
- **Visual smoke not performed.** User to confirm the profile now draws to km 393.
**What changed in the repo:** PR #41, merged `3612aeb`. `src/Profile.elm` only (+92/-22 lines).
**What I learned:**
- "Pure pipeline is fine; the bug is downstream" is best diagnosed by running the pipeline outside the runtime suspected of the bug. A headless `Platform.worker` is light to set up (~30 lines of Elm + a Node runner) and worth keeping in mind for similar UI vs. pipeline questions.
- The Chromium soft path-element limit isn't documented in any spec I could find, but the empirical evidence (Cocodona truncated, UTMB renders) is consistent with a per-element rendering ceiling around 16-20 k px. 10 k chunks give healthy margin without producing absurd counts even for hypothetical 2 000 km races.
- The area fill uses a closed polygon (`M baseline L profile L baseline Z`). Splitting into N polygons that share boundary points produces N adjacent filled regions that visually appear as one continuous shape — the shared boundary edge means there's no seam at the joins.
**Next:** TASK-030 — plan table populates from predictor default when no target saved.

---
## 2026-05-18 — fix: predictor-default target on plan view (TASK-030)

**Task:** TASK-030 — same Cocodona session, user noted the plan view's Pace / Time / Current sum columns are blank when first opened until they move the slider. Their hypothesis: "maybe this wasn't a performance issue but the plan not being applied directly but rather waiting for me to move the slider." Correct.
**What I did:** Traced through: `Planning.distribute` short-circuits to `Dict.empty` when `target == Nothing` (Planning.elm L372), so every km's `result.seconds = 0` until the slider commits a real `targetSeconds`. New `effectiveTargetSeconds : Profile -> Race -> List Km -> Int` falls back to `Predictor.predict profile race kms 1.0 |> .totalS` when no target is saved. Plumbed through all five `Planning.distribute` call sites: `viewPlanTable`, `viewPlanSection`, `viewPlanKm`, `ExportCsvKms`, `ExportCsvSections`. Display-only — `race.plan.targetSeconds` stays `Nothing` until the slider commits explicitly.
**What I verified:**
- `npm run build` exit 0. JS 331.59 → 331.77 kB (+180 B); gzip 102.96 → 103.02 kB.
- Five distribute call sites updated, confirmed via `grep "Planning.distribute" src/Main.elm`.
- Display gating preserved: plan target panel's Δ-vs-Target and Avg-pace cells still hide when `race.plan.targetSeconds = Nothing` (showing diff vs an implicit target would be misleading).
- **Visual smoke not performed.** User to verify by uploading a new race — table should populate immediately, slider stays in sync.
**What changed in the repo:** PR #42, merged `3d296e5`. `src/Main.elm` only (+26/-5 lines).
**What I learned:**
- `Planning.distribute` was internally consistent (Nothing target → empty dict) but the UX assumed a saved target. The seam between "what the data model lets you express" and "what the user sees" is the right place to insert a fallback, not in `distribute` itself.
- The fact that CSV exports also benefit (a no-target-yet export now produces a sensible plan, not zeros) was a nice side-effect of plumbing `effectiveTargetSeconds` through all five call sites rather than just the view code.
**Next:** Cleanup chore.

---
## 2026-05-18 — chore: samples cleanup, archive spec, perf trace tool

**Task:** User asked to cleanup `samples/` and the root `trail_race_planner_spec.md` if unused. Picked "Aggressive" — also drop the early UI mockups referenced only by the brief.
**What I did:**
- Deleted 15 files from `samples/`: all `f-*` UI feedback mockups (8), `profile-01/03/04/05.png` (4), `profile-02-strava.png`, `race-cards.png`, `route-cards.png`, `profile-interrupted.png` (TASK-029's bug screenshot, no longer needed).
- Kept: `aid-station.png` (TASK-025 ref), `20k_oh_meu_deus.gpx` / `utmb_2025.gpx` / `cocodona_250.gpx` / `sample.gpx` (perf fixtures), `coros_pace_strategy.html` (ADR-0002 source).
- Moved `trail_race_planner_spec.md` → `knowledge/reference/archive/`. Updated `pace-prediction-roadmap.md`'s source-path reference.
- Rewrote `project-brief.md`'s "Visual direction" paragraph to drop refs to deleted mockups; pointed to the live implementation (`src/Profile.elm`, `viewRaceCard`) as the canonical style reference now.
- Committed `scripts/profile-trace.mjs` as the perf trace tool used to diagnose TASK-029. Added `npm run perf:trace` script in `package.json` — `npm run perf:trace -- samples/cocodona_250.gpx 10` runs the parse + Haversine + DP pipeline against any GPX and reports counts + per-stage timing. **This is our first real perf-testing tool.**
**What I verified:**
- `samples/` is down from 22 files to 6.
- `npm run perf:trace -- samples/cocodona_250.gpx 10` → parse 24.7 ms, cumDist 4.1 ms, simplify 19.0 ms, total 47.8 ms. UTMB: total 34.3 ms. Both well under 100 ms in pure Elm-mirror JS; the on-device parse is slower due to Elm Regex.find iteration and IDB write, but the algorithm itself isn't the bottleneck.
- No code references to deleted files remain. Journal mentions are historical (acceptable; journal is append-only).
- `npm run build` exit 0 (doc-only changes outside of `package.json`'s scripts hash, which doesn't affect the bundle).
**What changed in the repo:** PR #43, merged `8449767` (sha backfilled 2026-06-09; was an unfilled placeholder). 15 file deletes, 1 file move, 4 file edits (brief, roadmap, planning files, journal), 1 new file (`scripts/profile-trace.mjs`), 1 package.json line.
**What I learned:**
- The user explicitly asked about perf testing. Answer was "no, we don't have any" — `scripts/profile-trace.mjs` is now the first one. It's an algorithm-side mirror, not a full end-to-end perf test (which would need browser instrumentation), but it answers questions like "is `Gpx.simplify` the slow part?" without booting the app.
- The "aggressive" option for cleanup wasn't actually destructive — the brief refs to deleted mockups were one-liners describing visual intent, and the canonical reference is now the implementation itself.
**Next:** Session-level wrap. Brainstorm + Cocodona-feedback sessions fully closed out.

---
## 2026-05-18 — fix: SVG gradient spans full SVG, not per-chunk bbox

**Task:** user reported visible amber-to-rose seam at chunk boundaries after PR #41 landed; screenshot at `samples/profile-chunk.png` (deleted in this PR per the new convention below).
**What I did:** Both `Svg.linearGradient` defs in `Profile.elm` now use `gradientUnits="userSpaceOnUse"` with explicit SVG-coordinate endpoints (stroke: padLeft → padLeft + drawWidth; fill: padTop → padTop + chartHeight). Single continuous gradient across the whole chart regardless of chunk count.

Also added a "Bug-screenshot hygiene" section to `knowledge/philosophy/working-style.md` codifying when bug screenshots in `samples/` get deleted (default: with the fix; keep only when referenced by durable docs). Applied the rule by removing `samples/profile-chunk.png` itself.
**What I verified:** `npm run build` exit 0. JS 331.77 → 331.85 kB (+80 B). Inline comment in `Profile.elm` left for future-me to avoid re-introducing.
**What changed in the repo:** PR #44, merged `3384452`. `src/Profile.elm` (+12/-4) + `knowledge/philosophy/working-style.md` (+15) + one screenshot deletion.
**What I learned:**
- SVG gradient defaults (`objectBoundingBox`) are convenient for single-element paintings but become a footgun when the same `<linearGradient>` reference is used across multiple paths. The seam isn't obvious in code review — the gradient def looks identical to before — but the rendering is per-element. Inline comment now explains why.
- The user's "we should codify this" observation about screenshot hygiene was the right shape — it'd otherwise drift into "always keep" because deletes are friction-y. Default-delete with explicit-keep makes the deliberate path the easier one.
**Next:** Nothing queued.

---
## 2026-06-05 — TASK-031: aid-station CSV import/export (+ cutoff, warm food, notes, scroll-to-editor)

**Task:** Started as a "wdyt?" design chat (2026-06-04) about importing aid stations from a CSV; promoted to TASK-031 after the user answered six scoping questions. Design recorded in `knowledge/whiteboard/csv-aid-station-import.md`. Grew through the session as the user added a distinct **Warm food** service, full **notes** support, and **scroll-the-editor-into-view** — all folded into the one PR while it was unmerged.

**What I did:**
- New pure `AidCsv.elm` — `parse` + `toCsv`. Hand-rolled RFC-4180 tokenizer (`String.foldl` state machine) handling quoted fields, doubled quotes, CRLF/LF/CR, UTF-8 BOM, `,`/`;` delimiters, decimal comma. Lenient: header-or-positional column mapping; only `name` + distance required; `distance_km`/`distance_mi` (and `km`/`mi`/`miles`) picks the unit → metres on ingest; malformed *required* field drops the row, malformed *optional* field → warning + fallback (`rest` defaults from `AthleteProfile.aidStyleSecondsPerStation`). Returns `{ stations, errors, warnings }` for a preview.
- `Types.AidStation` gained `cutoff : Maybe Int` (elapsed seconds from start). Back-compat `D.oneOf [field, succeed Nothing]` decoder — no `.trail` version bump (same trick as `services`/`notes`).
- Race page: **Import CSV** (`File.Select` → `File.toString` → parse → preview panel → replace-with-confirm; `assignAidIds` continues `aidStationSeq` so a later manual add can't collide; plan is km-indexed so replace never orphans it) and **Export CSV** (`AidCsv.toCsv` via the existing `Download.file` port).
- 6th `Service` variant **WarmFood** (label "Warm food", 🍲, key `warm_food`). Compiler forced all five service functions; also updated the JS `SERVICE_EMOJI`/`SERVICE_LABEL` maps in `leaflet-element.js` (the one spot the compiler can't see).
- Full **notes**: notes were already parsed/exported/persisted but never shown or editable (manual form hardcoded `notes = ""`), so imports *looked* dropped. Added a notes textarea to the aid form and surfaced `aid.notes` in the aid list, import preview, **km table**, **section table**, and the per-km + per-section planning pages.
- New minimal `Dom.elm` port (`scrollIntoView` only — skipped the rest of the reference `DomEvents` surface). Fires on Add/Edit; JS defers one `requestAnimationFrame` so Elm has rendered the form first. Form has a stable id + `scroll-mt-4`.

**What I verified:**
- `npx elm make src/Main.elm --output=/dev/null` → `Success!`
- `npm run build` → `Success` (14 modules — the test harness is *not* bundled; `main.js` imports only `Main.elm`).
- `node scripts/smoke-aid-csv.mjs` → `PASS` (47 checks) driving the **real compiled** `AidCsv.parse`/`toCsv` via a `Platform.worker` harness (`src/AidCsvHarness.elm`): happy path, miles conversion, partial import + correct row numbers, BOM/CRLF/quoting/doubled-quotes, `;` + decimal comma, warm-food tokens (`soup`/`Hot Food` → `warm_food`, distinct from `food`), notes survival, `toCsv → parse` round-trip, and the shipped `samples/aid-stations-example.csv`.
- `npm run smoke` (storage) → `PASS` — cutoff field didn't regress IDB, incl. UTMB-size.
- Dev server boots (index + Elm `main.js` both HTTP 200); `scrollIntoView` present in the production bundle (port reachable → wired into `app.ports`); `scroll-mt-4` generated.
- **UI click-through done by the user** — the one gate I can't automate (no headless browser in the repo). User confirmed "good to be merged."

**What changed in the repo:** PR #53, squash-merged `422d118`, branch deleted. New: `AidCsv.elm`, `AidCsvHarness.elm`, `Dom.elm`, `scripts/smoke-aid-csv.mjs`, `samples/aid-stations-example.csv`. Edited: `Types.elm`, `Main.elm`, `leaflet-element.js`, `main.js`, `package.json` (+`smoke:aidcsv`).

**What I learned / gotchas:**
- **Verifying pure Elm logic from Node, faithfully.** The repo's prior pattern (`profile-trace.mjs`) re-implements logic in JS — tests a *copy*. For the parser I instead compiled a `Platform.worker` harness with `elm make`, evaluated the IIFE via `new Function(code).call(scope)` to capture `this.Elm`, and drove the real ports from a node script. Tests the actual shipped code without a browser. Worth reusing for future pure modules.
- **Port + render ordering.** Elm schedules its render rAF during `update` (before the port message reaches JS), so a single `requestAnimationFrame` in the JS handler runs *after* the form is in the DOM. No double-rAF needed.
- **"Dropped" was a display gap, not data loss.** Check the full path (parse → store → display) before assuming an import bug. Here parse/encode/persist were fine; the field was just never rendered and the form hardcoded it empty.
- **cutoff is elapsed-from-start, not clock time** — no race start-time-of-day field exists, so clock-time cutoffs can't compute margin. Deferred.

**Next:** Nothing queued. Candidate follow-ups (not promoted): clock-time cutoffs + race start-time field; margin-vs-cutoff warnings in planning; miles in the *manual* form; paste-a-table import (parser already supports it). Backlog parking-lot "Race-organiser bulk-import" struck — shipped by this task.

## 2026-06-09 — TASK-032: "Crew access" aid-station service

**Task:** Add a 7th `Service` category for stations where a runner's *personal
crew* may meet and assist them — a distinct crew-logistics planning signal,
independent of drop-bag / food / medical. Asked for by the user 2026-06-05;
scope locked in `CURRENT.md` (promoted via `cf6b3bf`).

**What I did:**
- `Types.Service` gained `Crew`. The compiler forced updates to `allServices`,
  `serviceToString` (`"crew"`), `serviceFromString`, `serviceLabel`
  ("Crew access"), `serviceIcon` (🤝). Manual-form chips and every services
  render site follow `allServices` automatically — no `Main.elm` changes.
- `AidCsv.serviceFromToken` maps the crew/assistance token family → `Crew`:
  `crew`, `crew access`, `crew allowed`, `crew point`, `crew permitted`,
  `support crew`, `assistance`, `assistance permitted`, `assistance allowed`,
  `personal assistance` (case/punctuation-insensitive via the existing
  normalizer). Unknown tokens still warn.
- `leaflet-element.js` `SERVICE_EMOJI`/`SERVICE_LABEL` gained `crew` — the one
  spot the Elm compiler can't see (same gotcha as TASK-031's warm food).
- `scripts/smoke-aid-csv.mjs` gained section J: crew-access category +
  aliases.

**What I verified (2026-06-09, pre-merge):**
- `npx elm make src/Main.elm --output=/dev/null` → `Success!`, exit 0.
- `npm run build` → `✓ built in 933ms`.
- `npm run smoke` → `SMOKE PASSED · IndexedDB schema + save/load/delete
  round-trips work, including UTMB-size payloads.`
- `npm run smoke:aidcsv` → `PASS — all aid-csv checks green`, incl. new
  section J: `"crew" -> crew`, `"assistance permitted" -> crew`,
  `"Crew Access" -> crew (case-insensitive)`, `combined with water`.
- User reviewed the branch and said it was ready to merge.

**What changed in the repo:** PR #55, squash-merged `9f4a54f`, branch deleted.
Edited: `Types.elm`, `AidCsv.elm`, `leaflet-element.js`,
`scripts/smoke-aid-csv.mjs` (+ `CURRENT.md` promote).

**What I learned / gotchas:** Nothing new — this was the warm-food playbook
(TASK-031) replayed for a new variant: Elm compiler drives the exhaustive
spots, `leaflet-element.js` is the manual checklist item, smoke locks the CSV
tokens in.

**Next:** Nothing queued. Pick the next task from `BACKLOG.md`.

---
## 2026-06-09 17:33 — TASK-033: knowledge-base tidy (review findings)

**Task:** TASK-033 — first half of a user request: review/tidy `knowledge/`, then split framework from project-specific content and extract it with pluggable features (TASK-034).
**What I did:** Ran a systematic review of the knowledge base — four dimensions (cross-reference integrity, internal consistency, staleness vs git history, framework soundness) plus a framework-vs-project classification of every file; 35 raw findings, each adversarially verified, 18 confirmed / 17 refuted. Fixed the confirmed set: created `reference/local-ci.md` (the "once defined" file three docs pointed at was never created — the real gates lived only in journal prose), dropped the phantom "lint" step from CI phrasing, removed `pr-workflow.md`'s `--merge` escape hatch (contradicted the brief's hard squash constraint; 0 merge commits in 58 anyway), codified the `docs/task-NNN-close` bookkeeping-PR convention (Rule 1 made post-merge planning updates technically impossible — practice existed, doc didn't), backfilled DONE/journal placeholders, removed a duplicate DONE stub, added a CURRENT.md entry template, documented BACKLOG's checked-in-place + TASK-id conventions, populated the glossary (empty for 32 tasks), added `whiteboard/` to CLAUDE.md's quick map, rewrote stale CSV-whiteboard follow-ups past-tense.
**What I verified:**
- All four local-ci gates run before documenting them: `npx elm make src/Main.elm --output=/dev/null` → "Success! Compiled 2 modules."; `npm run build` → "✓ built in 977ms"; `npm run smoke` → "SMOKE PASSED"; `npm run smoke:aidcsv` → "PASS — all aid-csv checks green".
- Shas against `git log`: PR #43 = `8449767`, TASK-015 = PR #18 `b451e1e`.
- Grep sweep: no unintended `<sha>` / `PR #N` / "once defined" / "types + lint" / `--merge` remain; every knowledge-path reference resolves (only the intentional `decisions/NNNN-slug.md` template pattern).
**What changed in the repo:** PR #57, merged `de1b946`. 12 files, +128/−33, docs only.
**What I learned:** The refuted findings were as valuable as the confirmed ones — three "bugs" (checked-in-place BACKLOG, point-in-time whiteboard entries, deleted screenshot refs) turned out to be designed conventions that were simply undocumented. The fix for an undocumented convention is to write it down, not to "repair" the files. Also: the close-PR convention had been practiced since TASK-031 but documented nowhere — exactly the kind of gap that bites a memoryless future session.
**Next:** TASK-034 — framework/project split + extraction with pluggable delivery modules. Design panel (3 adversarial lenses) running; criteria from its output.

---
## 2026-06-09 17:58 — TASK-034: the framework extracted, delivery made pluggable

**Task:** TASK-034 — second half of the 2026-06-09 user request (first half: TASK-033 tidy).
**What I did:** Split `knowledge/` into the reusable framework (`knowledge/framework/`, 7 flat files) and trail instance content. `pr-workflow.md` generalized into `framework/delivery.md` with three profiles — `pr` (trail's full branch → PR → self-merge cycle), `commits` (commit but no branch/PR management), `none` (agent never mutates VCS; exact command policy, read-only git allowed, no checkout-based undo). Per-task overrides ("you may make several commits for this one") are valid only when recorded in the CURRENT.md task entry, expire with the task, never imply push/force/PRs, and are bounded by manifest hard constraints. Undeclared delivery mode fails safe to `none`. `knowledge/README.md` became the project manifest (greppable `delivery: pr` + operative meaning, project rules incl. user-only attribution and the Batman/squash specifics that left the framework docs, the loop instantiated for trail, and the instance-free guard). CLAUDE.md now states the reading chain manifest → framework README → enabled profile. Tombstone at `philosophy/README.md`; historical journal/DONE paths intentionally untouched.
**Design process:** proposed structure was adversarially reviewed by a 3-lens panel (fresh-agent bootstrap, reuse/drift, minimalism) before any file moved. Biggest calls the panel changed: one `delivery.md` with profiles instead of four module files; SETUP.md with inline skeletons instead of a `templates/` tree (filename collisions + never-exercised copies breed staleness); flat framework dir; undeclared = `none`.
**What I verified:**
- Instance-free guard: `grep -riE '\btrail\b|\belm\b|batman|gillchristian|coros|samples/' knowledge/framework/` → "GUARD CLEAN" (word boundaries because "trailers"/"trailing" are unavoidable English).
- Two fresh-agent dry-runs, both verdict "holds-up": (a) trail-chain probe answered all 8 questions correctly with citations (squash-only, close-PR flow, attribution re-check at delivery moment, unrecorded override not in effect); (b) literal SETUP.md adoption in /tmp/dryrun-workproj as a delivery-none corporate project — installed system forbade commit/stash, defined hand-off delivery, handled the "several commits" grant correctly. Six findings from the dry-runs fixed before merge (override-vs-hard-constraint precedence now explicit in delivery.md §4; loop step 8 sync wording; SETUP empty-brief path; version-line location; DONE-skeleton redundancy under none; verification gate 5 phrasing).
- Local CI: elm make "Success!", build "✓ built in 970ms", smoke "SMOKE PASSED", smoke:aidcsv "PASS".
**What changed in the repo:** PR #59, merged `bc0214f`. 15 files, +709/−167. Four philosophy docs register as git renames; delivery.md diverged too far from pr-workflow.md for default rename detection (`--follow --find-renames=30%` recovers the lineage).
**What I learned:** The dry-run-as-verification pattern (have a fresh agent literally follow SETUP.md in a temp dir) caught real gaps that inspection missed — notably that nothing said whether a recorded override can defeat a manifest hard constraint. Also: a mechanical instance-free grep needs word boundaries from day one; "Co-Authored-By trailers" contains "trail".
**Next:** Nothing active. The framework is adoptable elsewhere by copying `knowledge/framework/` + following SETUP.md; publishing it as its own repo is the user's call. Product work resumes from BACKLOG parking lot / Proposals.

---
## 2026-06-09 18:18 — TASK-035: the labyrinth principle

**Task:** TASK-035 — user follow-up to the framework session: Videla's "Notes on the synthesis of labyrinths" partly defines the philosophy; include the idea, not the article.
**What I did:** Added principle 7 to `framework/principles.md` — "Record the maze, not just the exit": dead ends and the reasoning at each fork are part of every artifact's deliverable; prescription says what, description says why. The framework already practiced this piecemeal (journal "failed attempts are the most useful entries", ADR "alternatives considered", whiteboard's whole purpose) but never named the shared value. Added a "Paths not taken" bullet to `working-style.md`'s communication section with the article's own elocutio caveat folded in (amplify dead ends that carried a lesson, abbreviate the rest — curate, don't dump). Article kept at `reference/labyrinth.md` on the instance side; the framework cites the published work by author/title so copies stay self-contained. Framework bumped v1 → v2 in both stamp locations — first real exercise of the upstream-change convention.
**What I verified:** instance-free guard → "CLEAN"; `reference/labyrinth.md` exists and all new cross-references resolve; local CI: elm make "Success!", build "✓ built in 979ms", smoke "SMOKE PASSED", smoke:aidcsv "PASS".
**What changed in the repo:** PR #61, merged `af65751`. 7 files, +97/−12.
**What I learned:** Deliberately cited the principle by *name* in working-style.md, not by number — minutes after verifying nothing cites principle numbers, I nearly introduced the first numeric citation myself. Renumbering-safe references are a one-word habit.
**Next:** Nothing active. Product work resumes from BACKLOG parking lot / Proposals.

---
## 2026-06-10 08:18 — Doc-vs-code audit → queued TASK-036/037/038

**Task:** User request after the framework session — re-review the code so the
docs stay accurate (code is the source of truth), then queue the fixes.
**What I did:** Ran an 11-area doc-vs-code audit as a verification workflow
(one auditor per doc area + a reverse auditor for undocumented features; every
raw finding re-checked by two independent skeptics told to refute it; a
completeness critic swept for unread docs). 54 raw findings → **39 confirmed,
5 split-vote (adjudicated by hand), 10 refuted**. Grouped the confirmed set
into three doc-fix tasks and queued them in `BACKLOG.md` Active (unchecked),
each carrying its file:line evidence inline:
- **TASK-036** — ship-status sync: the predictor/Strava track shipped, but the
  roadmap header, cadence spec + addendum, BACKLOG's own Proposals section, and
  a whiteboard doc still frame TASK-014..021 / 024 / 026 as pending.
- **TASK-037** — `project-brief.md` + `glossary.md` rewrite: "No backend, ever"
  is now false; three shipped features undocumented; **VMH defined wrong**
  (glossary says flat km/h, code uses it as vertical m/h of climb).
- **TASK-038** — ADR-0002/0003 + cadence-spec + local-ci + MORNING accuracy
  fixes (un-normalized slope-factor table, nonexistent "Reset plan", streams
  `data` nesting, undocumented global-Elm prereq, dev port 5174 not 5173, …).
**What I verified:** Docs-only change; ran all four local-CI gates green —
`npx elm make … --output=/dev/null` → "Success!", `npm run build` →
"✓ built in 939ms", `npm run smoke` → "SMOKE PASSED", `npm run smoke:aidcsv`
→ "PASS — all aid-csv checks green". Next TASK id confirmed 036 (highest
existing = TASK-035).
**What changed in the repo:** PR #63, merged `616797a` (the queueing); this
close PR carries the journal entry + the CURRENT.md orientation note.
**What I learned:** The refuted/split findings mattered as much as the
confirmed ones — the roadmap's *appendix* predictor formulas do match the code
(refuted), so only the status *headers* are stale, not the math; and the
roadmap §10 "suggested task breakdown" is explicitly aspirational, so listing
shipped tasks there isn't a defect. The raw audit output was a transient
workflow artifact (temp dir, GC'd), so the durable record is the inline
evidence in the three backlog entries — not a saved report. If the full
39-item detail is ever wanted, re-run the audit or capture it to `reference/`.
**Next:** Three doc-fix tasks queued; none pulled into `CURRENT.md` pending a
user go-ahead on which to start. TASK-036 is the cheapest win (pure
status-flips); TASK-037 fixes the most load-bearing doc (the brief).

---
## 2026-06-10 08:36 — TASK-036: ship-status sync across docs

**Task:** TASK-036 — first of three 2026-06-10 doc-vs-code audit fixes (user
go-ahead to clear all of 036/037/038).
**What I did:** Flipped stale "still a proposal" framing in the docs to match
shipped reality. `pace-prediction-roadmap.md`: status header → "largely
implemented (only TASK-022 open)"; §0 bullets + §2 diagram/"how it landed" +
§12 "what this doc is" rewritten from proposed→shipped; §8 line-296 promise to
update the brief "when TASK-024 lands" now records that TASK-024 shipped
(PR #25/#26) and the brief rewrite is tracked by TASK-037.
`cadence-backend-spec.md`: header → "implemented" (cadence shipped all 5 PRs;
trail consumes via `StravaApi`/`StravaStreams`); §9 trail-side list marked
built. Addendum-1: the two spots treating trail's TASK-024 as unshipped flipped
(its *own* cadence-side scope change stays pending — genuinely unshipped).
BACKLOG Proposals: TASK-014..021 struck through + PR-annotated to match the
TASK-023/024 convention, leaving only TASK-022. `training-as-analysis.md`:
TASK-026 no longer "Queued" (PR #35).
**What I verified:** Code is the source of truth, so I confirmed the claims
before editing: `Predictor.predict : Profile -> Race -> List Km -> Float ->
Prediction` at `src/Predictor.elm:53`; `StravaApi.elm` exposes
`fetchActivities`/`fetchStreams` against the live cadence endpoints. Grep:
no `not yet greenlit` / `exploration only, nothing committed` / `Queued in
BACKLOG` / `proposed, Layer B` strings remain in live docs (only the task
descriptions quote them as evidence). Local CI all green — `elm make` →
"Success!", `npm run build` → "✓ built in 935ms", `npm run smoke` → "SMOKE
PASSED", `npm run smoke:aidcsv` → "PASS — all aid-csv checks green".
**What changed in the repo:** PR #65, merged `7b8455f`. 6 files (docs only):
the two cadence specs, the roadmap, BACKLOG, whiteboard, + CURRENT criteria.
This close PR carries DONE/BACKLOG-tick/journal and orients TASK-037 into
CURRENT.
**What I learned:** Kept the addendum's top-level status pending on purpose —
the *trail* TASK-024 it references shipped, but the addendum is about a
cadence-side `profile:read_all` scope change that's still awaiting hand-off to
a cadence session (per BACKLOG TASK-023 note). Flipping the whole header would
have over-claimed. The audit's refuted findings held: the roadmap appendix
formulas match the code, so only the *status* framing was stale, not the math.
**Next:** TASK-037 — rewrite `project-brief.md` + `glossary.md` (incl. the VMH
definition fix: glossary says flat km/h, code uses vertical m/h of climb).
Criteria already in CURRENT.md.

---
## 2026-06-10 08:44 — TASK-037: brief + glossary rewrite

**Task:** TASK-037 — second of three 2026-06-10 doc-vs-code audit fixes.
**What I did:** Rewrote the two most load-bearing reference docs to match the
code. `project-brief.md`: the "No backend, ever" / "No backend / multi-user /
sync" constraints (which the live Strava integration flatly contradicted) now
carry the roadmap's agreed hybrid wording — Layer 0 fully local, Layer 1
opt-in Strava sync via the shared `cadence` backend (which holds no trail
state, offline-degrading). Added a "Features shipped beyond the original list"
section (plan-vs-actual + HR, athlete profile + predictor, aid CSV); fixed
feature 10 (map is the `<trail-map>` custom element, *not* a JS port) and the
stack drifts (`Browser.application` not `.element`; IDB ~100 lines / 2 stores
not ~50 / 1; km-only is a UI rule — CSV import accepts `distance_mi`).
`glossary.md`: **VMH was defined backwards** — "flat-ground speed (km/h)" — when
the code uses `verticalRateVmh` as a vertical *climb* rate (m ascent/hour),
`climb = gain / (VMH × intensity)`. Redefined it, added **flat trail pace**
(`flatTrailPaceSecPerKm`) as the genuinely-flat rate it was confused with, and
added the user-visible card terms (distance category S/M/L/XL, elevation
density, flat-equivalent distance).
**What I verified:** Code is the source of truth — confirmed every claim before
writing: `Browser.application` (`Main.elm:83`), two object stores in 256-line
`src/main.js`, `<trail-map>` via `customElements.define` (`leaflet-element.js:217`),
`distance_mi`/`miles` in `AidCsv.elm`, `verticalRateVmh` "m of climb per hour"
(`AthleteProfile.elm:47`) used as `gain/(vmh*i)` (`Predictor.elm:114`),
`distanceCategory`/`elevationDensity`/`equivalentFlatKm` in `Main.elm`. Local
CI all green — elm make "Success!", build "✓ built in 1.01s", smoke "SMOKE
PASSED", smoke:aidcsv "PASS".
**What changed in the repo:** PR #67, merged `73b206f`. 2 docs (brief, glossary)
+ CURRENT criteria. This close PR carries DONE/BACKLOG-tick/journal and orients
TASK-038.
**What I learned:** The VMH error was the sharpest find of the audit — a future
session sizing a climb-rate field off the glossary would have built the wrong
model (treating a vertical-ascent-rate as a flat ground speed). The fix names
both rates explicitly so they can't be conflated again. Kept "kilometre" →
"kilometer" American spelling to match the brief's existing usage rather than
introduce a second spelling in one doc.
**Next:** TASK-038 — ADR-0002/0003 + cadence-spec + local-ci + MORNING accuracy
fixes. All claims already verified this session; criteria in CURRENT.md. Note:
the `Planning.elm:323` *code comment* repeats ADR-0003's un-normalized
slope-factor error — TASK-038 is docs-only so I'll log it as a parking-lot
follow-up rather than touch `src/`.

---
## 2026-06-10 08:52 — TASK-038: ADR/CI/MORNING accuracy fixes (audit queue cleared)

**Task:** TASK-038 — last of three 2026-06-10 doc-vs-code audit fixes. Clears
the BACKLOG Active queue.
**What I did:** Fixed concrete technical inaccuracies across six docs, each
claim verified against code first. ADR-0003: the slope-factor properties table
listed *un-normalized* `exp(3.5·|s+0.05|)` values (f(+0.10) shown as 1.687) and
implied symmetry about 0 — replaced with the normalized values that match
`Planning.slopeFactor` (f(+0.10)=1.419, f(−0.10)=1.000=flat) and stated the
real symmetry axis s=−0.05; dropped the nonexistent "Reset plan" row (only
per-km `ResetKmToAuto` exists) and corrected the all-Manual row (the committed
target is *kept*, not replaced by the sum); noted the slope divisor is the
window length (last km partial) not a fixed 1000 m + the independent-rounding
drift. ADR-0002: `sym` is auto-derived from services (`symbolForAid`; no UI
picker; no-services default "Flag, Blue" not Restaurant), `<desc>` example fixed
to `buildDesc`'s real `Km X · services · Rest m:ss` form, removed the
nonexistent "Aid N" name fallback. cadence-spec + addendum: streams example now
shows the `{"data":[…]}` per-key nesting `StravaStreams.streamData` actually
decodes (a client built from the old flat-array example couldn't decode the
real response); env var `VITE_BACKEND_URL`; "fields flow through to settings"
reframed (trail has no `/api/athlete` client yet); "§14.2" citation repointed
from the roadmap (no §14) to `archive/trail_race_planner_spec.md`. local-ci.md:
added a Prerequisites section (global Elm 0.19.1 — not an npm dep, so
`npm install` alone can't run gates 1/2/4 — plus the Node v22 `.nvmrc` pin) and
scoped the storage-smoke claim to the v1 `races` store. MORNING.md: frozen
2026-05-15 historical banner, dev port 5174, parking lot is mid-BACKLOG, stale
nvm-22 caveat refreshed.
**What I verified:** Recomputed the slope factors via node (f values + symmetry
about −0.05 confirmed). Code-checked every claim: `ResetKmToAuto` only
(`Main.elm:860`); `effectiveTargetSeconds` returns the committed `Just s`
(`Main.elm:6511`); `slope = (eleEnd-eleStart)/distance` window-length
(`Planning.elm`); `symbolForAid` else→"Flag, Blue" (`GpxExport.elm:112`);
`buildDesc` format; `streamData` decodes `field key (field "data" …)`
(`StravaStreams.elm`); `VITE_BACKEND_URL` (`main.js:16`); no `/api/athlete` in
`StravaApi`; archive spec §14.2 exists, roadmap has none; `.nvmrc`=v22, elm
absent from `package.json`. Local CI green — elm make "Success!", build "✓ built
in 975ms", smoke "SMOKE PASSED", smoke:aidcsv "PASS".
**What changed in the repo:** PR #69, merged `9529c01`. 6 docs + CURRENT
criteria. This close PR carries DONE/BACKLOG-tick/journal, empties CURRENT (audit
queue cleared), and queues one parking-lot follow-up.
**What I learned:** The slope-factor table was wrong in an instructive way — it
mixed normalized rows (f(0), f(−0.05)) with un-normalized ones (f(+0.10),
f(±0.20)), which is exactly how the "either way / symmetric about 0" error crept
in. The `Planning.elm:323` *code comment* has the identical mistake; kept
TASK-038 docs-only and queued the one-line comment fix to the parking lot rather
than smuggle a `src/` change into a docs task. Goal met: all three audit doc-fix
tasks (036/037/038) shipped + closed; BACKLOG Active is empty.
**Next:** Nothing active. BACKLOG Active is clear. Future work: parking lot
(incl. the new slope-comment fix + the older section-overlap bug) or the lone
open Proposal TASK-022 (predictor calibration) — needs explicit user go-ahead.

---
## 2026-06-15 12:42 — Queue a five-task batch (user request); orient TASK-039

**What I did:** The user promoted five backlog items in one go and asked me to
work them one at a time, each its own PR. Queued them into BACKLOG Active
(`[ ]`, in execution order): **TASK-039** section-overlap double-count fix,
**TASK-040** separate `gpxText` into its own IDB row, **TASK-041** the
`Planning.elm` slope-factor *comment* fix (the follow-up TASK-038 deferred),
**TASK-042** print-friendly planning-table export, **TASK-022** calibration
from past activities. Next id was 039 (highest anywhere was 038); TASK-022 keeps
its existing Proposals id. Annotated the four promoted parking-lot bullets
(struck + `→ promoted as TASK-0NN`), keeping the not-promoted section-card Δ
sub-note parked. TASK-022's Proposals entry + the "needs go-ahead" gate updated
to record the explicit user go-ahead (2026-06-15). Oriented **TASK-039** into
CURRENT.md with full acceptance criteria.
**What I verified:** Baseline before any change — `elm 0.19.1`, `node v22.19.0`,
tree clean, `npx elm make src/Main.elm --output=/dev/null` → "Success!". Read
`Planning.elm` end-to-end + the Main.elm section-consumption sites
(`sectionsWithCumulative` 5049, `viewSectionCardAndDetails` 5231,
`sectionActualSeconds` 6332) and `Csv.elm:170/188` to map the double-count blast
radius before writing TASK-039's criteria. This is a docs/planning-only PR.
**What changed in the repo:** queue PR (docs) — `BACKLOG.md` (+5 Active, parking
lot + Proposals annotations), `CURRENT.md` (TASK-039 oriented), this entry.
**Plan/order:** 039 → 040 → 041 → 042 → 022. 039/041 both touch `Planning.elm`
but different functions (no conflict; rebase between). 022 is Large → split into
sub-tasks when oriented.
**Next:** Implement TASK-039 on `fix/task-039-section-overlap`.

---
## 2026-06-15 12:57 — TASK-039: section-overlap double-count fix

**Task:** TASK-039 — first of the five-task batch. Fix the section-overlap
double-count in `Planning.sectionsForRace`.
**What I did:** `sectionsForRace` grouped kms into sections with an overlap test
`km.distStart < b && km.distEnd > a`. A 1 km window straddling an aid distance
`b` matched it for both the section ending at `b` and the one starting at `b`,
so its index landed in two `kmIndices` lists and `sumKmField` (which ignored its
`a`/`b` args) summed its gain/loss twice. Blast radius confirmed by reading the
consumers first: `sectionSeconds` (`Main.elm:5060`/`5236`), the cum column
`runningAfterSection` (`5071`), `section.gain`/`.loss` (`5109-5110`/`5357-5360`),
`containedKms` (`5234`), `sectionActualSeconds` (`6332`), and section-mode CSV
(`Csv.elm:188`). Fix: group each km into the single section whose half-open
`[a, b)` interval contains its **midpoint** `(distStart+distEnd)/2` — a clean
partition. Dropped `sumKmField`'s now-unused `a`/`b` params; rewrote both
misleading comments (the old one *claimed* center-based assignment the code
never did).
**What I verified:** New `npm run smoke:sections` (`src/SectionsHarness.elm` +
`scripts/smoke-sections.mjs`, mirroring `AidCsvHarness`) drives the REAL compiled
`Planning.sectionsForRace` and asserts, across straddle / on-boundary / no-aid /
gain+loss scenarios: clean partition (flattened `kmIndices` == `[0..n-1]`), Σ
section gain/loss == course totals, Σ section distance == total. All 20 checks →
`PASS — all section-partition checks green`. **Failure case proven:** temporarily
reverting the filter to the overlap test made scenario A fail exactly as
predicted (`[[0,1],[1,2,3],[3,4]]`, Σ gain 700 not 500) and D (350/560 not
250/400) while on-boundary + no-aid stayed green — so the test catches the bug
and the fix touches only straddle behavior. Full local CI green: elm make
`Success!`, build `✓ built in 853ms`, smoke `SMOKE PASSED`, smoke:aidcsv `PASS`,
smoke:sections `PASS`.
**What changed in the repo:** PR #72, merged `633e263`. `src/Planning.elm` (fix),
`src/SectionsHarness.elm` + `scripts/smoke-sections.mjs` + `package.json` (new
gate), `knowledge/decisions/0004-section-km-attribution.md` + INDEX, `local-ci.md`
+ manifest (5th gate). This close PR (`docs/task-039-close`) moves it to DONE,
ticks BACKLOG, and orients TASK-040.
**What I learned:** Reviewing the diff before committing caught a duplicated
comment block — my "revert to overlap to prove the test fails, then restore" dance
left two copies of the new comment (the revert removed only the filter, not the
comment; the restore re-added it). Collapsed to one and re-ran the gates. The
midpoint partition also unblocks the still-parked section-card Δ-vs-plan fix.
Chose midpoint over pro-rating (ADR-0004): per-km plan seconds are indivisible
and pro-rating gain/loss honestly needs the elevation re-sampled at the split —
not worth it for planning.
**Next:** TASK-040 — separate `gpxText` into its own IDB row. Oriented in
CURRENT.md (studied `main.js`/`Storage.elm`/`Types.elm` + the 14 saveRace sites
to scope it). Branch `refactor/task-040-gpx-store`.

---
## 2026-06-15 13:14 — TASK-040: gpxText in its own IDB row (v3 + migration)

**Task:** TASK-040 — batch task 2 of 5. Stop re-shipping the ~3 MB GPX on every
plan/aid edit.
**What I did:** Reading first confirmed the shape + a trap: `RaceSaved` decodes
the save echo as a full `Race` and rebuilds the track/kms caches from
`race.gpxText`, and the edit sites return `model` unchanged (they *rely* on that
echo) — so a light echo can't simply drop gpxText. And site 1476, named
`newRace`, is actually the **SliderCommit edit** (the headline hot path), not a
creation. Final split: 2 creation sites (`.trail` + GPX import) vs 12 edits.
Implementation: new `gpx` IDB store (`{id, gpxText}`), DB v2→v3 with an
`onupgradeneeded` cursor migration that moves inline GPX out of each races row.
`Types`: extracted `raceMetaFields` shared by `encodeRace` (appends gpxText) and
new `encodeRaceMeta` (omits it) so they can't drift; decoder defaults gpxText to
`""`. `Storage`: new `saveRaceMeta` port. `main.js`: `loadAllRaces` joins gpx
back; `saveRace` (full) writes both stores + echoes full; `saveRaceMeta` (light)
writes only the races row; `deleteRace` clears both (no orphan). `Main`:
`RaceSaved` refills gpxText from the in-model race when the echo omits it; routed
the 12 edit sites to the light save.
**What I verified:** Rewrote `smoke-storage.mjs` into a faithful v3 mirror of
`main.js` — 24 checks: split (races row has no gpxText, gpx row holds it), full
+ light save, **light save leaves the gpx row untouched** (the win), orphan-free
delete, and **v2→v3 migration** of a 2.29 MB GPX → `SMOKE PASSED`. Type-check
`Success!`, build `✓ built in 882ms` (compiles main.js), smoke:aidcsv `PASS`,
smoke:sections `PASS`. Confirmed the compiled bundle emits the new
`storageSaveMeta` port (so the JS `subscribe` binds — wiring is real, not just
type-checked); dev server boots `HTTP 200`. **Gap, stated honestly:** the
human browser round-trip (import→edit→reload) wasn't run — the project can't
drive the compiled Elm bundle from Node (the smoke's standing limitation), so
storage has always shipped on the JS-mirror smoke. The migration runs in an
atomic versionchange tx (a mid-migration error aborts → v2 data intact), and the
smoke tests that exact code, so the risk is bounded; flagged a manual browser
pass as the recommended final check in the PR.
**What changed in the repo:** PR #74, merged `a922894`. `Types.elm`,
`Storage.elm`, `main.js`, `Main.elm` (the split), `smoke-storage.mjs` (rewrite),
ADR-0005 + INDEX + `local-ci.md`. This close PR moves it to DONE, ticks BACKLOG,
orients TASK-041.
**What I learned:** Two reading-caught traps (the echo dependency + the
mis-named `newRace` slider-commit site) would each have been a data/behavior bug
if I'd routed by variable name or dropped the echo. The shared `raceMetaFields`
list is the durable guard against the two encoders drifting. Also added
`deleteRace` two-store cleanup (orphan GPX) — a gap the split introduced that
wasn't in the original scope but is clearly entailed.
**Next:** TASK-041 — fix the `Planning.elm` `slopeFactor` docstring (un-normalized
values). Trivial, comment-only; recomputed the values (f(+0.10)=1.419, symmetric
about −0.05). Oriented in CURRENT.md. Branch `fix/task-041-slopefactor-comment`.

---
## 2026-06-15 13:19 — TASK-041: slopeFactor docstring fix (batch task 3/5)

**Task:** TASK-041 — correct the un-normalized values in the `slopeFactor`
docstring (the follow-up TASK-038 queued, held back because it touches `src/`).
**What I did:** Recomputed the normalized factors via node (f(0)=1.000,
f(−0.05)=0.839, f(+0.10)=1.419, f(−0.10)=1.000, f(+0.20)=2.014, f(−0.20)=1.419),
then rewrote the docstring: symmetric about s=−0.05 (not "either way" about 0),
f(+0.10)≈1.42 / f(+0.20)≈2.01 / f(−0.20)≈1.42. Kept the already-correct f(0)=1.0
and s=−0.05-minimum lines. `grep -rniE "1\.69|2\.40|either way|1\.687" src/`
confirmed these two lines were the only stale copies.
**What I verified:** Comment-only diff (`git diff` showed just the 3 docstring
lines). All five gates green: type-check `Success!`, build `✓ built in 858ms`,
smoke `SMOKE PASSED`, smoke:aidcsv `PASS`, smoke:sections `PASS` (slopeFactor's
body is untouched, so behavior — and the section/aid smokes — are unchanged).
**What changed in the repo:** PR #76, merged `c580bdf`. `src/Planning.elm` only.
This close PR moves it to DONE, ticks BACKLOG, orients TASK-042.
**What I learned:** Nothing surprising — recomputing (rather than trusting
ADR-0003 transitively) means the docstring and the ADR now both trace to the
same fresh computation. The doc-drift trio (036/037/038) plus this finally retire
the un-normalized 1.69/2.40 numbers everywhere.
**Next:** TASK-042 — print-friendly planning table. Scoped from `viewPlanTable`
(`Main.elm:4082`) + `app.css` (Tailwind v4, `print:` variants available).
Approach: `print:hidden` chrome + `@media print` table restyle + a `window.print()`
port button. Visual acceptance needs a human (env can't render print preview) —
flagged. Branch `feat/task-042-print-plan`.

---
## 2026-06-15 13:31 — TASK-042: print-friendly plan table (batch task 4/5)

**Task:** TASK-042 — print the plan table cleanly on paper.
**What I did:** New `Dom.print` port → `window.print()` (Elm can't call it), wired
a **Print** button next to Download CSV. Hid chrome with Tailwind's `print:hidden`
variant (app header, footer, breadcrumb, and — wrapped in one `print:hidden` div
at the `viewPlanTable` call site to preserve on-screen order + `space-y-6`
spacing — the target panel, predictor slider, actual-run strip; plus the
tabs/buttons row). Wrapped the printable race-header + table in `.plan-print` and
added an `@media print` block in `app.css`: white bg, black text, `1px` cell
borders, `thead{display:table-header-group}` (header repeats per page),
`tr{break-inside:avoid}`, compact 11px table font, `@page{margin:1.5cm}`.
**What I verified:** Type-check `Success!`, build `✓ built in 827ms`, smoke
`SMOKE PASSED`, smoke:aidcsv `PASS`, smoke:sections `PASS`. Confirmed the built
bundle wires `window.print` and the built CSS carries the `.plan-print` /
`table-header-group` / `break-inside` rules. On-screen unchanged (the wrapper is
visually inert — `print:` only applies in print media; spacing preserved).
**Caught while editing:** first compile failed — `Dom.print` is a port of type
`() -> Cmd msg`, so the handler needed `Dom.print ()`, not `Dom.print`. Fixed.
**Honest gap:** the actual print-preview legibility (does it look good on paper?)
is the real acceptance and the headless env can't render it — implemented the
conventional low-risk print-stylesheet pattern and flagged a manual ⌘P review in
the PR. Same class of gap as TASK-040's browser round-trip.
**What changed in the repo:** PR #78, merged `c2d30b4`. `Dom.elm`, `Main.elm`,
`main.js`, `app.css`. This close PR moves it to DONE, ticks BACKLOG, and **splits
TASK-022** (calibration) into per-fit sub-tasks, orienting TASK-043.
**What I learned / decided about TASK-022:** Read roadmap §7/§9/§10 + the data
shapes. §9's "open questions" are mostly already resolved by shipped work (one
global profile, continuous slider, loud confidence, actual-as-column, hybrid
local-first); only calibration-transparency (#7) is open and the roadmap answers
it (transparent/opt-in). So no user blocker — proceed with an ADR. Split TASK-022
per the roadmap ("split into per-fit subtasks"): **TASK-043 = vmh** (the #1
value-per-effort fit, replaces the core hand-set climb rate, feasible from
existing linked-actual data: course gain via `kmsCache` + `actualSplits.splits`),
TASK-044 = flat pace (queued), remaining fits left in roadmap §7 (data-gated).
**Next:** TASK-043 — `Calibration.fitVmh` (pure, harness-tested) + a transparent
calibrate panel on `#/profile`. Oriented in CURRENT.md. Branch
`feat/task-043-vmh-calibration`.

---
## 2026-06-15 13:42 — TASK-043: vmh calibration (batch task 5/5 — batch complete)

**Task:** TASK-043 — first calibration fit (climb rate from linked runs); first
slice of the TASK-022 epic.
**What I did:** New pure `Calibration.elm` (`fitVmh`): over climb kms (course
gain ≥ 30 m with a positive recorded time) across the user's linked actual runs,
`vmh = Σ gain / (Σ seconds / 3600)` — the gain-weighted realized climb rate;
returns value + climb-km/run counts or `Nothing`. Uses data already held
(`kmsCache` gain + `actualSplits.splits`); no new fetching. Surfaced on
`#/profile` via a transparent opt-in panel (`viewCalibrationPanel`): fitted rate
+ contributing run names + current value → explicit Apply (`CalibrateVmh` sets +
persists `verticalRateVmh`); hint when nothing's linked. Helpers
`linkedRunsWithRace`/`linkedRuns`/`calibrationContributors`. ADR-0006.
**What I verified:** New `smoke:calibration` harness drives the REAL compiled
`fitVmh` — 17 checks: gain-weighting (1421/1000/1080 m/h for known inputs), the
30 m threshold cut, skipping kms with no/zero recorded time, `null` for no data,
multi-run aggregation → `PASS`. type-check `Success!`, build `✓`, smoke / aidcsv
/ sections all green. `CalibrateVmh` + the panel strings present in the compiled
bundle. **Gap:** the UI click-path (link run → Apply → field updates + persists)
isn't headless-testable — fit logic fully smoke-tested + wiring type-checks;
flagged a manual check.
**What changed in the repo:** PR #80, merged `819e9dc`. `Calibration.elm`,
`CalibrationHarness.elm`, `smoke-calibration.mjs`, `package.json`, `Main.elm`,
ADR-0006 + INDEX + `local-ci.md`. This close PR moves it to DONE, ticks BACKLOG,
and **clears CURRENT — the five-task batch is complete.**
**Batch summary (user promoted 5 on 2026-06-15, one PR each + close PR):**
TASK-039 section-overlap fix (#72) · TASK-040 gpxText IDB split + v2→v3 migration
(#74) · TASK-041 slopeFactor docstring (#76) · TASK-042 print-friendly table
(#78) · TASK-043 vmh calibration (#80, first slice of the TASK-022 epic). Added
ADRs 0004/0005/0006 and three CI gates (`smoke:sections`, `smoke:calibration`,
expanded storage `smoke`). Two manual checks recommended (headless env can't do
them): browser round-trip after the TASK-040 IDB migration; print-preview of the
TASK-042 table.
**What I learned:** Calibration's §9 "open questions" turned out mostly resolved
by shipped work — the disciplined move was to read the roadmap before assuming
the user needed to weigh in, then proceed with an ADR for the one real choice
(transparency). The pure-fit + harness pattern (shared with sections) made the
risky part (the math) the well-verified part.
**Next:** Nothing active — batch complete. BACKLOG has TASK-044 (flat-pace
calibration) + the further roadmap §7 fits + parking-lot items, each needing only
selection (calibration fits want a per-fit user go-ahead). Surfacing the two
recommended manual checks + the queued calibration work to the user.

---
## 2026-06-15 14:18 — TASK-044: flat-trail-pace calibration (core rates done)

**Task:** TASK-044 — second calibration fit; user said "continue on the
recalibration" after TASK-043 (and confirmed vmh on their real data: 616 m/h).
**What I did:** Added `Calibration.fitFlatPace` — over runnable kms (the
predictor's own band, `abs slope < 0.04`, `Predictor.elm:98`) with a positive
distance + recorded time, `pace = Σ distance / Σ time` (s/km). Same realized-rate
method as vmh. Extended the harness/smoke to carry per-km slope+distance and
return both fits (made the harness `gain` decoder optional so flat-only specs
parse). Restructured the `#/profile` panel into two rows via a shared `calibRow`
(climb rate + flat pace), each with its own Apply (`CalibrateFlatPace` sets +
persists `flatTrailPaceSecPerKm`; the pace field is derived from the profile so
it reflects immediately). Generalized `calibrationContributors` to "runs feeding
*either* fit." ADR-0007.
**What I verified:** `smoke:calibration` now 27 checks over BOTH compiled fits —
flat: paces 379/300/480/380 s/km for known inputs, the strict `<0.04` band cut
(0.04 excluded), zero-time + zero-distance skip, no-data null, a both-fits-coexist
case. type-check `Success!`, build `✓`, smoke/aidcsv/sections green. Built bundle
carries the "Flat pace" row + both `/km` renderings (the `CalibrateFlatPace`
constructor is optimized away as a union tag — expected; the wiring type-checks).
**What changed in the repo:** PR #82, merged `a76db2e`. `Calibration.elm`,
`CalibrationHarness.elm`, `smoke-calibration.mjs`, `Main.elm`, ADR-0007 + INDEX +
`local-ci.md`. This close PR moves it to DONE, ticks BACKLOG, clears CURRENT.
**Decision — checkpoint here.** The two core *continuous* rates (climb + flat)
are the cleanest, highest-value fits and are done. The remaining roadmap §7 fits
each carry a real complication: descent skill is an *enum* (calibration = snap a
fitted multiplier to a level); fatigue/climb-fatigue need time-binning + a curve
fit; Riegel/HR/decoupling are *new predictor capabilities* + data-gated. That's a
genuine scope/priority step-up, so I'm pausing to ask the user rather than
autopiloting into them — `CURRENT.md` records the options.
**Next:** Await the user's call on the harder fits (descent / fatigue / Riegel /
HR / decoupling) vs. pausing calibration. Other ready work: the section-card
Δ-vs-plan fix (now unblocked), parking-lot items.

---
## 2026-06-15 14:23 — Calibration paused (user decision)

Asked the user how far to take calibration after the two core rates (vmh +
flat) shipped. **They chose to pause here.** So the remaining roadmap §7 fits
(descent technique, fatigue/climb-fatigue curves, Riegel-k, sustainable-HR,
decoupling) stay queued and unpromoted — do not start them without a fresh
go-ahead. `CURRENT.md` updated from "checkpoint pending" to "paused by user."
Nothing active. Ready work when the user returns: the section-card Δ-vs-plan
fix (unblocked by TASK-039's partition), other parking-lot items, or the two
recommended manual checks (TASK-040 browser round-trip, TASK-042 print preview).

---
## 2026-06-15 14:40 — TASK-045: section plan time is clock time (clock-vs-clock Δ)

**Task:** TASK-045 (parking lot → promoted; the follow-up TASK-025 explicitly
deferred, unblocked by TASK-039/ADR-0004). User asked for it directly.

**What I did:** The section `Δ vs plan` compared planned **moving** seconds
(`Σ` per-km moving over `kmIndices`) against actual **clock** seconds
(`sectionActualSeconds` — real splits, which include time spent at an aid), so
resting at an aid but running on pace read as that-much "behind plan." Made a
section's plan **Time = clock** = `sectionMoving + sectionAidRest`, kept **Pace
moving**, and set **Δ = actual − clock** — the section-level lift of TASK-025's
per-km clock model. New pure `Planning.sectionAidRest aids section` sums the rest
of aids whose containing km (`kmAtDistance`) is in `section.kmIndices`. Applied
to the section table (`sectionsWithCumulative` — Time/Cum clock, aid rows now
non-additive dividers showing rest as context, a footer caption), the section
card (`viewSectionDetails` — Time stat clock + amber caption mirroring the per-km
one), and section-mode CSV (`buildSectionRows` — `section_time` /
`cumulative_after_aid` clock, matching the UI + km-mode). ADR-0008.

**The crux (why not `followedByAid`):** the obvious "use the aid this section
ends at" is wrong ~half the time. An aid at `b` lives in km `floor(b/1000)`,
whose midpoint is `…+500`; when `frac(b) < 500` the aid's km — and so its
stoppage in the actual split — belongs to the section *after* `b`, not the one
that ends at it. `sectionActualSeconds` sums actual splits over `kmIndices`, so
charging the plan rest to the same km/section is the only rule consistent with
the actual in every case. The midpoint partition (ADR-0004) makes that km unique
— which is exactly why this was blocked on TASK-039.

**What I verified:** all six local-CI gates green. Type-check `Success!`; build
`✓ built` (350.02 kB). Smokes: storage `SMOKE PASSED`, aid-csv `PASS`,
calibration `PASS`, and **sections `PASS`** — extended (the harness had
hard-coded rest = 0) with the new `Planning.sectionAidRest` driven over the real
compiled module:
```
E: aid-rest attribution (clock time) + conservation
  ok   km map still [[0,1],[2],[3,4]]
  ok   aidRest per section == [300, 0, 600]
  ok   Σ aidRest == 900 (== Σ rests; none dropped or double-counted)
F: aids but no rest times → aidRest all zero
  ok   aidRest == [0, 0]
```
Scenario E is the proof: aid@3300 (first half of its km) attributes to section 2
(the section *after* it) → `[300, 0, 600]`, **not** `[300, 600, 0]` that
`followedByAid` would give. Worked consequence: a runner who holds planned moving
pace and rests exactly as planned now sees Δ = 0 on every section (it used to
show a phantom deficit equal to the aid rest). Not verifiable headless: the
browser render of the section table/card with a **linked actual** — recommended
post-merge (added to CURRENT.md's manual-check list).

**What changed in the repo:** PR #86, merged `08c9a66`. `Planning.elm`
(`sectionAidRest` + export), `Main.elm` (section table + card), `Csv.elm`,
`SectionsHarness.elm` + `smoke-sections.mjs` (scenarios E/F), ADR-0008 + INDEX +
`local-ci.md`. This close PR moves it to DONE, ticks BACKLOG, strikes the
parking-lot line, clears CURRENT.

**Next:** Nothing active. Calibration stays **paused** (user decision 2026-06-15)
— don't promote the harder roadmap §7 fits without a fresh go-ahead. Ready work:
parking-lot items (light/dark, multi-language); three recommended manual checks
(TASK-040 round-trip, TASK-042 print preview, TASK-045 section view with a linked
actual).

---
## 2026-06-15 20:37 — Coach-collaboration epic: intake (ADR + spec + tickets)

**Task:** Not a TASK — meta-intake. The user handed off a self-contained spec
("Coach collaboration via `.trail` merge") and asked to ticket it, then start
working. Per the spec's own hand-off brief: promote §0 to an ADR, queue a brief
nuance, create the WI tasks in §6 order.

**What I did (PR #88, merged `8167db4`):**
- **ADR-0009** — `.trail` file sync: three-way merge against a common ancestor
  (not a CRDT) + *freeze the course, merge the plan*. §1 of the spec became the
  alternatives body.
- **`reference/coach-collab-spec.md`** — the full spec preserved (rationale +
  per-WI acceptance criteria + the 5 open questions), marked adopted.
- **BACKLOG** — TASK-046 (brief nuance) · TASK-047 (WI-1 identity/integrity
  guard) · TASK-048 (WI-2 course freeze) · TASK-049 (fork-safe aid ids) ·
  TASK-050 (WI-3 three-way merge) · TASK-051 (WI-4 history feed). §6 order.
- INDEX + manifest reference list updated.

**The maze I recorded (spec premises vs. the actual code, verified 2026-06-15):**
1. **Stable share id is new** — `Race.id` exists (JS `crypto.randomUUID()`) and
   is in the `.trail`, but the import path *regenerates* it (`Main.elm:447`,
   `id = raceIdFromString ""`) so a file can be imported twice. So WI-1's
   identity needs a *separate* id that survives the round-trip.
2. **Aid ids already exist** (`AidStation.id = "a" ++ aidStationSeq`,
   `Main.elm:1967`; round-trips). The spec's "distance-keyed aids" premise is
   stale. The real hazard: the *shared* per-race counter mints identical ids on
   both forks → collisions. So TASK-049 is reframed "add ids" → "fork-safe ids."
3. **`.trail` version is a strict-equality gate** (`ProjectFile.elm` `D.fail`s),
   not a `D.oneOf` default — WI-1 must widen it to {v1, v2} explicitly.

**Verification:** docs-only — `git diff --name-only` showed only `knowledge/`,
so the code CI gates (elm/build/smokes) don't apply. ADR + spec linked; six
tickets carry acceptance criteria + Q-gates + deps.

**Decision-gates ahead (not auto-decidable — spec §7):** Q1 (courseHash input +
mismatch behavior) gates WI-1; Q2–Q5 gate WI-3. The spec routes these to the
user; I'll surface Q1 when I pull TASK-047.

**Next:** TASK-046 (brief nuance, docs-only, no open questions) → then TASK-047
(WI-1), where Q1 must be resolved with the user first.

---
## 2026-06-15 20:52 — TASK-046: file-based collaboration scoped into the brief

**Task:** TASK-046 (coach-collab epic, spec §0). First of six. No open
questions — the decision is settled in ADR-0009.

**What I did (PR #89, merged `4896f60`):** Nuanced `project-brief.md`'s *Out of
scope* the way "No backend, ever" was softened for Strava. Qualified
"no multi-user" → "no *server-side* multi-user"; rewrote "No social / sharing
features." → "No *server-side* social / sharing features — no accounts, no
hosted documents, no real-time co-editing," with a parenthetical that
async/file-based/single-document collaboration (export → annotate → merge via
three-way merge) is in scope at Layer 0, pointing at ADR-0009 /
`coach-collab-spec.md`. Both lines nuanced, not deleted.

**What I verified:** docs-only — `git diff --name-only` showed only
`knowledge/reference/project-brief.md` (+ the CURRENT.md plan record), no `src/`,
so the code CI gates don't apply. Re-read the two lines + new nuance: reads
consistently with the Strava-softening already a few lines up.

**Next:** TASK-047 (WI-1 — `.trail` identity/integrity guard). **Gated on Q1**
(courseHash input: canonical decoded track vs. raw bytes; and mismatch behavior:
hard-block vs. warn). Per spec §7 these are the user's call — surfacing Q1 to the
user before writing WI-1's plan.

---
## 2026-06-15 23:18 — TASK-047: WI-1 `.trail` v2 identity + integrity guard

**Task:** TASK-047 (coach-collab epic, spec §2). Second of six; the foundation
the merge (WI-3) sits on. **Q1 resolved with the user** before implementing
(spec §7 routed it there): courseHash from the **canonical decoded track**
(not raw bytes), and **hard-block** on course mismatch. → ADR-0010.

**What I did (PR #91, merged `409eeee`):**
- `Race` + `shareId` (stable cross-round-trip identity) and `courseHash`. The
  code's reality (verified during intake) drove the design: `Race.id` is the IDB
  key and is *regenerated on import* (`Main.elm:447`), so it can't be the shared
  identity — `shareId` is new, minted JS-side like `id` but **preserved on
  import** (only `id` is blanked). Both default `""` (v1 files / old IDB rows);
  stamped on the way in.
- New pure **`TrailSync`** module: `courseHash : Gpx.Track -> String` over a
  canonical rendering (lat/lon scaled to 5 dp, ele to nearest m) hashed with a
  **double polynomial** (two moduli, ~60-bit) — each fold stays in Elm's
  safe-integer range, so no `Math.imul` 32-bit tricks and no crypto port (the
  threat model isn't adversarial). `classify` returns the typed verdict
  `Mergeable | DifferentRace | DifferentCourse`; empty shareId never matches.
- `.trail` → **v2**: `currentVersion = 2`, gate widened to `{1,2}`
  (`isSupportedVersion`); codecs carry both fields with `D.oneOf` defaults;
  decoder restructured (placeholder `""` in `coreBuilder`, overlaid by a `map3`
  wrapper) to dodge Elm's `map8` arity ceiling. `main.js` mints shareId.

**The crux (why a new field, not reuse `id`):** the spec assumed `raceId` was new
but the code already had a UUID `id` — yet that id is *deliberately* thrown away
on import. Reusing it would break the round-trip link the moment the coach
imports. So `shareId` is orthogonal: `id` = local row key (fresh per import),
`shareId` = logical document identity (preserved). Documented in ADR-0010 +
the Types docstring.

**What I verified (all 7 gates green; quoted):**
```
type-check  Success!
build       ✓ built in 902ms
storage     SMOKE PASSED   (+ shareId minted-when-absent / preserved / round-trips)
aidcsv      PASS
sections    PASS
calibration PASS
trailsync   PASS  (new — 24 checks)
```
New `smoke:trailsync` proves: courseHash deterministic + **cosmetically-different
GPX → same hash** (the rounding tolerance — sub-1m precision + sub-1m ele) +
different course → different hash + unparseable → ""; all three classify verdicts
+ empty-shareId-never-matches; v1 decodes (fields→""), v2 decodes (preserved), v3
rejected, **v1 re-exports as v2** with identity intact. Not headless-verifiable
(standing project limit): the full browser upload→export→re-import→guard flow —
recommended manual check.

**Scope boundary (deliberate):** WI-1 is data + the pure guard, no merge UI. The
"update-from-file" action that calls `classify`→merge is WI-3 (TASK-050). Known
edge for WI-3: re-importing your own file as-new makes two local rows share a
shareId — the update-from-file path is the intended route.

**Next:** TASK-048 (WI-2 course freeze) — light, **no open questions** (Q2–Q5
gate WI-3, not WI-2), so proceeding autonomously. Then TASK-049 (fork-safe aid
ids), then TASK-050 (WI-3, gated on Q2–Q5 — will surface those to the user),
then TASK-051 (WI-4 feed).

---
## 2026-06-15 23:26 — TASK-048: WI-2 course-freeze boundary

**Task:** TASK-048 (coach-collab epic, spec §3). Third of six. No open questions
(Q2–Q5 gate WI-3). Light by design.

**What I did (PR #93, merged `c5bc0af`):** Turned "freeze the course, merge the
plan" from an axiom into a *type-enforced boundary*. New `Merge` module splits a
`Race` into three disjoint groups — frozen course (gpxText + distance/gain/loss +
courseHash), mergeable `PlanningLayer` (name/date/location/url/notes + aids +
plan), local/owner-only (id/shareId/createdAt + coverImage + actualSplits) — with
`planningLayer : Race -> PlanningLayer` and `withPlanningLayer : PlanningLayer ->
Race -> Race`. The reassembly copies the course + identity + owner-only fields
from the **local** race verbatim, so WI-3's merge can never alter track points:
they're not in the planning layer, full stop.

**Why this shape (vs. a doc-only invariant):** WI-1 already shipped the *guard*
half (reject a different-course import) and trail has no course editor, so a
naive WI-2 would be near-empty. The value is the structural surface WI-3 builds
on: WI-3 will produce a merged `PlanningLayer` and rebuild via `withPlanningLayer`
— the freeze is then a property of the reassembly, not a rule to remember. Kept
the per-field merge *policy* out (that's WI-3, partly Q3); WI-2 only draws the
in/out-of-bounds line.

**What I verified (all 8 gates green; quoted):**
```
type-check Success!   build ✓ built
storage SMOKE PASSED   aidcsv/sections/calibration/trailsync PASS
merge PASS  (new — 25 checks)
```
`smoke:merge`: with a `PlanningLayer` taken from a *different* course, the rebuilt
race keeps local's gpxText/courseHash/distance/gain/loss + id/shareId/createdAt/
coverImage/actualSplits, and takes name/date/location/url/notes/aids/plan from
source; round-trip `withPlanningLayer (planningLayer r) r == r` holds.

**Next:** TASK-049 (fork-collision-safe aid ids) — **no open questions**,
proceeding autonomously. Then TASK-050 (WI-3 three-way merge — gated on Q2–Q5,
will surface to the user), then TASK-051 (WI-4 history feed).

---
## 2026-06-15 23:34 — TASK-049: fork-collision-safe aid ids + per-device id

**Task:** TASK-049 (coach-collab epic, the sub-task between WI-2 and WI-3). No
open questions. Reframed at intake from the spec's stale "add ids" to "make the
existing ids fork-safe" (ADR-0009 grounding #2).

**What I did (PR #95, merged `fa0969f`):** Aid ids were `"a" ++ aidStationSeq`
off a *per-race* counter — two forks both at seq N mint the same id for
different new aids, which WI-3 couldn't tell apart. Introduced a stable
**`deviceId`** (UUID, `main.js` → `localStorage['trail.deviceId']`, passed in
flags → `Model.deviceId`) and `Merge.mintAidId deviceId seq` →
`"a"+seq+"-"+first8(deviceId)`, wired into both minting sites (`validateAidForm`
+ `assignAidIds`/CSV). Existing `"aN"` ids untouched.

**Two calls worth recording:**
1. **localStorage, not IDB, for `deviceId`.** Elm needs it synchronously at boot
   (flags) to tag ids the moment an aid is added; IDB is async (ports). It's a
   device fingerprint, not race data, so localStorage is the right store despite
   the rest of the app using IDB. Noted in the `main.js` comment.
2. **Build `deviceId` now, not in WI-4.** It's used by aid-id tagging (here),
   WI-3 conflict attribution, and WI-4 author stamping — 3 uses, clears the
   extraction bar, and the spec explicitly intends a shared per-device id. Not
   premature.

**Why back-compat is automatic:** ancestral aids (from the common ancestor)
carry the SAME `"aN"` id on both forks → they correctly *match* in the merge.
Only *new* post-fork aids need distinguishing, and those get device tags. So
tagging only new ids is exactly right — no migration, no re-id.

**Verified (all 8 gates green; quoted):**
```
type-check Success!   build ✓ built
storage/aidcsv/sections/calibration/trailsync PASS
merge PASS  (extended: mint-aid — diff-device-same-seq DISTINCT, same-device
            deterministic, empty deviceId → bare "a5")
```

**Next:** TASK-050 (WI-3 three-way merge — the core). **Gated on Q2–Q5** (spec
§7): ancestor delivery (embed base vs lookup), profile/splits authority, version
scheme, conflict UX. Per the spec these are the user's call — surfacing Q2–Q5
before writing WI-3's plan.

---
## 2026-06-15 23:52 — TASK-050: WI-3 three-way merge engine (pure)

**Task:** TASK-050 (coach-collab epic, spec §4). The correctness core of WI-3.
**Q2–Q5 resolved with the user** first (spec §7 routed them there): Q2 embed
`{base,current}`; Q3 splits + cover owner-only (= WI-2 boundary); Q4 per-device
version vector; Q5 dedicated review screen, per-km note pick-one v1. → ADR-0011.

**Split decision:** WI-3 is large (engine + version/base orchestration + entry
point + review UI). I split it: **this task = the pure engine** (fully
smoke-testable — the hard correctness part), **TASK-052 = integration + review
UI** (verification largely manual). Mirrors how the project shipped `Predictor`
before the slider. Recorded TASK-052 in BACKLOG.

**What I did (PR #97, merged `afefeb8`):** Added to `Merge`:
- Version vector (`Dict deviceId Int`) + `classifyVersions → Same | FastForward
  | Behind | Diverged`, `bumpVersion`, `mergeVersions`.
- `mergePlanningLayer base mine theirs → { merged, conflicts }`: a `field3`
  three-way primitive (only-one-side-changed → that side; both differ → typed
  conflict, default mine); applied to scalars + per-km `{time,notes}`; aids as a
  keyed set by fork-safe id (union adds / honoured removes / per-field three-way
  / edit-vs-remove → presence conflict).
- `resolve key theirs acc` — pure dispatch folding one "take theirs" onto merged.

**Design calls (in ADR-0011):** (1) merged-defaults-to-mine + `resolve` fold,
rather than wrapping every field as `MergeField` — keeps `merged` always valid
and the UI reconstruction a simple fold; both halves smoke-testable. (2)
per-field aid merge (spec) not whole-aid. (3) version vector over a plain counter
(only it gives fast-forward detection).

**What I verified (all 8 gates green; quoted):**
```
type-check Success!   build ✓ built
storage/aidcsv/sections/calibration/trailsync PASS
merge PASS  (extended with WI-3 acceptance scenarios)
```
The acceptance criteria, headlessly: disjoint coach km-note + owner aid → **0
conflicts**, both land; same km note both sides → **1 typed conflict**, `merged`
= mine, `resolve(theirs)` flips it; deterministic; disjoint aid adds → both
present; honoured removes; scalar three-way (name vs date); `classifyVersions`
all four relations. The "human resolves / applies with no conflict UI" parts are
TASK-052 (UI).

**Next:** TASK-052 (WI-3 part 2 — integration + review UI): persist
`mergeBase`+`version` on Race, `.trail` carries `{base,current,version}`, bump
on edit, the import→merge entry point, the dedicated review screen. Verification
largely manual (browser) per the standing limit. Then TASK-051 (WI-4 feed).

---
## 2026-06-16 08:26 — TASK-053: backfill .trail identity for pre-existing races

**Task:** TASK-053 (user bug report). The user verified import works, then found
existing races export as v2 with an **empty courseHash** (and shareId). Root
cause: WI-1's decoder defaults both to `""` for back-compat, and nothing
backfilled races already in IDB — so the export carried blanks, which would
break the coach round-trip (returned file's courseHash wouldn't match the local
`""` → guard blocks).

**Decision (with the user):** backfill **at download/export**, not on load. The
user suggested download-time; I agreed — computing courseHash needs a GPX
re-parse, and the home page doesn't parse GPX today, so hashing every race on
load would add a one-time hitch; only the shared race needs identity, so stamp
it lazily at share time. Persist so it's stable for the round-trip.

**What I did (PR #100, merged `bdedf61`):**
- Pure `TrailSync.ensureIdentity : Race -> Race` — fills courseHash (from gpxText)
  + shareId when empty; **shareId seeded from the race's stable IDB `id`** (a
  UUID): a unique/stable seed needing no async JS mint. It coincides with `id`
  initially for backfilled races but diverges after any import (id regenerates,
  shareId preserved) — consistent with ADR-0010. Already-stamped races unchanged.
- `ExportProjectFile` stamps before encoding; if it changed, persists via
  `saveRaceMeta` (light — no 3 MB GPX re-ship). New races still get a JS UUID
  shareId at full save; this only backfills the pre-WI-1 ones.

**Why shareId-from-id instead of the pendingExport+JS-UUID dance:** the pure
synchronous seed avoids adding async export state to the update loop (less
compile-only-verified surface), and equality-comparison doesn't care about
shareId format. Documented the trade-off in the code + ADR-0010 lineage.

**What I verified (all 8 gates green; quoted):**
```
type-check Success!   build ✓ built
storage/aidcsv/sections/calibration/merge PASS
trailsync PASS  (extended: ensureIdentity backfills from id+gpx; already-stamped preserved)
```
The pure backfill is smoke-tested; the export-handler wiring is type-check/build
+ the user's in-browser confirm (they're actively verifying).

**Next:** coach-collab arc still paused at the verified seam — TASK-052 (WI-3
merge UI/orchestration) + TASK-051 (WI-4 feed) remain, both needing in-browser
verification. Resume on the user's go-ahead.

---
## 2026-06-16 09:44 — TASK-051: WI-4 change-history feed (drawer)

**Task:** TASK-051 (coach-collab epic, spec §5). User picked it next over the
WI-3 merge UI, with 3 Tailwind-UI feed refs ("inspiration, gamified styling")
and asked where the open button should go. Resumed from the paused seam with
their go-ahead + active in-browser verification.

**What I did (PR #102, merged `ddf7076`):**
- Pure **`Changelog`**: two-way `diff : PlanningLayer -> PlanningLayer -> List
  ChangeDescriptor`, `union` by entryId, entry constructors. `diff` emits only
  the spec taxonomy (aids, km note/pace, race name/date) and **nothing** for
  target-time/location/url/notes — so the effort slider doesn't spam the feed.
- `Race.history` + a `commitRaceEdit` chokepoint at the `saveRaceMeta` edit
  sites (diff before→after; empty diff → no entry). New races seed
  `CourseUploaded`. Carried in `.trail`.
- Right slide-over **drawer**: timeline + per-type colored circular badges +
  author/relative-time; "Activity" button on the header row mirroring the back
  link (the user's suggested placement).

**The architectural snag worth recording — import cycle.** `Race` (in `Types`)
must hold the history, but `Changelog` imports `Merge` → `Types`, so `Types`
importing `Changelog` back would cycle. Resolved by putting the *typed
`ChangeDescriptor`/`ChangeEntry` + their codecs in `Types`* (data layer) and
keeping the *diff/union logic in `Changelog`*. Clean split: `Types` = data +
codecs, `Changelog` = the diff that needs `Merge.PlanningLayer`.

**Process note — held for review before merge.** Unlike the smaller fixes, I
left PR #102 unmerged and handed it to the user for in-browser review first
(design-subjective UI + behaviour I can't verify headlessly — the `delivery.md`
"want a second pair of eyes" case). They confirmed ("Looks good") and removed
their `feed-0N.html` scratch refs; then I merged.

**What I verified (all 9 gates green; quoted):**
```
type-check Success!   build ✓ built
storage/aidcsv/sections/calibration/trailsync/merge PASS
changelog PASS  (new: every descriptor kind, non-taxonomy → [], codec round-trip, union dedupe)
```
The drawer render + logging round-trip (edit → entry → echo → drawer) was the
user's in-browser check; the engine + codec are smoke-tested. Traced the
`RaceSaved` echo: it keeps the decoded race's history and only refills gpxText,
so logged entries flow back into the model.

**Next:** the arc's last piece is **TASK-052 (WI-3 part 2 — merge integration +
review UI)**: persist `mergeBase`+`version`, `.trail` carries `{base,current,
version}`, version-bump on edit, the import→merge entry point, the dedicated
review screen, and appending `Merged` change-sets to the WI-4 feed. Q2–Q5
already resolved; verification largely manual (browser). Epic so far: TASK-046
✓ 047 ✓ 048 ✓ 049 ✓ 050 ✓ 051 ✓ 053 ✓.

---
## 2026-06-16 — Intake: companion spec (identity + merge-review UI) → backlog

**Task:** Not a TASK — meta-intake, like the engine-spec intake (#88). The user
handed off `merge-ui-and-identity-spec.md` (companion to the already-ticketed
`coach-collab-spec.md`): *"process my exploration on the next steps… for now
just work on ingesting all of this into the backlog."* Scope this session was
explicitly **backlog only** — not the ADR, not resolving the open questions, not
implementation.

**What I did (PR #104, merged `df5a8c9`):** docs-only, mirroring #88.
- **Relocated the spec** → `reference/merge-ui-identity-spec.md` (durable home,
  as `coach-collab-spec.md` is for the engine), fixed the companion cross-refs,
  and added a **Reality corrections** callout grounding it against the code.
- **Three tasks** under a new epic sub-section "Identity & merge-review UI":
  **TASK-054** (WI-5 identity & authorship — foundation) · **TASK-055**
  (home-view personal/other + filter by person) · **TASK-056** (WI-3·UI
  suggestion-review surface). Acceptance from spec §1.6 / §1.5 / §2.6, plus the
  two-mint-points discipline and the `nameUpdatedAt` LWW rule per the hand-off.
- **Annotated TASK-052** (didn't gut it): its part (d) review screen is now
  detailed by TASK-056 and its labels depend on TASK-054, so (d) is the
  integration/apply seam TASK-056 drives. Refreshed `CURRENT.md`'s arc note
  (it wrongly read "only TASK-052 remains").

**The maze I recorded (spec premises vs. the actual code, verified 2026-06-16):**
1. **A device-global id already *is* the author identity.** `deviceId`
   (localStorage `trail.deviceId`, `main.js:188`) already keys the changelog
   author (`authorLabel`, `Main.elm:6769`), the version vector
   (`Merge.bumpVersion`), the aid-id prefix (`Merge.mintAidId`), and the
   `entryId` (`author ++ "-" ++ seq`). The spec discards "device-id = person,"
   but that's about *labels* — so WI-5 **adds a person-level `userId` over
   `deviceId`, it does not replace it.** `userId` = human identity (owner,
   labels, directory); `deviceId` stays the device-scoped collision key.
   Re-keying `entryId` by `userId` would be a latent bug (two devices of one
   person collide on seq → WI-4 union silently drops entries).
2. **`me` ≠ the performance profile, and that collision is real here.**
   `src/AthleteProfile.elm:46` already defines `type alias Profile`. §1.2's
   "don't nest `me` in the performance profile" is concrete, not hypothetical.
3. **No `owner` on `Race` yet** — WI-5 adds it; `shareId`/`raceId` already
   exist per-race (identify the *document*, not the *person*).

**Decisions / judgment calls (surfaced for the user):** the recommended
sequencing **TASK-054 (WI-5) → 052 (integration) → 056 (review UI) → 055 (home
view)** is recorded but not locked. The exact split between TASK-052(d) and
TASK-056 is left to settle at promotion. TASK-052 was annotated, not rewritten.

**Deferred per scope (flagged, not done):** the ADR promoting §1.2 identity +
§2.2 UI reframe (extend ADR-0009 or a new ADR-0012) — pairs with the WI-5
kickoff; resolving **Q-I1–Q-I3** (WI-5) and **Q-U1–Q-U5** (WI-3·UI) with the user
at each gate.

**Verification:** docs-only — `git diff --name-only` showed only `knowledge/`
(no `framework/`, so the instance-free grep gate is N/A; no code CI gates apply).
TASK ids 054–056 unique (max was 053) with one definition line each. The root
duplicates `coach-collaboration-spec.md` + `merge-ui-and-identity-spec.md` are
left untracked — now redundant with the `reference/` copies; the user can bin
them.

**Next:** the arc resumes with **TASK-054 (WI-5)** on the user's go-ahead —
resolve Q-I1–Q-I3 and write the identity ADR first.

---
## 2026-06-16 — Apply user decisions on the merge arc (drop 052 → 056)

**Task:** Follow-up to the companion-spec intake (#104/#105). The user reviewed
the ticketing and decided: (1) keep both `deviceId` + `userId` — stressing that
the *same person on two devices* is the case `userId` exists to solve; (2) **drop
TASK-052, fold it into TASK-056** (WI-3's whole last mile — integration + review
UI — ships last); (3) confirmed the sequencing. They also handed over a UI
prototype as design inspiration.

**What I did (PR #106, merged `b15475d`):** docs-only.
- **TASK-052 dropped** (struck), its integration scope moved verbatim into
  **TASK-056**, retitled "WI-3 (part 2): merge integration + suggestion-review
  UI" and marked **ships last**; deps now TASK-050 (done) + TASK-054. Repointed
  TASK-051's `Merged`-pending note to 056.
- **Build order locked:** TASK-054 (identity) → TASK-055 (home) → TASK-056
  (merge UI, last) — sub-section intro + CURRENT.md.
- **Preserved the prototype** → `reference/merge-review-prototype.html`,
  referenced from TASK-056: take the UX/layout (card list, two equal options,
  ring+check selection, reassurance row, Apply/Keep footer, confirm-on-dismiss,
  identity tint); not the icons/markup; and its `"Coach"` role labels are the
  exact seat-relative bug WI-5 fixes → person names.
- **Sharpened the grounding:** same person/two devices = one `userId`, so
  `userId` is device-independent by design, never derived from `deviceId`.

**Verification:** docs-only (only `knowledge/`). No live deps reference the
dropped TASK-052. Root loose files left untracked for the user to remove.

**Next:** start **TASK-054 (WI-5)** — gated on **Q-I1–Q-I3** (surfaced to the
user this turn) + the identity ADR (ADR-0012). Once answered: write the ADR,
pull TASK-054 into CURRENT with acceptance criteria, implement.

---
## 2026-06-16 — WI-5 kickoff: gating questions resolved, ADR-0012, TASK-054 slices 1–2

**Gating questions resolved + ADR-0012 (PR #108, merged `ab216e9`).** The user
answered Q-I1–Q-I3: **build the explicit dual-id link action**; **dedicated IDB
store** for the identity record; **names-only** (no role badge). Their steer on
Q-I1 — "the same person on two devices is the problem this solves" — drove
choosing the robust link action over punting. Promoted §1.2 + the three answers
to **ADR-0012**; opened TASK-054 in CURRENT with acceptance criteria + a
pure-core-first slice plan (mirroring the TASK-050/052 verifiability split).

**Slice 1 — pure `Identity` core (PR #109, merged `1dfe2fb`).** New module, no
existing code touched, fully headless-verifiable: types
(UserId/Me/DirEntry/Directory); the name **LWW** register (`learn` /
`mergeDirectory`, ordered by `nameUpdatedAt` so a stale import never reverts a
name); the import **mint/adopt decision** as pure fns (`decideImport` — only a
file you own imports silently; `resolveOwnership` — *yourself* adopts the file
owner id and **never mints**, *someone-else*-with-no-identity mints-then-reviews);
`subsetFor`; codecs. New **`smoke:identity`** gate (`src/IdentityHarness.elm` +
`scripts/smoke-identity.mjs`, 21 checks), registered in local-ci.md.

**Slice 2 — `owner` on Race (PR #110, merged `da1c64b`).** `owner : String` (a
userId), introduced exactly like `shareId`/`courseHash` (TASK-047/053): defaults
"", rides `raceMetaFields`, stamped later. Types (type + encode + `decodeRace`
overlay `map4→map5` with `D.oneOf ""` + `coreBuilder`); `buildDraftRace` seeds
"". `smoke:trailsync` extended: owner round-trips (v2), defaults "" (v1),
survives export. Because it rides `encodeRace`, the `.trail` already carries it.

**Verified (all headless):** type-check Success; build ✓; all 8 smokes PASS
(incl. the new identity gate + the owner assertions). **`deviceId` untouched** —
`userId` layers over it (ADR-0012).

**Inert by design until the flows:** owner is "" at runtime and `me` doesn't
exist yet — the deferred-mint discipline means identity only appears at first
share. Slices 1–2 are the schema + pure-logic foundation; a `.trail` exported
now already carries `owner` (forward-compat).

**Remaining (browser-verified, like the WI-4 feed):**
- **Slice 3 — IDB identity store + boot:** the dedicated `identity` store (DB
  v3→v4) + `Storage` ports + `main.js` handlers; load `me : Maybe Me` +
  `directory` into the model at boot; `.trail` name denormalization (the
  `people` pairs) + import-merge into the directory. Store mechanics are
  storage-smoke-able (fake-indexeddb); the real boot needs a browser.
- **Slice 4 — flows:** export-mint name prompt; import yourself/someone-else
  prompt (adopt/mint/review); `owner` backfill on touch/export; the Q-I1 link
  action; `resolveName` wired into labels.

**Next:** slice 3 (store + boot), then slice 4 (flows) — both need the user's
in-browser verification (IDB upgrade, boot, the prompts/link action), as TASK-051
did. A couple of slice-4 UX details (prompt copy, link-action placement) are
worth a quick look with the user.
