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

_(none — the five-task batch the user promoted on 2026-06-15 is complete:
**TASK-039** section-overlap fix (PR #72, `633e263`), **TASK-040** gpxText IDB-row
split (PR #74, `a922894`), **TASK-041** slopeFactor docstring (PR #76, `c580bdf`),
**TASK-042** print-friendly plan table (PR #78, `c2d30b4`), and **TASK-043** —
the first calibration fit, vmh from linked runs (PR #80, `819e9dc`), the first
slice of the TASK-022 calibration epic. Each shipped via its own PR + close PR;
ADRs 0004/0005/0006 added; three new local-CI gates (`smoke:sections`,
`smoke:calibration`, and the expanded `smoke` for the v3 storage migration).

Next session — pick from `BACKLOG.md`, all needing nothing more than selection:
- **TASK-044** — flat-trail-pace calibration (same data path as TASK-043) —
  queued; the user asked for calibration go-aheads per fit.
- The further calibration fits in roadmap §7 (climb-fatigue `k`, Riegel,
  sustainable-HR-by-duration, descent technique, decoupling) — several gated on
  more data; promote with user appetite.
- Parking-lot items: the section-card **Δ-vs-plan** moving-vs-clock fix (now
  unblocked by TASK-039's partition), light/dark toggle, multi-language UI, etc.

Two manual checks recommended (the headless env can't do them): a browser
round-trip after the **TASK-040** IDB migration, and a print-preview of the
**TASK-042** plan table.)_
