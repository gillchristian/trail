# CLAUDE.md — trail (system entry)

You're in **trail** (the race planner: Elm + Vite + Tailwind frontend), one system
of the monorepo. Build and run everything from **this directory**
(`systems/trail/`) — it is self-contained (own `package.json`/`node_modules`).

**Read these, in order, before doing anything else:**
1. the repo-root manifest `/knowledge/README.md` (ROOT MANIFEST: repo-wide
   delivery/identity rules trail inherits + the system index),
2. this system's manifest `systems/trail/knowledge/README.md` (trail-local rules +
   **Locations**),
3. `knowledge/framework/README.md` at the repo root (the shared working system),
4. the `pr` profile in `knowledge/framework/delivery.md`.

## Non-negotiables (trail)

1. **One task at a time.** Pull from `systems/trail/knowledge/planning/CURRENT.md`
   (the system manifest's Locations block is authoritative). If empty, promote the
   top unchecked `BACKLOG.md` item. Acceptance criteria before code.
2. **Delivery: pr** (inherited repo ceiling). Branches → PRs you merge yourself,
   squash-only; `master` sacred. Branch prefix `trail/`; new ids `TRAIL-NNN`
   (legacy `TASK-` history preserved). Full profile in
   `knowledge/framework/delivery.md`.
3. **User-only attribution.** No `Co-Authored-By: Claude …` trailer, no "🤖
   Generated with Claude Code" footer. Git config is already correct.
4. **Verify before declaring done — from `systems/trail/`.** Gates in
   `knowledge/framework/verification.md`; commands in the reference area's
   `local-ci.md`. Run the program, quote real output; don't confuse "compiles"
   with "works."
5. **Journal everything.** Append to `systems/trail/knowledge/progress/journal.md`
   after every task.
6. **When stuck, follow `knowledge/framework/when-stuck.md`.** Don't ask the user;
   log real blockers to `systems/trail/knowledge/progress/blockers.md`, then pivot.

## Quick map (trail)

- `systems/trail/knowledge/README.md` — the system manifest: delivery (inherits
  root), Locations, branch prefix `trail/`, id-ns `TRAIL-`, the loop.
- `systems/trail/knowledge/planning/` — `CURRENT.md`, `BACKLOG.md`, `DONE.md`.
- `systems/trail/knowledge/progress/` — `journal.md`, `blockers.md`.
- `systems/trail/knowledge/decisions/` — trail's ADRs.
- `systems/trail/knowledge/reference/` — `project-brief.md` (product intent — wins
  conflicts), `glossary.md`, `local-ci.md`, specs, roadmaps.
- `knowledge/framework/` (repo root) — the shared working system; keep it
  instance-free (changes are `MONO-` tasks at the root tier).
- Repo-wide rules + the system index: the root manifest (`/knowledge/README.md`).

## Project status pointer

Trail's current work is in `systems/trail/knowledge/planning/CURRENT.md`; the
product intent is in `systems/trail/knowledge/reference/project-brief.md`. If they
disagree, the brief wins and `CURRENT.md` is updated.
