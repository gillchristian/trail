# Trail — morning triage

> **⚠️ Historical snapshot — frozen 2026-05-15.** This is the hand-off note from
> the original overnight build (the first 10 PRs). It is **not** maintained as
> the project's live state — for that, read `CLAUDE.md` →
> `knowledge/README.md` → `knowledge/planning/CURRENT.md`. A few facts below were
> corrected in the 2026-06-10 doc audit (TASK-038); the rest stands as a
> point-in-time record of that morning.

End-of-night summary (the morning after the overnight build).

## Feedback pass (after your morning notes)

You left a list of issues at 07:00 — addressed in a follow-up PR. Headline: **#7 and #9 ("auto planning and per-km don't save") were the same bug** — `currentRace` only matched the `RaceDetail` route, so every save attempt from the plan view silently dropped. Fixed. The rest:

- **Offline on dev**: by design — the service worker is gated on `import.meta.env.PROD`, so `npm run dev` (which runs Vite's HMR) never registers it. Test offline via `npm run build && npm run preview` instead. (If you'd rather a dev-time SW for parity, say the word and I'll wire one with HMR-safe path skipping.)
- **Storage works** ✓
- **Race card without picture**: replaced the dead-space band with a category-coloured decorative panel (gradient + faint mountain silhouette + category letter watermark). Cards across the grid now stay the same shape regardless of which ones have covers.
- **Contrast**: pinned the page to `color-scheme: dark` and added explicit `background:#020617` to `<html>` and `<body>` (inline + CSS), so OS-level auto-tinting or any FOUC can't push a light cast.
- **Whole row clickable in the plan view**: yes; rows now navigate to the per-km view on click, with `role="link"` + `tabindex` for keyboard nav.
- **Section view cards**: not in this pass — earmarked for the next PR (per-section card layout with auto-time = sum of contained kms).
- **Km cards changing size**: fixed. Card width stays 360 px, chart height is now computed from the *steepest* km of the whole race, so every km in a given race uses the same card shape and the Prev/Next buttons stay anchored. Flatter kms get visual headroom above the silhouette — that's the right 1:1 story.
- **Profile axis labels overlapping**: tick count is now width/height-aware (~70 px per distance label, ~28 px per elevation label). FitWidth on a narrow viewport no longer stacks labels on top of each other.
- **Map polish**: aid-station popups show service emojis (💧🍌⛑🚻🎒) + distance from start + planned rest. Start gets a green ▶ marker, finish gets a black 🏁 marker.

After the fix-pass PR lands, the workflow you couldn't actually use last night (target time → auto-distributed kms → manual overrides → notes → CSV download) works end-to-end.

## What shipped (original overnight build)

Full backlog done. 10 PRs, all squash-merged into `master`, all authored as `gillchristian` (no Claude credit, per your rule). Build is clean (`npm run build` ✓), smoke test is clean (`npm run smoke` ✓).

| # | PR | What |
|---|---|---|
| 1 | [#1](https://github.com/gillchristian/trail/pull/1) | Scaffold (Elm 0.19 + Tailwind v4 + Vite, `Gpx.elm` lifted from crest) |
| 2 | [#2](https://github.com/gillchristian/trail/pull/2) | IndexedDB races + hash router + race index/detail |
| 3 | [#3](https://github.com/gillchristian/trail/pull/3) | True 1:1 elevation profile (`Profile.elm`) |
| 4 | [#4](https://github.com/gillchristian/trail/pull/4) | Aid station CRUD + profile markers |
| 5 | [#5](https://github.com/gillchristian/trail/pull/5) | Planning engine + per-km card + table view (Tobler GAP) |
| 6 | [#6](https://github.com/gillchristian/trail/pull/6) | CSV / GPX / `.trail` exports + `.trail` import |
| 7 | [#7](https://github.com/gillchristian/trail/pull/7) | Offline-first PWA shell |
| 8 | [#8](https://github.com/gillchristian/trail/pull/8) | Gamified visual pass (ghost-wave profile, UTMB-style badges, race-card aesthetic, motion) |
| 9 | [#9](https://github.com/gillchristian/trail/pull/9) | Race metadata editing + cover image |
| 10 | [#10](https://github.com/gillchristian/trail/pull/10) | Real-world map (Leaflet + OSM, tile cache for offline) |

Stack ended up exactly as ADR-0001 proposed: Elm + Tailwind + Vite + a few tiny JS ports (IDB, downloads, image picker, custom Leaflet element).

## Try it

```sh
npm install   # if you haven't recently
npm run dev
# open http://localhost:5174   (dev server port, per package.json)
```

Then drop `samples/20k_oh_meu_deus.gpx` onto the index page (or click *Choose a file*). You should land on a race detail with the 1:1 profile drawn in.

## Morning verification checklist

Concrete things to click through to confirm I didn't break anything I couldn't browser-test from here. Should take 10 minutes.

### Core workflow
- [ ] **Upload** `samples/20k_oh_meu_deus.gpx`. Stats look right? Race detail loads?
- [ ] **Reload** the page (Cmd-R). The race is still there?
- [ ] **Add an aid station** (e.g. "Cafetería", 6 km from start, 5 min rest, water + food). Save → marker appears on the profile?
- [ ] **Open the plan**. Set target time `3:00`. Per-km times distribute? Sum matches?
- [ ] **Per-km nav** (click a row, then prev/next at the bottom of the card). Mini-profile renders 1:1?
- [ ] **Manual override**: enter `5:30` on a km, blur the field. M badge appears? Other kms re-distribute?
- [ ] **Edit details** on the race (name, date, location, cover image). Save → re-render the index card with the cover?
- [ ] **Map view**: navigate to `View on map →`. OSM tiles render? Track + numbered markers?
- [ ] **Exports**:
  - GPX for Coros → opens a download. Inspect the `<wpt>` block; verify it has lat/lon/ele/name/desc/sym/type for each aid station.
  - .trail file → re-import it. New race shows up with everything intact (aids, plan, notes, cover).
  - CSV (km mode + sections mode) → open in a spreadsheet; verify columns + Hh:Mm:Ss formatting.
- [ ] **Delete a race** (hover its card; click ✕; confirm). Reload — gone.

### Offline
- [ ] DevTools → Application → Service Workers → confirm `trail` is registered.
- [ ] DevTools → Network → check "Offline". Reload. Page still renders. Map view shows cached tiles (panned-over areas) but new pans go blank — expected.

### Performance
- [ ] Drop `samples/utmb_2025.gpx`. ~26k track points. Initial parse may take a second or two (one-time, on load). After that, scale-mode switches should be instant. Profile and map should render without freezing.

### Coros field test (the real gate)
- [ ] Export the 20k race as GPX. Upload to the COROS app. Enable Waypoint Alerts on the route. Start a Pace Strategy. Confirm the aid stations show up in the segmentation.
- [ ] If they *don't*: that's the real validation gate for [ADR-0002](knowledge/decisions/0002-coros-aid-station-format.md). Open a `BLOCKER` in [`knowledge/progress/blockers.md`](knowledge/progress/blockers.md) with whatever the watch shows; we'll iterate on the `<sym>` / `<type>` / extension shape.

## Where things live

- [`knowledge/`](knowledge/) — the system. Read [`README.md`](knowledge/README.md) for the loop.
- [`knowledge/decisions/`](knowledge/decisions/) — three ADRs (stack, Coros format assumption, Tobler pace).
- [`knowledge/progress/journal.md`](knowledge/progress/journal.md) — the full overnight log (timestamps + what changed + what I learned at each step).
- [`knowledge/planning/DONE.md`](knowledge/planning/DONE.md) — completed-task index with merge shas.
- `src/` is the Elm + JS code. `samples/` is the input fixtures + Coros docs HTML. `scripts/smoke-storage.mjs` is the JS-side IDB roundtrip test (`npm run smoke`).

## Known caveats / parking-lot items

(Backlog parking lot — the **mid-file** section of [`knowledge/planning/BACKLOG.md`](knowledge/planning/BACKLOG.md), between Active and Proposals — is the canonical list. Highlights:)

- **No browser-driven E2E test** in CI. _(Refreshed 2026-06-10.)_ Local CI is the four gates in [`knowledge/reference/local-ci.md`](knowledge/reference/local-ci.md): `npm run smoke` covers the JS-side `races` storage round-trip and `npm run smoke:aidcsv` drives the **real compiled** `AidCsv` parser through a `Platform.worker` harness. Node is now pinned to v22 via `.nvmrc`, so the old "needs `nvm use 22` for jsdom" caveat is moot. A full browser-driven Elm E2E still doesn't exist.
- **Tobler descents** may feel slow on aggressive technical descenders. ADR-0003 calls out the "descent aggressiveness slider" follow-up if it's wrong in practice.
- **Coros GPX format** is an *assumption* (ADR-0002). Real-watch validation pending.
- **Per-km card "ghost-wave" rendering** is only on the main race-detail profile, not on the per-km mini cards. Adding it there is easy; skipped to keep the card visually quiet.
- **Map performance** with UTMB-size 26k-point polyline: Leaflet handles it but rendering may stutter on slow phones. If it matters, we can decimate the polyline with the Douglas-Peucker we already have.

## If you want me to keep going

Bring up specific feedback (anything from "this looks ugly" to "this aid station export didn't work") and I'll iterate. The PR-per-task discipline + the journal mean every change is reviewable in isolation.
