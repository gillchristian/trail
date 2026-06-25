# knowledge/ — project manifest (trail)

The working system lives in [`framework/`](framework/README.md); this file is
what makes it THIS project. Reading order: this file → `framework/README.md`
→ the `pr` profile in `framework/delivery.md`.

## Delivery mode

delivery: pr (merge: squash; self-merge: yes; close-pr: yes)

**Operative meaning:** I own the full branch → PR → squash-merge cycle and
merge my own PRs (`framework/delivery.md`, profile `pr`). `master` is sacred:
after the initial `Batman` root commit, nothing lands on it directly — not
even bookkeeping (that's what the close PR is for).

## Locations

The role → path map the framework dereferences (framework v3 / MONO-000). The
framework refers to instance areas by role ("the planning area", "the
journal"); this block says where they live. Paths are repo-root-relative.
These are trail's **current, pre-monorepo-move** paths — MONO-001 will update
them when trail's instance areas move under `systems/trail/`; `framework` will
stay at the repo root as the monorepo's single shared copy.

framework:  knowledge/framework
planning:   knowledge/planning
progress:   knowledge/progress
decisions:  knowledge/decisions
reference:  knowledge/reference
whiteboard: knowledge/whiteboard

## Project rules

- **Identity/attribution:** commits and PRs are authored by the user only
  (`gillchristian`). No `Co-Authored-By: Claude ...` trailers, no "Generated
  with Claude Code" footers. The git config is already correct — just don't
  add attribution.
- **Squash-only.** A hard constraint from the brief; `--merge` is not an option.
- **Root commit:** the initial `Batman` commit (subject "Batman", no parents)
  is the only direct commit to `master`, ever.
- **Framework copy:** v3 — and this repo is the **canonical upstream**
  (`gillchristian/trail` → `knowledge/framework/`). v3 adds path indirection
  (MONO-000): the framework names instance areas by role and resolves them
  through the **Locations** block above, so the one shared copy can serve the
  monorepo's per-system instances. Framework files stay instance-free: before
  merging any framework-touching PR, run
  `grep -riE '\btrail\b|\belm\b|batman|gillchristian|coros|samples/' knowledge/framework/`
  — it must return nothing (`context7` may appear only inside an "e.g." clause;
  word boundaries keep English words like "trailing" out of the net).
  Project specifics belong here in the manifest, not in `framework/`.

## The loop, instantiated for trail

1. **Orient** — read `planning/CURRENT.md`; if empty, promote the top
   unchecked item of `planning/BACKLOG.md`.
2. **Plan** — acceptance criteria into `CURRENT.md` before touching code.
3. **Branch** — `git checkout master && git pull --ff-only && git checkout -b <kind>/task-NNN-<slug>`.
4. **Execute** — implement, committing as I go (conventions in `framework/delivery.md`).
5. **Verify** — gates in `framework/verification.md`; local CI commands in
   `reference/local-ci.md` (type-check, build, the smoke harnesses).
6. **PR** — `gh pr create` (template in `delivery.md`), then
   `gh pr merge --squash --delete-branch`.
7. **Log** — journal entry with PR number, merge sha, and quoted verification output.
8. **Advance** — close PR (branch `docs/task-NNN-close`): move the task to
   `DONE.md`, append the journal entry, optionally pull the next task into
   `CURRENT.md`; sync `master`.

If I ever feel stuck or unsure, the answer is in `framework/when-stuck.md` —
not in asking the user.

## Layout

- **framework/** — the reusable working system (this repo is the upstream copy).
- **planning/** — `CURRENT.md` (one active task), `BACKLOG.md` (ordered queue;
  conventions in its header), `DONE.md` (archive).
- **progress/** — `journal.md` (append-only log), `blockers.md` (things that
  need the user — surface at session end).
- **decisions/** — ADRs + `INDEX.md` (template + criteria live there).
- **reference/** — `project-brief.md` (product intent — wins conflicts),
  `glossary.md`, `local-ci.md`, `labyrinth.md` (the article behind the
  record-the-maze principle), the cadence specs, `pace-prediction-roadmap.md`,
  `coach-collab-spec.md`, `archive/`.
- **whiteboard/** — discussions in flight; conventions + index in its README.
- **philosophy/** — tombstone only; the docs moved into `framework/`
  (2026-06-09, TASK-034).

If the brief and `CURRENT.md` disagree, the brief wins and `CURRENT.md` gets
updated.
