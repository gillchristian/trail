# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none — TASK-006 shipping in this PR; see DONE.md + journal entry 2026-05-15 19:30. Promote from `BACKLOG.md` when new work arrives.)_

## Template for a task entry

```
## TASK-NNN: <short title>

**Pulled from backlog:** YYYY-MM-DD HH:MM
**Why this now:** <one sentence>
**Spec reference:** `/Users/bb8/dev/trail/knowledge/reference/cadence-backend-spec.md` §X.Y (if applicable)

### Acceptance criteria
- [ ] Criterion 1 (observable, testable)
- [ ] Criterion 2
- [ ] Existing cadence frontend still works (specify the flow exercised)
- [ ] ...

### Plan
1. Step 1
2. Step 2
3. ...

### Verification plan
- How I will demonstrate each acceptance criterion is met.
- Specific commands I will run (curl invocations, sqlite queries, browser smoke).

### Notes during execution
<append as I go — surprises, side discoveries, decisions made>

### Done
<filled in when all gates pass; quote final verification output here>
```
