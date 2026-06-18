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

### TASK-065 — Translate: plan table + per-km + per-section (the big one)

**Source:** BACKLOG (i18n epic). **Deps:** TASK-061 (done, PR #134).
**Branch:** `feat/task-065-plan-translations`
**Acceptance criteria:**
- [ ] Plan table view: target-time UI + hint, Download CSV / Print buttons, by-km/by-section toggle, the "Tap a row to edit…" hint, all column headers (Km/Span/Δ ele/Grade/Pace/Time/Cum/Notes / stops/Actual/Δ vs plan/Avg HR), section headers + "Section time"/"Cum" help.
- [ ] Per-km view (`viewPlanKm`): "Km N of M" breadcrumb, "Plan this km", Manual/Auto tabs, "Reset to auto (GAP)" + its note, "Aid stations in this km", clock-time note, the "Actual run linked…" messages.
- [ ] Per-section view (`viewPlanSection`): "Section N of M" breadcrumb, "Section plan", "Ends at" label, "Edit aid station →", "🏁 finishes the race", section stats labels.
- [ ] `gradeClass` (Steep climb/Climb/Runnable/Descent/Steep descent) localizes via the inline `tr` helper (threshold-derived, like density). Effort tiers (Conservative/Goal/Push/All-in) + "Effort"/"Predicted finish" labels. The `serviceLabel` at the plan-section aid header (the 6891 holdover) + **`formatRest`** localize here (5 of its 7 callers are these views; thread `Language` through `kmsWithCumulative`/`viewKmRow`).
- [ ] Actual-run linking panel (`viewActualRun`-ish): section title, "Actual run linked", "Distance run"/"vs Target" headers, Replace/Unlink.
- [ ] New Spanish terms in `reference/i18n-glossary.md`; no `_ ->` in new fns; CI green incl. `smoke:sections`, `smoke:calibration`. **Manual browser check:** all three plan views read Spanish.

**Notes:** Biggest surface — may take a large diff. Thread `Language`/`Context` into `viewPlanTable`/`viewPlanKm`/`viewPlanSection` and their row helpers (`viewKmRow`, `kmsWithCumulative`, section-row helpers). Localize `formatRest` here (the deferred TASK-064 item) + its plan-view callers + the 2 aid-section callers (revert them to the localized form). Decimal displays (km distances, gradient %) route through `Format`; pace/clock/HR stay as-is (colon/integer). Dynamic predictor confidence strings — check if app-defined or computed. Spec WI-4 surface task. On close, pull TASK-066 (profile / calibration / Strava / elevation toolbar).

---

**Arc state (2026-06-17):** **coach-collaboration arc COMPLETE.** WI-1 (TASK-047),
WI-2 (048), aid-id (049), WI-3 engine (050), WI-4 feed (051), backfill (053),
WI-5 identity (054), home owner view (055), and WI-3·UI merge integration + review
modal (056) all shipped. ADRs 0009–0013. The whole flow — share a `.trail`,
annotate it, import it back, three-way-merge with a person-named review surface —
is live and user-verified in-browser.

**Recommended in-browser checks (standing, pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview; TASK-045 section table/card with a linked actual.

---

## Standing reminders (not active tasks)

- **i18n epic is the active arc (started 2026-06-18).** English + Spanish,
  type-driven, no library — TASK-058–069, sequenced machinery (058→060) →
  translation sweep (061→069). Spec `reference/i18n-spec.md` (read its *Resolved
  decisions* callout), ADR-0014, glossary `reference/i18n-glossary.md`. **Units
  (metric/imperial) are descoped** to TASK-070 (parking lot) — language only.
  Translation PRs are large-surface and user-reviewed; keep terms consistent via
  the glossary.
- **Calibration is paused (user, 2026-06-15).** The two core continuous rates
  shipped (TASK-043 vmh, TASK-044 flat pace); the harder roadmap §7 fits
  (descent / fatigue / Riegel / sustainable-HR / decoupling) stay queued —
  promote only on a fresh go-ahead.
- **Three manual checks recommended** (headless env can't do them): browser
  round-trip after the TASK-040 IDB migration; print-preview of the TASK-042
  table; section table/card with a **linked actual** for TASK-045 (clock Time,
  Actual − Time = Δ, monotonic Cum ending at total clock).
- **Coach-collab arc: COMPLETE** (2026-06-17). All work items shipped + verified
  (TASK-046–051, 053–056; ADRs 0009–0013). Nothing outstanding in the arc.
- **Vercel deploy (in progress, 2026-06-18).** The build is fixed (TASK-057 —
  `elm` is now a dev dep; `spawn elm ENOENT` gone). **Remaining is config, not
  code:** (1) set `VITE_BACKEND_URL` in Vercel to the cadence URL — it's inlined
  at *build* time, so set it before building; (2) on **cadence's** side add the
  Vercel origin to CORS (`FRONTEND_URLS`) and set `FRONTEND_URL_TRAIL` to the
  Vercel URL (the OAuth callback redirects there). No `vercel.json` needed
  (hash router → static `dist/`). Optional follow-up: pin `engines.node: "22.x"`
  (Vercel built on Node 24; dev/`.nvmrc` pin v22). The Strava developer-app
  callback domain is cadence's and does **not** change.
