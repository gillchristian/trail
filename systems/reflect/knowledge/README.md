# systems/reflect/knowledge/ — reflect system manifest (STUB)

**reflect** is the **Reflect** system (Plan → Execute → Reflect): post-hoc analysis/learning from
executed runs. **Scope not yet defined** — this is a **v3 stub instance** (knowledge only). **Read the
repo-root manifest first** (`/knowledge/README.md`) for the repo-wide rules this system inherits.

Reading chain: root `CLAUDE.md` → root manifest → **this file** → `knowledge/framework/` (the shared
copy at the repo root) → the `pr` profile in `framework/delivery.md`.

## Delivery

Inherits the repo-wide ceiling from the root manifest (**pr**; squash-only; `master` sacred;
user-only attribution). Does not narrow it.

- **Branch prefix:** `reflect/` · **Task-id namespace:** `REFLECT-`, starting at `REFLECT-001`.

## Locations

framework:  knowledge/framework
planning:   systems/reflect/knowledge/planning
progress:   systems/reflect/knowledge/progress
decisions:  systems/reflect/knowledge/decisions
reference:  systems/reflect/knowledge/reference
whiteboard: systems/reflect/knowledge/whiteboard

(`framework` is the shared copy at the repo root; the rest are reflect's. Paths repo-root-relative.)

## The loop, instantiated for reflect

The standard framework loop (see `framework/README.md`) — **once scope is defined.** Until then,
there is no backlog (see the brief's Unknowns + the open scope blocker). Stuck? `framework/when-stuck.md`.

## Status: STUB — scope undefined (knowledge only)

No code, **no backlog** (deliberately — scope gates everything). The brief records what's known + an
explicit Unknowns list; `progress/blockers.md` holds the open scope blocker. When the user defines
scope: resolve the blocker, then seed the first `BACKLOG.md` item and proceed normally.

## Layout (reflect instance)

- **planning/** — `CURRENT.md`, `BACKLOG.md`, `DONE.md` (empty — scope-gated).
- **progress/** — `journal.md` (append-only), `blockers.md` (the open scope blocker).
- **decisions/** — ADRs + `INDEX.md` (none yet).
- **reference/** — `project-brief.md` (what's known + Unknowns).
- **whiteboard/** — discussions in flight; index in its README.

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` is updated.
