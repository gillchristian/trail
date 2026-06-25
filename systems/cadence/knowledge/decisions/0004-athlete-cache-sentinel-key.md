# 0004 — Athlete cache reuses `activity_cache` via a sentinel key

**Date:** 2026-05-15
**Status:** accepted
**Implemented by:** PR #6 (`c21d44b`), TASK-005. See `athleteCacheKey` in `server/store/activity_cache.go`.

## Context

The trail spec (§4.5) calls for a 24h cache of the `GET /api/athlete` pass-through, and explicitly leaves the storage shape to us: "Either reuse `activity_cache` with a sentinel id, or a new tiny `athlete_cache` row. Pick whichever is smaller code-diff." The choice deserves a written rationale because a future reader inspecting `activity_cache` will see a row with `activity_id = -777` and wonder.

## Decision

Reuse the existing `activity_cache` table. Athlete entries are keyed by `athleteCacheKey(id) = -id` (a small helper in `store/activity_cache.go`). Two thin wrappers — `GetAthlete(athleteID)` / `SetAthlete(athleteID, json)` — delegate to the existing `Get` / `Set` with the negated key. A one-liner comment above `athleteCacheKey` explains the rationale so a reader doesn't go hunting for an `athlete_cache` table.

## Alternatives considered

- **New `athlete_cache` table + migration 017.** ~20 LoC of store + a migration. Cleaner schema, no surprising negative keys. Rejected: the spec asked for the smaller diff, and this would be ~3× the new code without any operational benefit at single-user scale.
- **In-memory cache.** Trivial code but invalidates on every restart, defeating the 24h TTL goal. Rejected.
- **Sentinel key inside a positive-only range (e.g. `athleteID + 1e18`).** Avoids negatives but is harder to read and harder to query out of the DB. Rejected.

## Consequences

- **Makes easy:** no migration to ship; uses the existing well-tested cache write/read path; the handler's TTL check (`isAthleteCacheFresh`) only knows about timestamps, not storage layout.
- **Makes harder:** anyone querying `activity_cache` directly has to remember the negative-key convention (`SELECT * FROM activity_cache WHERE activity_id < 0` gets athlete rows). The wrapper functions hide it from Go callers; SQL ad-hoc work has to know.
- **Revisit if:** the cache shape needs to grow (e.g. per-key TTLs, per-athlete metadata beyond a single blob). At that point, splitting into a dedicated table is the natural move and the sentinel can be dropped.
