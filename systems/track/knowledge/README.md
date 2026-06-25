# systems/track/knowledge/ — track system manifest (pre-code)

**track** is the **Execute** system (Plan → Execute → Reflect): a race-day execution/tracking app,
not yet built — **code pending**. The MVP is designed + backlogged (specs in `reference/`; work
queued as `TRACK-000…010`). **Read the repo-root manifest first** (`/knowledge/README.md`) for the
repo-wide rules this system inherits.

Reading chain: root `CLAUDE.md` → root manifest → **this file** → `knowledge/framework/` (the shared
copy at the repo root) → the `pr` profile in `framework/delivery.md`.

## Delivery

Inherits the repo-wide ceiling from the root manifest (**pr**; squash-only; `master` sacred;
user-only attribution). Does not narrow it.

- **Branch prefix:** `track/` · **Task-id namespace:** `TRACK-`, starting at `TRACK-001`.

## Locations

framework:  knowledge/framework
planning:   systems/track/knowledge/planning
progress:   systems/track/knowledge/progress
decisions:  systems/track/knowledge/decisions
reference:  systems/track/knowledge/reference
whiteboard: systems/track/knowledge/whiteboard

(`framework` is the shared copy at the repo root; the rest are track's. Paths repo-root-relative.)

## The loop, instantiated for track

The standard framework loop (see `framework/README.md`): orient from the planning area's `CURRENT.md`,
acceptance criteria before code, branch `track/<task-id>-<slug>`, verify from `systems/track/` once code
exists, PR + squash-merge, journal, advance. Stuck? `framework/when-stuck.md` — not asking the user.

## Status: speced + backlogged — no code yet

The MVP is designed and seeded into `planning/BACKLOG.md` (epic "Tracker MVP", 2026-06-25): the
canonical specs are in `reference/` (`mvp-plan.md`, `tracking-view-spec.md`, `design/` wireframes),
and the work items are queued as **TRACK-000…TRACK-010**. **Next: TRACK-000** — the Swift/iOS
toolchain bootstrap (prerequisite; the build owner is new to Swift/iOS). When started: promote it
into `CURRENT.md` (copy the acceptance criteria from its BACKLOG line), branch `track/track-000-…`,
and record build/run/test commands in a new `reference/local-ci.md` as the toolchain appears.

## Layout (track instance)

- **planning/** — `CURRENT.md`, `BACKLOG.md`, `DONE.md`.
- **progress/** — `journal.md` (append-only), `blockers.md`.
- **decisions/** — ADRs + `INDEX.md` (none yet).
- **reference/** — `project-brief.md` (what track is + the MVP sequence + `.trace`/`.trail` pointers).
- **whiteboard/** — discussions in flight; index in its README.

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` is updated.
