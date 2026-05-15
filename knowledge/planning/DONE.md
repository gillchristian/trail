# Done

Tasks that passed all verification gates. Newest at top.

Each entry: the TASK-NNN id, title, the date completed, and a one-line summary of what shipped + a link/pointer to the journal entry.

```
- TASK-NNN — title — YYYY-MM-DD — one-line summary — see journal YYYY-MM-DD HH:MM
```

## Completed

- TASK-002 — Multi-origin CORS — 2026-05-15 — `FRONTEND_URLS` comma-separated env var feeds `cors.Options.AllowedOrigins`; falls back to legacy `FRONTEND_URL`. PR #3, merged `1788389`. See journal 2026-05-15 16:10.
- TASK-001 — Split `tokens` into `tokens` + `sessions` — 2026-05-15 — migrations 013-016, transactional `SetTokens(t, sessionToken, origin)`, `GetTokensBySession` joins + bumps `last_seen_at`, `ClearTokensBySession` removes session only. PR #2, merged `3e85f86`. See journal 2026-05-15 15:50.
