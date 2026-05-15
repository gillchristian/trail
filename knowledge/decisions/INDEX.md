# Decisions (ADRs)

One file per non-trivial decision. Format: `NNNN-short-title.md` (e.g. `0001-sessions-table-split.md`).

## Template

```markdown
# NNNN — <decision title>

**Date:** YYYY-MM-DD
**Status:** proposed | accepted | superseded by NNNN

## Context
What is the situation? What forces are at play? (2–4 sentences.)

## Decision
What did I decide? Be specific.

## Alternatives considered
Bullet list. For each: why I didn't pick it.

## Consequences
What does this make easy? What does this make hard? What will I have to revisit later?
```

## What deserves an ADR

- A schema migration that changes the meaning of an existing table.
- A choice between two viable architectures (e.g. "in-memory nonce store vs. DB-backed").
- Interpreting an ambiguous requirement in the upstream trail spec in a particular way.
- A trade-off (caching, rate-limiting, error-handling policy) that future-me would re-litigate without context.
- Anything I'd want a teammate to be able to *understand later without asking me*.

## What does NOT need an ADR

- Routine implementation choices that follow naturally from the spec.
- Renames, refactors, file moves.
- Bug fixes (the commit message + journal entry is enough).

## Index

_(none yet — first ADR will likely come from TASK-001's interpretation choices: e.g. whether to keep the old `tokens` table around for a deprecation window or drop it immediately.)_
