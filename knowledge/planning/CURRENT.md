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

### TASK-044 — Calibrate flat-trail-pace from runnable kms

**Source:** Second split of TASK-022 (calibration); user go-ahead to continue
2026-06-15 — after TASK-043 (vmh) shipped (PR #80) and the user confirmed it on
their real data (616 m/h fitted from 3 linked runs; they liked the transparency).
**Branch:** `feat/task-044-flat-pace-calibration`

**Goal.** Calibrate `flatTrailPaceSecPerKm` (the predictor's runnable-km input)
from linked runs — the sibling fit to TASK-043's vmh, same data path + the same
transparent opt-in panel.

**Approach.** Extend `Calibration.elm` with `fitFlatPace : List Run -> Maybe
FlatPaceFit`. A **runnable km** is one the predictor itself treats as runnable —
`abs slope < 0.04` (`Predictor.elm:98-105`) — with a positive recorded time and
distance. Realized pace = `Σ runnable seconds / Σ runnable distance (km)`
(distance-weighted; mirrors vmh's realized-rate method, no Tobler/intensity
back-out — ADR-0007). Add a second row to the existing calibrate panel on
`#/profile`: fitted pace (M:SS/km) + current + Apply (`CalibrateFlatPace` sets
`flatTrailPaceSecPerKm` + persists). The pace field is derived from the profile
(`formatMmss prof.flatTrailPaceSecPerKm`), so Apply reflects immediately.

**Acceptance criteria:**
- [ ] `Calibration.fitFlatPace` returns the distance-weighted realized pace over
  runnable kms (`abs slope < 0.04`) across linked runs, contributing counts, and
  `Nothing` for no runnable data.
- [ ] `smoke:calibration` extended for `fitFlatPace` (known-input pace, the
  slope-band cut, no/zero-time skip, no-data null) over the real compiled fn.
- [ ] The panel shows the flat-pace fit alongside vmh, each with its own Apply;
  the contributors line covers runs feeding either fit.
- [ ] Wiring verified headlessly (build, panel/Msg in bundle); UI click flagged
  for a manual check (the user already confirmed the vmh path on real data).
- [ ] ADR-0007 for the flat-pace fit (runnable = predictor band; raw realized
  pace; Tobler-normalization considered + deferred).
- [ ] All local-CI gates green.

**Notes.** Completes the two core predictor rates (climb + flat) from real data.
Further fits (climb-fatigue `k`, Riegel, sustainable-HR, descent, decoupling —
roadmap §7) stay queued/data-gated. The orient rides in the task PR (CURRENT was
empty post-batch; no prior close PR to carry it).
