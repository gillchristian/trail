# systems/gateway/knowledge/ — gateway system manifest

Gateway is the Go backend (Strava OAuth + proxy; SQLite token/session store) that
serves **both** cadence's and trail's frontends. It deploys to fly.io as the app
`cadence` (the *app* name is historical; the *system* is `gateway`). **Read the
repo-root manifest first** (`/knowledge/README.md`) for the repo-wide rules this
system inherits; this file adds only gateway-local truth.

Reading chain: root `CLAUDE.md` → root manifest → **this file** →
`knowledge/framework/` (the shared copy at the repo root) → the `pr` profile in
`framework/delivery.md`.

## Lineage (v1 → v3; inherited cadence history)

Gateway is the **primary inheritor** of the pre-monorepo **cadence** repo's unified
knowledge — cadence's `planning/`, `progress/` (journal + blockers), `decisions/`
(ADRs 0001–0004), and the caching/glossary references moved here intact. That
history **covers pre-monorepo cadence (client + server)** and doesn't bisect
cleanly between the two deployables, so it stays whole with gateway; the cadence
*frontend* started a fresh v3 instance under `systems/cadence/`. The old v1
framework (`knowledge/philosophy/*`) was **discarded** (superseded by the shared
root v3 `framework/`); references to `knowledge/philosophy/...` in the inherited
journal/DONE/ADRs are historical (tombstone convention — left untouched). Imported
via the MONO-002 bootstrap merge.

## Delivery

Inherits the repo-wide ceiling defined in the root manifest (**pr**; squash-only;
`master` sacred; user-only attribution). Gateway does not narrow it. Authority for
those rules is the root manifest — not restated here.

- **Branch prefix:** `gateway/` (e.g. `gateway/gw-007-…`).
- **Task-id namespace:** `GW-` for new gateway work. The inherited cadence history
  used the global `TASK-` counter (TASK-001..006, the trail-integration backend
  arc) — those ids are preserved verbatim in `planning/`/`progress/`; new gateway
  tasks continue as `GW-NNN`.

## Locations

framework:  knowledge/framework
planning:   systems/gateway/knowledge/planning
progress:   systems/gateway/knowledge/progress
decisions:  systems/gateway/knowledge/decisions
reference:  systems/gateway/knowledge/reference
whiteboard: systems/gateway/knowledge/whiteboard

(`framework` is the shared copy at the repo root; the rest are gateway's. Paths
repo-root-relative. No `whiteboard/` exists yet — create on first use.)

## The loop, instantiated for gateway

1. **Orient** — read the planning area's `CURRENT.md`; if empty, promote the top
   unchecked item of `BACKLOG.md`.
2. **Plan** — acceptance criteria into `CURRENT.md` before code.
3. **Branch** — `git checkout master && git pull --ff-only && git checkout -b gateway/<task-id>-<slug>`.
4. **Execute** — implement from `systems/gateway/`, committing as I go.
5. **Verify** — gates in `framework/verification.md`; **run from `systems/gateway/`**:
   `go build -tags fts5 ./...`, `go vet ./...`, `go test ./...`, plus the Docker
   build (`docker build -f Dockerfile .` from this dir) and a curl smoke where the
   image / endpoints matter.
6. **PR** — `gh pr create`, then `gh pr merge --squash --delete-branch`.
7. **Log** — journal entry with PR number, merge sha, quoted verification.
8. **Advance** — close PR; move task to `DONE.md`; sync `master`.

Stuck? `framework/when-stuck.md` — not asking the user.

## Deploy (fly.io)

- App **`cadence`** stays (renaming would orphan the `data` volume holding
  `tokens.db`; Locked decision 7). Config: `systems/gateway/fly.toml`
  (`dockerfile = 'Dockerfile'`) + `systems/gateway/Dockerfile`.
- **Manual deploy:** `fly deploy systems/gateway`. Confirm `/` health + that the
  `data` volume / `tokens.db` are intact (never recreated). `tokens.db`/`tokens.json`
  are untracked and live only on the fly volume.
- **CI:** `/.github/workflows/fly-deploy.yml` is path-filtered to `systems/gateway/**`
  but **not the active path** (deploys are manual today). To wire it, set the
  **`FLY_API_TOKEN`** repo secret — a "when you wire CI" prerequisite, not a
  migration blocker.

## Layout (gateway instance)

- **planning/** — `CURRENT.md`, `BACKLOG.md`, `DONE.md` (inherited cadence history).
- **progress/** — `journal.md`, `blockers.md` (inherited; covers cadence client+server).
- **decisions/** — ADRs 0001–0004 + `INDEX.md` (inherited; gateway keeps 0001–0004).
- **reference/** — `project-brief.md` (the backend brief), `caching.md`, `glossary.md`.
- Cross-system contracts: `trail-integration.md` is in the shared
  `knowledge/reference/specs/`; the upstream backend spec is in trail's reference
  (`systems/trail/knowledge/reference/cadence-backend-spec.md`).

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` is updated.
