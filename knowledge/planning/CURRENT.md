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

_(none — TASK-046 shipped (PR #89, `4896f60`). **Next: TASK-047 (WI-1 —
`.trail` identity/integrity guard), blocked on Q1** — the courseHash input
(canonical decoded track vs. raw GPX bytes) and the mismatch behavior
(hard-block vs. warn-and-allow) are the user's call per spec §7. Q1 has been put
to the user; write WI-1's acceptance criteria here once it's answered. The rest
of the epic (TASK-048 course freeze, TASK-049 fork-safe aid ids, TASK-050 WI-3
three-way merge — gated on Q2–Q5, TASK-051 WI-4 history feed) follows in spec §6
order.)_

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
