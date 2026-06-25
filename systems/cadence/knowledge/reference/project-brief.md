# Project brief — Cadence (frontend)

## What it is

**Cadence** is a personal-use, single-user web app that visualizes one runner's Strava
activity trends over time — monthly snapshots of running volume, pace, HR, and
elevation, rendered with Recharts. This system is the **frontend**; the Go **gateway**
backend (`systems/gateway/`, fly app `cadence`) handles Strava OAuth, caches activities
in SQLite, and serves the REST API the frontend reads.

## Stack

- React 19, Vite, Tailwind v4, Recharts, TypeScript.
- Custom hooks (`useAuth`, `useActivities`, `useChartData`) for auth, data fetching with
  localStorage caching, and chart-data normalization. API client in `src/lib/api.ts`.
- **Deploy:** Vercel, Root Directory `systems/cadence`; `VITE_API_URL` → the gateway URL.

## Talks to gateway

- Auth: Strava OAuth via gateway (`/auth/strava`, `/auth/callback`, `/auth/status`,
  `/auth/logout`); session token in localStorage, sent as `Authorization: Bearer`.
- Data: `/api/activities`, `/api/activities/{id}/detail`. The endpoint contract is owned
  by **gateway** (and, for the trail-shared surface, trail's spec). Don't change the
  contract from here.

## Out of scope

- Backend concerns (OAuth, caching, token/session storage) — those are **gateway**.
- Multi-user; webhook ingestion.

## Hard constraints

- **Live frontend.** Reads gateway's existing endpoints; preserve that contract.
- **Author identity:** commits + PRs by the user only; no Claude attribution.

## History

Pre-monorepo, cadence was a single repo (`client/` + `server/`) with unified knowledge.
At the monorepo import (MONO-002) the backend became **gateway** and inherited the
unified history (ADRs, journal, the trail-integration arc). This is the fresh
frontend-only brief; the backend brief is
`systems/gateway/knowledge/reference/project-brief.md`.
