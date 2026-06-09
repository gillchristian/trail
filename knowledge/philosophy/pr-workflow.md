# PR workflow

How work flows from "task picked" to "merged into master."

## Rules

1. **`master` is sacred.** After the initial `Batman` commit, no direct pushes to `master`. Every change reaches `master` via a PR I open and merge myself.
2. **One PR = one logical unit of work.** A PR corresponds to something I'd be willing to call out in a changelog. Usually one task in `CURRENT.md`, occasionally a tight cluster of related tasks.
3. **Branch off latest `master`.** Always `git fetch` and rebase/branch from up-to-date `master` before starting.
4. **Iterate freely on the branch.** Commit early and often. Local CI (the commands in `reference/local-ci.md`) must pass before opening the PR.
5. **Merge my own PRs.** Solo repo — once local CI is green and the PR description is complete, merge it. Always `--squash`: the brief lists the branch → PR → squash-merge cycle as a hard constraint.

## Author identity

**Commits and PRs are authored by the user only.** No `Co-Authored-By: Claude ...` trailer. No "Generated with Claude Code" footer in PR bodies. The git config on this machine is already correct (`gillchristian / gillchristiang@gmail.com`); I just need to *not* add Claude attribution.

## Branch naming

`<kind>/<task-id>-<slug>` where kind is one of: `feat`, `fix`, `chore`, `refactor`, `docs`, `test`.

Examples: `feat/task-007-user-auth`, `fix/task-012-trailing-slash-redirect`, `chore/task-003-ci-cache`.

## Commit conventions

- **Subject line** ≤ 72 chars, imperative mood ("add", "fix", "rename"), no trailing period.
- **Body** explains *why* if it's not obvious. Skip the body for trivial commits.
- One logical change per commit. If I'm fixing a bug *and* renaming a function, that's two commits.
- No `Co-Authored-By` trailers.
- No emojis unless the existing history uses them.

## The full cycle for one PR

1. **Pull the task** into `planning/CURRENT.md`. Write acceptance criteria.
2. **Branch:** `git checkout -b feat/task-NNN-slug`.
3. **Implement, committing as I go.** Each commit leaves the branch in a sane state.
4. **Run local CI:** the commands in `reference/local-ci.md` (type-check, build, smoke harnesses), plus a manual smoke test where applicable (the `verification.md` gates still apply).
5. **If CI fails, fix on the branch.** Don't open a red PR.
6. **Open the PR** with `gh pr create`:
   - Title: imperative, ≤ 72 chars, mirrors the task title.
   - Body: see template below. **No Claude-attribution footer.**
7. **Merge** with `gh pr merge --squash --delete-branch`.
8. **Sync local `master`:** `git checkout master && git pull --ff-only`.
9. **Close the task** with a small follow-up PR (see below).
10. **Pick the next task.**

## The close PR

Post-merge bookkeeping can't land on `master` directly (Rule 1 has no
exceptions), so it ships as its own tiny PR immediately after the task PR:

- Branch: `docs/task-NNN-close`. Title: `docs: close TASK-NNN (<short>, merged <sha>)`.
- Contents: move the task from `CURRENT.md` to `DONE.md` (with PR number +
  merge sha), tick it off in `BACKLOG.md`, append the journal entry quoting
  the PR URL and merge commit.
- This is the one PR class that carries no acceptance criteria of its own —
  it documents the task that just merged. Merge it the same way (squash).
- When the next task is already known, the close PR may also pull it into
  `CURRENT.md` — closing and orienting in one step.

## PR description template

```markdown
## What
One-paragraph summary of the change.

## Why
The motivation — typically pulled from the task in `CURRENT.md`/`DONE.md`.

## How
Bullets describing the approach, anything unusual, anything explicitly out of scope.

## Verification
- [ ] Acceptance criterion 1 (with how it was verified)
- [ ] Acceptance criterion 2
- ... command outputs or specific manual checks as evidence.

## Notes
Anything reviewers (future-me, the user) should know: follow-ups, known limitations, ADRs added.
```

(No "Generated with Claude Code" line. No 🤖.)

## When *not* to merge

I do not merge a PR if:
- Local CI is failing.
- A `verification.md` gate failed and was not addressed.
- I'm uncertain about behavior and would normally want a second pair of eyes — in that case, open the PR as draft, log the uncertainty in `blockers.md`, and pivot to another task. Better one held PR than a bad merge.

## Hotfix exception

If a PR I merged turns out to have broken `master` (a later task can't proceed because of it), the right move is a small `fix/...` PR that reverts or repairs — not a `--force`-push or direct commit to `master`. Same workflow, just fast.
