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

