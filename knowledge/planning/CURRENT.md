# Current task

## TASK-002 — IndexedDB storage + race index page + minimal routing

**Pulled from backlog:** 2026-05-15 01:40
**Why this now:** With the scaffold in place, the very next foundation is *persistence + identity*. Everything after this assumes "races live somewhere; you can re-open the app and they're still there." Also introduces the hash router so subsequent tasks can build page-by-page.

### Acceptance criteria
- [ ] User can open the app and see an **index page** (race grid). Empty state if no races yet.
- [ ] User can upload a GPX from the index. A new `Race` is created with: id (uuid-like, generated client-side), name (initially the GPX track name), date = null, location/url/notes = "", coverImage = null, stats (distance/gain/loss) computed from the parsed Track, plus the raw GPX text retained for re-export.
- [ ] The race is persisted to **IndexedDB** before navigation. After saving, the URL changes to `#/race/<id>` and the race detail page renders.
- [ ] Race detail page (stub for now): shows race name + distance + gain + loss + a "Back to races" link. Detailed views (profile, planning, aid stations) come in later tasks.
- [ ] Reloading the page (hard reload, F5) preserves all races: on init we read all from IDB and the index lists them again.
- [ ] User can **delete** a race from the index (with a confirm) and IDB no longer contains it after reload.
- [ ] Hash router: `#/` → index, `#/race/:id` → detail, anything else → 404 with "Back to races."
- [ ] UTMB-size GPX (samples/utmb_2025.gpx) parses + persists without blocking the UI for >1s on a modern machine (qualitative — note actual time observed).
- [ ] `npm run build` succeeds.
- [ ] PR opened with the standard template + merged.
- [ ] Bookkeeping commit: this CURRENT cleared, DONE updated, journal entry written.

### Plan
1. Add `Types.elm` — `RaceId`, `Race`, `RaceMeta` (the editable fields), `Race.toMeta`, `Race.fromMeta` helpers.
2. Add `Route.elm` — `Route = Index | RaceDetail RaceId | NotFound`, `Route.fromUrl`, `Route.toUrl`.
3. Add `Storage.elm` — port-backed `loadAll`, `save`, `delete`, plus the inbound subscription `gotRaces`/`gotRace`.
4. Write `public/idb.js` (or inline in `src/main.js`) — vanilla IDB wrapper exposing the three ops over a single `racesIDB` object store.
5. Convert `Main.elm` from `Browser.element` to `Browser.application` so we get URL changes.
6. Implement page dispatch: render Index for `Index`, RaceDetail for `RaceDetail id`, NotFound otherwise.
7. Move the file-upload UI from the current Main into the Index page; on upload success: generate id, build Race, dispatch `Storage.save`, then `Browser.Navigation.pushUrl` to `#/race/:id`.
8. Implement RaceDetail page stub.
9. Wire `Storage.loadAll` in `init` and stash results in the model.
10. Add a "Delete" affordance on the index card (with `window.confirm` via a port for now, or pure-Elm modal).
11. Smoke test with `samples/20k_oh_meu_deus.gpx` and `samples/utmb_2025.gpx`. Hard-reload, verify persistence.
12. PR + merge + bookkeeping.

### Verification plan
- Manual: upload 20k GPX → race card appears → click → detail shows correct stats → back → hard reload → race still there.
- Repeat with UTMB GPX. Note time to parse + persist.
- Delete a race → reload → it's gone.
- Navigate to `#/race/bogus-id` → NotFound view.
- Quote `npm run build` output.

### Notes during execution
_(append as I go)_

### Done
_(filled when all gates pass)_
