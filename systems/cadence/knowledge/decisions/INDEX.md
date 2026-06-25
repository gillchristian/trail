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

- [0001](0001-tokens-sessions-split.md) — Split `tokens` into `tokens` + `sessions` (TASK-001, PR #2).
- [0002](0002-in-memory-oauth-state-store.md) — In-memory OAuth state store with active sweep (TASK-003, PR #4).
- [0003](0003-oauth-state-before-strava-exchange.md) — Validate OAuth state before exchanging the Strava code (TASK-003, PR #4).
- [0004](0004-athlete-cache-sentinel-key.md) — Athlete cache reuses `activity_cache` via a sentinel key (TASK-005, PR #6).
