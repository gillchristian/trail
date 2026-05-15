# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

## TASK-002: Multi-origin CORS

**Pulled from backlog:** 2026-05-15 16:00
**Why this now:** Second PR of the trail-integration backlog and a hard prerequisite for the trail frontend ever being able to call this backend from a different origin. Tiny in scope (S) and unblocks TASK-003 (origin routing) cleanly.
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §4.1

### Acceptance criteria
- [ ] `main.go` reads `FRONTEND_URLS` (comma-separated). If unset, falls back to existing `FRONTEND_URL` to preserve back-compat.
- [ ] The parsed `[]string` is what's passed to `cors.Options.AllowedOrigins` — not a single string.
- [ ] Whitespace around comma entries is trimmed; empty entries are dropped.
- [ ] With `FRONTEND_URLS=http://localhost:5173,http://localhost:5174` set, both origins receive an `Access-Control-Allow-Origin` reflecting the request `Origin` header for a `GET /api/activities` preflight/normal request.
- [ ] With only legacy `FRONTEND_URL=http://localhost:5173` set, that origin still works (back-compat).
- [ ] An origin not in the list does not receive an `Access-Control-Allow-Origin` header (CORS denial).
- [ ] `go build -tags fts5` and `go vet -tags fts5 ./...` pass.
- [ ] Cadence frontend (`localhost:5173`) still loads against the running server (auth-status round-trip succeeds via CORS).

### Plan
1. Refactor `env()` use in `main.go`: add a tiny helper to parse a comma-separated env var, trimming and dropping empties.
2. Compute `allowedOrigins []string` as: prefer `FRONTEND_URLS` (split), else fall back to `[]string{frontendURL}`.
3. Pass `allowedOrigins` to `cors.Options.AllowedOrigins`.
4. `handlers.AuthHandler.FrontendURL` stays as a single string for the Callback redirect — that target is set explicitly per the spec (`FRONTEND_URL_TRAIL`/`FRONTEND_URL_CADENCE` arrive in TASK-003). For now we keep using `FRONTEND_URL` as the default redirect target so back-compat holds.
5. Verify with two curl calls (5173, 5174), one denied-origin curl call, fresh build + vet.

### Verification plan
- `cd server && go build -tags fts5 .` — exit 0.
- `cd server && go vet -tags fts5 ./...` — exit 0.
- Run server with `FRONTEND_URLS=http://localhost:5173,http://localhost:5174`. For each allowed origin, send a normal GET to `/api/activities` with `Origin:` and observe `Access-Control-Allow-Origin: <that origin>` in the response. Send an OPTIONS preflight with `Origin: http://localhost:5173` and `Access-Control-Request-Method: GET` and observe the same.
- Repeat with an explicitly disallowed origin (e.g. `http://localhost:9999`) — `Access-Control-Allow-Origin` must be absent.
- Run server again with only legacy `FRONTEND_URL=http://localhost:5173` (no `FRONTEND_URLS`) and confirm 5173 still gets `Access-Control-Allow-Origin` (back-compat).
- Quote each `curl -i` response section in the journal.

### Notes during execution

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
