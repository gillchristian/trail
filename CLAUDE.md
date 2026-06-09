# CLAUDE.md — trail

**Read these, in order, before doing anything else:** `knowledge/README.md`
(the project manifest: delivery mode + project rules), `knowledge/framework/README.md`
(the working system), then the `pr` profile in `knowledge/framework/delivery.md`.
The summary below is just the headline rules so you can't accidentally violate
them while still loading the rest.

## Non-negotiables

1. **One task at a time.** Pull from `knowledge/planning/CURRENT.md`. If empty, promote the top unchecked item of `knowledge/planning/BACKLOG.md`. Write acceptance criteria before touching code.
2. **Delivery: pr.** Work on branches, ship via PRs you merge yourself, squash-only. `master` is sacred — the only direct commit to it is the initial `Batman` commit. Full profile in `knowledge/framework/delivery.md`.
3. **Commits and PRs are authored by the user only.** No `Co-Authored-By: Claude ...` trailer in commits. No "🤖 Generated with Claude Code" footer in PR bodies. The git config is already correct — just don't add Claude attribution.
4. **Verify before declaring done.** Hard gates in `knowledge/framework/verification.md`. Run the program, quote actual output, don't confuse "compiles" with "works."
5. **Journal everything.** Append to `knowledge/progress/journal.md` after every task. Future-you has no memory of this session.
6. **When stuck, follow `knowledge/framework/when-stuck.md`.** Do not ask the user; do not invent answers; do log to `knowledge/progress/blockers.md` when a real blocker exists, then pivot.

## Quick map

- `knowledge/README.md` — the manifest: delivery mode, project rules, the loop instantiated for trail.
- `knowledge/framework/` — the reusable working system: principles, verification gates, when-stuck playbook, working style, delivery profiles. This repo is its upstream copy — keep it instance-free.
- `knowledge/planning/` — `CURRENT.md` (one active task), `BACKLOG.md` (queue), `DONE.md` (archive).
- `knowledge/progress/` — `journal.md` (append-only log), `blockers.md` (things needing the user).
- `knowledge/decisions/` — ADRs.
- `knowledge/reference/` — `project-brief.md` (what we're building), `glossary.md`, `local-ci.md`.
- `knowledge/whiteboard/` — open discussions that haven't earned an ADR or a backlog task yet; index in its README.

## Project status pointer

The current state of work lives in `knowledge/planning/CURRENT.md`. The product intent lives in `knowledge/reference/project-brief.md`. If those disagree, the brief wins and `CURRENT.md` must be updated.
