# Caching Strategies

Cadence uses three layers of caching, each with a different strategy.

## 1. Activity List (Summary) — Incremental Sync

**Endpoint:** `GET /api/activities`
**Store:** `activities` SQLite table, keyed by `(athlete_id, activity_id)`
**Strategy:** Sync-on-read with incremental fetching

Every authenticated request fetches from Strava, but only activities after `min(latestCachedDate - 1h, now - 24h)`. Results are upserted into SQLite (raw Strava JSON), then the full list is queried from the DB and returned. The 24h floor ensures recent activity metadata (titles) stays fresh even if no new activities exist.

- First sync: fetches 30 days of history
- Strava errors are non-fatal — falls back to cached data
- `X-Data-Source: strava` if Strava returned activities, `cache` otherwise

## 2. Activity Detail (Compare) — Stale-While-Revalidate

**Endpoint:** `GET /api/activities/{id}/detail`
**Store:** `activity_cache` SQLite table, keyed by `activity_id`
**Strategy:** Cache-first with background revalidation

Always serves from cache immediately if available. On cache miss, fetches from Strava (blocking), computes per-km heart rate from streams, caches the result, and returns it. Requires authentication on miss.

Staleness rules (checked only for authenticated users):
- **Activity < 24h old:** stale after 1h — triggers a background goroutine to re-fetch and update the cache
- **Activity >= 24h old:** never stale — no revalidation

The background refresh is fire-and-forget; errors are logged but don't affect the already-sent response. Next request gets the updated data.

- `X-Data-Source: cache` on hit, `strava` on miss

## 3. Client-Side — localStorage

**Store:** `localStorage` key `cadence-activities`
**Strategy:** Cache with conditional auto-fetch

On page load, cached activities are shown immediately. A fresh fetch is triggered automatically only if the cache has no activity from today (heuristic: if you ran today and it's cached, the list is probably current). Manual refresh is always available.

Stores `{ activities, fetchedAt }`. No TTL — staleness is determined by whether today's data is present.
