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

_(none — calibration's two **core continuous rates** are now both data-driven:
**TASK-043** climb rate `vmh` (PR #80, `819e9dc`; confirmed on the user's real
data — 616 m/h) and **TASK-044** flat-trail pace (PR #82, `a76db2e`). Both via
the pure `Calibration` module + the `smoke:calibration` gate + the transparent
`#/profile` panel; ADRs 0006/0007.

**Checkpoint with the user before the remaining calibration fits** — they step
up in complexity / scope and several are data-gated, so they want a priority
call rather than autopilot:
- **Descent technique** — feasible from existing data (descent kms vs the
  flat×Tobler baseline → implied multiplier), but `descentSkill` is an *enum*,
  so calibration means snapping a fitted multiplier to the nearest level (new
  wrinkle vs. the continuous vmh/pace fits).
- **Fatigue slope / climb-fatigue `k`** — need time-binning + a curve fit over
  long runs (`pace(t)`, `vmh(t)`); more involved than the realized-rate fits.
- **Riegel `k`, sustainable-HR-by-duration, decoupling** — *new predictor
  capabilities* (no profile field today) and data-gated (multiple race
  distances / HR streams across durations).

Also still queued: parking-lot items (section-card **Δ-vs-plan** fix — unblocked
by TASK-039; light/dark; multi-language). Two manual checks remain recommended
(headless env can't do them): browser round-trip after the TASK-040 IDB
migration; print-preview of the TASK-042 table.)_
