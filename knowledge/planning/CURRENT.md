# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

## TASK-001: Split `tokens` into `tokens` + `sessions`

**Pulled from backlog:** 2026-05-15 15:20
**Why this now:** First PR of the trail-integration backlog. The schema split is the load-bearing change every subsequent PR depends on (origin column for state-routing, multi-session for two-frontend coexistence).
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §4.3 / §7

### Acceptance criteria
- [ ] Migrations 013–016 added to `server/store/migrate.go`: create `tokens_v2`, create `sessions` (PK session_token, FK athlete_id, columns origin/created_at/last_seen_at), copy data with `origin='cadence'`, drop old `tokens` + rename `tokens_v2` → `tokens`.
- [ ] `store/token.go`: `GetTokensBySession` joins `sessions ⋈ tokens` on athlete_id and updates `last_seen_at` for the resolved session.
- [ ] `store/token.go`: `SetTokens(tokens, sessionToken, origin)` upserts tokens by athlete_id + inserts a new sessions row (transactional).
- [ ] `store/token.go`: `ClearTokensBySession` deletes from `sessions` only (tokens stay so other sessions for the same athlete keep working).
- [ ] `handlers/auth.go` Callback passes `origin="cadence"` to `SetTokens` (default for back-compat).
- [ ] Fresh DB: server starts, migrations apply cleanly, schema matches the new shape.
- [ ] Existing `tokens.db` (copy of live): migrations apply idempotently, the existing session_token still resolves via `GetTokensBySession`, `sqlite3 tokens.db "SELECT count(*) FROM sessions"` returns ≥1.
- [ ] Cadence frontend OAuth round-trip works end-to-end against the new schema (login, /api/activities returns data).
- [ ] `go build -tags fts5` and `go vet -tags fts5 ./...` pass.

### Plan
1. Add migrations 013–016 to `server/store/migrate.go` (additive at the end of the migrations slice, IDs in order).
2. Rewrite `store/token.go` for the new schema. Wrap `SetTokens` in a transaction so the two writes succeed or fail together.
3. Update `handlers/auth.go` Callback site to pass `"cadence"` as origin.
4. Backup current `server/tokens.db` to `server/tokens.db.bak`.
5. Build + vet.
6. Verify fresh-DB migration: `cp /dev/null /tmp/fresh.db && DB_PATH=/tmp/fresh.db go run -tags fts5 .` → no panic, then `sqlite3 /tmp/fresh.db ".schema"` shows new `tokens` (no session_token) and `sessions` table.
7. Verify live-DB migration: run server against the actual `tokens.db`. Confirm `sqlite3 tokens.db "SELECT count(*) FROM sessions"` ≥ 1 and existing session token still resolves (curl `/auth/status` with the current Bearer token).
8. Manual smoke: with both `npm run dev` (client) and the server running, click through the cadence app and confirm activities load. If session is dead, log in again and re-verify.
9. Commit, open PR, merge, journal, advance.

### Verification plan
- `cd server && go build -tags fts5 .` — exit 0.
- `cd server && go vet -tags fts5 ./...` — exit 0.
- Fresh-DB run: `DB_PATH=/tmp/fresh.db cd server && go run -tags fts5 .` — log line "Applied migration 013…016" appears once, "Server running" follows, no panic. Quote the relevant log lines in the journal.
- `sqlite3 /tmp/fresh.db ".schema tokens"` → matches the new shape (no session_token).
- `sqlite3 /tmp/fresh.db ".schema sessions"` → matches the new shape.
- Live-DB run: same server start against `server/tokens.db.bak` copy, confirm session count > 0 in the new sessions table.
- Curl smoke: `curl -i http://localhost:3001/auth/status -H "Authorization: Bearer $SESSION"` returns `{"authenticated":true,"athleteId":...}`.
- Browser smoke: `npm run dev` + server, refresh `localhost:5173`, click "Connect Strava" (or rely on existing session), confirm activity list loads.

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
