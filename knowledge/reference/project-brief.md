# Project brief — Cadence

## What it is

**Cadence** is a personal-use, single-user web app that visualizes one runner's Strava activity trends over time. A React frontend (Vercel) talks to a Go backend (Fly.io) that handles Strava OAuth, caches activities in SQLite, and serves a small REST API.

The frontend renders monthly snapshots — running volume, pace, HR, elevation — via Recharts. The backend's caching and incremental-sync logic is the load-bearing piece: full historical backfill, FTS5 search by activity name, per-activity detail with HR-from-streams extraction.

## What it's becoming (current initiative)

In addition to serving its own frontend, cadence's backend is being extended to also serve **trail** (`~/dev/trail/`), a separate Elm app for trail-race planning. Trail needs:
- OAuth + token refresh (cadence already has this).
- A streams pass-through endpoint (currently hardcoded to `distance,heartrate` inside `compare.go`; needs generalising).
- Multi-origin CORS.
- A sessions table that supports more than one logged-in frontend per athlete.

The full spec for this is at:

**`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`**

Trail is the *driver*. Requirements live there; cadence implements. No trail-domain state lands on the cadence server — races, plans, and profiles stay in trail's IDB. Cadence is purely a thin Strava proxy with the existing token-refresh machinery.

See `reference/trail-integration.md` for the summary and the hand-off brief.

## Stack

- **Backend:** Go 1.24, chi router, modernc.org/sqlite (pure Go SQLite, no CGO), FTS5 via build tag.
- **Frontend:** React 19, Vite, Tailwind v4, Recharts.
- **Deploy:** Backend → Fly.io (single machine, persistent volume at `/data` for SQLite). Frontend → Vercel.
- **Auth:** Strava OAuth 2.0. Session token (random 32-byte hex) returned to the frontend via URL query param after callback; stored in localStorage; sent via `Authorization: Bearer`.
- **Caching strategy:** three layers (activity list incremental sync, activity detail stale-while-revalidate, client-side localStorage). Full detail in `reference/caching.md`. Streams are explicitly never cached.

## Hard constraints

- **Single machine, single user.** SQLite doesn't support concurrent writers across machines. Never scale beyond 1 Fly machine.
- **One row per athlete in `tokens`.** This is the existing model. The trail-integration work splits this into `tokens` (per athlete) + `sessions` (per logged-in frontend) — a deliberate change documented in trail spec §4.3.
- **Strava rate limits:** 100 req / 15 min, 1000 / day. Calibration-style burst flows from trail's side must throttle client-side.
- **Live frontend.** Cadence's React frontend reads existing endpoints. Every backend change must preserve that contract.
- **Author identity:** commits + PRs authored by the user only. No Claude attribution. The machine's git config is already correct.

## Soft preferences

- Keep handlers thin. Logic in `store/` and `strava/` packages.
- Cache where the data is immutable (activity details); never cache where it's large + rarely re-read (streams).
- Migrations are append-only, idempotent, ID-stamped in the `migrations` table.

## Out of scope

- Multi-user. Anything that requires per-user data partitioning beyond the existing `athlete_id` keying.
- Webhook ingestion (Strava can push events; we poll instead, simpler).
- Any cadence-frontend feature work while the trail-integration backlog is active.

## Repo layout

- `server/` — Go backend. `main.go` wires chi router; `handlers/` for HTTP; `store/` for SQLite; `strava/client.go` for the Strava HTTP client.
- `client/` — React frontend (Vite). Hooks for auth + activities; pages + components for the UI.
- `package.json` (root) — thin npm wrapper that proxies to `client/`.
- `fly.toml`, `Dockerfile` (in `server/`) — Fly deployment config.

## Success criteria for the current initiative

- All five tasks in `planning/BACKLOG.md` ship as separate PRs, each independently deployed.
- Cadence's existing frontend keeps working at every step (verified manually in each PR).
- Trail's frontend can authenticate via cadence's backend and fetch streams for any activity owned by the same Strava athlete.
- No domain state for trail lives on the cadence server.
