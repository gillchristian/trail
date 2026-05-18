# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### chore — knowledge whiteboard area + queue follow-up tasks

Capture the pattern that emerged during the 2026-05-18 brainstorm: we need a
home for in-flight discussions that aren't yet ADRs, backlog items, or brief
edits. Record the two open discussions (profile management, training-mode
vs. planner). Queue the four tasks that came out of the brainstorm.

**Acceptance criteria:**

- [ ] `knowledge/whiteboard/` exists with a `README.md` that explains its
      purpose, how it differs from ADRs and backlog, and the lifecycle of an
      entry.
- [ ] `knowledge/whiteboard/profile-management.md` records the discussion:
      claude's "race-archetype presets" proposal, user's pushback (snapshot
      profiles into races; soft link only; longitudinal tracking benefit),
      where we landed (no action yet — keep thinking).
- [ ] `knowledge/whiteboard/training-as-analysis.md` records the discussion:
      training mode vs. planning north star, user agreement, decision to do
      *only* HR-on-linked-actuals for now, defer everything else.
- [ ] `knowledge/README.md` lists `whiteboard/` in the Layout section.
- [ ] `knowledge/planning/BACKLOG.md` has TASK-025..028 in the Active list,
      ordered as: pace bug → HR display → skeleton loading → home split.
- [ ] Build still passes (`npm run build`) — doc-only PR, but verify.
- [ ] Journal entry appended.
- [ ] PR opened and merged.
