# Project brief — Gateway (backend; ex-cadence `server/`)

> **Monorepo note (MONO-002):** this is **gateway's** brief — the Go backend that
> serves both cadence's and trail's frontends (deployed as the fly app `cadence`).
> The **cadence frontend** has its own brief at
> `systems/cadence/knowledge/reference/project-brief.md`. The body below describes
> the cadence system as it stood at import (frontend + backend); the backend half
> is gateway's concern. The upstream trail contract is
> `systems/trail/knowledge/reference/cadence-backend-spec.md`; the integration
> summary is the shared `knowledge/reference/specs/trail-integration.md`.

## (historical — cadence at import)

## What it is

**Cadence** is a personal-use, single-user web app that visualizes one runner's Strava activity trends over time. A React frontend (Vercel) talks to a Go backend (Fly.io) that handles Strava OAuth, caches activities in SQLite, and serves a small REST API.

The frontend renders monthly snapshots — running volume, pace, HR, elevation — via Recharts. The backend's caching and incremental-sync logic is the load-bearing piece: full historical backfill, FTS5 search by activity name, per-activity detail with HR-from-streams extraction.

## Also a backend for trail (shipped 2026-05-15)

In addition to serving its own frontend, cadence's backend serves **trail** (`~/dev/trail/`), a separate Elm app for trail-race planning. The 5-PR arc that wired this up (TASK-001..005, all in `planning/DONE.md`) added:
- A `sessions` table so the same Strava athlete can be logged in to both frontends concurrently.
- Multi-origin CORS via `FRONTEND_URLS`.
- OAuth state-based origin routing (`?origin=trail|cadence`) with per-origin redirect targets.
- `GET /api/activities/{id}/streams` — allow-listed pass-through with no caching.
- `GET /api/athlete` — pass-through with a 24h cache.

The full spec was driven by trail and lives at:

**`/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`**

Trail remains the *driver* for any future revisions to this surface. Requirements live there; cadence implements. No trail-domain state lives on the cadence server — races, plans, and profiles stay in trail's IDB. Cadence is purely a thin Strava proxy with the existing token-refresh machinery.

See `reference/trail-integration.md` for the integration summary and the original hand-off brief.

## Stack

- **Backend:** Go 1.24, chi router, modernc.org/sqlite (pure Go SQLite, no CGO), FTS5 via build tag.
- **Frontend:** React 19, Vite, Tailwind v4, Recharts.
- **Deploy:** Backend → Fly.io (single machine, persistent volume at `/data` for SQLite). Frontend → Vercel.
- **Auth:** Strava OAuth 2.0. Session token (random 32-byte hex) returned to the frontend via URL query param after callback; stored in localStorage; sent via `Authorization: Bearer`.
- **Caching strategy:** three layers (activity list incremental sync, activity detail stale-while-revalidate, client-side localStorage). Full detail in `reference/caching.md`. Streams are explicitly never cached.

## Hard constraints

- **Single machine, single user.** SQLite doesn't support concurrent writers across machines. Never scale beyond 1 Fly machine.
- **One row per athlete in `tokens`; many rows per athlete in `sessions`.** Split landed 2026-05-15 (TASK-001, PR #2). See ADR `decisions/0001-tokens-sessions-split.md` and trail spec §4.3.
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
- Any cadence-frontend feature work that contradicts trail's contract with this backend (trail spec §5 lists the endpoint surface trail relies on).

## Repo layout

- `server/` — Go backend. `main.go` wires chi router; `handlers/` for HTTP; `store/` for SQLite; `strava/client.go` for the Strava HTTP client.
- `client/` — React frontend (Vite). Hooks for auth + activities; pages + components for the UI.
- `package.json` (root) — thin npm wrapper that proxies to `client/`.
- `fly.toml`, `Dockerfile` (in `server/`) — Fly deployment config.

## Trail-integration success criteria (shipped)

The 5-PR arc met these:

- All five tasks shipped as independent PRs (#2..#6, all in `planning/DONE.md`).
- Cadence's existing frontend kept working at every step (`/auth/{status,strava,logout}` shapes unchanged; `/api/activities` and `/api/activities/{id}/detail` unchanged).
- Trail's frontend can authenticate via cadence's backend and fetch streams for any activity owned by the same Strava athlete.
- No trail-domain state lives on the cadence server.
