# Backlog

Ordered. Top item is next. Promote into `CURRENT.md` when started.

## Active

- [x] TASK-001 — Scaffold the Elm + Vite + Tailwind app, lift Gpx.elm from crest, basic "hello / upload / parse" working end-to-end — (M) ✓ PR #1
- [x] TASK-002 — IndexedDB storage layer + race index page (upload GPX → race appears, persists across reload) — (M) ✓ PR #2
- [x] TASK-004 — True-1:1 profile view (port crest's Main.elm rendering into the Race page) — (M) — ✓ PR #3
- [x] TASK-005 — Aid-station CRUD: add by distance-from-start or distance-from-previous, edit, delete, persist — (M) — ✓ PR #4
- [x] TASK-006 — Per-km planning view (left card with 1:1 mini-profile, right inputs: notes + pace, prev/next nav) — (L) — ✓ PR #5 (combined with TASK-007)
- [x] TASK-007 — Pace distribution engine (Tobler, ADR-0003) + total-target UI, locked vs auto kms — (M) — ✓ PR #5
- [x] TASK-008 — Planning table view (km / section toggle) + CSV export in both modes — (M) — table done in PR #5; CSV export ✓ PR #6
- [x] TASK-009 — GPX export with aid-station waypoints (ADR-0002), downloadable from the race page — (S) — ✓ PR #6
- [x] TASK-010 — `.trail` project file export/import (round-trip: GPX + plan + aid stations) — (M) — ✓ PR #6
- [x] TASK-011 — Gamified visual pass: UTMB-DNA badges, layered/ghost-wave elevation, race-card aesthetic, glow accents, micro-animations — (L) — ✓ PR #8
- [x] TASK-012 — Offline-first: PWA manifest + service worker for app shell + IDB confirmed durable — (M) — ✓ PR #7
- [x] TASK-013 — Real-world map overview view via Leaflet/OSM JS port — (M) — ✓ PR #10
- [x] TASK-003 — Race metadata editing (name inline + date/location/url/notes + cover image upload) — (S) — ✓ PR #9
- [x] TASK-025 — Fix pace bug: per-km Target Time should be clock time (moving + aid rest in that km); Pace stays moving-only. Flows through km card, km table, section table, section card. Manual-typed target subtracts in-km aid rest before storing. See `samples/aid-station.png` for the screenshot the user flagged. — (S) — ✓ PR #34
- [x] TASK-026 — Show HR avg per km on linked actuals (per-km card + km table). Extend the streams fetch to include `heartrate` if it isn't already; persist on `ActualSplits.splits`. — (S) — ✓ PR #35
- [x] TASK-027 — Skeleton/pulse loading state on the home page drop component while a GPX parse is in progress. Pulse animation on the whole drop area, "Parsing <filename>…", input disabled during parse. Applies to file-drop, file-select, and Strava picker paths. — (S) — ✓ PR #36
- [x] TASK-028 — Home page two-section split: "Plans" (no `actualSplits`) and "Executions" (linked). Find better naming if "Plans / Executions" doesn't feel right; the cut is linked-actual vs. not. Section headers + empty states. — (S) — ✓ PR #37
- [x] TASK-029 — Chunked SVG profile path so the elevation chart renders end-to-end on long tracks (Cocodona 250 stops mid-track at 10 m/px). Browser SVG single-path rendering limit; not in Elm. — (S) — ✓ PR #41
- [x] TASK-030 — Populate plan-table Pace / Time / Current-sum from `Predictor.predict` at intensity = 1.0 when `race.plan.targetSeconds = Nothing`, so a freshly-uploaded race shows a sensible plan immediately. Display-only; commit happens on first slider interaction. — (S) — ✓ PR #42

## Parking lot

- **Section-overlap bug.** `Planning.sectionsForRace` uses an overlap test (`km.distStart < b && km.distEnd > a`) when assigning kms to sections. A km that straddles an aid distance is placed in *both* adjacent sections, so `sectionSeconds`, section-card "Time" stat, and section-table cum column all double-count that km. Discovered while scoping TASK-025; the fix wants careful thought about pro-rating and was deferred. Section-card Δ vs plan still has the moving-vs-clock apples-to-oranges bug at the section level; fixing that cleanly needs the section-overlap fix first.
- **Separate `gpxText` into its own IDB row** so plan-only saves (slider commit, aid-station edits, etc.) don't have to re-ship the ~3 MB GPX string across the FFI. PR #29 deferred this by deferring the save off the drag hot path; a schema refactor would let those saves be small.
- Strava GAP-style descent aggressiveness slider (if Tobler feels off in practice).
- Per-km gain/loss separately for slope-factor (instead of net Δele).
- ~~Race-organiser bulk-import (paste a list of aid stations with distances).~~ **Shipped 2026-06-05 as TASK-031** — CSV *file* import/export (+ cutoff, warm food, notes). Paste-a-table can reuse `AidCsv.parse` as-is when wanted.
- Print-friendly export of the planning table.
- Light / dark mode toggle (dark default).
- Multi-language UI ("tramos" → "sections" toggle).
- Comparing planned vs actual after the race (post-MVP, would need an .fit upload).

## Proposals (not yet promoted — see `knowledge/reference/pace-prediction-roadmap.md`)

The roadmap doc covers the why and the trade-offs. These entries are the *chunks* that would come out of it if approved. Do not promote into Active without an explicit go-ahead from the user.

- **TASK-014 — Course summary card additions.** Equivalent flat distance + elevation density label, shown on race index/overview. (S, no Strava needed.)
- **TASK-015 — Per-km segment classification by grade.** Colour tag in the planning table derived from `Km.slope`. (S.)
- **TASK-016 — Planned-vs-actual upload (manual `.gpx`).** Snap to course, compute actual splits at planned km boundaries, render diff column. **High-leverage, fully local.** (M.)
- **TASK-017 — Profile data model + IDB store + settings page.** Hand-set fields, preset picker (Mid-pack / Strong mid-pack / Sub-elite), one global active profile. (M.)
- **TASK-018 — `Predictor.predict` module (Layer B).** Pure function; climb + descent + runnable + aid; takes profile + intensity. Unit-tested. Depends on TASK-017. (M.)
- **TASK-019 — Bidirectional aggressiveness slider on the planning page.** Intensity ↔ target time, inverse via bisection of the predictor. Depends on TASK-018. (M.)
- **TASK-020 — Confidence indicator surfacing on predictor output.** Annotated by profile source. (S.)
- **TASK-021 — Strava streams parser.** Reconstruct a usable `Gpx.Track`-shaped value from cadence's streams response (keyed-object form, see spec §4.4). Pure Elm decoder + transform; takes JSON, produces `{ points, cumDist, totalDist }`. Local-only — works on any streams JSON, whether from cadence or a manual dump. (M.)
- **TASK-022 — Calibration from past activities.** Fit `vmh`, fatigue slope, optional HR bands. Surface "what changed and why." Depends on TASK-021 (streams parser) + TASK-024 (auth wiring). (L — split when picked up.)
- ~~**TASK-023 — Decision: OAuth helper or stay manual.**~~ **Resolved 2026-05-15.** Decision: extend `cadence`'s backend. Spec at `knowledge/reference/cadence-backend-spec.md`; cadence shipped all 5 PRs. Addendum 1 (broaden OAuth scope to `profile:read_all` for `max_heartrate` / `weight` / `ftp` / `measurement_preference`) drafted at `knowledge/reference/cadence-backend-spec-addendum-1-profile-scope.md` — pending hand-off to a cadence session.
- ~~**TASK-024 — Strava OAuth integration in trail.**~~ **Shipped.** v1 (PR #25): token storage + Connect/Disconnect. b (PR #26): activity picker + streams fetch + persist via `StravaStreams.parse` → `ActualGpx.computeSplits`.

Open questions to resolve before promoting any of the above: see roadmap §9.
