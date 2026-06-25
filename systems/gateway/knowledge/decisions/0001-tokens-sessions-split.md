# 0001 — Split `tokens` into `tokens` + `sessions`

**Date:** 2026-05-15
**Status:** accepted
**Implemented by:** PR #2 (`3e85f86`), TASK-001.

## Context

Before this change, `tokens` was keyed by `athlete_id` with a single `session_token` column. Each OAuth flow ran `UPSERT ON CONFLICT(athlete_id) DO UPDATE SET session_token = excluded.session_token`, which silently invalidated any other browser that was already holding a session. With cadence + trail wanting to coexist for the same Strava athlete, this would have been a constant logout-loop. The trail spec (§4.3 / §7) called for splitting the table.

## Decision

Two tables, additive migrations 013-016:

- `tokens(athlete_id PK, access_token, refresh_token, expires_at)` — one row per Strava-authorised athlete; holds the Strava credentials only.
- `sessions(session_token PK, athlete_id FK, origin, created_at, last_seen_at)` — one row per browser/frontend that's logged in. Many rows can point at the same athlete.

`GetTokensBySession` joins on `athlete_id`. `SetTokens(t, sessionToken, origin)` is transactional: UPSERT into tokens, INSERT into sessions. `ClearTokensBySession` removes from `sessions` only — Strava credentials survive other sessions logging out. `last_seen_at` advances on each successful resolve.

The migration copies existing rows into both new tables, seeding `origin='cadence'` for back-compat, then drops the old table and renames `tokens_v2 → tokens`. SQLite 3.25+ auto-rewrites the sessions FK during the rename.

## Alternatives considered

- **Keep one table, add an `origin` column.** Would have left the UPSERT-by-`athlete_id` foot-gun in place. Rejected — the whole point is to support multiple concurrent sessions per athlete.
- **Sessions in a separate datastore (Redis, JWT-only).** Adds infra and contradicts cadence's single-machine SQLite shape. Rejected.
- **Soft-deprecate the old `tokens` table, dual-write for a release.** Cadence is a one-user app on a single Fly volume — no value in a deprecation window. The atomic data migration runs once on startup and is idempotent.

## Consequences

- **Makes easy:** multiple frontends authenticated for the same athlete; per-session telemetry (`origin`, `last_seen_at`); a future "log out everywhere" by deleting all rows for an `athlete_id`.
- **Makes harder:** any future analytics that want a "currently active session" count now require a query against `sessions`, not the single row in `tokens`.
- **Revisit if:** we ever introduce session expiry (`last_seen_at` is in place; a sweep job would be a small follow-up); or if we ever need cross-machine sessions (would require moving sessions out of SQLite, which conflicts with the "single Fly machine" constraint).
