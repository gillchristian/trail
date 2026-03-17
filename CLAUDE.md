# CLAUDE.md

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
