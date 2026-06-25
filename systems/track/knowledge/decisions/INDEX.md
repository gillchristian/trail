# Decisions (ADRs)

One file per non-trivial decision: `NNNN-short-title.md`.

## Template

```markdown
# NNNN — <decision title>
**Date:** YYYY-MM-DD · **Status:** proposed | accepted | superseded by NNNN
## Context — the situation and forces, 2–4 sentences.
## Decision — what was decided, specifically.
## Alternatives considered — bullets, each with why not.
## Consequences — what this makes easy/hard; what to revisit.
```

## What deserves an ADR

Language/framework/major-library picks; choosing between viable architectures; the `.trace` schema;
interpreting an ambiguous requirement; anything a teammate should understand later without asking.

## Index

- [0001](0001-ios-project-tooling-and-deployment-target.md) — iOS project tooling (standard Xcode project) & deployment target (iOS 17.0). *accepted, 2026-06-25 · TRACK-000.*
