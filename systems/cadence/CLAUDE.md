# CLAUDE.md

**Before doing anything else, read `knowledge/README.md`.** That document defines the working system for this project — how tasks are pulled, branched, verified, shipped, and logged. The summary below is just the headline rules so you can't accidentally violate them while still loading the rest.

## Non-negotiables

1. **One task at a time.** Pull from `knowledge/planning/CURRENT.md`. If empty, promote the top of `knowledge/planning/BACKLOG.md`. Write acceptance criteria before touching code.
2. **Work on branches, ship via PRs.** No direct pushes to `master`. Every change goes through branch → PR → squash-merge. Full workflow in `knowledge/philosophy/pr-workflow.md`.
3. **Commits and PRs are authored by the user only.** No `Co-Authored-By: Claude ...` trailer. No "🤖 Generated with Claude Code" footer. Git config is already correct — just don't add Claude attribution.
4. **Verify before declaring done.** Hard gates in `knowledge/philosophy/verification.md`. `go build -tags fts5`, `go vet`, manual `curl` smoke, and the existing cadence frontend exercised against the change.
5. **Journal everything.** Append to `knowledge/progress/journal.md` after every task. Future-you has no memory of this session.
6. **When stuck, follow `knowledge/philosophy/when-stuck.md`.** Do not ask the user; do log to `knowledge/progress/blockers.md` when a real blocker exists, then pivot.
7. **When trail drives work, the canonical spec is `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md`.** Don't reinterpret it silently; file a blocker if a section seems wrong. (The 2026-05-15 trail-integration arc — TASK-001..005 — is shipped; see `knowledge/planning/DONE.md`.)

## Quick map

- `knowledge/README.md` — the loop, end-to-end.
- `knowledge/philosophy/` — principles, verification gates, when-stuck playbook, working style, PR workflow.
- `knowledge/planning/` — `CURRENT.md` (one active task), `BACKLOG.md` (queue), `DONE.md` (archive).
- `knowledge/progress/` — `journal.md` (append-only log), `blockers.md` (things needing the user).
- `knowledge/decisions/` — ADRs.
- `knowledge/reference/` — `project-brief.md` (what cadence is), `trail-integration.md` (shipped 2026-05-15, plus historical hand-off), `glossary.md`.

---

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
npm run dev          # Run frontend dev server (localhost:5173)
npm run build        # TypeScript check + Vite build (client only)
npm run lint         # ESLint across the client

# Backend (Go)
cd server && go run -tags fts5 .          # Run backend dev server (localhost:3001)
cd server && go build -tags fts5 -o cadence-server .  # Build binary
```

## Architecture

Cadence — a monthly snapshot of your running metrics. Full-stack app that visualizes Strava running activity data. Split deployment: React frontend on Vercel, Go backend on Fly.io. Monorepo with separate `client/` and `server/` packages.

**Frontend (`client/`)** — React 19 + Vite + Tailwind CSS v4 + Recharts. Custom hooks (`useAuth`, `useActivities`, `useChartData`) encapsulate auth flow, data fetching with localStorage caching, and chart data normalization (0-1 range). API client in `client/src/lib/api.ts`.

**Backend (`server/`)** — Go with chi router:
- `handlers/auth.go` — Strava OAuth 2.0 flow (`/auth/strava`, `/auth/callback`, `/auth/status`, `/auth/logout`)
- `handlers/activities.go` — Fetches running activities from Strava API (filters to Run/TrailRun/VirtualRun, 30-day window)
- `store/token.go` — SQLite (modernc.org/sqlite, pure Go) single-row token store with auto-refresh (5-min buffer)
- `strava/client.go` — Strava API HTTP client

**Data flow:** User authenticates via Strava OAuth → tokens stored in SQLite → backend fetches activities from Strava API → frontend caches and visualizes with Recharts line charts.

## Environment

Each package has its own `.env.example`. Copy and fill in:
- `server/.env` — `STRAVA_CLIENT_ID`, `STRAVA_CLIENT_SECRET`, and optionally `FRONTEND_URL`, `API_BASE_URL`, `DB_PATH`, `PORT`
- `client/.env` — `VITE_API_URL` (backend URL)

## Deployment

Frontend deploys to Vercel from `client/` (set `VITE_API_URL` to backend URL). Backend deploys to Fly.io via Docker (GitHub Actions on push to master). Fly.io uses a persistent volume at `/data` for the SQLite database.
