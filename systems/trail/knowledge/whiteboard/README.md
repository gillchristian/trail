# whiteboard/

The thinking-out-loud area. Where ideas live before they earn a decision.

## What goes here

In-progress discussions where I (Claude) and the user have explored a topic
but not committed to action. A whiteboard entry captures:

- The question or proposal.
- The options considered.
- The tradeoffs that came up.
- Where the conversation landed (often: "we're not building this yet, but
  here's why we paused, and here's what would change our mind").

The whiteboard is not a backlog. Entries here are not "things to do." They
are records of *what we considered* so future-me doesn't reopen the same
discussion from scratch.

## How it differs from the other areas

| Area | Purpose | Stability |
|---|---|---|
| `reference/project-brief.md` | What we're building | Stable, rarely changes |
| `decisions/` (ADRs) | Decisions made, with rationale | Permanent record; content stays, status may flip to superseded |
| `planning/BACKLOG.md` | Decided work, ordered | Active queue |
| `whiteboard/` | Discussions in flight | Ephemeral; entries may be promoted, archived, or left as-is |

If an entry here gets decided, the path forward is one of:

1. **Promote to an ADR.** A real decision was made; capture the *why* in
   `decisions/NNNN-slug.md` and link the whiteboard entry from the ADR's
   "alternatives considered" section.
2. **Promote to a backlog task.** The decision was to do something; the task
   goes into `planning/BACKLOG.md`.
3. **Update the project brief.** The decision changes what we're building.
4. **Leave it as-is.** "We thought about this and chose not to act" is a
   useful record on its own. The entry's resolution section says so.

## Lifecycle of a whiteboard entry

1. Create `whiteboard/<topic-slug>.md` with the structure below.
2. Append to it as the conversation continues.
3. When the topic is resolved (or explicitly tabled), update the
   **Resolution** section at the bottom.
4. If the resolution produces work or an ADR, link out from the entry; do
   not delete the entry — the trail of thinking is the value (the idea behind
   this whole area: `../reference/labyrinth.md`).

## Entry structure

Loose but consistent:

```markdown
# <Topic>

> Status: open / resolved / tabled — <one-line summary>

## Context

What prompted the discussion. Link to the journal entry or PR if relevant.

## Options considered

The proposals. Bullet or section per option, with the case for and against.

## Where we landed

The current state. If resolved, what was decided and why. If tabled, what
would re-open the discussion.

## Follow-ups

Links to ADRs, backlog tasks, or further whiteboard entries that grew out
of this one.
```

Keep entries terse but specific. The reader is future-me, who has zero
context and limited patience.

## Index of current entries

- [Profile management](profile-management.md) — how to associate athlete
  profiles with race plans without breaking historical records.
- [Training-mode vs. planner](training-as-analysis.md) — should the app
  ingest training runs for analysis, or stay strictly a race-planning tool?
- [CSV aid-station import](csv-aid-station-import.md) — bulk-import aid
  stations from a CSV file / pasted table; format, merge semantics, preview.
