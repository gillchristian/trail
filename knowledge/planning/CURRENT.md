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

### TASK-041 — Fix the `Planning.elm` `slopeFactor` docstring

**Source:** BACKLOG parking lot, promoted 2026-06-15 (batch task 3 of 5; TASK-039
PR #72 `633e263`, TASK-040 PR #74 `a922894` shipped).
**Branch:** `fix/task-041-slopefactor-comment`

**Problem.** The `slopeFactor` docstring (`Planning.elm`, ~lines 318-324) repeats
the un-normalized values TASK-038 already corrected in ADR-0003: it says
"10 % uphill ≈ 1.69×; 20 % grade either way ≈ 2.40×". The actual normalized
`slopeFactor s = e ^ (3.5 * |s + 0.05| − 0.175)` gives (recomputed via node):
f(0)=1.000, f(−0.05)=0.839 (min), f(+0.10)=**1.419** (not 1.69), f(−0.10)=1.000,
f(+0.20)=**2.014**, f(−0.20)=**1.419**. The curve is symmetric about **s = −0.05**,
not "either way" about 0. This was deliberately held out of docs-only TASK-038
because it touches `src/` (the journal for TASK-038 queued it).

**Approach.** Comment-only edit to the docstring. Keep the correct parts (`f(0)=1.0`,
"peaks downward at s = −0.05"). Replace the wrong magnitudes/symmetry with the
recomputed values, matching ADR-0003's corrected table. No behavior change.

**Acceptance criteria:**
- [ ] Docstring states f(+0.10) ≈ 1.42 (not 1.69×), and the curve is symmetric
  about s = −0.05 — e.g. f(−0.20) ≈ 1.42 vs f(+0.20) ≈ 2.01 — instead of
  "20 % either way ≈ 2.40×".
- [ ] `f(0) = 1.0` and the s = −0.05 minimum framing kept (already correct).
- [ ] Values agree with ADR-0003 and a fresh recomputation.
- [ ] All five local-CI gates green (comment-only — no behavior change; the
  `slopeFactor` body and the `smoke:sections`/`smoke:aidcsv` results are
  unchanged).

**Notes.** `src`-touching but trivial. Also re-grep for any *other* stale
"1.69"/"2.40"/"either way" copies in `src/` while here, but don't expand scope
beyond the slope-factor comment.
