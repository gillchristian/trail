# 0005 — Store GPX text in its own IndexedDB row

**Date:** 2026-06-15
**Status:** accepted

## Context

A `Race` carries `gpxText : String` — the raw GPX, ~3 MB for a UTMB-size track.
Until now the whole race object (GPX included) was the value in the single
`races` IDB store, and every `Storage.saveRace (encodeRace …)` re-encoded and
re-shipped that 3 MB across the Elm↔JS port and rewrote it to IDB. Almost all
of the 14 save sites are plan/aid/metadata/actual edits — including the slider
commit, the hot path — none of which change the GPX (it's set once, at import,
and never edited). PR #29 only worked around the *drag* case (`SliderInput` is
live-only). TASK-040 is the real fix.

## Decision

Split persistence into two stores (DB version 2 → 3):

- `races` — the race **without** `gpxText`.
- `gpx` — `{ id, gpxText }`, keyed by race id; written **once** at import.

Two save paths: `saveRace` (full — import/new race) writes both stores and
echoes the full race back; `saveRaceMeta` (light — every edit) writes only the
`races` row from a `gpxText`-free payload (`Types.encodeRaceMeta`). On load, JS
re-joins `gpxText` into each race so the Elm decoder is unchanged in spirit
(the field is just sourced from the other store). The `RaceSaved` echo refills
`gpxText` from the in-model race when a light echo omits it. `onupgradeneeded`
migrates existing v2 races by moving inline `gpxText` into the `gpx` store and
stripping it from the `races` row. `deleteRace` removes both rows.

## Alternatives considered

- **Patch/merge save in one store** (ship only changed fields; JS reads the
  stored race, applies them, writes back). Avoids the Elm→JS *send* cost but
  still rewrites the 3 MB row to IDB on every edit, and the parking-lot item
  explicitly asked to *separate the row*. Rejected.
- **Drop `gpxText` from the Elm `Race` model** (thread the GPX separately).
  Much larger blast radius — `GpxExport`, profile parse, `.trail` export all
  read `race.gpxText`. Keeping the field in the model and splitting only the
  *persistence* path is far less invasive. Rejected.
- **No migration (lazy split on next save).** Leaves v2 races inline while the
  loader expects the join — inconsistent and fragile. Rejected in favor of an
  explicit `onupgradeneeded` migration.

## Consequences

- Plan/aid/metadata/actual edits no longer ship or rewrite the GPX — the slider
  commit and aid edits become small saves.
- The `.trail` file format is unchanged: `ProjectFile` still uses the full
  `encodeRace`, so exports keep the GPX. No `.trail` version bump.
- New invariants to keep: the load-join, the `RaceSaved` gpx-refill, and
  `deleteRace` clearing both rows. `scripts/smoke-storage.mjs` (a faithful
  mirror of `main.js`'s IDB logic — it can't import it) guards the split,
  migration, light-save, and orphan-free delete.
- Verification gap: the JS-mirror smoke + the Elm compiler + the Vite build
  cover everything testable headlessly (the project can't drive the compiled
  Elm bundle from Node — see the smoke header), but a human browser round-trip
  (import → edit → reload) is still the recommended final check on any IDB
  schema change.
