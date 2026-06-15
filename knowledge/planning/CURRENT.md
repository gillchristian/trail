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

### TASK-046 — Brief nuance: file-based collaboration is in scope (Layer 0)

**Source:** BACKLOG (coach-collaboration epic, spec §0) / user request
**Branch:** docs/task-046-brief-collab-scope
**Acceptance criteria:**
- [ ] `reference/project-brief.md` *Out of scope* is nuanced (not deleted) the
  same way "No backend, ever" was softened for Strava: async, file-based,
  single-document collaboration (export → annotate → merge) is in scope as a
  Layer-0 feature; server-side multi-user, accounts, hosted documents stay out.
  (Verify by reading the two affected lines + the new nuance.)
- [ ] The nuance points at ADR-0009 so the reasoning is one hop away.
- [ ] Docs-only — no `src/` touched (verify `git diff --name-only`).
**Notes:** First task of the coach-collab epic; no open questions (the decision
is settled in ADR-0009/spec §0). The two lines to nuance are "No social /
sharing features" and "No multi-user" in the *Out of scope* section.

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
