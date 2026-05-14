# Done

Tasks that passed all verification gates. Newest at top.

Each entry: the TASK-NNN id, title, the date completed, and a one-line summary of what shipped + a link/pointer to the journal entry.

```
- TASK-NNN — title — YYYY-MM-DD — one-line summary — see journal YYYY-MM-DD HH:MM
```

## Completed

- TASK-005 — aid-station CRUD on the race detail page — 2026-05-15 — Aid stations live on the Race record (per-race id seq, no uuid lib). Inline add/edit form with "from start" / "from previous" toggle, rest-minutes, services multi-select (water/food/medical/wc/drop-bag). Markers render on the profile chart. Backwards-compatible decoder defaults to [] for old IDB records. PR #4 (TBD). See journal 2026-05-15 05:30.
- TASK-004 — true-1:1 elevation profile view — 2026-05-15 — Profile.elm lifted from crest with dark-theme retune (rose gradient, slate grid), in-model parsed-track cache so UTMB-size GPX parses once on RacesLoaded and renders instantly afterward, viewport-aware container width via Browser.Events.onResize. PR #3, merged as `1287f25`. See journal 2026-05-15 04:00.
- TASK-002 — race storage + index + routing — 2026-05-15 — Browser.application shell with hash router, IndexedDB-backed Race persistence, race index grid with delete-confirm, race detail stub. PR #2, merged as `34b8c7b`. See journal 2026-05-15 03:00.
- TASK-001 — scaffold Elm + Vite + Tailwind app — 2026-05-15 — Elm 0.19 + Tailwind v4 + Vite project bootstrapped, Gpx.elm lifted from crest, file-upload happy path renders track stats. PR #1, merged as `0419712`. See journal 2026-05-15 01:35.
