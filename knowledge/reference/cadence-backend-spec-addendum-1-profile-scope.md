# Cadence backend spec — Addendum 1: broaden OAuth scope to `profile:read_all`

**Status:** proposal — ready for hand-off.
**Parent spec:** `cadence-backend-spec.md` (PRs already merged in cadence).
**Driver:** trail. Discovered during verification of cadence's TASK-005 (athlete pass-through).

## Why this is needed

Cadence's `/auth/strava` currently requests scope `activity:read_all`. That scope authorises everything cadence-the-app needs (activities, streams, athlete summary), but it returns the **SummaryAthlete** shape from Strava's `/athlete` endpoint — not **DetailedAthlete**. Verified empirically with a fresh trail session: the response includes `id, firstname, sex, city, country, premium, ...` but **not** `max_heartrate`, `weight`, `ftp`, `measurement_preference`.

Trail's roadmap (`pace-prediction-roadmap.md` §7 — calibration) wants those four fields to seed an athlete profile sensibly:

| Field | Trail use |
|---|---|
| `max_heartrate` | Anchor the HR zone model in `pace-prediction-roadmap.md` §14.2 (LTHR ≈ 95% of max for trained runners). |
| `weight` | Reserve for future power-curve heuristics (Stryd-style). Not load-bearing. |
| `ftp` | Bike-only on Strava, but if the user has it set we can ignore it gracefully. |
| `measurement_preference` | Currently moot for trail (km-only per `project-brief.md`), but useful if cadence ever needs it. |

Without those fields, trail falls back to population-tier defaults, which is fine for v1 but lossy. Adding `profile:read_all` is a single-line scope change and unblocks proper calibration when we get there.

## Scope of the change

One code line + a deploy choreography. Estimated size: **S**.

### 1. Update the OAuth scope in `handlers/auth.go`

In `AuthHandler.StravaRedirect`, change the `scope` query parameter:

```diff
- "https://www.strava.com/oauth/authorize?client_id=%s&response_type=code&redirect_uri=%s&scope=activity:read_all&approval_prompt=auto"
+ "https://www.strava.com/oauth/authorize?client_id=%s&response_type=code&redirect_uri=%s&scope=activity:read_all,profile:read_all&approval_prompt=auto"
```

That's the only required code change. The athlete pass-through handler (TASK-005) returns Strava's response verbatim, so the additional fields appear automatically once the access token is issued with the broader scope.

### 2. Bust the athlete cache once after deploy

TASK-005 stored the athlete response in `activity_cache` keyed on a negative-athlete-id sentinel, with a 24 h TTL. After the scope change, existing cached rows hold the old SummaryAthlete shape. Two ways to invalidate:

**Option A — explicit cache bust on deploy (recommended):**

Add a one-shot migration (e.g. `017_invalidate_athlete_cache_for_scope_upgrade`):

```sql
DELETE FROM activity_cache WHERE activity_id < 0;
```

This guarantees the very first `/api/athlete` after deploy re-fetches from Strava. Idempotent on re-runs (the rows will be re-populated and the DELETE is a no-op on the next migration replay because the migration is already marked applied).

**Option B — wait it out:**

Don't migrate. Within ≤24 h the cache expires naturally and the next request fetches fresh.

Recommendation: **A**. The DB write is trivial and saves a 24 h confusing window where `/api/athlete` returns old-shape data.

### 3. Re-auth choreography (what users see)

Deploying the scope change does **not** automatically broaden the scope of existing access tokens. Strava's refresh flow returns access tokens with the *same scope* the original authorization granted. The user has to go through `/auth/strava` (the consent flow) at least once to receive new tokens covering the new scope.

For the single-user system this means:

1. Deploy lands.
2. User visits cadence UI (or trail UI once TASK-024 ships). Existing session still works for the activity endpoints — no breakage.
3. `/api/athlete` keeps returning SummaryAthlete (no `max_heartrate`) for that user until they re-auth. That's fine — trail's calibration UX will prompt re-auth when it actually needs those fields.
4. When the user clicks "Connect Strava" again, Strava notices the requested scope set differs from the previously granted set and shows an *incremental consent* page asking specifically for profile access. User accepts.
5. New tokens issued with combined scope. `SetTokens` upserts the row by `athlete_id`. **All sessions for that athlete now resolve to upgraded tokens** because `GetTokensBySession` joins on `athlete_id` — no session-row migration needed.
6. Next `/api/athlete` call returns DetailedAthlete shape.

No frontend code change required in cadence (its existing "Connect Strava" link already goes through `/auth/strava`). Trail's TASK-024 will hit the same endpoint.

### 4. (Optional, deferred) Persist scope per token

Strava's token response includes a `scope` field. Cadence currently ignores it. If we wanted to be defensive — e.g. a server-side check that errors before hitting `/athlete` if the stored scope is missing `profile:read_all` — we'd add a `scope TEXT NOT NULL DEFAULT ''` column to `tokens` and populate it on `SetTokens`. **Skip this for now.** It's a "nice to have" that adds a migration and a column without solving any observed problem. The natural failure mode (old-scope token → SummaryAthlete response, no `max_heartrate`) is recoverable and surfaces the right UX prompt in trail.

## What this change does NOT need

- No schema change (unless we adopt the optional §4 above).
- No new endpoint.
- No change to TASK-005's handler (it passes through Strava verbatim).
- No change to `FetchActivityStreams`, `FetchActivities`, or any other Strava client method.

## Verification

After deploy + re-auth in any one frontend (cadence or trail):

```bash
TOKEN=<session token from the re-auth flow>

curl -sf "http://localhost:3001/api/athlete" -H "Authorization: Bearer $TOKEN" | jq 'keys'
```

Expected: `keys` array includes `max_heartrate`, `weight`, `ftp`, `measurement_preference` (some may be `null` if the athlete hasn't populated them in Strava — that's the user's profile state, not a backend issue).

Compare to the pre-change observed shape:

```
[ "badge_type_id", "bio", "city", "country", "created_at", "firstname",
  "follower", "friend", "id", "lastname", "premium", "profile",
  "profile_medium", "resource_state", "sex", "state", "summit",
  "updated_at", "username" ]
```

The post-change shape should be a superset, gaining at minimum: `max_heartrate, weight, ftp, measurement_preference, clubs, bikes, shoes, date_preference`, etc. (Strava's full DetailedAthlete shape; cadence passes everything through.)

Also verify the cache cycles:

```bash
curl -s -i "http://localhost:3001/api/athlete" -H "Authorization: Bearer $TOKEN" | grep -i "X-Data-Source"
# First call after deploy: X-Data-Source: strava
curl -s -i "http://localhost:3001/api/athlete" -H "Authorization: Bearer $TOKEN" | grep -i "X-Data-Source"
# Second call within 24h: X-Data-Source: cache
```

## Open questions / non-blocking notes

- Strava's developer console (Authorization Callback Domain settings) doesn't require a scope-list declaration at app-config level — scope is purely per-request. No console change needed.
- If the Strava app is ever configured for a different OAuth audience (e.g. multi-user), `profile:read_all` is sensitive (returns name, age, weight, etc.). Currently single-user and personal use, so fine.
- Trail's IDB doesn't need to change. The session token model is unchanged. The new profile fields, when they appear, simply flow through to trail's settings page.

## Hand-off brief for the cadence agent

> You're working in `~/dev/cadence/`. A small addendum to the trail-integration arc has come up. The full spec is at `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec-addendum-1-profile-scope.md`.
>
> Ship it as **one PR** containing:
>
> 1. A one-line scope change in `handlers/auth.go` (`AuthHandler.StravaRedirect`): add `,profile:read_all` to the `scope=` query parameter.
> 2. A new migration `017_invalidate_athlete_cache_for_scope_upgrade` that runs `DELETE FROM activity_cache WHERE activity_id < 0;` (idempotent; doesn't break on re-run because applied migrations are skipped by ID).
> 3. A short note in cadence's `knowledge/progress/journal.md` explaining the change and the re-auth choreography (point users at the addendum spec for full reasoning).
>
> Acceptance criteria:
> - `go build -tags fts5 .` + `go vet -tags fts5 ./...` clean.
> - Fresh-DB migration applies cleanly; live-DB migration applies and deletes any existing athlete-cache rows.
> - After deploy + a manual re-auth via `/auth/strava` (your existing browser flow), `curl /api/athlete -H "Authorization: Bearer $TOKEN" | jq 'keys'` includes `max_heartrate` (or the field is present as `null` if your Strava profile doesn't have it set — either way it's in the response shape).
> - Existing cadence frontend still works (the additional scope appears as an *incremental consent* page from Strava the first time you re-auth; subsequent auto-prompts are silent).
> - Don't add a `scope` column to `tokens` (§4 of the spec, deferred).
>
> When done, report the PR sha and the post-deploy `jq 'keys'` output back to the user. Trail's TASK-022 (calibration) will consume these fields downstream; nothing else in trail needs to change.
