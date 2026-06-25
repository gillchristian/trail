# Verification gates

A task is **not done** until every applicable gate below passes. This is the antidote to the "looks right, ship it" failure mode that wrecks autonomous work.

## The gates

For every task, before marking it complete:

1. **Acceptance criteria met.** Re-read the acceptance criteria written in `CURRENT.md`. Tick each one off explicitly. If a criterion is no longer relevant, document *why* in the task entry — don't silently drop it.
2. **It builds.** Backend: `cd server && go build -tags fts5 .`. Frontend (if touched): `npm run build` (runs `tsc -b && vite build`).
3. **It vets.** Backend: `cd server && go vet -tags fts5 ./...`. Frontend: `npm run lint`.
4. **It runs.** Start the server: `cd server && go run -tags fts5 .`. Verify it reaches "Server running on http://localhost:3001" without panicking on startup (migrations apply, DB opens).
5. **It does the thing — end to end.** For backend changes:
   - If a new endpoint: hit it with `curl` and quote the response shape in the journal.
   - If an OAuth-flow change: walk through the full `/auth/strava → /auth/callback → ?token=` round-trip with the cadence client *and* (where applicable) a manual `?origin=trail` probe.
   - If a schema change: confirm migration applies on a fresh DB *and* on the existing `tokens.db`. Existing cadence sessions must keep resolving.
   - If touching `compare.go` or activity caching: `GET /api/activities/{id}/detail` against a real activity, verify response matches the existing cadence frontend's expectations.
   Type-checking is not behavior verification. A passing unit test on a mocked dependency is not behavior verification. Run the actual thing.
6. **Existing cadence frontend still works.** Pull up `npm run dev` (client) + `go run -tags fts5 .` (server), exercise the affected flow in the browser. Don't ship a backend change that breaks the live UI.
7. **Tests where they earn their keep.** No Go tests currently in `server/`. If the logic has non-trivial branches, edge cases, or is likely to regress (e.g. state-decoder, stream-key validator, sessions-table queries), add a `*_test.go` file. Don't write tests for trivial getters.
8. **No new TODOs left behind.** If a TODO is necessary, it goes in `BACKLOG.md` as a real task, not as a comment buried in code.
9. **Committed.** One commit per logical change, with a message that explains *why*. No `Co-Authored-By: Claude ...` trailer — commits are authored by the user only. Working tree clean before next task.
10. **PR opened and merged.** Every change to `master` goes through a PR I open and merge myself. Local CI (build + vet + lint + manual smoke) must pass before I open the PR. Details in `pr-workflow.md`.

## Cadence-specific quick commands

```bash
# Backend
cd server && go build -tags fts5 .       # compile
cd server && go vet -tags fts5 ./...     # vet
cd server && go run -tags fts5 .         # run (needs .env)

# Frontend (only if client/ touched)
npm run build                             # tsc -b && vite build
npm run lint                              # eslint .
npm run dev                               # vite (localhost:5173)

# Manual smoke — full stack
# Terminal 1: cd server && go run -tags fts5 .
# Terminal 2: npm run dev
# Browser: http://localhost:5173, click through OAuth, view activities
```

## Database migration verification

Migrations run automatically on `OpenDB`. Two checks every time you add one:

```bash
# Apply to a fresh DB
cp /dev/null fresh.db
DATABASE_PATH=fresh.db go run -tags fts5 .

# Apply on top of the live DB
cp tokens.db tokens.db.bak
go run -tags fts5 .          # should be a no-op for already-applied migrations
sqlite3 tokens.db ".schema"  # confirm new shape
```

If a migration breaks the upgrade path, **stop**. A broken migration on the Fly volume is hard to recover from.

## How to verify without me lying to myself

The trap: writing code, running it once, seeing no error, declaring victory. Antidotes:

- **Test the failure case too.** If I implemented "endpoint 401s when no Bearer header," actually call it with no header and watch it 401.
- **Quote the output.** In the journal entry, quote the actual `curl -i` output or `go run` log line — not a paraphrase. If I can't quote it, I didn't run it.
- **Distinguish "compiles" from "works."** Note explicitly which gates passed: did I just `go build`, or did I `go run` and hit the endpoint?
- **If I cannot verify, that is a blocker.** Don't fake-verify. Log in `blockers.md` what verification is missing and why, then pick a task whose verification *is* possible.

## End-of-session sweep

Before stopping (or at long natural breaks):

- `git status` clean? (Or every dirty file accounted for in `CURRENT.md`?)
- `progress/journal.md` has an entry for every task touched this session?
- `planning/CURRENT.md` reflects reality?
- Any silent assumptions that should be ADRs in `decisions/`?
- Did any backend change need a corresponding update to trail's expectations? If yes, surface it in the journal (don't silently drift the contract).
