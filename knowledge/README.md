# knowledge/

The source of truth for autonomous work on this project. Everything I need to keep working without supervision lives here.

## Layout

- **philosophy/** — Stable principles. The "why" and the "how we work." Read first, change rarely.
- **planning/** — The active plan: backlog, current focus, next steps. This is where work is chosen.
- **progress/** — A running log of what was done, what was verified, what broke. Append-only.
- **decisions/** — One file per non-trivial decision (an ADR). Captures *why* a path was chosen.
- **reference/** — Project facts: domain glossary, external APIs, fixed constraints. Things I look up.

## The loop

Every working session follows the same shape:

1. **Orient** — Read `planning/CURRENT.md` to find the next task. If empty, refill from `planning/BACKLOG.md`.
2. **Plan the task** — Write the acceptance criteria into `planning/CURRENT.md` before touching code.
3. **Branch** — `git checkout master && git pull --ff-only && git checkout -b <kind>/task-NNN-slug` (see `philosophy/pr-workflow.md` for naming).
4. **Execute** — Implement, committing as I go. Commits authored by the user only — no Claude credit.
5. **Verify** — Run the gates defined in `philosophy/verification.md`. Run local CI (tests + types + lint). If any fail, fix before moving on.
6. **PR** — `gh pr create` with the template in `pr-workflow.md`. Merge it (`gh pr merge --squash --delete-branch`).
7. **Log** — Append a one-paragraph entry to `progress/journal.md` with timestamp, PR number, merge sha, what was verified, and what's next.
8. **Advance** — Move task to `DONE.md`, sync `master`, pull the next task into `CURRENT.md`.

If I ever feel stuck or unsure, the answer is in `philosophy/when-stuck.md` — not in asking the user.

## Index of key documents

- `philosophy/principles.md` — Core values, what to prioritize.
- `philosophy/verification.md` — How to know a task is actually done.
- `philosophy/when-stuck.md` — Decision tree for ambiguity, errors, dead-ends.
- `philosophy/working-style.md` — Cadence, scope discipline, anti-patterns.
- `philosophy/pr-workflow.md` — Branching, commit conventions, PR open/merge flow, author identity.
- `planning/CURRENT.md` — Active task with acceptance criteria. One task at a time.
- `planning/BACKLOG.md` — Ordered list of upcoming work.
- `planning/DONE.md` — Completed tasks (moved here from CURRENT).
- `progress/journal.md` — Chronological log, append-only.
- `progress/blockers.md` — Things that genuinely require user input — surface at session end.
- `decisions/INDEX.md` — Pointers to ADRs.
- `reference/glossary.md` — Project-specific terms.
- `reference/project-brief.md` — What the project actually is (filled in once user describes it).
