# CLAUDE.md — trail monorepo (dispatch)

This is a **monorepo** of five systems under `systems/`. Before doing anything:

1. **Which system are you working in?** Read that system's `CLAUDE.md` and follow
   it for system-local rules:
   - `systems/trail/CLAUDE.md` — trail (the race planner; Elm + Vite frontend)
   - `systems/cadence/CLAUDE.md` — cadence (frontend; arrives MONO-002)
   - `systems/gateway/CLAUDE.md` — gateway (Go backend; arrives MONO-002)
   - `systems/track/CLAUDE.md`, `systems/reflect/CLAUDE.md` — stubs (MONO-003)
2. **Doing shared/structural work** (the `framework/`, this root manifest,
   cross-system specs)? That's a `MONO-` task — read the root manifest's
   *Shared-tier discipline* first.

**Reading chain:** this file (dispatch) → `knowledge/README.md` (ROOT MANIFEST:
repo-wide delivery/identity rules + system index) → the system manifest
(`systems/<s>/knowledge/README.md`: local rules + **Locations**) →
`knowledge/framework/` (the shared working system) → the enabled profile in
`framework/delivery.md`.

## Repo-wide non-negotiables

These hold in every system. The root manifest is authoritative; a system manifest
may narrow them, never widen.

1. **One task at a time.** Pull from the active system's planning-area `CURRENT.md`
   (its manifest's **Locations** block says where). If empty, promote the top
   unchecked `BACKLOG.md` item. Acceptance criteria before touching code.
2. **Delivery: pr.** Branches → PRs you merge yourself, **squash-only**. `master`
   is sacred — the only sanctioned irregularities are the bootstrap exceptions in
   the root manifest (`Batman` root; the one cadence-import merge). Full profile in
   `knowledge/framework/delivery.md`.
3. **User-only attribution.** Commits and PRs carry the user's identity only
   (`gillchristian`). No `Co-Authored-By: Claude …` trailer, no "🤖 Generated with
   Claude Code" footer. The git config is already correct.
4. **Verify before declaring done.** Gates in `knowledge/framework/verification.md`.
   Run the program, quote real output, build/verify **from the system's own dir**
   (each system is self-contained).
5. **Journal everything.** Append to the active system's journal after every task.
6. **When stuck, follow `knowledge/framework/when-stuck.md`.** Don't ask the user;
   log real blockers to that system's blockers log, then pivot.

## Map

- `knowledge/` — **shared tier**: `framework/` (the working system, v3, instance-
  free), `README.md` (root manifest), `reference/specs/` (cross-system contracts).
  Edited only via `MONO-` tasks.
- `systems/<s>/` — each system's code + its **own** `knowledge/` instance + its
  `CLAUDE.md` + `MORNING.md`. Self-contained: own `package.json`/`node_modules`,
  builds from its own dir.
- Migration contract: `knowledge/reference/specs/monorepo-migration-spec.md`.
