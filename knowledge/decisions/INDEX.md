# Decisions (ADRs)

One file per non-trivial decision. Format: `NNNN-short-title.md` (e.g. `0001-language-choice.md`).

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

- Picking a language, framework, or major library.
- Choosing between two viable architectures.
- Interpreting an ambiguous requirement in a particular way.
- Anything I'd want a teammate to be able to *understand later without asking me*.

## Index

- [0001 — Stack: Elm 0.19 + Tailwind v4 + Vite](0001-stack.md)
- [0002 — Aid-station GPX format for Coros Pace Strategy](0002-coros-aid-station-format.md) *(assumption — field-test required)*
- [0003 — Grade-adjusted pace distribution (Tobler-based)](0003-pace-distribution.md)
- [0004 — Section km-attribution: midpoint partition, not pro-rating](0004-section-km-attribution.md)
- [0005 — Store GPX text in its own IndexedDB row](0005-gpx-own-idb-row.md)
