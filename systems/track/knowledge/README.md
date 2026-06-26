# systems/track/knowledge/ — track system manifest (in build)

**track** is the **Execute** system (Plan → Execute → Reflect): a race-day execution/tracking app.
**Code has started** — the SwiftUI app builds + runs in the iOS Simulator (TRACK-000/001 done;
TRACK-002 next). The MVP is designed + backlogged (specs in `reference/`; work queued as
`TRACK-000…010`). **Read the repo-root manifest first** (`/knowledge/README.md`) for the repo-wide
rules this system inherits.

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

## Status: in build — WI-1 done (TRACK-000/001)

The Swift/SwiftUI app lives at `Track/` and builds + runs in the iOS Simulator (build/run/test commands
in `reference/local-ci.md`). **Done:** TRACK-000 (toolchain bootstrap + ADR-0001, PR #161), TRACK-001
(WI-1 project skeleton — a Races list over a `Documents/Races/<id>/race.json` bundle; iOS deployment
target pinned 17.0; shared scheme committed; PR #162). The canonical specs are in `reference/`
(`mvp-plan.md`, `tracking-view-spec.md`, `design/` wireframes); the work items are queued as
**TRACK-000…TRACK-010** in `planning/BACKLOG.md`. **Next: TRACK-002** — WI-2 domain model + durable
persistence (the append-only `events.log` / fsync spine; `mvp-plan.md` §4 + §7). Promote it from
`BACKLOG.md` into `CURRENT.md` (copy its AC), branch `track/track-002-…`.

## Layout (track instance)

- **planning/** — `CURRENT.md`, `BACKLOG.md`, `DONE.md`.
- **progress/** — `journal.md` (append-only), `blockers.md`.
- **decisions/** — ADRs + `INDEX.md` (none yet).
- **reference/** — `project-brief.md` (what track is + the MVP sequence + `.trace`/`.trail` pointers).
- **whiteboard/** — discussions in flight; index in its README.

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` is updated.
