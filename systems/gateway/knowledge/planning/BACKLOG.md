# Backlog

Ordered. Top item is next. Promote into `CURRENT.md` when started.

When trail drives work, the canonical spec is at:

**`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`**

Read it before pulling any spec-driven task; each entry should reference the spec section that drives it. Cadence-only items go in the Parking lot until they're ready to be promoted.

## Active

_(empty — trail-integration arc complete. Promote a parking-lot item or new spec item when needed.)_

## Shipped (trail-integration, 2026-05-15)

All five PRs from `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §4 landed. Details in `planning/DONE.md` and `progress/journal.md`.

- TASK-001 — Split `tokens` into `tokens` + `sessions` — PR #2 (`3e85f86`).
- TASK-002 — Multi-origin CORS — PR #3 (`1788389`).
- TASK-003 — OAuth state-based origin routing — PR #4 (`a68896e`).
- TASK-004 — Streams endpoint — PR #5 (`590c52c`).
- TASK-005 — Athlete pass-through — PR #6 (`c21d44b`).

Trail-side consumer integration (TASK-024 in trail's BACKLOG) is owned in the trail repo.

## Parking lot

Half-baked ideas / followups noted during recent work. Promote to Active (with a TASK-NNN id) when you want one done.

- **Add Go tests for `store/`.** Handlers + strava have tests now; `store/token.go` (transactional `SetTokens`, the `last_seen_at` bump, the no-tokens-wipe-on-logout invariant) and `store/activity_cache.go` (sentinel-key wrappers) would benefit from direct coverage rather than relying on the handler-level smoke. Use `modernc.org/sqlite` against a `:memory:` DB.

## Resolved out-of-band

- ~~Decide what to do with the tracked `server/cadence-server` binary.~~ User shipped `9f78ee0` ("Small tweaks") on 2026-05-15 which `.gitignore`s the binary and removes it from the tree. Done.
