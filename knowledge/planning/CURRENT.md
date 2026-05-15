# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

## TASK-005: Athlete pass-through

**Pulled from backlog:** 2026-05-15 17:10
**Why this now:** Last PR of the trail-integration backlog. Trail's calibration UX wants `max_heartrate`/`weight`/`ftp` to seed a profile; the spec calls this optional but small enough to close out the arc in the same session.
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §4.5

### Acceptance criteria
- [ ] New `GET /api/athlete` — pass-through of Strava `/athlete`. Auth required (401 on missing/unknown bearer).
- [ ] Response is the Strava athlete JSON forwarded verbatim, including `max_heartrate`, `weight`, `ftp`, etc.
- [ ] Cached for 24h. Second call within the window returns the cached payload with `X-Data-Source: cache`. First call (or post-expiry) returns `X-Data-Source: strava` and writes to the cache.
- [ ] Smallest reasonable code-diff for storage — reuse `activity_cache` keyed by `-athleteID` (negative-id sentinel; Strava activity ids are positive) rather than introduce a new table + migration.
- [ ] `go build -tags fts5` + `go vet -tags fts5 ./...` + `go test -tags fts5 ./...` pass.
- [ ] Existing endpoints (`/api/activities`, `/api/activities/{id}/streams`, `/api/activities/{id}/detail`) unchanged.

### Plan
1. `strava/client.go`: add `FetchAthlete(accessToken string) ([]byte, http.Header, error)` — single GET to `/athlete`, returns body+headers verbatim. Calls `LogRateLimit`.
2. `store/activity_cache.go`: add thin `GetAthlete(athleteID int64)` / `SetAthlete(athleteID int64, json []byte)` wrappers that call the existing `Get`/`Set` with the `-athleteID` sentinel; document the rationale in a short comment.
3. New `handlers/athlete.go`: `AthleteHandler{Store, Strava, Cache}`. `Get` handles auth + cache lookup (24h TTL) + Strava call + cache write. Sets `X-Data-Source` per source.
4. `main.go` wires `AthleteHandler` + `r.Get("/api/athlete", athleteHandler.Get)`.
5. `handlers/athlete_test.go`: TTL boundary table and cache-source decision logic via an injectable clock or by parameterising the freshness check.
6. Live smoke: cold call returns `X-Data-Source: strava` (with fake token → 502 from Strava 401, expected); seed a cache row directly via sqlite and re-call to confirm `X-Data-Source: cache`; manually expire the cache and confirm the next call goes back to Strava.

### Verification plan
- Build/vet/tests as above.
- Curl matrix (quoted in journal):
  - No auth → 401 `{"error":"Not authenticated"}`.
  - Bogus session → 401.
  - With a seeded session + a seeded `activity_cache` row at sentinel `-athleteID` cached within 24h → 200 + cached body + `X-Data-Source: cache`.
  - Manually expire the cache row (`UPDATE activity_cache SET cached_at = 0`) → next call goes to Strava (fake creds → 502).
- Confirm `/api/activities` and friends still work (route table inspection + existing test pass).

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
