# systems/trail/knowledge/ — trail system manifest

Trail's instance of the knowledge framework. **Read the repo-root manifest first**
(`/knowledge/README.md`) for the repo-wide delivery/identity/VCS rules this system
inherits; this file adds only trail-local truth.

Reading chain: root `CLAUDE.md` → root manifest → **this file** →
`knowledge/framework/` (the shared copy at the repo root) → the `pr` profile in
`framework/delivery.md`.

## Delivery

Inherits the repo-wide ceiling defined in the root manifest (**pr**; squash-only;
`master` sacred; user-only attribution). Trail does not narrow it. Authority for
those rules is the root manifest — they are not restated here.

- **Branch prefix:** `trail/` for trail feature work (e.g. `trail/trail-007-…`).
  Structural/shared work uses `mono/` and is tracked at the root tier.
- **Task-id namespace:** `TRAIL-` for new trail work. The pre-monorepo history used
  the global `TASK-` counter (TASK-001..071); those ids are preserved verbatim in
  `planning/`/`progress/`, and new trail tasks continue as `TRAIL-NNN`.

## Locations

The role → path map the framework dereferences (paths repo-root-relative). The
framework is the **shared** copy at the repo root; trail's instance areas live
under `systems/trail/knowledge/`.

framework:  knowledge/framework
planning:   systems/trail/knowledge/planning
progress:   systems/trail/knowledge/progress
decisions:  systems/trail/knowledge/decisions
reference:  systems/trail/knowledge/reference
whiteboard: systems/trail/knowledge/whiteboard

## The loop, instantiated for trail

1. **Orient** — read the planning area's `CURRENT.md`; if empty, promote the top
   unchecked item of `BACKLOG.md`.
2. **Plan** — acceptance criteria into `CURRENT.md` before touching code.
3. **Branch** — `git checkout master && git pull --ff-only && git checkout -b trail/<task-id>-<slug>`.
4. **Execute** — implement from `systems/trail/`, committing as I go.
5. **Verify** — gates in `framework/verification.md`; local-CI commands in the
   reference area's `local-ci.md` — **run from `systems/trail/`** (type-check,
   build, the smoke harnesses).
6. **PR** — `gh pr create` (template in `framework/delivery.md`), then
   `gh pr merge --squash --delete-branch`.
7. **Log** — journal entry with PR number, merge sha, quoted verification output.
8. **Advance** — close PR (branch `docs/<task-id>-close`): move the task to
   `DONE.md`, append the journal entry, optionally pull the next task into
   `CURRENT.md`; sync `master`.

Stuck or unsure? `framework/when-stuck.md` — not asking the user.

## Layout (trail instance)

- **planning/** — `CURRENT.md` (one active task), `BACKLOG.md` (ordered queue;
  conventions in its header), `DONE.md` (archive).
- **progress/** — `journal.md` (append-only), `blockers.md` (needs the user —
  surface at session end).
- **decisions/** — trail's ADRs + `INDEX.md` (template + criteria live there).
- **reference/** — `project-brief.md` (product intent — wins conflicts),
  `glossary.md`, `local-ci.md`, `labyrinth.md`, the cadence specs,
  `pace-prediction-roadmap.md`, `coach-collab-spec.md`, `archive/`.
- **whiteboard/** — discussions in flight; index in its README.
- **philosophy/** — tombstone only; the docs moved into the shared `framework/`
  (2026-06-09, TASK-034).

(The shared `framework/` lives at the repo root, not here — see Locations. Cross-
system contracts live in the shared `knowledge/reference/specs/`.)

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` is updated.
