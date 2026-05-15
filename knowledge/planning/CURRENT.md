# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

## TASK-003: OAuth state-based origin routing

**Pulled from backlog:** 2026-05-15 16:20
**Why this now:** Third PR of the trail-integration backlog. Depends on TASK-001's `sessions.origin` column and TASK-002's multi-origin CORS. Without state-based routing, the OAuth callback can only ever redirect back to a single frontend, so trail can never finish login.
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §4.2

### Acceptance criteria
- [ ] `/auth/strava` accepts `?origin=trail|cadence`, defaults to `cadence`. Unknown origins → 400.
- [ ] A nonce (16 random bytes, base64url) is generated per request and stored in an in-memory map keyed by nonce → origin with a 5-minute TTL and a background sweep.
- [ ] The Strava redirect includes `state=base64url(JSON({n: nonce, o: origin}))`.
- [ ] `/auth/callback` rejects: missing state → 400; malformed state → 400; well-formed state with an unknown/expired/replayed nonce → 400; mismatched origin → 400.
- [ ] On a valid state, the callback consumes the nonce (one-shot Take), exchanges the code, persists tokens with `origin` (from validated state), and redirects to the origin-specific frontend URL: `FRONTEND_URL_TRAIL` for `trail`, `FRONTEND_URL_CADENCE` for `cadence`, both falling back to `FRONTEND_URL`.
- [ ] State validation runs BEFORE the Strava code exchange, so an invalid state does not burn the code.
- [ ] Existing cadence OAuth flow (no `?origin` param) keeps working as before.
- [ ] `go build -tags fts5` + `go vet -tags fts5 ./...` pass. Tests for state-store + codec exist and pass.

### Plan
1. New file `handlers/oauth_state.go`: constants (`OriginCadence`, `OriginTrail`), `OAuthStateStore` (sync.Map + 5-min TTL + 1-min background sweep), `Put/Take`, `newOAuthNonce`, `encodeOAuthState/decodeOAuthState` (base64url(JSON{n, o})), `IsAllowedOrigin`.
2. Update `handlers/auth.go`:
   - `AuthHandler` gets `FrontendURLs map[string]string` and `OAuthState *OAuthStateStore` (and a `redirectURLFor(origin)` helper that falls back to `FrontendURL`).
   - `StravaRedirect` parses `?origin`, validates, generates+stores nonce, includes `&state=` in the Strava URL.
   - `Callback` reads `code` + `state`, decodes state, calls `OAuthState.Take(nonce)` to validate and consume, compares stored vs encoded origin, then proceeds with the existing token-exchange path passing `origin` into `SetTokens`. Redirects via `redirectURLFor`.
3. Update `main.go`: populate `FrontendURLs` from `FRONTEND_URL_CADENCE` + `FRONTEND_URL_TRAIL` (env helper with `frontendURL` fallback), instantiate `OAuthState`.
4. `handlers/oauth_state_test.go`: round-trip, garbage decode, one-shot Take, unknown nonce, expired nonce (inject a fake clock), `IsAllowedOrigin` cases, `redirectURLFor` per-origin + empty fallback.
5. Manual smoke: build/vet/test; curl each error/positive path; extract a real state from `/auth/strava?origin=trail` and replay it twice to demonstrate the nonce is one-shot.

### Verification plan
- `cd server && go build -tags fts5 .` — exit 0.
- `cd server && go vet -tags fts5 ./...` — exit 0.
- `go test -tags fts5 ./handlers` — all pass.
- For each `curl -i` scenario, quote the status line + relevant headers in the journal:
  - `/auth/strava` (no origin) → 302 to Strava with `&state=…`. Decode state, confirm `{"n":..., "o":"cadence"}`.
  - `/auth/strava?origin=trail` → 302 with `o:"trail"` in state.
  - `/auth/strava?origin=bogus` → 400 "Unknown origin".
  - `/auth/callback` no code → 400; with code, no state → 400; garbage state → 400; well-formed JSON state with unknown nonce → 400.
  - Round-trip: extract a real state, call `/auth/callback?code=fake&state=<that>` → 500 (Strava code exchange fails after state validation passed). Replay same state → 400 (nonce consumed).

### Notes during execution
- State validation must happen before Strava exchange (spec §4.2 wording + the "replay 4xx's" acceptance line both demand it).
- Spec says "5-min TTL eviction" — chose active sweep (goroutine, 1-min ticker) over passive-only, since the spec uses the word "eviction".

### Done

## Template for a task entry

```
## TASK-NNN: <short title>

**Pulled from backlog:** YYYY-MM-DD HH:MM
**Why this now:** <one sentence>
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §X.Y (if applicable)

### Acceptance criteria
- [ ] Criterion 1 (observable, testable)
- [ ] Criterion 2
- [ ] Existing cadence frontend still works (specify the flow exercised)
- [ ] ...

### Plan
1. Step 1
2. Step 2
3. ...

### Verification plan
- How I will demonstrate each acceptance criterion is met.
- Specific commands I will run (curl invocations, sqlite queries, browser smoke).

### Notes during execution
<append as I go — surprises, side discoveries, decisions made>

### Done
<filled in when all gates pass; quote final verification output here>
```
