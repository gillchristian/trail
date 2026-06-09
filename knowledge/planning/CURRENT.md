# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Entry template

```markdown
### TASK-NNN — <title>

**Source:** BACKLOG / parking lot / user request
**Branch:** <kind>/task-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, anything decided while planning.
```

## Active

### TASK-035 — Labyrinth principle: record the maze, not just the exit

**Source:** user request (2026-06-09) — Alvaro Videla's "Notes on the synthesis of labyrinths" is part of what defines the philosophy; include the idea (not the article) in the framework.
**Branch:** `docs/task-035-labyrinth-principle`
**Acceptance criteria:**
- [x] `framework/principles.md` gains the principle (record dead ends + reasoning at forks, not just the solution; prescription *and* description), cited to the author/title — not inlined. Renumbering stays consistent; nothing in the repo cites principle numbers (verified before edit).
- [x] `framework/working-style.md` "Communication style in artifacts" gains one reinforcing bullet tying journal/ADR/whiteboard records to the principle.
- [x] The article lives at `knowledge/reference/labyrinth.md` (instance side; framework cites the published work by name only — instance-free guard still passes).
- [x] Framework version bumped (v1 → v2) in `framework/README.md` and the manifest's "Framework copy" rule, per the framework's own upstream-change convention.
- [x] Local CI green.
**Notes:** The framework already practices the idea (journal failures, ADR alternatives, whiteboard records); this names the value those rules share so future sessions inherit the *why*, not just the rules.
