# CLAUDE.md — cadence (system entry)

You're in **cadence** (the frontend: React 19 + Vite + Tailwind v4 + Recharts — a
monthly snapshot of your Strava running metrics). It talks to the **gateway** backend
(`systems/gateway/`, the fly app `cadence`) for Strava OAuth + data. Build and run
everything from **this directory** (`systems/cadence/`) — self-contained (own
`package.json`/`node_modules`).

**Read these, in order, before doing anything else:**
1. the repo-root manifest `/knowledge/README.md` (repo-wide rules cadence inherits),
2. this system's manifest `systems/cadence/knowledge/README.md` (cadence-local rules
   + **Locations**),
3. `knowledge/framework/README.md` at the repo root (the shared working system),
4. the `pr` profile in `knowledge/framework/delivery.md`.

## Non-negotiables (cadence)

1. **One task at a time.** Pull from `systems/cadence/knowledge/planning/CURRENT.md`.
   If empty, promote the top unchecked `BACKLOG.md` item. Acceptance criteria first.
2. **Delivery: pr** (inherited ceiling). Branches → PRs you merge yourself,
   squash-only; `master` sacred. Branch prefix `cadence/`; ids `CAD-NNN`.
3. **User-only attribution.** No `Co-Authored-By: Claude …` trailer, no generated-with footer.
4. **Verify before declaring done — from `systems/cadence/`.** `npm run build`
   (tsc + vite), `npm run lint`. Run it; quote real output.
5. **Journal everything** in `systems/cadence/knowledge/progress/journal.md`.
6. **When stuck, follow `knowledge/framework/when-stuck.md`.** Log blockers to
   `systems/cadence/knowledge/progress/blockers.md`, then pivot.

## Dev

- `npm run dev` (Vite dev server) · `npm run build` (tsc + vite) · `npm run lint` (ESLint).
- Backend is the **gateway** system (`systems/gateway/`, fly app `cadence`). Set
  `VITE_API_URL` to the gateway URL (the `.env.example` carried across from `client/`).

## History

The pre-monorepo cadence repo's **unified** knowledge (client + server) went to
**gateway** (the primary inheritor — it doesn't bisect cleanly). This is a **fresh v3
instance** for the cadence frontend; planning/journal start empty. Backend ADRs + the
trail-integration history live under gateway.

## Quick map (cadence)

- `systems/cadence/knowledge/README.md` — system manifest (Locations, `cadence/`, `CAD-`).
- `systems/cadence/` — `src/`, `index.html`, `package.json`, `vite.config.ts`, `vercel.json`.
- `knowledge/framework/` (repo root) — shared working system (changes = `MONO-` tasks).
- Repo-wide rules + system index: the root manifest (`/knowledge/README.md`).
