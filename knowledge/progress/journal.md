# Journal

Append-only. Newest at the bottom. Each entry is a snapshot for future-me with no memory of this session.

## Entry format

```
---
## YYYY-MM-DD HH:MM — <short heading>

**Task:** TASK-NNN (or "scaffolding" / "exploration" / "blocker triage")
**What I did:** 1–3 sentences.
**What I verified:** which gates I ran, including any literal command output worth preserving.
**What changed in the repo:** files touched, key commits (sha + subject).
**What I learned:** anything that would surprise future-me. Non-obvious only.
**Next:** the very next thing I will do when I resume.
```

## Entries

---
## 2026-05-15 14:10 — knowledge/ scaffolding

**Task:** scaffolding (no TASK-NNN; this is the meta-system itself).
**What I did:** Set up `knowledge/` with philosophy, planning, progress, decisions, and reference subdirectories — porting the working system from the trail project (`~/dev/trail/knowledge/`). Adapted philosophy docs for Go/chi/SQLite specifics; seeded `planning/BACKLOG.md` with TASK-001 through TASK-005, each pointing at the relevant section of trail's `cadence-backend-spec.md`. Created `reference/project-brief.md` (about cadence) and `reference/trail-integration.md` (pointer + hand-off context). Updated `CLAUDE.md` to point at `knowledge/README.md` as the entry point.
**What I verified:** No code changed in `server/` or `client/`. All knowledge files render as expected. Pointers to the trail spec use absolute paths (`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`).
**What changed in the repo:** New `knowledge/` tree (~14 files). `CLAUDE.md` gained a one-line pointer at the top.
**What I learned:**
- Cadence has no `_test.go` files in `server/` yet. The verification gates lean on `go build`, `go vet`, manual `curl` smoke, and exercising the existing cadence frontend.
- The git config is already correct for the no-Claude-attribution rule; nothing to configure.
- Existing commit messages in master are loose (one-line subjects, no bodies). The new workflow tightens this from now on; don't backfill old commits.
**Next:** Pull TASK-001 (split `tokens` into `tokens` + `sessions`) into `CURRENT.md` and start the first PR.

---
## 2026-05-15 15:50 — TASK-001 shipped: tokens/sessions split

**Task:** TASK-001 (PR #2, merge sha `3e85f86`, https://github.com/gillchristian/strava/pull/2).
**What I did:** Added migrations 013-016 (create `tokens_v2`, create `sessions` referencing it, copy old `tokens` rows + seed `sessions` with `origin='cadence'`, drop old `tokens` and rename `tokens_v2`). Rewrote `store/token.go`: `GetTokensBySession` joins on `athlete_id` and bumps `last_seen_at`; `SetTokens(t, sessionToken, origin)` is transactional (UPSERT tokens + INSERT sessions); `ClearTokensBySession` deletes from `sessions` only. Updated `handlers/auth.go` Callback to pass `origin="cadence"`. Also shipped a separate scaffolding PR (PR #1, sha `2d2a6df`) to land `knowledge/` before starting backlog work.
**What I verified:**
- `cd server && go build -tags fts5 .` + `go vet -tags fts5 ./...` clean.
- Fresh-DB run applied 013-016 in order:
  ```
  Applied migration 013_create_tokens_v2
  Applied migration 014_create_sessions_table
  Applied migration 015_migrate_tokens_to_v2
  Applied migration 016_drop_old_tokens_rename_v2
  Server running on http://localhost:3099
  ```
- Live-shape DB simulated by inserting `(123456, 'abc123session', 'access_xyz', 'refresh_xyz', expires)` into the old-schema `tokens` on a copy of the local `tokens.db`. After migration: `tokens` row = `123456|access_xyz|refresh_xyz|1778855671`, `sessions` row = `abc123session|123456|cadence|1778852079|1778852079`.
- `curl /auth/status -H 'Authorization: Bearer abc123session'` → `{"authenticated":true,"athleteId":123456}` (existing session still resolves post-migration).
- `last_seen_at` advanced from `1778852079` to `1778852097` after one `GetTokensBySession`.
- `POST /auth/logout` returned `{"ok":true}`; `SELECT count(*) FROM sessions` then = 0, `SELECT count(*) FROM tokens` = 1. Confirms `ClearTokensBySession` no longer wipes Strava credentials.
- Re-running the server against the migrated DB logged no migration lines (idempotency confirmed).
- The cadence frontend only consumes `/auth/{strava,status,logout}` — none of these endpoints changed shape, so the existing client keeps working without code changes (verified by grep against `client/src`).
**What changed in the repo:** `server/store/migrate.go` (+4 migrations), `server/store/token.go` (rewrote 3 functions, added transactions), `server/handlers/auth.go` (one line: pass `"cadence"` as origin), `knowledge/planning/CURRENT.md` (TASK-001 plan).
**What I learned:**
- modernc.org/sqlite's `db.Exec` happily runs multi-statement SQL separated by `;` — already true for migration 011, so I followed the pattern in 014/015/016 without splitting.
- SQLite ≥ 3.25 auto-rewrites foreign-key references during `ALTER TABLE ... RENAME TO` (no `legacy_alter_table` issue here). The `.schema sessions` output after migration 016 shows the FK is correctly pointing at the renamed `tokens` table.
- The local `tokens.db` was nearly empty (0 rows, only migrations 001-002 applied) — so the prod-shape live test had to be synthesized by injecting a row. The Fly volume has the real session. Migration shape is identical, so the synthesized test is representative.
- The committed `server/cadence-server` binary is just a local-dev artifact: the Fly Dockerfile builds from source. I intentionally do not bump the tracked binary in PRs.
**Next:** TASK-002 — multi-origin CORS. `main.go` accepts comma-separated `FRONTEND_URLS`, falls back to single `FRONTEND_URL`.

---
## 2026-05-15 16:10 — TASK-002 shipped: multi-origin CORS

**Task:** TASK-002 (PR #3, merge sha `1788389`, https://github.com/gillchristian/strava/pull/3).
**What I did:** Added `envList()` helper that splits an env var on `,`, trims whitespace, and drops empty entries. In `main.go`, compute `allowedOrigins = envList("FRONTEND_URLS") || []string{frontendURL}` and pass it to `cors.Options.AllowedOrigins`. `AuthHandler.FrontendURL` is untouched — origin-aware redirect routing for OAuth callbacks arrives in TASK-003.
**What I verified:**
- `cd server && go build -tags fts5 .` + `go vet -tags fts5 ./...` clean.
- With `FRONTEND_URLS='http://localhost:5173,  http://localhost:5174 ,'` (deliberately ugly):
  - `curl -i -H 'Origin: http://localhost:5173' /api/activities` → `Access-Control-Allow-Origin: http://localhost:5173`.
  - `curl -i -H 'Origin: http://localhost:5174' /api/activities` → `Access-Control-Allow-Origin: http://localhost:5174` (whitespace was trimmed; trailing empty entry dropped).
  - `curl -i -H 'Origin: http://localhost:9999' /api/activities` → no `Access-Control-Allow-Origin` (denied; `Vary: Origin` only).
  - OPTIONS preflight from 5173 returned `Access-Control-Allow-Methods: GET` and `Access-Control-Allow-Headers: Authorization`.
- With only legacy `FRONTEND_URL=http://localhost:5173` (no `FRONTEND_URLS`): 5173 still allowed, 5174 denied. Back-compat fallback works.
**What changed in the repo:** `server/main.go` — `envList` helper + `allowedOrigins` slice. `knowledge/planning/{CURRENT,DONE}.md` and `knowledge/progress/journal.md` per-PR rollover.
**What I learned:**
- chi/cors emits `Vary: Origin` even on denied requests — that's the correct CORS behavior (response varies by Origin header) and what lets a downstream cache distinguish allowed/denied entries.
- The PR convention I've adopted (carry the prior task's retro into the next PR) trades a slight body-line bump for keeping master clean and avoiding direct-push exceptions to the workflow.
**Next:** TASK-003 — OAuth state-based origin routing. Wire `?origin=trail|cadence`, base64url-encoded `{nonce, origin}` state, `sync.Map` with 5-min TTL, callback decode+validate, per-origin redirect targets.

---
## 2026-05-15 16:35 — TASK-003 shipped: OAuth state-based origin routing

**Task:** TASK-003 (PR #4, merge sha `a68896e`, https://github.com/gillchristian/strava/pull/4).
**What I did:** New `handlers/oauth_state.go` — `OAuthStateStore` (sync.Map of nonce→{origin, expiresAt}, 1-min background sweep, 5-min TTL), `Put`/`Take` (one-shot via `LoadAndDelete`), `encodeOAuthState`/`decodeOAuthState` (base64url over `{"n":..., "o":...}` JSON), `newOAuthNonce` (16 random bytes b64url), `IsAllowedOrigin`. Rewrote `StravaRedirect` to accept `?origin` (default `cadence`, 400 on unknown), mint + store a nonce, append `&state=…` to the Strava authorize URL. Rewrote `Callback` to validate state — decode → `Take` → match encoded vs stored origin — BEFORE calling Strava's token exchange, so a malformed/replayed state can never burn the code. Wired `FrontendURLs` from `FRONTEND_URL_{CADENCE,TRAIL}` in `main.go` (each falling back to legacy `FRONTEND_URL`); on success, `Callback` redirects via the per-origin URL and passes the validated `origin` into `SetTokens` (lands in `sessions.origin`). Added 7 unit tests covering codec round-trip, garbage decode, one-shot Take, unknown nonce, expired nonce (fake clock), per-origin redirect routing + empty-string fallback, and the allow-list.
**What I verified:**
- `go build -tags fts5 .` + `go vet -tags fts5 ./...` clean.
- `go test -tags fts5 ./handlers` → 7/7 PASS.
- Live HTTP smoke (`FRONTEND_URL_TRAIL=http://localhost:6000`, `STRAVA_CLIENT_ID=test_client_id`):
  - `/auth/strava` → 302 with state `eyJuIjoiRnlqZ28zdndzQmpxQ2JGREFDcjVLQSIsIm8iOiJjYWRlbmNlIn0` → decodes to `{"n":"Fyjgo3vwsBjqCbFDACr5KA","o":"cadence"}` (default).
  - `/auth/strava?origin=trail` → state `{"n":"...","o":"trail"}`.
  - `/auth/strava?origin=bogus` → `400 Unknown origin`.
  - `/auth/callback` no code → 400; with code, no state → 400; garbage state → 400.
  - Well-formed JSON state with unknown nonce → 400 (logged `OAuth nonce verification failed: unknown or already-consumed OAuth state`).
  - **Nonce one-shot round-trip**: extracted a real state from `/auth/strava?origin=trail`, called `/auth/callback?code=fake_code_123&state=<that>` → 500 (logged `OAuth callback error: token exchange failed: 400 ... "field":"client_id","code":"invalid"`). Confirms state validation passed and the request reached Strava. Replaying the SAME state → 400 (nonce already consumed).
**What changed in the repo:** `server/handlers/oauth_state.go` (new, ~110 LoC), `server/handlers/oauth_state_test.go` (new, ~120 LoC), `server/handlers/auth.go` (rewrote `StravaRedirect`/`Callback`, added `FrontendURLs` + `OAuthState` fields + `redirectURLFor` helper), `server/main.go` (wired the new fields).
**What I learned:**
- State validation must run before the Strava code exchange, both for security (no code burning) and efficiency (no wasted Strava API call on every bad state).
- "TTL eviction" in the spec implied active cleanup, so I added a 1-min background sweep on top of the passive `Take`-time check.
- Tested expiry by injecting a fake clock (`now func() time.Time` on the struct) — lets me verify TTL without a real `time.Sleep` in tests.
**Next:** TASK-004 — `GET /api/activities/{id}/streams`. Generalise `strava.Client.FetchActivityStreams(keys []string)`, add allowlist-validated handler, no caching, log rate-limit at >80 %.

---
## 2026-05-15 17:00 — TASK-004 shipped: streams endpoint

**Task:** TASK-004 (PR #5, merge sha `590c52c`, https://github.com/gillchristian/strava/pull/5).
**What I did:** Factored `strava.Client.doStreamsRequest(...)` so both the typed (`FetchActivityStreams(keys []string)`) and raw (`FetchActivityStreamsRaw`) paths share HTTP setup, auth header, status handling, and rate-limit observation. The typed path drops `key_by_type=true` (fixes a latent shape mismatch with its array decode); the raw path keeps it per the trail spec and returns Strava's body verbatim. Added `strava.LogRateLimit(h)` that warns at >=80 % usage on either the 15-min or daily bucket of `X-Ratelimit-{Limit,Usage}`. New `handlers/streams.go` validates `keys` against a 12-entry allow-list (matching Strava's documented set), 401s on missing/unknown bearer, 400s with the offending key named on rejection, 502s on Strava failure, and writes the Strava JSON to the response with no caching. Updated `compare.go` to pass `[]string{"distance","heartrate"}`. Wired route + handler in `main.go`. Added tests: `streams_test.go` covers the allow-list (positive/negative/mixed/whitespace/case-sensitive); `ratelimit_test.go` covers the threshold (no headers, well-under, exactly 80 %, above-short-only, above-both, garbage).
**What I verified:**
- `go build -tags fts5 .` + `go vet -tags fts5 ./...` clean.
- `go test -tags fts5 ./...` — handlers + strava packages PASS.
- Live HTTP smoke against a seeded `tokens`/`sessions` row (fake creds):
  - No auth → 401; bogus session → 401.
  - `id=notanumber` → 400 `Invalid activity ID`.
  - Missing/empty `keys` → 400 `missing required parameter: keys`.
  - `keys=bogus` → 400 `{"error":"unknown stream key: bogus"}`.
  - `keys=distance,bogus,heartrate` → 400 `{"error":"unknown stream key: bogus"}` (first invalid wins).
  - `keys=Distance` → 400 `{"error":"unknown stream key: Distance"}` (allow-list is case-sensitive).
  - `keys=time,distance,latlng,altitude,heartrate` → request reaches Strava; fake access_token rejected; logged `Streams fetch error (activity 123): strava streams error: 401 ... "field":"","code":"invalid"`; server returns 502. Confirms the happy path actually hits Strava with the requested keys.
- Side-effect audit: `SELECT count(*) FROM activity_cache` = 0 after the smoke; tokens row unmodified. Streams stay un-cached per the caching policy.
**What changed in the repo:** `server/strava/client.go` (factored helper + generalised + raw method), `server/strava/ratelimit.go` (new), `server/strava/ratelimit_test.go` (new), `server/handlers/streams.go` (new), `server/handlers/streams_test.go` (new), `server/handlers/compare.go` (1-line callsite), `server/main.go` (handler + route).
**What I learned:**
- The previous `FetchActivityStreams` was sending `key_by_type=true` AND decoding into `[]streamEntry` — Strava returns an object with `key_by_type=true` and an array without it, so either the request was silently parsed as something usable (Strava ignoring the flag?) or the decode was failing and the per-km HR fallback in compare.go masked the bug. Splitting into two methods (array decode for typed, raw bytes for pass-through) removes the ambiguity.
- For the rate-limit logger, kept the parsing tolerant: if the headers aren't a strict `int,int` pair we just don't log anything. Production traffic shouldn't depend on Strava header shape.
**Next:** TASK-005 — `GET /api/athlete` pass-through with 24h cache. Reuse `activity_cache` with `-athleteID` sentinel to avoid a fresh migration.

---
## 2026-05-15 17:25 — TASK-005 shipped: athlete pass-through

**Task:** TASK-005 (PR #6, merge sha `c21d44b`, https://github.com/gillchristian/strava/pull/6).
**What I did:** Added `strava.Client.FetchAthlete(accessToken)` — single GET to `/athlete`, returns bytes + headers verbatim, calls `LogRateLimit`. Extended `ActivityCacheStore` with `GetAthlete`/`SetAthlete` thin wrappers that key the existing `activity_cache` table at `-athleteID` (Strava activity ids are positive, so the sentinel never collides). New `handlers/athlete.go` does auth → cache lookup (24h TTL via injectable clock) → Strava fetch on miss → cache write on success. Returns `X-Data-Source: cache` when served from cache, `X-Data-Source: strava` on refresh. Wired in `main.go`. Tests cover the TTL boundary table + the clock-injection contract.
**What I verified:**
- `go build -tags fts5 .` + `go vet -tags fts5 ./...` clean.
- `go test -tags fts5 ./...` — all PASS.
- Live HTTP smoke (seeded `tokens` + `sessions` with athlete_id=777, session=`SESS`, fake creds):
  - No auth / bogus session → 401.
  - Cache miss → Strava → 502 (logged `Athlete fetch error: strava athlete error: 401`).
  - After seeding `INSERT INTO activity_cache (activity_id, response_json, cached_at) VALUES (-777, '{...}', now)` → 200 with `X-Data-Source: cache` and the seeded JSON body verbatim.
  - `UPDATE activity_cache SET cached_at = 0 WHERE activity_id = -777` then re-call → falls through to Strava → 502. TTL gating works.
  - `SELECT activity_id FROM activity_cache` → only `-777`. Sentinel doesn't collide with positive activity ids.
- Failed Strava responses are not cached — only successful bodies overwrite `activity_cache`.
**What changed in the repo:** `server/strava/client.go` (`FetchAthlete`), `server/store/activity_cache.go` (sentinel + 2 wrappers), `server/handlers/athlete.go` (new), `server/handlers/athlete_test.go` (new), `server/main.go` (handler + route).
**What I learned:**
- Reusing `activity_cache` at a negative sentinel was a clean way to avoid a migration. Documented the rationale in a one-liner above `athleteCacheKey` so a future reader doesn't go hunting for an athlete_cache table.
- Injecting `now func() time.Time` on the handler kept the freshness test trivial — no real `time.Sleep` and the boundary cases (exactly-at-TTL is stale; 1s-under-TTL is fresh) are easy to assert.
**Next:** Trail-integration backlog is complete (TASK-001..005). The corresponding consumer-side work lives in trail (TASK-024 in its BACKLOG). On the cadence side, BACKLOG is empty until new work arrives.

---
## 2026-05-15 17:35 — Close out trail-integration backlog

**Task:** post-merge cleanup (no TASK-NNN).
**What I did:** Folded the TASK-005 retro into `knowledge/progress/journal.md`, added it to `DONE.md`, cleared `CURRENT.md` back to its template-only state, and moved the five completed TASK-001..005 entries from `planning/BACKLOG.md` (which was the trail-integration arc) into a "Shipped (trail-integration)" section so future readers see at a glance that the arc is done.
**What I verified:** No code changed. `git diff --stat` against master shows only the four planning/progress files touched. All five trail-spec PRs are on master in order: PR#2 (`3e85f86`), PR#3 (`1788389`), PR#4 (`a68896e`), PR#5 (`590c52c`), PR#6 (`c21d44b`).
**What changed in the repo:** `knowledge/planning/CURRENT.md`, `knowledge/planning/BACKLOG.md`, `knowledge/planning/DONE.md`, `knowledge/progress/journal.md`.
**What I learned:**
- The "carry the prior task's retro into the next PR" convention worked well for chaining tasks but leaves the *last* task's retro to a dedicated closeout PR. Worth it — keeps each task's retro adjacent to a real code change instead of in a trailing master push.
**Next:** Backlog is empty. New work will be promoted from a future BACKLOG addition (cadence-only ideas, or a fresh upstream spec from trail).

---
## 2026-05-15 18:00 — Knowledge tidy-up after trail-integration shipment

**Task:** post-shipment cleanup (no TASK-NNN).
**What I did:** Wrote four ADRs for the non-trivial decisions made during TASK-001..005 — `decisions/0001-tokens-sessions-split.md`, `0002-in-memory-oauth-state-store.md`, `0003-oauth-state-before-strava-exchange.md`, `0004-athlete-cache-sentinel-key.md` — and indexed them in `decisions/INDEX.md`. Tightened post-shipment-stale language in `CLAUDE.md` (non-negotiable #7 now says "when trail drives work …" instead of asserting it as the current backlog), `reference/project-brief.md` (the "becoming" section is now a "shipped 2026-05-15" section pointing at DONE.md + the ADRs; success criteria flipped to past tense), `reference/trail-integration.md` (status banner at top, hand-off brief marked historical), and `planning/BACKLOG.md` (intro reads "when trail drives work" instead of asserting the spec drives the current backlog). Added the "carry prior retro into next PR" convention to `philosophy/pr-workflow.md` so future-me doesn't have to rediscover it. Added two parking-lot entries to `BACKLOG.md`: decide what to do with the stale tracked `server/cadence-server` binary, and write Go tests for `store/`.
**What I verified:** No code changes. `git diff --stat` against master touches only knowledge/* and CLAUDE.md. `find knowledge -type f` matches the expected layout. `grep -n "current initiative\|current backlog\|in-flight"` against `knowledge/` returns nothing — no remaining present-tense statements about the shipped arc.
**What changed in the repo:** 4 new ADR files; `decisions/INDEX.md`, `reference/project-brief.md`, `reference/trail-integration.md`, `planning/BACKLOG.md`, `philosophy/pr-workflow.md`, `CLAUDE.md`, this journal entry.
**What I learned:**
- Writing the ADRs after the fact was easy because the journal already had the rationale buried in each "What I learned" — the ADRs are essentially the *transferable* form of those notes.
- "Boring drift maintenance" (post-shipment language tidying) is part of keeping `knowledge/` from rotting. The convention is: whenever an arc ships, do a tidy-up PR like this one so the docs don't lie about being in flight.
**Next:** Knowledge tree is in a state where promoting a fresh task from `planning/BACKLOG.md` (or dropping one directly into `CURRENT.md` with the template) is the only step needed to start new work.

