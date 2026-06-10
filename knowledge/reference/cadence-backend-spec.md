# Spec: extending cadence's backend to serve trail

**Status:** implemented — greenlit (2026-05-15) and shipped. cadence merged all
five PRs (§12); trail consumes the backend via `StravaApi.elm` + `StravaStreams.elm`
(TASK-024 PR #25, TASK-024b PR #26). Kept as the design + interface record. One
follow-up scope change is still pending on the cadence side — see Addendum 1
(`cadence-backend-spec-addendum-1-profile-scope.md`).
**Companion to:** `pace-prediction-roadmap.md` §6 (Strava integration phasing) and §8 (local-first tension).
**Audience:** an agent working inside `~/dev/cadence/` once the user has approved this direction. The §12 brief at the bottom is the hand-off prompt; everything above it is context.

This is a *minimal* extension. The goal is to make cadence's backend serve both frontends (cadence and trail) with the fewest possible changes, without forking. trail's local-first character is preserved: all race / plan / profile state stays in trail's IDB; cadence's backend only does OAuth + Strava proxy.

---

## 1. Goal

trail (browser, Elm + IDB) needs Strava data to do two things:

1. **Planned-vs-actual** — fetch a completed activity, reconstruct a track, snap it to the planned course, render per-km diff.
2. **Calibration** — bulk-pull past activity streams to fit profile coefficients (vmh, fatigue slope, sustainable HR by duration).

Neither requires server-side state about trail (no races, no plans, no profiles stored server-side). The backend's only role is **OAuth + a thin Strava proxy with the existing token-refresh machinery**.

---

## 2. Why cadence, not a new backend or `strava-mcp`

- **cadence is already deployed** (Fly, scale-to-zero, persistent volume). One machine, one user.
- **cadence already has** OAuth, token refresh, activity listing, search (FTS5 trigram), per-activity detail with metric splits + HR extraction from streams, and a backfill loop. trail needs ~80 % of this.
- **strava-mcp** is MCP-transport-shaped — its auth flow is for Claude, not for a browser. Reusing it would mean retrofitting browser OAuth on top of MCP semantics. Not worth it.
- **A new dedicated backend** duplicates infra (Fly app, secrets, deploy pipeline) for code that already exists.

The cost is **coupling**: changes in cadence's backend can break trail and vice versa. Mitigation: keep the trail-facing surface narrow (auth + a couple of read-only proxy endpoints) and version it implicitly (additive changes only).

---

## 3. Architecture

```
                   ┌──────────────────────┐
                   │  Strava API v3       │
                   └────────▲─────────────┘
                            │  HTTPS, Bearer
                            │
                ┌───────────┴────────────┐
                │  cadence backend       │
                │  (Fly, Go, chi)        │
                │                        │
                │  /auth/*               │
                │  /api/activities       │   ← shared
                │  /api/activities/{id}/ │
                │     detail             │   ← shared
                │  /api/activities/{id}/ │
                │     streams            │   ← NEW for trail
                │  /api/activities/      │
                │     search             │   ← shared
                │                        │
                │  SQLite on /data       │
                │   - tokens             │   schema change: split into
                │   - sessions  (NEW)    │     tokens + sessions
                │   - activities (cache) │
                │   - activity_cache     │
                │   - athletes           │
                │   - backfill_status    │
                └─────▲────────────▲─────┘
                      │            │
              CORS: origins = [cadence-frontend, trail-frontend]
                      │            │
       ┌──────────────┴──┐    ┌────┴──────────────────┐
       │  cadence client │    │  trail (Elm, IDB)     │
       │  (Vercel)       │    │  (Vercel / wherever)  │
       └─────────────────┘    └───────────────────────┘
```

trail's IDB owns: races, plans, profiles, `race ↔ stravaActivityId` links. cadence's backend never sees any of those.

---

## 4. Required backend changes

In rough order of size:

### 4.1 CORS: multi-origin

`main.go` currently reads `FRONTEND_URL` (single). Replace with `FRONTEND_URLS` (comma-separated) parsed into `[]string` passed to `cors.Options.AllowedOrigins`. Keep `FRONTEND_URL` as a fallback if `FRONTEND_URLS` is unset (back-compat).

Trivial. ~10 lines.

### 4.2 OAuth state for origin routing

Right now `AuthHandler.Callback` redirects to a fixed `h.FrontendURL`. With two frontends, the callback has to know where the OAuth flow *originated* so it can redirect back there.

OAuth's `state` parameter is the standard answer. Two responsibilities for `state`:

1. **Origin routing** — which frontend to redirect to.
2. **Anti-CSRF** — bind the callback to a session-local nonce so a stolen `code` can't be replayed cross-session.

Proposed shape:

```
state = base64url(JSON({ "origin": "trail" | "cadence", "nonce": <random 16 bytes> }))
```

- `StravaRedirect` accepts `?origin=trail` (or `?origin=cadence`, default cadence for back-compat). It generates a nonce, stores `(nonce → origin)` in a short-lived in-memory map (5 min TTL) or a tiny `oauth_states` table, and includes the encoded `state` in the redirect to Strava.
- `Callback` decodes `state`, validates the nonce, looks up the origin, and redirects to `FRONTEND_URLS[origin]` with the session token in the query string (as today).

Configure `FRONTEND_URLS` as a map: env var `FRONTEND_URL_TRAIL` + `FRONTEND_URL_CADENCE` (clearer than parsing a structured env var). Both fall back to existing `FRONTEND_URL` if unset.

### 4.3 Sessions table (multi-session per athlete)

**This is the most architecturally meaningful change.** Currently `tokens` is keyed by `athlete_id` with `session_token TEXT NOT NULL UNIQUE`. Each new OAuth flow `UPSERT ON CONFLICT(athlete_id)` overwrites the existing `session_token`, invalidating any other browser/frontend that was holding it.

If trail and cadence are both authenticated and trail goes through OAuth again, cadence's session is silently killed. Game-of-musical-chairs.

Fix: split into two tables.

```sql
-- tokens: one row per athlete, holds the Strava credentials
CREATE TABLE tokens_v2 (
    athlete_id    INTEGER PRIMARY KEY,
    access_token  TEXT NOT NULL,
    refresh_token TEXT NOT NULL,
    expires_at    INTEGER NOT NULL
);

-- sessions: many rows per athlete, one per logged-in browser/frontend
CREATE TABLE sessions (
    session_token TEXT PRIMARY KEY,
    athlete_id    INTEGER NOT NULL REFERENCES tokens_v2(athlete_id),
    origin        TEXT NOT NULL,           -- 'trail' | 'cadence' | future
    created_at    INTEGER NOT NULL,
    last_seen_at  INTEGER NOT NULL
);
CREATE INDEX idx_sessions_athlete ON sessions(athlete_id);
```

Migration (`013_split_tokens_sessions.sql`):
- Copy existing `tokens` rows into `tokens_v2` (drop `session_token` column).
- Copy `(session_token, athlete_id)` into `sessions` with `origin='cadence'` (best guess for existing data).
- Drop old `tokens` table. Rename `tokens_v2` → `tokens`.

Code changes (small):
- `store/token.go`: `GetTokensBySession` joins `sessions` and `tokens` on `athlete_id`. `SetTokens` becomes two operations: upsert into `tokens` (by athlete_id), insert into `sessions` (new row, new session_token).
- `ClearTokensBySession` deletes from `sessions` only (don't wipe the Strava tokens — other sessions might still be using them). Add a separate `ClearAllSessions(athlete_id)` for a "log out everywhere" flow if ever needed.
- `auth_handler.Callback`: after token exchange, insert a new `sessions` row, return that token to the frontend.

**Acceptance:** a user can be logged in to trail and cadence simultaneously, with two distinct session tokens, both resolving to the same `athlete_id` and Strava tokens.

### 4.4 New endpoint: `GET /api/activities/{id}/streams`

cadence already calls Strava's `/activities/{id}/streams` internally (in `compare.go`'s `fetchAndCacheActivity` → `FetchActivityStreams`), but only fetches `distance` and `heartrate`. trail needs the **full set** to reconstruct a usable track.

Proposed handler:

```
GET /api/activities/{id}/streams?keys=time,distance,latlng,altitude,heartrate,velocity_smooth,grade_smooth

→ 200 application/json
   Strava `key_by_type=true` shape — each key maps to an OBJECT with a `data`
   array (NOT a bare array). This nesting is load-bearing: `StravaStreams.parse`
   decodes `D.field key (D.field "data" inner)` (`src/StravaStreams.elm`), so a
   client built against a flat-array example would fail to decode.
   { "time":      { "data": [ ... ] },
     "distance":  { "data": [ ... ] },
     "latlng":    { "data": [[lat,lng], ...] },
     "altitude":  { "data": [ ... ] },
     "heartrate": { "data": [ ... ] }, ... }
```

Requirements:
- Auth required (`Authorization: Bearer <session_token>`). 401 if missing/unknown.
- Validate `keys` against the Strava-allowed set; reject unknown keys with 400.
- **Do not cache streams.** They're large (~MB for long activities) and the cache strategy doc explicitly says "streams are never cached." Each call hits Strava.
- Rate-limit awareness: log when approaching 80 % of 15-min quota (the existing `StravaClient` in strava-mcp does this; cadence's client is simpler — add the same behaviour or document that backfill-style flows must throttle from the client side).
- Returns `key_by_type=true` shape (object keyed by stream type) — cleaner for clients than the array-of-typed-entries form.

`strava/client.go` already has the `FetchActivityStreams` function but hardcodes `keys=distance,heartrate`. Generalise it to accept a `[]string` of keys.

### 4.5 Optional: athlete pass-through

`GET /api/athlete` — pass-through of Strava's `/athlete`. Returns at least `max_heartrate`, `weight`, `ftp` (the fields useful for profile pre-population). Cache 24 h. Single tiny handler.

Not strictly required for Phase 1; useful for the "calibration" wizard to seed a profile.

---

## 5. Endpoints summary

| Endpoint | Status | Used by |
|---|---|---|
| `GET  /auth/strava?origin=trail\|cadence` | **modified** | both |
| `GET  /auth/callback` | **modified** (state-decode) | both |
| `GET  /auth/status` | unchanged | both |
| `POST /auth/logout` | unchanged | both |
| `GET  /api/activities?from=&to=&days=` | unchanged | both (trail uses for the activity browser) |
| `GET  /api/activities/search?q=&min_distance=&max_distance=` | unchanged | both |
| `GET  /api/activities/{id}/detail` | unchanged | both |
| `GET  /api/activities/{id}/streams?keys=...` | **NEW** | trail |
| `GET  /api/athlete` | **NEW** (optional) | trail |
| `GET  /api/backfill/status` | unchanged | cadence |
| `GET  /api/resolve-link` | unchanged | cadence (compare link sharing) |
| `GET  /health` | unchanged | both |

---

## 6. Rate-limit + capacity considerations

Strava limits: **100 req / 15 min**, **1000 req / day**.

cadence's existing flows:
- Activity list refresh: ~1 req per session per visit, or batched at sync time.
- Backfill: paginated 200 per page with `time.Sleep(2 * time.Second)` between pages. Conservative.

trail's projected flows:
- Planned-vs-actual: **1 streams call per linked activity**. Probably ≤ 5 / day.
- Calibration: **N streams calls** where N is the number of past activities the user wants to ingest. Could be 30–50 in one session.

For calibration, trail's client **must throttle** to ≤ 1 stream call every 2 s. Don't try to parallelise. Backend should reject (429) if it sees a sustained burst, but the primary enforcement is client-side cooperation. Document this clearly in trail's calibration UX ("estimating ~2 minutes for 50 activities").

**Single Fly machine consideration:** cadence is hard-locked to one machine (SQLite). Adding trail's traffic to the same machine is fine — even peak calibration is single-digit rps. No scaling change needed.

---

## 7. Database changes

Only the sessions split (§4.3). No new tables for trail itself — trail's state lives in IDB.

Migration files added under `server/store/migrate.go` migrations list:
- `013_create_tokens_v2`
- `014_create_sessions_table`
- `015_migrate_tokens_to_v2`
- `016_drop_old_tokens_rename_v2`

All additive + idempotent guard via the `migrations` table that's already there.

---

## 8. Auth flow walkthrough

**Trail user, first time, not logged in to cadence either:**

1. Trail UI shows "Connect Strava" button → links to `https://<backend>/auth/strava?origin=trail`.
2. Backend generates nonce, stores `(nonce → origin=trail)`, redirects to Strava with `state=base64({nonce, origin})`.
3. Strava prompts user to authorize the app. User accepts.
4. Strava redirects to `https://<backend>/auth/callback?code=XXX&state=...`.
5. Backend exchanges `code` for tokens, decodes `state`, validates nonce, picks `FRONTEND_URL_TRAIL`, creates a new `sessions` row with `origin=trail`, redirects to `https://<trail-frontend>/?token=<session_token>`.
6. Trail reads `?token=` from URL, stores in IDB (`settings.stravaSessionToken`), strips it from URL via `history.replaceState`.
7. Subsequent calls to `/api/*` include `Authorization: Bearer <session_token>`.

**Same user later logs into cadence in another tab:**

1. Click "Connect Strava" on cadence → `?origin=cadence`.
2. Strava sees existing authorization, returns code immediately (no consent screen).
3. Backend creates a *second* `sessions` row, same `athlete_id`, redirects to cadence frontend.
4. Both sessions are now valid. Both resolve to the same `tokens` row.

**Refresh-token edge:** the first session to need a fresh access token calls Strava's refresh endpoint, gets new tokens, updates `tokens.athlete_id` row. All sessions for that athlete now see the new tokens. No coordination needed.

---

## 9. Trail-side changes (informational, not part of the cadence spec)

For completeness — what trail had to build to consume this. **All of it shipped**
in TASK-024 (PR #25) + TASK-024b (PR #26):

- `Settings.stravaSessionToken : Maybe String` stored in IDB under a `settings` keyval. ✓
- HTTP client wrapper that adds the auth header to every backend call. ✓ (`StravaApi.elm`)
- 401 handler → clear token from IDB → show "Reconnect Strava" UI. ✓
- `VITE_BACKEND_URL` env var (Vite) so dev points at localhost:3001 and prod at the Fly URL — read in `src/main.js`, defaulting to `http://localhost:3001`. ✓
- All this was captured in `pace-prediction-roadmap.md` TASK-024.

---

## 10. Open questions

1. **`origin` parameter on `/auth/strava`** — string ("trail") or numeric ID? String is more debuggable. Stick with string.
2. **Nonce storage: in-memory map or DB table?** In-memory is fine for single-machine cadence; survives until restart, which is acceptable (an OAuth flow taking longer than a restart is a failed flow). DB table is more robust but more code. Recommendation: in-memory `sync.Map` with TTL eviction.
3. **Session expiry** — currently sessions live forever. Add a `last_seen_at` update on every authenticated call; sweep sessions inactive >90 days? Not urgent; can come later.
4. **CSRF on cookie-less Bearer auth?** Bearer in `Authorization` header is naturally CSRF-resistant (cross-origin requests can't set arbitrary headers without preflight). State nonce only covers the OAuth round-trip itself, which is enough.
5. **Logging out everywhere** — should `POST /auth/logout` clear *all* sessions for an athlete or just the calling one? Calling-session-only is the safer default; an explicit "log out everywhere" can be added if ever needed.

---

## 11. Migration / rollout plan

Cadence is single-user, single-machine, low-risk. The migration plan:

1. Land schema migrations (013–016) as a single PR. Deploy. Verify cadence still works (existing session token continues to resolve via the new `sessions` table thanks to the data-migration step).
2. Land CORS + state-routing changes. Deploy. Verify cadence's OAuth round-trip still works with `origin` defaulting to `cadence`.
3. Land `/api/activities/{id}/streams` and (optionally) `/api/athlete`. Deploy. Verify with `curl` from the dev machine.
4. Set `FRONTEND_URL_TRAIL` secret. Trail PR lands using the backend.

Each step independently deployable. No coordinated cutover.

---

## 12. Hand-off brief for the cadence agent

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
