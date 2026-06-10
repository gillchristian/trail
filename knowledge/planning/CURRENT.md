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

### TASK-036 — Sync ship-status across the planning + reference docs

**Source:** BACKLOG (queued by the 2026-06-10 doc-vs-code audit) — user
go-ahead 2026-06-10 to clear all three audit doc-fix tasks (036/037/038).
**Branch:** `docs/task-036-ship-status-sync`
**Acceptance criteria:**
- [x] `reference/pace-prediction-roadmap.md` status header (line 3) no longer
  reads "proposal — exploration only, nothing committed"; §0/§2 (+ §12) no longer
  frame the predictor + athlete model as proposed/distributor-only (`Predictor.predict`
  ships at `src/Predictor.elm:53`); the line-296 promise to update the brief
  "when TASK-024 lands" reflects that TASK-024 shipped (PR #25/#26) and the
  brief rewrite is now tracked (TASK-037).
- [x] `reference/cadence-backend-spec.md` status header (line 3) no longer
  reads "not yet greenlit"; §9 "what trail has to build" reflects that it is
  built (`StravaApi`/`StravaStreams`, TASK-024/024b).
- [x] `reference/cadence-backend-spec-addendum-1-profile-scope.md` lines 64/70
  no longer treat trail's TASK-024 as unshipped (the addendum's own
  cadence-side status stays pending — that scope change is genuinely unshipped).
- [x] `BACKLOG.md` Proposals: TASK-014..021 struck through + PR-annotated to
  match the TASK-023/024 convention; only TASK-022 (calibration) left open.
- [x] `whiteboard/training-as-analysis.md:91` no longer frames TASK-026 (HR on
  actuals) as "Queued" — it shipped (PR #35).
- [x] Local CI green (4 gates: elm make "Success!", build "✓ built in 935ms",
  smoke "SMOKE PASSED", smoke:aidcsv "PASS"); grep confirms no stale "not yet
  greenlit" / "exploration only" / "Queued in BACKLOG" status strings remain in
  live docs.
**Notes:** Docs-only, status-sync only. Out of scope: rewriting the brief/glossary
(TASK-037) and the roadmap appendix formulas (audit confirmed they match the
code — refuted finding). The roadmap §10 task breakdown is explicitly
aspirational, so listing shipped tasks there isn't a defect.
