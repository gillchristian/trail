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
