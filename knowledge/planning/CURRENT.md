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
**Coach-collab arc — updated 2026-06-16:** the companion spec
(`reference/merge-ui-identity-spec.md`) was ingested into the backlog, adding
three tasks beyond TASK-052 — which the user then **dropped, folding it into
TASK-056** (the merge UI ships last). Remaining work in the arc:

- **TASK-054 — WI-5: identity & authorship** *(foundation; next)*. Gated on
  Q-I1–Q-I3 + an ADR (promote spec §1.2 / §2.2). A person-level `userId`
  layered over the existing device-level `deviceId` (same person on two devices =
  one `userId`); see the spec's Reality corrections.
- **TASK-055 — Home view: personal/other + filter by person** *(falls out of
  WI-5; deps TASK-054)*.
- **TASK-056 — WI-3 part 2: merge integration + review UI** *(WI-3's whole last
  mile — absorbs the dropped TASK-052; ships LAST)*. Gated on Q-U1–Q-U5; deps
  TASK-050 (done) + TASK-054. Design ref: `reference/merge-review-prototype.html`.

Build order (user, 2026-06-16): **TASK-054 → TASK-055 → TASK-056 (last)**.
Verification of 056 is largely manual (browser); the review-then-merge flow used
for TASK-051 worked well. Resume on the user's go-ahead — resolve the gating
questions (and the WI-5 ADR) first.

Done so far: TASK-046 ✓ · 047 (WI-1) ✓ · 048 (WI-2) ✓ · 049 (fork-safe ids) ✓ ·
050 (WI-3 engine) ✓ · 051 (WI-4 feed) ✓ · 053 (identity backfill) ✓.

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
