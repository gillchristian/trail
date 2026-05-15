# Glossary

Domain-specific terms used in this project. Add entries the moment a term first appears with a specific meaning.

## Format

**Term** — definition. (origin or context if useful.)

## Entries

**athlete_id** — Strava's stable per-user integer ID. Cadence keys its `tokens` and `activities` tables on this. One athlete per database row.

**session_token** — Cadence-generated 32-byte hex string used by frontends as a bearer credential. Currently stored as a UNIQUE column on `tokens`; the trail-integration work moves it to its own `sessions` table so multiple frontends can be authenticated simultaneously for the same athlete.

**origin** — In the trail-integration design, the label on a `sessions` row identifying which frontend created the session: `'cadence'` or `'trail'`. Drives the OAuth callback's redirect target via the `state` parameter.

**streams** — Strava's time-series data for an activity (distance, lat/lng, altitude, heartrate, etc.). Cadence's existing code fetches `distance` + `heartrate` only; the trail-integration work generalises this to any allowlisted key set. **Never cached** — large, immutable, rarely re-read.

**splits_metric** — Strava's pre-computed 1-km splits attached to an activity's detail response. Includes elapsed time, moving time, average speed, elevation difference. Used by `compare.go` for the cadence comparison view.

**backfill** — The background loop that paginates through an athlete's full Strava history and stores activities in the `activities` table. Triggered automatically on first `/api/activities` call; sleeps 2 s between pages.

**FTS5 trigram** — SQLite's full-text-search v5 extension with trigram tokenisation, used by `/api/activities/search` for fuzzy name search. Requires the `fts5` Go build tag.
