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

### TASK-033 — Knowledge-base tidy (review findings)

**Source:** user request (2026-06-09) — "review the knowledge base, tidy things up, make sure the framework is sound." Findings from a 4-dimension review (cross-references, consistency, staleness, soundness), each adversarially verified.
**Branch:** `docs/task-033-knowledge-tidy`
**Acceptance criteria:**
- [ ] `reference/local-ci.md` exists, lists the real gate commands, and every command in it was actually run with output quoted in the journal. `pr-workflow.md`, `verification.md`, and `README.md` point to it instead of the dangling "once defined" reference; the phantom "lint" step is gone from the CI phrasing.
- [ ] Squash-merge rule is consistent across `project-brief.md` (hard constraint), `README.md` (loop step 6), and `pr-workflow.md` (no more `--merge` escape hatch).
- [ ] Post-merge bookkeeping convention (`docs/task-NNN-close` PR) is codified in `pr-workflow.md`.
- [ ] Placeholders backfilled with verified values: DONE.md `<sha>` → `8449767`, "PR #N" → "PR #18, merged `b451e1e`"; journal 2026-05-18 cleanup entry `<sha>` → `8449767`. Duplicate TASK-008/009/010 stub line removed from DONE.md.
- [ ] DONE.md's stated entry format matches actual practice (entries are paragraph summaries with PR + merge sha).
- [ ] `CLAUDE.md` Quick map includes `knowledge/whiteboard/`.
- [ ] `CURRENT.md` has a task-entry template; `BACKLOG.md` header documents the checked-in-place convention and TASK-id allocation; journal template clarifies the HH:MM rule.
- [ ] `reference/glossary.md` populated with the established domain vocabulary (terms with surprising semantics first: cutoff, Target vs Pace, section, Executions).
- [ ] Stale pre-resolution follow-up bullets in `whiteboard/csv-aid-station-import.md` rewritten as past-tense notes.
- [ ] `whiteboard/README.md` no longer calls ADRs "immutable" (status legitimately changes to superseded).
- [ ] Grep sweep shows no dangling file references in `knowledge/` or `CLAUDE.md`.
**Notes:** Tidy only — no restructuring. The framework/project split + extraction is the next task (TASK-034). Refuted findings deliberately not acted on: BACKLOG's checked-in-place Active list, whiteboard entries as point-in-time records, deleted bug-screenshot references — all confirmed as designed conventions; the tidy codifies the first one instead of "fixing" it.
