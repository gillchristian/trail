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
- [0006 — Calibrate climb rate (`vmh`) from linked runs: gain-weighted, transparent](0006-calibration-vmh.md)
- [0007 — Calibrate flat-trail pace from runnable kms](0007-calibration-flat-pace.md)
- [0008 — Section plan time is clock time (moving + midpoint-attributed aid rest)](0008-section-clock-time.md)
- [0009 — `.trail` file sync for coach collaboration: three-way merge, frozen course](0009-trail-file-sync.md)
- [0010 — Course identity for `.trail` sharing: stable shareId + canonical course hash, hard-block on mismatch](0010-course-identity-and-guard.md)
- [0011 — Three-way merge engine for coach collaboration (WI-3)](0011-three-way-merge-engine.md)
- [0012 — Identity & authorship: person-level userId over device id (WI-5)](0012-identity-and-authorship.md)
- [0013 — Merge-review UI: review suggestions, person-named, no red/green (WI-3 · UI)](0013-merge-review-ui.md)
