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

### TASK-038 — Fix technical-accuracy drift in ADRs + local-CI + MORNING docs

**Source:** BACKLOG (2026-06-10 doc-vs-code audit) — user go-ahead 2026-06-10 to
clear all three audit doc-fix tasks (036/037/038). TASK-036 closed (PR #65,
`7b8455f`), TASK-037 closed (PR #67, `73b206f`). Last of the three.
**Branch:** `docs/task-038-adr-ci-morning-accuracy`
**Acceptance criteria:**
- [x] **ADR-0003 slope-factor table.** Replaced the un-normalized values with
  the normalized `slopeFactor s = e^(3.5·|s+0.05| − 0.175)` (`src/Planning.elm:327`):
  f(0)=1.000, f(−0.05)=0.839 (min), f(+0.10)=1.419 (not 1.687), f(−0.10)=1.000,
  f(+0.20)=2.014, f(−0.20)=1.419; stated the curve is **symmetric about s=−0.05**,
  not 0 (computed via node to confirm the values).
- [x] **ADR-0003 interactions table.** "Reset plan (all kms → Auto)" removed —
  only per-km `ResetKmToAuto` exists (`Main.elm:860`, "Reset to auto (GAP)"),
  folded into the existing per-km row to avoid a duplicate. All-Manual "target
  becomes derived" corrected to "committed target is **kept**"
  (`effectiveTargetSeconds`, `Main.elm:6511`).
- [x] **ADR-0003 consequences.** Slope divisor noted as the **window length**
  (last km partial), not a fixed 1000 m; added the auto-km independent-rounding
  drift caveat.
- [x] **ADR-0002 (bullets + example).** `sym` documented as auto-derived from
  services (`symbolForAid`, `GpxExport.elm:112`), no UI picker, no-services
  default **Flag, Blue**; `<desc>` example fixed to `Km 22.6 · Water, Food ·
  Rest 5:00` (`buildDesc`); removed the nonexistent "Aid 1/Aid 2" fallback (name
  emitted verbatim).
- [x] **cadence-backend-spec.md.** Streams example now shows the `{"data":[…]}`
  per-key nesting (`StravaStreams.elm` `streamData`); env var corrected to
  `VITE_BACKEND_URL` (`main.js:16`).
- [x] **addendum-1.** "fields flow through to trail's settings" corrected (no
  `/api/athlete` client — reframed to "when TASK-022 builds one"); "§14.2"
  citation repointed to `archive/trail_race_planner_spec.md` §14.2.
- [x] **local-ci.md.** Added a Prerequisites section (global Elm 0.19.1 + Node
  v22); qualified the storage-smoke row to the v1 `races` store only.
- [x] **MORNING.md.** Added a frozen-2026-05-15 historical banner; dev port
  5174; parking lot described as mid-`BACKLOG.md`; refreshed the stale
  nvm-22/storage-smoke caveat (`.nvmrc` v22 + `smoke:aidcsv`).
- [x] Local CI green (4 gates: elm make "Success!", build "✓ built in 975ms",
  smoke "SMOKE PASSED", smoke:aidcsv "PASS"). `src/` untouched — the identical
  un-normalized error in the `Planning.elm:323` *code comment* is logged as a
  parking-lot follow-up (added in the close PR), not fixed here.
**Notes:** Docs-only; all claims code-verified this session. The `Planning.elm`
code comment ("10 % uphill ≈ 1.69×") has the identical un-normalized error;
left for a separate code-touching change (added to the parking lot).
