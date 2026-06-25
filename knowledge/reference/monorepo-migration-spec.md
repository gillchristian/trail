# Monorepo migration — handoff spec

**Status:** ready for execution · **Created:** 2026-06-24 · **Owner:** `gillchristian`
**Delivery:** `pr` (squash-only, `master` sacred) — with **one recorded bootstrap exception** (PR 2, see MONO-002)
**Task namespace:** `MONO-` (this migration is repo-structural / shared-tier work)

---

## 0. What this is

Transform the existing **trail** repo (`/Users/bb8/dev/trail`) into a monorepo housing five systems, fold in the external **cadence** repo (`/Users/bb8/dev/cadence`), and stand up the two-tier federated knowledge base that lets one agent per system work in parallel.

Execute as **five squash-merged PRs**, in order. The working tree must build green after every PR. PRs 0→1→2→4 are strictly ordered; PR 3 (stubs) may land any time after PR 1.

This document is the contract. The **Locked decisions** below are settled — do not relitigate them mid-execution. The **Open questions** block lists the only things still requiring user input; two of them gate PR 4.

---

## 1. Locked decisions (do not reopen)

1. **Monorepo is born from the trail repo.** Trail's git history is preserved through renames via `git mv`. No new repo is created.
2. **Framework strategy B — path indirection.** One canonical `framework/` copy at the monorepo root; the framework stops hardcoding `../planning` sibling paths and resolves instance-area locations from the manifest. This is framework **v2 → v3** (PR 0).
3. **Two-tier knowledge base.** Shared top-level tier (read-mostly, global truth) + per-system tier (high-write, local truth). Split axis: *write-contention × scope-of-truth*.
4. **Five systems, flat under `systems/`:** `trail`, `cadence` (old `client/`), `gateway` (old `server/`), `track` (stub), `reflect` (stub). The backend is `gateway`, not a child of cadence — it serves both cadence's and trail's UIs.
5. **Gateway layout: flatten.** `server/`'s contents move directly under `systems/gateway/` (not `systems/gateway/server/`). This requires editing `fly.toml` and the Dockerfile (MONO-002).
6. **Cadence import uses a recorded bootstrap exception:** exactly one sanctioned non-squash merge brings cadence's history in inline, documented in the root manifest, precedent-setting for nothing (mirrors the `Batman` root-commit irregularity).
7. **Fly app name stays `cadence`.** The *directory* is `gateway`; the fly *app* is independent. Renaming the app would orphan the `data` volume holding `tokens.db`. Decouple the two.
8. **`tokens.db` / `tokens.json` do not migrate.** Confirmed untracked in cadence (`git ls-files`). Only `server/.env.example` carries across as the seed; live token state lives on the fly volume.
9. **Cadence's unified knowledge history → gateway.** Cadence's append-only `journal.md`/`DONE.md` cover both deployables and don't bisect cleanly; they stay with `gateway` under a tombstone note. Cadence starts a fresh v3 instance referencing it.
10. **Per-system task-id namespaces and branch prefixes** (table in §3). No global counters — they are an allocation race under parallel agents.
11. **Cross-system status is a read-time projection** over per-system `blockers.md`/`journal.md`, never a shared mutable file.
12. **Deploy targets are re-pointed, not recreated.** The fly app, both Vercel projects, and their secrets/volumes/domains are preserved; only their source paths and git connections change.
13. **No root workspace by default.** Each system owns its `package.json` + `node_modules` (self-contained, per-system lockfiles). A root `package.json`/`node_modules` appears **only if** a genuinely global dev dependency emerges — avoided otherwise. No hoisting; no workspace declaration in the base migration.
14. **`MORNING.md` is a per-system overnight report.** One per system (the agent's "what I worked on overnight" log) at `systems/<s>/MORNING.md`. Not a root file.
15. **Deploys are manual.** No active auto-deploy. The agent prepares deploy config and **asks the user to run the manual deploy and confirm health**, rather than deploying itself.

---

## 2. Target structure (post-migration)

```
<monorepo root>  (was: trail/)
├── .github/workflows/        repo-wide CI, path-filtered per system
├── .claude/                  consolidated (trail + cadence settings merged)
├── .gitignore                consolidated
├── CLAUDE.md                 DISPATCH: "which system?" + the reading chain
│                             (no root package.json/node_modules unless a global dev dep emerges)
├── knowledge/                ── SHARED TIER (read-mostly, global) ──
│   ├── framework/            single canonical v3 copy (monorepo is upstream)
│   ├── README.md             ROOT MANIFEST: repo-wide delivery/identity/VCS rules + system index
│   ├── reference/
│   │   ├── product-vision.md   Plan(Trail) → Execute(Track) → Reflect
│   │   └── specs/              .trail / .trace contracts; trail-integration.md
│   ├── decisions/            cross-cutting ADRs only
│   └── whiteboard/           cross-system discussions
└── systems/                  ── PER-SYSTEM TIER (high-write, local) ──
    ├── trail/
    │   ├── knowledge/        v3 instance: README(manifest)+planning+progress+decisions+reference+whiteboard
    │   ├── CLAUDE.md         system reading-chain entry
    │   ├── MORNING.md        per-system overnight report
    │   └── <code>            src/ public/ samples/ scripts/ index.html elm.json vite.config.js package.json …
    ├── cadence/              (old client/, flattened) + fresh v3 knowledge instance
    ├── gateway/              (old server/, FLATTENED) + v3 knowledge instance (inherits cadence history)
    ├── track/                stub v3 instance (knowledge only, no code)
    └── reflect/              stub v3 instance (knowledge only, no code)
```

---

## 3. Namespaces & conventions

| System    | Dir                 | Branch prefix | Task-id ns | Deploy target          |
|-----------|---------------------|---------------|------------|------------------------|
| trail     | `systems/trail`     | `trail/`      | `TRAIL-`   | Vercel (re-rooted)     |
| cadence   | `systems/cadence`   | `cadence/`    | `CAD-`     | Vercel (re-pointed)    |
| gateway   | `systems/gateway`   | `gateway/`    | `GW-`      | fly.io (re-rooted)     |
| track     | `systems/track`     | `track/`      | `TRACK-`   | — (none yet)           |
| reflect   | `systems/reflect`   | `reflect/`    | `REFLECT-` | — (none yet)           |
| (shared)  | `knowledge/`        | `mono/`       | `MONO-`    | —                      |

- **Reading chain (post-migration):** root `CLAUDE.md` (dispatch) → root manifest (repo-wide delivery/identity) → system manifest (`systems/<s>/knowledge/README.md`: local rules + **Locations block**) → `knowledge/framework/` → enabled delivery profile.
- **Parallelism primitive:** one `git worktree` per active agent (isolated working tree, shared object store + branch namespace). Branch prefixes above keep namespaces disjoint; per-system planning/progress keeps state writes disjoint.
- **Delivery ceiling:** the root manifest sets the repo-wide delivery posture (`pr`, squash-only, `master` sacred, user-only attribution). A system manifest may *narrow* it, never widen it.
- **Per-system install:** each system has its own `package.json`/`node_modules` and builds standalone from its own dir. No root workspace unless a global dev dep emerges.
- **`MORNING.md`:** per-system overnight report at `systems/<s>/MORNING.md`; one per system.

---

## MONO-000 · PR 0 — Framework v2 → v3: path indirection

**Goal:** the framework resolves instance-area locations from the manifest instead of hardcoded `../` siblings. Pure framework change; **no file moves, no new systems**. Trail keeps working because trail's manifest declares the same locations it already had.

**Why first:** proves the indirection before anything depends on it. PRs 1–3 all instantiate v3 instances; they must have a working v3 framework to point at.

### Operations
1. Read every file under `knowledge/framework/` and inventory each hardcoded reference to a sibling area: `../planning/`, `../progress/`, `../decisions/`, `../reference/`, `../whiteboard/`, and the manifest `../README.md`. (Known sites: `framework/README.md` "The pieces" + "The loop" step 1; `framework/delivery.md` manifest + `planning/CURRENT.md` + `progress/blockers.md` refs; `framework/SETUP.md` skeletons; sweep the rest.)
2. Replace path-literals with **role names** in framework prose ("the planning area", "the journal", "the manifest"). The framework refers to areas by role; the *manifest* maps roles → paths.
3. Add a **Locations block** convention to the manifest skeleton in `SETUP.md`:
   ```markdown
   ## Locations
   framework:  <path>
   planning:   <path>
   progress:   <path>
   decisions:  <path>
   reference:  <path>
   whiteboard: <path>
   ```
   The single hardcoded hop that remains: `CLAUDE.md` → the manifest path. Everything else dereferences through Locations.
4. Update trail's manifest (`knowledge/README.md`) and `CLAUDE.md` to the v3 convention, declaring the **current** (pre-move) trail paths. Trail must behave identically.
5. Stamp `framework/README.md`: **Framework v3 (2026-06-24)**, with a one-line changelog (path indirection; manifest Locations block). This repo remains the canonical upstream.

### Acceptance criteria
- Grep over `knowledge/framework/` returns **no** `\.\./(planning|progress|decisions|reference|whiteboard)/` path-literals (role names only).
- Instance-free guard still clean: `grep -riE '\btrail\b|\belm\b|batman|gillchristian|coros|samples/' knowledge/framework/` returns nothing (the existing `context7`-in-"e.g." carve-out still applies).
- Fresh-agent dry-run (per the upstream-change convention): a cold read of `CLAUDE.md → manifest → framework` resolves every area correctly with zero prior context.
- Trail's existing loop is unchanged: `npm run build` and `npm run smoke` still pass.

### Verification gates
`npx elm make src/Main.elm --output=/dev/null` · `npm run build` · `npm run smoke` · `npm run smoke:aidcsv` — all green, output quoted in the journal.

---

## MONO-001 · PR 1 — Restructure trail in place

**Goal:** move trail's code into `systems/trail/`, split its knowledge into the shared tier + a trail v3 instance, and split its manifest into root + system. Trail still builds and deploys from the new path.

**Preconditions:** PR 0 merged.

### File map (use `git mv` to preserve history)
**Code → `systems/trail/`:**
`src/ public/ samples/ scripts/ index.html elm.json vite.config.js package.json package-lock.json .envrc .nvmrc MORNING.md`
(`MORNING.md` is trail's per-system overnight report — one per system; it stays with trail.)

**Knowledge split:**
- `knowledge/framework/` → **stays at root** (now the monorepo's single canonical copy).
- `knowledge/{planning,progress,decisions,reference,whiteboard}/` → `systems/trail/knowledge/`.
- `knowledge/README.md` (trail manifest) → **split**:
  - Repo-wide rules (squash-only, `master` sacred, `Batman` root, user-only attribution) → **root** `knowledge/README.md` (new root manifest) + the system index table.
  - Trail-local rules (local-ci commands, branch prefix `trail/`, id-namespace `TRAIL-`, brief pointer, **Locations block**) → `systems/trail/knowledge/README.md`.

**Manifest/dispatch:**
- Root `CLAUDE.md` → **dispatch**: "which system are you in? read that system's `CLAUDE.md`" + the reading chain + repo non-negotiables.
- Trail's old `CLAUDE.md` content → `systems/trail/CLAUDE.md` (system reading-chain entry, pointing at root manifest then system manifest).

**Do not move (artifacts, regenerate):** `dist/ elm-stuff/ node_modules/`. Consolidate `.gitignore` at root (keep trail-specific ignores scoped if needed). Merge `.claude/` at root.

### Path-dependent fixes (inspect and update)
- `systems/trail/vite.config.js` — base/root/publicDir paths if any are repo-root-relative.
- `systems/trail/package.json` scripts and any `scripts/*` that assume repo-root cwd.
- Append-only history (`journal.md`, `DONE.md`, old ADRs) referencing `knowledge/philosophy/...` or old paths: **leave untouched** (tombstone convention). Fix only *live* pointers (CLAUDE quick-map, local-ci, manifest cross-links).

### Acceptance criteria
- `npm run build`, `npm run smoke`, `npm run smoke:aidcsv`, `npx elm make … --output=/dev/null` all pass **run from `systems/trail/`**.
- `git log --follow systems/trail/src/Main.elm` shows pre-move history (rename preserved).
- Reading chain resolves cold: root `CLAUDE.md` → root manifest → `systems/trail/knowledge/README.md` (Locations) → root `knowledge/framework/`.
- Root manifest carries every repo-wide delivery/identity rule; trail's system manifest carries only system-local rules. No rule is duplicated across both tiers.
- **Vercel (trail):** Root Directory set to `systems/trail` (see §Deploy). Build succeeds in Vercel.

---

## MONO-002 · PR 2 — Import cadence (bootstrap exception)

**Goal:** fold cadence's `client/` → `systems/cadence/` and `server/` → `systems/gateway/` (flattened), upgrade its v1 knowledge into two v3 instances, route its unified history to gateway, and re-point both deploy targets.

**Preconditions:** PR 1 merged.

**⚠ Delivery exception (recorded):** importing cadence's history requires `git subtree add --prefix=… <cadence> master` (or equivalent) with `--allow-unrelated-histories`, producing **one merge commit on `master`**. This is the single sanctioned exception to squash-only/`master`-sacred for this task. **Record it in the root manifest** under a "Bootstrap exceptions" note (alongside the `Batman` precedent), stating it sets no precedent. No other non-squash merge is permitted.

### Code map
**Cadence client → `systems/cadence/` (flatten `client/`):**
all of `client/*` → `systems/cadence/*` (`src/ index.html package.json package-lock.json vite.config.ts tsconfig*.json eslint.config.js vercel.json .env.example vite-env.d.ts`).

**Cadence server → `systems/gateway/` (FLATTEN `server/`):**
all of `server/*` → `systems/gateway/*` (`main.go go.mod go.sum handlers/ store/ strava/ Dockerfile .env.example`), plus `fly.toml` and `.dockerignore` → `systems/gateway/`.

**Drop:** cadence's root `package.json` / `package-lock.json` (workspace orchestration superseded by the monorepo root — see PR 4). Cadence root `README.md` → fold useful bits into the gateway/cadence briefs, otherwise drop.

### Gateway flatten — deploy-critical edits
Because the build context becomes `systems/gateway/` (deployed via `fly deploy systems/gateway`), and the Dockerfile/fly.toml paths were anchored at cadence's repo root:

1. `systems/gateway/fly.toml`:
   ```toml
   [build]
   -  dockerfile = 'server/Dockerfile'
   +  dockerfile = 'Dockerfile'
   ```
   **Leave `app = 'cadence'` unchanged** (Locked decision 7). All other fly.toml keys unchanged.
2. `systems/gateway/Dockerfile`: **read it**, then rewrite every build-context-relative path that referenced `server/`:
   - `COPY server/<x> …` → `COPY <x> …` (e.g. `COPY server/go.mod ./` → `COPY go.mod ./`).
   - Any `WORKDIR`/`ADD`/`COPY` path beginning `server/` → strip the `server/` segment.
   - `go.mod`/`go.sum` are now at context root; `RUN go build` working dir adjusts accordingly.
3. Verify the image builds from the new context **before** touching the live app: `docker build -f systems/gateway/Dockerfile systems/gateway` (or `fly deploy systems/gateway --build-only` if available).

### Knowledge routing (cadence v1 → v3)
Cadence's knowledge is **pre-extraction (framework v1, `knowledge/philosophy/*`)** and is a **single instance authored across both deployables**. Route as:

| Source (cadence)                              | Destination                                  |
|-----------------------------------------------|----------------------------------------------|
| `decisions/0001-tokens-sessions-split.md`     | `systems/gateway/knowledge/decisions/`       |
| `decisions/0002-in-memory-oauth-state-store.md` | `systems/gateway/knowledge/decisions/`     |
| `decisions/0003-oauth-state-before-strava-exchange.md` | `systems/gateway/knowledge/decisions/` |
| `decisions/0004-athlete-cache-sentinel-key.md`| `systems/gateway/knowledge/decisions/`       |
| `decisions/INDEX.md`                          | rebuild per instance (gateway gets 0001–0004)|
| `reference/caching.md`                        | `systems/gateway/knowledge/reference/`       |
| `reference/trail-integration.md`              | **shared** `knowledge/reference/specs/` (cross-system contract) |
| `reference/project-brief.md`                  | split: server concerns → gateway brief; cadence client gets a fresh derived brief stub |
| `reference/glossary.md`                       | gateway by default; lift any genuinely cross-system terms to shared `knowledge/reference/` |
| `planning/{BACKLOG,CURRENT,DONE}.md`          | **gateway** (primary inheritor); cadence starts fresh empty planning |
| `progress/{journal,blockers}.md`              | **gateway**, with a tombstone note "covers pre-monorepo cadence (client+server)"; cadence starts fresh `journal.md` |
| `knowledge/philosophy/*` (v1 framework)       | **discard** (superseded by root v3 framework); leave a one-line tombstone in gateway README noting the v1→v3 upgrade |
| `knowledge/README.md` (v1 manifest)           | becomes `systems/gateway/knowledge/README.md`, rewritten to v3 (Locations block, branch prefix `gateway/`, id-ns `GW-`); repo-wide bits already live in the root manifest |

Then create **`systems/cadence/knowledge/`** as a fresh v3 instance: manifest (branch `cadence/`, id-ns `CAD-`, Locations), empty planning, fresh `journal.md`/`blockers.md`, a brief derived from the client-relevant slice of cadence's old project-brief. Re-number gateway's imported ADRs only if collisions exist (they won't — gateway keeps 0001–0004; cadence starts at 0001 in its own namespace).

### CI
- `.github/workflows/fly-deploy.yml` → **root** `.github/workflows/`. Deploys are **manual** today (no active auto-deploy), so this file is moved for completeness, not relied on. Update it for the new layout anyway so it's correct if/when wired:
  - path filter `paths: ['systems/gateway/**']` (server-only trigger),
  - deploy step pointed at the new dir (`fly deploy systems/gateway --remote-only`, or `working-directory: systems/gateway`).
  - **`FLY_API_TOKEN`** repo secret is only needed *if* CI deploy is later enabled; it is **not** a migration blocker under manual deploys. Note it in the gateway manifest as a "when you wire CI" prerequisite.

### Acceptance criteria
- `systems/gateway`: `go build ./...` and `go test ./...` pass from the new root; Docker image builds from `systems/gateway` context.
- `systems/cadence`: `npm install && npm run build` (tsc + vite) passes from `systems/cadence`.
- Exactly **one** non-squash merge commit exists on `master` from this PR, recorded in the root manifest's bootstrap-exceptions note.
- `tokens.db`/`tokens.json` are **absent** from the tree and present in `.gitignore`; `server/.env.example` → `systems/gateway/.env.example` present.
- Gateway knowledge instance reads cold via the chain; cadence knowledge instance is a clean fresh v3 with no orphaned `philosophy/` refs in live pointers.
- **fly:** image builds from the `systems/gateway` context (verified locally via `docker build` / `--build-only`). The live deploy is **manual** — prepare the config, then **ask the user to run `fly deploy systems/gateway` and confirm** `/` health + that the `data` volume / `tokens.db` are intact (not recreated). Do not deploy autonomously.
- **Vercel (cadence):** project re-pointed to monorepo repo, Root Directory `systems/cadence`, build green, Strava redirect URL + domain + env vars intact.

---

## MONO-003 · PR 3 — Scaffold track + reflect stubs

**Goal:** two empty v3 knowledge instances so agents can pick the systems up later. **Knowledge only, no code.** May land any time after PR 1.

### Operations
For each of `systems/track/` and `systems/reflect/`, run the SETUP adoption flow (copy-if-absent; do **not** copy `framework/` — point at the root copy via Locations):
- `knowledge/README.md` manifest: delivery inherits root ceiling; branch prefix + id-ns per §3; Locations block; brief pointer.
- `knowledge/CLAUDE.md` (or system `CLAUDE.md`) reading-chain entry.
- empty `planning/CURRENT.md`, `planning/BACKLOG.md`, `planning/DONE.md`; `progress/journal.md`, `progress/blockers.md`; `decisions/INDEX.md`; `reference/project-brief.md`; `whiteboard/README.md`.

**Track brief** carries the already-designed MVP work-item sequence (skeleton → domain/persistence → library/race-config → CSV import → **paused for the tracking-view design** → tracking view → post-race view; deferred: `.trace` export, `.trail` ingestion, Live Activity). Record the `.trace`/`.trail` contracts as pointers into shared `knowledge/reference/specs/`.
**Reflect brief** records scope-not-yet-defined + an explicit Unknowns list. Log a blocker if any setup input is missing; do not invent a backlog.

### Acceptance criteria
- Both instances read cold via the chain; SETUP installed-guard would now (correctly) refuse to re-run against them.
- No code, no build target introduced. `framework/` is **not** duplicated into either system.

---

## MONO-004 · PR 4 — Workspace + parallelism wiring

**Goal:** documented parallel-agent operating model. **No root workspace** — each system stays self-contained (Locked decision 13).
**Preconditions:** PRs 1 & 2 merged.

### Operations
1. **No root `package.json`/`node_modules`.** Each system keeps its own. Only introduce a root manifest if a genuinely global dev dependency later appears — out of scope here.
2. Root manifest additions:
   - the worktree-per-agent flow (one worktree per active system/agent),
   - branch-prefix + id-namespace table (§3),
   - the rule that **cross-system status is a projection** over per-system `blockers.md`/`journal.md`, never a shared mutable file,
   - the discipline that **shared-tier files are edited only via an explicit cross-cutting `MONO-` task**, never as a side effect of system work.
3. CI: ensure each system's build job is **path-filtered** (`systems/trail/**`, `systems/cadence/**`, `systems/gateway/**`) so a one-system commit doesn't rebuild the others.

### Acceptance criteria
- Each system builds standalone from its own dir with its own install; no root install step exists.
- Two agents on two worktrees (e.g. `trail/…` and `gateway/…`) can each branch, edit their own planning/progress, and open PRs with zero file-write or branch-namespace collision.
- Both Vercel projects build green rooted at their own system dir, with **no** "include files outside the Root Directory" needed (self-contained installs).

---

## Deploy cutover (cross-cutting — referenced by PR 2 & PR 4)

### fly.io (gateway)
- App `cadence` **stays**; `data` volume + `tokens.db` **preserved** (do not recreate the app).
- fly.toml `dockerfile = 'Dockerfile'`; Dockerfile COPY paths de-`server/`-ed (MONO-002).
- Deploy is **manual**: the agent prepares config and verifies the image builds locally, then asks the user to run `fly deploy systems/gateway` and confirm health. `fly-deploy.yml` is moved + corrected but not the active path; `FLY_API_TOKEN` is a "when you wire CI" prerequisite, not a migration blocker.

### Vercel (two projects, both re-pointed not recreated)
- **trail project** (already on this repo): Root Directory → `systems/trail`.
- **cadence project** (on the dying cadence repo): re-point Git connection → monorepo repo; Root Directory → `systems/cadence`. Env vars, domain, Strava redirect URLs survive the re-point.
- **Per project:** set **Ignored Build Step** to `git diff --quiet HEAD^ HEAD -- ./` so a one-frontend commit doesn't rebuild the other.
- Self-contained installs mean **no** "include files outside the Root Directory" toggle is needed.

---

## Resolved since draft

1. **Workspace model** → self-contained per-system `package.json`/`node_modules`; no root workspace, no hoist (Locked decision 13).
2. **Deploys** → manual; agent prepares config and asks the user to run the deploy. `FLY_API_TOKEN` only matters if CI deploy is later wired (Locked decision 15).
3. **`MORNING.md`** → per-system overnight report, one per system (Locked decision 14).
4. **ADR 0009** → revisit-as-follow-up accepted (below).

## Follow-ups (not migration blockers)

- **ADR 0009 (`.trail` sync) scope.** Once trail's UI depends on `gateway`, the deferred "server-hosted share snapshot" direction is effectively live. Revisit ADR 0009's *Out of scope / deferred* lines so trail's and gateway's briefs don't contradict once they coexist. File as a `TRAIL-` or `MONO-` task after PR 2; do not block the migration on it.
- **User actions during execution:** run the manual `fly deploy systems/gateway` when MONO-002 asks; re-point the cadence Vercel project's git connection (UI-only step the agent can't perform).

---

## Handoff brief

Start at **MONO-000 (PR 0)** — framework v3 path indirection, the de-risking move; nothing else is safe until the framework resolves areas from the manifest. Then **MONO-001** (trail restructure, history-preserving `git mv`), then **MONO-002** (cadence import — the only PR with a sanctioned non-squash merge; flatten the gateway and fix fly/Docker paths *before* asking the user to deploy the live app). **MONO-003** (stubs) can slot in any time after PR 1. **MONO-004** (parallelism wiring) lands last — no root workspace, each system self-contained.

Tree builds green after every PR. Every PR squash-merges except the one recorded cadence-import merge. Quote real verification output into the journal at each step. When stuck, follow `when-stuck.md` — log a blocker (notably the `FLY_API_TOKEN` one), pivot, don't ask.
