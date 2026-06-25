# knowledge/ — ROOT MANIFEST (trail monorepo)

This is the **shared tier** of a two-tier knowledge base: the repo-wide truth —
the delivery posture every system inherits, the identity/VCS rules, the system
index, and the single shared `framework/`. It is read-mostly, global. Per-system
work lives in each system's own high-write instance under
`systems/<s>/knowledge/`.

**Reading chain:** root `CLAUDE.md` (dispatch) → **this manifest** (repo-wide
delivery/identity) → the system manifest (`systems/<s>/knowledge/README.md`:
local rules + Locations block) → `knowledge/framework/` (the shared working
system) → the enabled profile in `framework/delivery.md`.

## What this repo is

A monorepo of five systems, flat under `systems/`, sharing one framework copy
and a federated knowledge base:

| System    | Dir                 | Branch prefix | Task-id ns | Deploy target        |
|-----------|---------------------|---------------|------------|----------------------|
| trail     | `systems/trail`     | `trail/`      | `TRAIL-`   | Vercel (re-rooted)   |
| cadence   | `systems/cadence`   | `cadence/`    | `CAD-`     | Vercel (re-pointed)  |
| gateway   | `systems/gateway`   | `gateway/`    | `GW-`      | fly.io (re-rooted)   |
| track     | `systems/track`     | `track/`      | `TRACK-`   | — (none yet)         |
| reflect   | `systems/reflect`   | `reflect/`    | `REFLECT-` | — (none yet)         |
| (shared)  | `knowledge/`        | `mono/`       | `MONO-`    | —                    |

As of MONO-001 only **trail** is populated (`systems/trail/`); cadence + gateway
arrive in MONO-002, the track/reflect stubs in MONO-003, parallelism wiring in
MONO-004. The migration contract is
`knowledge/reference/specs/monorepo-migration-spec.md`.

## Delivery posture (repo-wide ceiling)

delivery: **pr** (merge: squash; self-merge: yes; close-pr: yes)

**Operative meaning:** the agent owns the full branch → PR → squash-merge cycle
and merges its own PRs (`framework/delivery.md`, profile `pr`). `master` is
**sacred**: nothing lands on it directly — not even bookkeeping (that's the close
PR). A system manifest may *narrow* this ceiling, never widen it.

- **Squash-only.** A hard constraint; `--merge` is not an option (save the one
  recorded bootstrap exception below).
- **Identity/attribution:** commits and PRs are authored by the user only
  (`gillchristian`). No `Co-Authored-By: Claude ...` trailers, no "Generated with
  Claude Code" footers. The git config is already correct — just don't add
  attribution.
- **Branch naming:** `<system-prefix>/<task-id>-<slug>` per the table (e.g.
  `trail/trail-007-…`, `gateway/gw-003-…`); shared/structural work uses `mono/`.

### Bootstrap exceptions (a closed list; precedent-setting for nothing)

1. **The `Batman` root commit** (subject "Batman", no parents) — the only direct
   commit to `master`, ever. Predates the framework.
2. *(reserved for MONO-002)* the single `git subtree add --allow-unrelated-histories`
   merge that imports cadence's history inline — one merge commit on `master`, the
   only sanctioned non-squash merge. Recorded here when it lands.

Outside this list, squash-only / `master`-sacred admit no exceptions.

## The framework (shared)

- **Framework copy:** v3 — one canonical copy at `knowledge/framework/`, shared by
  every system. This repo is the **upstream** (`gillchristian/trail` →
  `knowledge/framework/`). v3's path indirection (MONO-000) is what lets one copy
  serve every system: the framework names instance areas by role; each system's
  manifest Locations block resolves them to paths.
- **Instance-free guard:** before merging any framework-touching PR, run
  `grep -riE '\btrail\b|\belm\b|batman|gillchristian|coros|samples/' knowledge/framework/`
  — it must return nothing (`context7` may appear only inside an "e.g." clause;
  word boundaries keep words like "trailing" out of the net).

## Shared-tier discipline

- The shared tier (`knowledge/framework`, `knowledge/reference/specs`, and — when
  they exist — cross-cutting `knowledge/decisions` + cross-system
  `knowledge/whiteboard`) is edited **only via an explicit `MONO-` task**, never as
  a side effect of one system's work.
- **No shared mutable planning/status file.** Cross-system status is a read-time
  projection over each system's `progress/` (journal + blockers), never a shared
  file someone keeps in sync.
- **Where `MONO-` work is tracked:** during the migration the `MONO-` epic rides in
  **trail's** instance (`systems/trail/knowledge/planning` + `progress`) — trail is
  the origin system the monorepo was born from. A `MONO-` task is pulled into
  trail's planning, branched `mono/…`, journaled in trail's progress. MONO-004
  revisits the parallelism model.

## Layout (shared tier)

- **framework/** — the reusable working system (v3; this repo is upstream).
- **README.md** — this root manifest.
- **reference/specs/** — cross-system contracts (today: the migration spec; the
  `.trail`/`.trace` contracts + `trail-integration.md` get lifted here as cadence
  and the consumers arrive).
- **decisions/** — *cross-cutting* ADRs only (none yet; per-system ADRs live in
  each system's instance). Created when the first one lands.
- **whiteboard/** — cross-system discussions (none yet). Created when the first
  one lands.

There is deliberately **no** shared `planning/` or `progress/` (see Shared-tier
discipline). Each system declares its own areas via its manifest's Locations block.
