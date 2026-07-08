# systems/cadence/knowledge/ — cadence system manifest

Cadence's instance of the knowledge framework. Cadence is the **frontend** (React 19 +
Vite + Tailwind v4 + Recharts) that visualizes a runner's Strava trends; it talks to
the **gateway** backend for OAuth + data. **Read the repo-root manifest first**
(`/knowledge/README.md`) for the repo-wide rules this system inherits; this file adds
only cadence-local truth.

Reading chain: root `CLAUDE.md` → root manifest → **this file** →
`knowledge/framework/` (the shared copy at the repo root) → the `pr` profile in
`framework/delivery.md`.

## A fresh v3 instance

This instance starts **fresh** (empty planning, fresh journal). The pre-monorepo
cadence repo's unified knowledge — its history, ADRs, journal, and the
trail-integration arc — went to **gateway** (`systems/gateway/knowledge/`), the primary
inheritor, because it covered both deployables and doesn't bisect cleanly between
frontend and backend. New cadence-frontend work is logged here as `CAD-`.

## Delivery

Inherits the repo-wide ceiling defined in the root manifest (**pr**; squash-only;
`master` sacred; user-only attribution). Cadence does not narrow it.

- **Branch prefix:** `cadence/` (e.g. `cadence/cad-001-…`).
- **Task-id namespace:** `CAD-`, starting at `CAD-001`.

## Locations

framework:  knowledge/framework
planning:   systems/cadence/knowledge/planning
progress:   systems/cadence/knowledge/progress
decisions:  systems/cadence/knowledge/decisions
reference:  systems/cadence/knowledge/reference
whiteboard: systems/cadence/knowledge/whiteboard

(`framework` is the shared copy at the repo root; the rest are cadence's. Paths
repo-root-relative.)

## The loop, instantiated for cadence

1. **Orient** — read the planning area's `CURRENT.md`; if empty, promote the top of `BACKLOG.md`.
2. **Plan** — acceptance criteria into `CURRENT.md` before code.
3. **Branch** — `git checkout master && git pull --ff-only && git checkout -b cadence/<task-id>-<slug>`.
4. **Execute** — implement from `systems/cadence/`, committing as I go.
5. **Verify** — gates in `framework/verification.md`; **run from `systems/cadence/`**:
   `npm run build` (tsc + vite), `npm run lint`.
6. **PR** — `gh pr create`, then the fresh-context review (verification gate 7:
   diff + acceptance criteria only; findings fixed or rebutted in the PR
   description), then `gh pr merge --squash --delete-branch`.
7. **Log** — journal entry with PR number, merge sha, quoted verification.
8. **Advance** — close PR; move task to `DONE.md`; sync `master`; check the
   session envelope (`framework/working-style.md`) before the next task — an
   empty backlog is a terminal state, not an error.

Stuck? `framework/when-stuck.md` — not asking the user.

## Deploy (Vercel)

Vercel project re-pointed to this monorepo, Root Directory `systems/cadence`. Set
`VITE_API_URL` to the gateway URL. The Strava redirect URL, domain, and env vars
survive the re-point.

## Layout (cadence instance)

- **planning/** — `CURRENT.md`, `BACKLOG.md`, `DONE.md`.
- **progress/** — `journal.md` (append-only), `blockers.md`.
- **decisions/** — ADRs + `INDEX.md` (none yet).
- **reference/** — `project-brief.md` (the frontend brief).
- **whiteboard/** — discussions in flight; index in its README.

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` is updated.
