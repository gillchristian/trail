# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

## TASK-004: Streams endpoint

**Pulled from backlog:** 2026-05-15 16:50
**Why this now:** Fourth PR of the trail-integration backlog. Trail needs full stream payloads (time/distance/latlng/altitude/heartrate/...) to reconstruct planned-vs-actual tracks and to calibrate profile coefficients. The handler is independent of TASK-001..003 but depends on the existing session-resolver to gate access.
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §4.4

### Acceptance criteria
- [ ] `strava.Client.FetchActivityStreams(accessToken, activityID, keys []string)` accepts a variable key list (compare.go callers updated to pass `[]string{"distance","heartrate"}`).
- [ ] New `strava.Client.FetchActivityStreamsRaw(accessToken, activityID, keys []string) ([]byte, http.Header, error)` returns the Strava response bytes unchanged (with `key_by_type=true`) plus headers, for pass-through.
- [ ] New `GET /api/activities/{id}/streams?keys=...` handler:
  - 401 when `Authorization: Bearer …` is missing or unknown.
  - 400 with `{"error":"unknown stream key: X"}` when any requested key isn't in the Strava-documented allow-list (`time, distance, latlng, altitude, heartrate, cadence, watts, velocity_smooth, grade_smooth, temp, moving, grade_adjusted_speed`).
  - 400 when `keys` is missing/empty.
  - 200 with the Strava keyed-object response forwarded verbatim when allowed keys are passed against a real activity.
  - Bad activity id (non-numeric) → 400.
  - Streams are not cached (no `activity_cache` writes; no `tokens.db` writes).
- [ ] Rate-limit observation: when `X-Ratelimit-Usage` exceeds 80 % of `X-Ratelimit-Limit` for the 15-min bucket, the server logs a warning.
- [ ] `go build -tags fts5` + `go vet -tags fts5 ./...` pass. Handler-side validation unit-tested where it earns its keep (the allow-list check + the rate-limit threshold).

### Plan
1. Refactor `server/strava/client.go`: add internal `doStreamsRequest(accessToken, activityID, keys, keyByType) ([]byte, http.Header, error)` that handles HTTP setup + auth + non-200 wrapping. Generalise `FetchActivityStreams` to accept `keys []string` and decode the array shape (compare.go's current expectation; keeps `key_by_type=false`). Add `FetchActivityStreamsRaw(keys []string) ([]byte, http.Header, error)` that calls the helper with `key_by_type=true`.
2. Add `strava.LogRateLimit(h http.Header)` that parses `X-Ratelimit-Limit` / `X-Ratelimit-Usage` and `log.Printf`s a warning if either bucket is ≥80 %. Call from both the typed and raw paths.
3. Update `server/handlers/compare.go` to pass `[]string{"distance", "heartrate"}` to the generalised typed method.
4. New file `server/handlers/streams.go`: `StreamsHandler{Store, Strava}`, `Get(w, r)`. Allow-list constant, `validateStreamKeys` helper. Auth + token-refresh + Strava call + 200 pass-through.
5. `main.go` wires `streamsHandler` and `r.Get("/api/activities/{id}/streams", streamsHandler.Get)`.
6. `server/handlers/streams_test.go`: validate the allow-list (positive + negative), and `strava.LogRateLimit` threshold (table test). Skip mocking Strava — the HTTP wrapper is small and tested via live curl.
7. Manual smoke: build/vet/test. Curl the new endpoint with no Authorization (401), with a bogus key (400), with mixed valid/invalid (still 400 on the invalid), and the missing-id / bad-id paths.

### Verification plan
- `cd server && go build -tags fts5 .` — exit 0.
- `cd server && go vet -tags fts5 ./...` — exit 0.
- `go test -tags fts5 ./...` — all pass.
- Curl matrix (quoted in journal):
  - No auth: `curl -i /api/activities/123/streams?keys=distance` → 401.
  - Bogus key: `curl -i -H 'Authorization: Bearer X' /api/activities/123/streams?keys=distance,bogus` → 400 `{"error":"unknown stream key: bogus"}`.
  - Bad id: `curl -i /api/activities/notanumber/streams?keys=distance` → 400.
  - Missing keys: `curl -i -H 'Authorization: Bearer X' /api/activities/123/streams` → 400.
  - Auth happy-path against a real activity (requires Strava session) is documented as performed by trail when ready; locally I'll exercise the auth+validation paths and the typed compare.go-flow regression.

### Notes during execution
- The existing `FetchActivityStreams` currently sends `key_by_type=true` but decodes an array — a latent shape mismatch. I'm splitting the API: the typed path drops `key_by_type` (matches the array decoding it already does); the raw path keeps `key_by_type=true` per the trail spec. compare.go's behaviour is unchanged.

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
