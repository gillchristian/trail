# Backlog

Ordered. Top item is next. Promote into `CURRENT.md` when started.

## Active

- [x] TASK-001 — Scaffold the Elm + Vite + Tailwind app, lift Gpx.elm from crest, basic "hello / upload / parse" working end-to-end — (M) ✓ PR #1
- [x] TASK-002 — IndexedDB storage layer + race index page (upload GPX → race appears, persists across reload) — (M) ✓ PR #2
- [x] TASK-004 — True-1:1 profile view (port crest's Main.elm rendering into the Race page) — (M) — ✓ PR #3
- [ ] TASK-005 — Aid-station CRUD: add by distance-from-start or distance-from-previous, edit, delete, persist — (M)
- [ ] TASK-006 — Per-km planning view (left card with 1:1 mini-profile, right inputs: notes + pace, prev/next nav) — (L)
- [ ] TASK-007 — Pace distribution engine (Tobler, ADR-0003) + total-target UI, locked vs auto kms — (M)
- [ ] TASK-008 — Planning table view (km / section toggle) + CSV export in both modes — (M)
- [ ] TASK-009 — GPX export with aid-station waypoints (ADR-0002), downloadable from the race page — (S)
- [ ] TASK-010 — `.trail` project file export/import (round-trip: GPX + plan + aid stations) — (M)
- [ ] TASK-011 — Gamified visual pass: UTMB-DNA badges, layered/ghost-wave elevation, race-card aesthetic, glow accents, micro-animations — (L)
- [ ] TASK-012 — Offline-first: PWA manifest + service worker for app shell + IDB confirmed durable — (M)
- [ ] TASK-013 — Real-world map overview view via Leaflet/OSM JS port — (M)
- [ ] TASK-003 — Race metadata editing (name inline + date/location/url/notes + cover image upload) — (S) — **deprioritized; can land alongside the visual polish task**

## Parking lot

- Strava GAP-style descent aggressiveness slider (if Tobler feels off in practice).
- Per-km gain/loss separately for slope-factor (instead of net Δele).
- Race-organiser bulk-import (paste a list of aid stations with distances).
- Print-friendly export of the planning table.
- Light / dark mode toggle (dark default).
- Multi-language UI ("tramos" → "sections" toggle).
- Comparing planned vs actual after the race (post-MVP, would need an .fit upload).
