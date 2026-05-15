# Backlog

Ordered. Top item is next. Promote into `CURRENT.md` when started.

The current backlog comes from the trail-integration initiative. The canonical spec is at:

**`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`**

Read it before pulling the first task. Each task below references the spec section that drives it.

## Active

- [ ] **TASK-001 — Split `tokens` into `tokens` + `sessions`.** Trail spec §4.3 / §7.
  - Add migrations 013–016 in `server/store/migrate.go`: create `tokens_v2`, create `sessions`, copy data with `origin='cadence'`, drop+rename.
  - Update `store/token.go`: `GetTokensBySession` joins `sessions` ⋈ `tokens` on athlete_id. `SetTokens(tokens, session_token, origin)` upserts tokens by athlete_id + inserts a sessions row. `ClearTokensBySession` deletes from `sessions` only. Add `last_seen_at` update inside `GetTokensBySession`.
  - Existing handler signatures stay the same except `SetTokens` gains an `origin` param (caller defaults to `"cadence"` for now).
  - **Acceptance:** existing `tokens.db` migrates cleanly (existing session_token continues to resolve); cadence frontend OAuth round-trip works end-to-end; `sqlite3 tokens.db "SELECT count(*) FROM sessions"` returns ≥1 after a fresh login.
  - Size: M.

- [ ] **TASK-002 — Multi-origin CORS.** Trail spec §4.1.
  - `main.go` accepts `FRONTEND_URLS` (comma-separated). Falls back to existing `FRONTEND_URL` if unset. Parse into `[]string`, pass to `cors.Options.AllowedOrigins`.
  - **Acceptance:** with `FRONTEND_URLS=http://localhost:5173,http://localhost:5174` set, both origins can hit `/api/activities` without CORS errors (verify with two `curl -H Origin:...` calls).
  - Size: S.

- [ ] **TASK-003 — OAuth state-based origin routing.** Trail spec §4.2.
  - `/auth/strava` accepts `?origin=trail|cadence`, default `cadence`.
  - Generate nonce (16 bytes random), store `nonce → origin` in `sync.Map` with 5-min TTL eviction.
  - Encode `state = base64url(JSON({nonce, origin}))` and include in Strava redirect.
  - `/auth/callback` decodes state, validates nonce against in-memory map, picks redirect target from `FRONTEND_URL_TRAIL` / `FRONTEND_URL_CADENCE` (fall back to `FRONTEND_URL`).
  - Pass `origin` to `SetTokens` so it lands in the new `sessions.origin` column (depends on TASK-001).
  - **Acceptance:** `/auth/strava?origin=trail` round-trips back to `FRONTEND_URL_TRAIL?token=…`; `/auth/strava` (no origin) defaults to cadence behaviour; replaying a code with a stale/missing nonce 4xx's.
  - Size: M.

- [ ] **TASK-004 — Streams endpoint.** Trail spec §4.4.
  - Generalise `strava.Client.FetchActivityStreams` to accept `keys []string` instead of hardcoded `distance,heartrate`. Existing `compare.go` callers pass `[]string{"distance","heartrate"}`.
  - New handler: `GET /api/activities/{id}/streams?keys=...`. Allowlist validates keys against Strava's documented set (`time, distance, latlng, altitude, heartrate, cadence, watts, velocity_smooth, grade_smooth, temp, moving, grade_adjusted_speed`). Return 400 with `{"error": "unknown stream key: X"}` on rejection.
  - Auth-required (`Authorization: Bearer <session_token>`). 401 if missing/unknown.
  - Pass `key_by_type=true` to Strava; return the keyed-object response as-is.
  - **Do not cache** streams (per existing policy in cadence's caching strategy).
  - Log rate-limit warnings at >80 % of 15-min quota (port the pattern from strava-mcp if not already present).
  - **Acceptance:** `curl -H "Authorization: Bearer $SESSION" "http://localhost:3001/api/activities/{real-id}/streams?keys=time,distance,latlng,altitude,heartrate"` returns 200 with the keyed-object shape; unknown key returns 400; no auth returns 401.
  - Size: M.

- [ ] **TASK-005 — (Optional) Athlete pass-through.** Trail spec §4.5.
  - `GET /api/athlete` — pass-through of Strava's `/athlete`. Returns `max_heartrate`, `weight`, `ftp`, etc.
  - Cache 24 h. Either reuse `activity_cache` with a sentinel id, or a new tiny `athlete_cache` row. Pick whichever is smaller code-diff.
  - **Acceptance:** `curl -H "Authorization: Bearer $SESSION" http://localhost:3001/api/athlete` returns the Strava athlete JSON; second call within 24 h is served from cache (verify with `X-Data-Source: cache` header or log).
  - Size: S.

## Parking lot

_(empty — add cadence-only ideas here as they come up; trail-spec items go above)_
