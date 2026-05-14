# Project brief — Trail

## What it is

**Trail** is a local-first browser app for preparing trail-running races. The user uploads a GPX of the course and uses the app to: see an overview, study the elevation in *true 1:1 scale*, define aid stations, write a kilometer-by-kilometer race plan with target pace, export a Coros-compatible GPX with aid-station waypoints, and re-import the whole project to keep iterating.

## Why it exists

The user runs trail races — a 20k next weekend, plus 110k and 130k targets later in the season. Existing tools (Strava, race-organiser pages) stretch elevation profiles vertically and don't expose a true sense of the climbs. Trail keeps the elevation honest (1:1 aspect ratio) and makes per-km planning a first-class workflow rather than an afterthought. The output integrates with the Coros watch via its **Pace Strategy** feature, which consumes routes with waypoints + waypoint alerts.

## Hard constraints

- **Local-first.** Works fully offline after first load. No backend, ever. Data lives in the browser.
- **Persistence.** Races + plans must survive reload. UTMB-size GPX (~80k lines) must fit comfortably → IndexedDB.
- **Performance target.** Parse + render UTMB-size GPX (~26k track points) without freezing the UI. 20k races (~3k points) should feel instant.
- **Type safety.** "If it compiles it works." Custom types model impossible-states-impossible (`State = Empty | Parsing | Failed | Loaded`).
- **No Claude credit anywhere.** Commits + PRs authored under the user's name only.
- **PR workflow.** After the `Batman` root commit, every change reaches `master` via a branch → PR → squash-merge cycle.

## Soft preferences

- Reusable code without over-abstraction (three usages before extraction).
- Simple stack — no Next.js, no Elm Land.
- Hash-based router, hand-rolled.

## Out of scope

- No backend / multi-user / sync.
- No social / sharing features.
- No paid map providers (no Mapbox token).
- No miles unit — kilometers only.
- No live activity tracking — this is *planning*, not *recording*.

## Stack

Locked in as ADR-0001:

- **Elm 0.19.1** — single-page app, `Browser.element` (or `Browser.application` once we add routing).
- **Tailwind v4** via `@tailwindcss/vite`.
- **Vite 6** with `vite-plugin-elm`.
- **IndexedDB** via a tiny JS port (no library dep needed; ~50 lines of vanilla JS).
- **Service worker** (vanilla; no Workbox) for offline shell + opportunistic tile cache.
- **Reused from Crest:** `Gpx.elm` verbatim — regex parser, Haversine distances, iterative Douglas-Peucker, elevation-gain-loss with 2m noise threshold. Iterative DP already proven on UTMB-size data.

## Features (priority order — see `planning/BACKLOG.md` for tasks)

1. Upload GPX, race appears on index, persists in IDB.
2. True-scale (1:1) elevation profile view.
3. Aid-station CRUD (input by distance-from-start or distance-from-previous).
4. Per-km planning UX with GAP-distributed target pace (Tobler-based).
5. Table view (km / section toggle) + CSV export.
6. Modified GPX export for Coros (waypoints + standard tags).
7. `.trail` project file export/import (full round-trip).
8. Gamified visual pass — UTMB-DNA + own personality.
9. **Offline-first** (PWA manifest + SW + cache strategy) — high priority per user.
10. Real-world map view (Leaflet + OSM via JS port) — last, nice-to-have.

## Visual direction

Hybrid: **UTMB DNA** (circular aid-station badges, layered/ghost-wave elevation rendering, pill distance markers, modal detail cards — see `samples/profile-01/03/04/05.png`) crossed with **our own gamified personality** (glow accents, animated reveal of segments, custom badge variants, race-card aesthetic from `samples/race-cards.png`). **Not** the flat Strava grey of `samples/profile-02-strava.png`.

## Race metadata fields

Per race (resolved with user 2026-05-15):

- `name` (required)
- `date` (optional)
- `location` (optional, free text)
- `url` (optional — link to race info / registration)
- `distance` (auto from GPX)
- `gain` / `loss` (auto from GPX)
- `notes` (free text)
- `coverImage` (optional, uploaded as data-URL, stored in IDB)

## Per-km card dimensions

Resolved with user 2026-05-15: card width fixed, sized to fit on an iPhone (≤ ~390 px useful width). On a 14" MacBook the planning view is two columns — card on the left half (centered), notes/pace inputs on the right. On mobile it stacks: card on top, inputs below (scroll).

The card draws elevation in true 1:1 (vertical m/px = horizontal m/px) inside the fixed-width frame. A 100 m climb on a 360 px-wide card renders as 36 px of elevation. Aid stations show as labeled vertical markers within the km they fall in. Boundaries are round 1 km from start; the last partial km is handled as-is.

## Pace model

Resolved with user 2026-05-15: **both** approaches, chained.

1. User enters a target total time + optional default time at each aid station.
2. App distributes target across kms using GAP based on per-km slope (Tobler-style; see ADR-0003).
3. User can override any individual km. Edited kms become "locked" — they keep their value while unlocked kms redistribute the remaining budget.
4. User can also start from scratch — set every km manually.
5. The total time row shows current sum vs target, with a visible diff if they don't match.

## Success criteria

- The user uploads the 20k GPX next weekend, adds aid stations, exports a Coros GPX, uploads to the Coros app, and Pace Strategy picks up the aid stations on the watch.
- The same workflow scales to UTMB (~170 km, ~10k m gain) without lag.
- The visual style is clearly **not** Strava-formal — it feels gamified, fun.
- All of this works offline after the first load.

## Open questions (deferred — not blocking)

- **Coros exact GPX format on the watch.** The public docs don't pin down the schema. We're going with standard GPX `<wpt>` (lat/lon/ele/name/sym/type). Validation = user testing on the watch with the 20k race. If it doesn't work, ADR-0002 gets revised and the export path updated. Tracked in `progress/blockers.md` only if the test fails.
- **GAP function tuning.** Tobler's curve has the descent-fastest point at -5% grade. Some trail runners go faster on steeper descents. We start with Tobler; if real-world planning consistently feels wrong, expose a "descent aggressiveness" slider in a follow-up.

## Raw notes (user words, 2026-05-15)

> "Process a GPX file and render it. This should be an overview of the course. Maybe it could use real world maps."
>
> "Modify the GPX adding the aid stations. This should be in a standard format and support re-downloading the GPX file. The goal is that I can upload this to the new Coros feature: Pace Strategy."
>
> "Each GPX file is associated with a race. Thus there should be a view for races, a card view of all the races uploaded with some of their information and a miniature view of the GPX."
>
> "View the GPX file in it's profile. ... the goal of that project was render the profile in a 1:1 ration between both axis. You know how normally the Y axis is disproportionally tall compared to the X axis."
>
> "A special view of the profile that will render one kilometer at a time. This is the center for the planning UX. On the left of the screen, you will render a 'card' like element that shows the 1:1 profile of the kilometer, and on the right I will be able to add notes about it, and target pace."
>
> "It should be possible to download some other file (with our own extension) that would contain all the other information ... so we can export and import."
>
> "Make sure to use cool styles, something maybe kinda gamified. Don't go for an UI like Strava's that is very formal and simple. Do something cool. Feel free to add animations and stuff."
>
> "This should be an entirely local first application."
>
> "Pick what you prefer."
>
> "I expect to have a working application tomorrow morning."

> Pace model worked example (user):
> "3km race, one flat, one 150m elevation, one 150m down. I predict 15min. This is a 5min/km. But the down might be 3:30, the flat might be 4:30, the up then is 7min. What I'm trying to say is it should add up."
