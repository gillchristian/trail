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

_(none — TASK-051 (WI-4 feed) shipped + user-verified (PR #102, `ddf7076`).
**The coach-collaboration arc has one piece left: TASK-052 (WI-3 part 2 — merge
integration + review UI)** — persist `mergeBase`+`version`, `.trail` carries
`{base,current,version}`, version-bump on edit, the import→merge entry point, the
dedicated review screen (Q5), and appending `Merged` change-sets to the WI-4
feed. Q2–Q5 already resolved (ADR-0011); the pure merge engine (TASK-050) is
done + smoke-tested. Verification is largely manual (browser) — same review-then-
merge flow as TASK-051 worked well; resume on the user's go-ahead.

Coach-collab epic: TASK-046 ✓ · 047 (WI-1) ✓ · 048 (WI-2) ✓ · 049 (fork-safe ids)
✓ · 050 (WI-3 engine) ✓ · 051 (WI-4 feed) ✓ · 053 (identity backfill) ✓ — only
**TASK-052** (WI-3 merge UI) remains.

**Recommended in-browser checks** (headless env can't do them):
- **Standing (pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview;
  TASK-045 section table/card with a linked actual.)_

---

## Standing reminders (not active tasks)

- **Calibration is paused (user, 2026-06-15).** The two core continuous rates
  shipped (TASK-043 vmh, TASK-044 flat pace); the harder roadmap §7 fits
  (descent / fatigue / Riegel / sustainable-HR / decoupling) stay queued —
  promote only on a fresh go-ahead.
- **Three manual checks recommended** (headless env can't do them): browser
  round-trip after the TASK-040 IDB migration; print-preview of the TASK-042
  table; section table/card with a **linked actual** for TASK-045 (clock Time,
  Actual − Time = Δ, monotonic Cum ending at total clock).
- **After TASK-046:** the epic continues with TASK-047 (WI-1), where **Q1**
  (courseHash input + mismatch behavior) must be resolved with the user first.
