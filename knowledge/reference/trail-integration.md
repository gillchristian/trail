# Trail integration

## The relationship

**Trail** (`~/dev/trail/`) is a separate Elm app for trail-race planning. It's local-first — race state, plans, and athlete profiles live in IndexedDB. The one thing it cannot do locally is the OAuth round-trip with Strava (needs a server with a client secret) and proxying authenticated Strava API calls.

Rather than spin up a dedicated helper service, the user has chosen to extend **cadence**'s existing backend to serve both frontends. Cadence keeps its single-machine, single-user, SQLite-backed shape — it just grows two new endpoints (`/api/activities/{id}/streams`, optional `/api/athlete`), multi-origin CORS, OAuth `state`-based origin routing, and a sessions table.

## Where the canonical spec lives

**`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`**

This file is read-only from cadence's perspective. Trail is the upstream driver. If something in the spec seems wrong or contradictory, file a blocker in `progress/blockers.md` rather than editing trail's repo.

## What's in scope for cadence

Five PRs, in order, each independently deployable:

1. **Sessions table** — split `tokens` (per athlete) from `sessions` (per logged-in frontend). Migrations 013–016. Spec §4.3 / §7.
2. **Multi-origin CORS** — env var `FRONTEND_URLS`, comma-separated. Spec §4.1.
3. **OAuth state routing** — `?origin=trail|cadence`, `state` carries nonce + origin, callback picks the right redirect target. Spec §4.2.
4. **Streams endpoint** — `GET /api/activities/{id}/streams?keys=...` with an allowlist validator. No caching. Spec §4.4.
5. **(Optional) Athlete pass-through** — `GET /api/athlete`, 24 h cache. Spec §4.5.

The detailed acceptance criteria are in `planning/BACKLOG.md`.

## What's out of scope for cadence

- Trail-domain state. Races, plans, profiles, `race ↔ stravaActivityId` links — **all** live in trail's IDB. Cadence's database does not gain new tables for any of these.
- Endpoints that only trail uses, beyond §4.4 and §4.5. If trail later needs richer functionality, that's a new spec revision.
- Webhooks, multi-user, real-time. None of this is part of the integration.

## Hand-off brief (copy-pasteable)

If starting a fresh agent session to work this initiative, the brief from spec §12 is reproduced below verbatim. Read the spec file in full before starting any task.

> You're working in `~/dev/cadence/`. The trail project (a separate Elm app at `~/dev/trail/`) needs to use this backend for Strava OAuth + activity-streams proxy. The full spec is at `~/dev/trail/knowledge/reference/cadence-backend-spec.md`.
>
> Implement the changes in §4 of that spec, in five PRs, in this order:
>
> 1. **Schema split (§4.3 / §7).** New migrations 013–016: split `tokens` into `tokens` (no session_token) + `sessions` (PK session_token, FK athlete_id, columns origin/created_at/last_seen_at). Migrate existing data with `origin='cadence'`. Update `store/token.go` — `GetTokensBySession` joins, `SetTokens` upserts into tokens + inserts a session row, `ClearTokensBySession` deletes from sessions only. Add `last_seen_at` update in `GetTokensBySession`. Don't change handler signatures yet.
>
> 2. **CORS multi-origin (§4.1).** `main.go` accepts `FRONTEND_URLS` (comma-separated) or falls back to existing `FRONTEND_URL`. Pass the parsed slice to `cors.Handler`.
>
> 3. **OAuth state + origin routing (§4.2).** Add `?origin=` to `/auth/strava`, default `cadence`. Encode `{nonce, origin}` as base64-url JSON into `state`. Store nonce in an in-memory `sync.Map` with 5-min TTL. `Callback` validates nonce + decodes origin + redirects to `FRONTEND_URL_<ORIGIN>` (env vars `FRONTEND_URL_TRAIL`, `FRONTEND_URL_CADENCE`; fall back to `FRONTEND_URL`). Pass `origin` through to `sessions.origin` when inserting.
>
> 4. **Streams endpoint (§4.4).** New handler `GET /api/activities/{id}/streams`. Auth-required. Accepts `?keys=` (comma-separated, allowlist-validated against Strava's documented stream keys). Generalise `strava.Client.FetchActivityStreams` to take `keys []string` instead of hardcoded `distance,heartrate`. Pass `key_by_type=true` to Strava and return the keyed-object response as-is. **Do not cache.** Log rate-limit warnings at >80 %.
>
> 5. **(Optional) Athlete pass-through (§4.5).** `GET /api/athlete` returning Strava's `/athlete` response. Cache 24 h in `activity_cache` (or a new tiny `athlete_cache` row, your call).
>
> Constraints:
> - One PR per step. Each PR independently deployable.
> - Existing cadence frontend keeps working at every step. Verify with `cd server && go run -tags fts5 .` + the cadence client locally.
> - Don't add fields to JSON responses cadence's frontend doesn't expect; if a stream-key validator rejects an unknown key, return 400 with `{"error": "unknown stream key: X"}`.
> - SQLite migrations must be idempotent and survive re-runs. Follow the existing `migrate.go` pattern.
> - Don't bump the Strava rate-limit risk on the cadence side — cadence's existing call patterns shouldn't change.
>
> When you're done with each PR, report back what changed in `server/` and which migration IDs you added. The trail-side integration (TASK-024 in trail's BACKLOG) will be done separately.

## Communication back to trail

The trail repo tracks the integration in `trail/knowledge/planning/BACKLOG.md` under TASK-024 ("Strava OAuth integration"). When PRs ship here, note the merge sha + a one-line summary in your own journal — trail's side will reference this when it picks up TASK-024.

If a spec section turns out to need revision (e.g. an unforeseen Strava API behaviour, a schema concern), the right path is:
1. File a blocker in `progress/blockers.md`.
2. Stop work on the affected task.
3. The user routes the revision request to trail; trail updates the spec; work resumes.

Do not silently reinterpret the spec.
