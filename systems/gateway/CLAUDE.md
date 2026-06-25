# CLAUDE.md — gateway (system entry)

You're in **gateway** (the Go backend: Strava OAuth + proxy, SQLite token/session
store; chi router; pure-Go sqlite + FTS5). It serves **both** cadence's and trail's
frontends and deploys to fly.io as the app `cadence`. Build and run everything from
**this directory** (`systems/gateway/`).

**Read these, in order, before doing anything else:**
1. the repo-root manifest `/knowledge/README.md` (repo-wide rules gateway inherits),
2. this system's manifest `systems/gateway/knowledge/README.md` (gateway-local rules
   + **Locations** + the cadence lineage),
3. `knowledge/framework/README.md` at the repo root (the shared working system),
4. the `pr` profile in `knowledge/framework/delivery.md`.

## Non-negotiables (gateway)

1. **One task at a time.** Pull from `systems/gateway/knowledge/planning/CURRENT.md`.
   If empty, promote the top unchecked `BACKLOG.md` item. Acceptance criteria first.
2. **Delivery: pr** (inherited ceiling). Branches → PRs you merge yourself,
   squash-only; `master` sacred. Branch prefix `gateway/`; new ids `GW-NNN`
   (inherited cadence `TASK-` history preserved).
3. **User-only attribution.** No `Co-Authored-By: Claude …` trailer, no "🤖 Generated
   with Claude Code" footer. Git config is already correct.
4. **Verify before declaring done — from `systems/gateway/`.** `go build -tags fts5 ./...`,
   `go vet ./...`, `go test ./...`, the Docker build where the image matters, and a
   curl smoke of the endpoints. Run it; quote real output.
5. **Journal everything** in `systems/gateway/knowledge/progress/journal.md`.
6. **When stuck, follow `knowledge/framework/when-stuck.md`.** Log real blockers to
   `systems/gateway/knowledge/progress/blockers.md`, then pivot.
7. **Trail drives the cross-system contract.** Canonical spec:
   `systems/trail/knowledge/reference/cadence-backend-spec.md`; summary: the shared
   `knowledge/reference/specs/trail-integration.md`. Don't reinterpret silently —
   file a blocker.

## Deploy (manual, fly.io)

App **`cadence`** stays (renaming orphans the `data` volume / `tokens.db`). Config in
`systems/gateway/{fly.toml,Dockerfile}`. Deploy: `fly deploy systems/gateway`; confirm
`/` health + the `data` volume intact. The CI workflow exists but is inactive (set the
`FLY_API_TOKEN` repo secret to wire it). `tokens.db`/`tokens.json` are never tracked.

## Quick map (gateway)

- `systems/gateway/knowledge/README.md` — system manifest (Locations, `gateway/`, `GW-`, lineage).
- `systems/gateway/` — `main.go`, `handlers/`, `store/`, `strava/`, `go.mod`, `Dockerfile`, `fly.toml`.
- `systems/gateway/knowledge/{planning,progress,decisions,reference}/` — inherited cadence knowledge.
- `knowledge/framework/` (repo root) — the shared working system (changes = `MONO-` tasks).
- Repo-wide rules + system index: the root manifest (`/knowledge/README.md`).
