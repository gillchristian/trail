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
- [ ] **ADR-0003 slope-factor table (lines 26-28).** Replace the un-normalized
  values with the normalized `slopeFactor s = e^(3.5·|s+0.05| − 0.175)`
  (`src/Planning.elm:327`): f(0)=1.000, f(−0.05)=0.839 (min), f(+0.10)=1.419
  (not 1.687), f(−0.10)=1.000, f(+0.20)=2.014, f(−0.20)=1.419 — and state the
  curve is **symmetric about s=−0.05**, not 0 (so "±" framing is wrong).
- [ ] **ADR-0003 interactions table (lines 67-68).** "Reset plan (all kms →
  Auto)" doesn't exist — only per-km `ResetKmToAuto` (`Main.elm:860`, button
  "Reset to auto (GAP)"). All-Manual "target becomes derived (= sum)" is wrong —
  the committed target is **kept** (`effectiveTargetSeconds`, `Main.elm:6511`).
- [ ] **ADR-0003 consequences.** Note the slope divisor is the **window length**
  (last km is partial), not a fixed 1000 m (line 90); note auto-km independent
  rounding can drift the sum a few seconds vs target.
- [ ] **ADR-0002 (line 36 + example).** `sym` is auto-derived from services
  (`symbolForAid`, `GpxExport.elm:112`): Food→Restaurant, Water→Drinking Water,
  Medical→First Aid, else→**Flag, Blue** — there's no per-station UI picker and
  no-services default is Flag,Blue not Restaurant. `<desc>` real format is
  `Km 22.6 · Water, Food · Rest 5:00` (`buildDesc`) — fix the example. No
  "Aid 1/Aid 2" unnamed fallback exists in the exporter (uses `aid.name` as-is).
- [ ] **cadence-backend-spec.md.** Streams example (lines 154-157) must show the
  `{"data":[…]}` per-key nesting the backend returns + `StravaStreams.parse`
  decodes (`streamData` at `StravaStreams.elm:107`); env var is
  `VITE_BACKEND_URL` not `BACKEND_URL` (the §9 line; `main.js:16`).
- [ ] **addendum-1.** "fields flow through to trail's settings" (line 119) is
  false — trail has no `/api/athlete` client (StravaApi only does
  activities/streams/search); reframe as "when TASK-022 builds one." Fix the
  "§14.2" citation (line 16) to point at `archive/trail_race_planner_spec.md`
  §14.2 (the roadmap has no §14).
- [ ] **local-ci.md.** Document the global **Elm 0.19.1** prerequisite (not an
  npm dep; `smoke-aid-csv.mjs` uses `npx --no-install elm`, so `npm install`
  alone can't run gates 1/2/4). Qualify the storage-smoke row (covers the v1
  `races` store round-trip, not the v2 `settings` store / upgrade path).
- [ ] **MORNING.md.** Mark it a frozen 2026-05-15 historical snapshot; fix dev
  port 5174 not 5173 (line 45); parking lot is mid-`BACKLOG.md`, not "at the
  bottom" (line 90); refresh the stale "needs nvm 22 later / JS-storage-smoke
  only" caveat (line 92) — `.nvmrc` now pins v22 and `smoke:aidcsv` drives real
  compiled Elm.
- [ ] Local CI green (4 gates). Docs-only — **do not** touch `src/` (the same
  un-normalized value in the `Planning.elm:323` *code comment* is logged as a
  follow-up, not fixed here).
**Notes:** Docs-only; all claims code-verified this session. The `Planning.elm`
code comment ("10 % uphill ≈ 1.69×") has the identical un-normalized error;
left for a separate code-touching change (added to the parking lot).
