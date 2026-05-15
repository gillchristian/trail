# Done

Tasks that passed all verification gates. Newest at top.

Each entry: the TASK-NNN id, title, the date completed, and a one-line summary of what shipped + a link/pointer to the journal entry.

```
- TASK-NNN — title — YYYY-MM-DD — one-line summary — see journal YYYY-MM-DD HH:MM
```

## Completed

- TASK-005 — Athlete pass-through — 2026-05-15 — `GET /api/athlete` with 24h cache reusing `activity_cache` at `-athleteID` sentinel; `X-Data-Source` reflects cache vs Strava; injectable clock for TTL tests. PR #6, merged `c21d44b`. See journal 2026-05-15 17:25.
- TASK-004 — Streams endpoint — 2026-05-15 — `GET /api/activities/{id}/streams?keys=` allow-listed pass-through (`key_by_type=true`), no caching, generalised `FetchActivityStreams(keys)` + new `FetchActivityStreamsRaw`, rate-limit logger at >=80 %. PR #5, merged `590c52c`. See journal 2026-05-15 17:00.
- TASK-003 — OAuth state-based origin routing — 2026-05-15 — `?origin=trail|cadence` on `/auth/strava` (default cadence), `state=base64url(JSON{n,o})`, in-memory nonce store (sync.Map + 5-min TTL + 1-min sweep), callback validates one-shot Take + matches encoded vs stored origin BEFORE Strava code exchange, per-origin redirect via `FRONTEND_URL_{CADENCE,TRAIL}`. PR #4, merged `a68896e`. See journal 2026-05-15 16:35.
- TASK-002 — Multi-origin CORS — 2026-05-15 — `FRONTEND_URLS` comma-separated env var feeds `cors.Options.AllowedOrigins`; falls back to legacy `FRONTEND_URL`. PR #3, merged `1788389`. See journal 2026-05-15 16:10.
- TASK-001 — Split `tokens` into `tokens` + `sessions` — 2026-05-15 — migrations 013-016, transactional `SetTokens(t, sessionToken, origin)`, `GetTokensBySession` joins + bumps `last_seen_at`, `ClearTokensBySession` removes session only. PR #2, merged `3e85f86`. See journal 2026-05-15 15:50.
