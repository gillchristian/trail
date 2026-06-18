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

### TASK-069 — i18n QA sweep + exhaustiveness check + deferred labels (closes the epic)

**Source:** BACKLOG (i18n epic). **Deps:** TASK-058–068 (all done).
**Branch:** `feat/task-069-i18n-qa`
**Acceptance criteria:**
- [ ] **Straggler sweep:** grep all `src/*.elm` for hardcoded user-facing strings missed by 061–068 (`text "…"`, `A.placeholder`, `A.title`, `A.attribute "aria-label"`, button labels); localize any real display string found (exclude SVG attrs, CSS, DOM ids, export/CSV/GPX, dynamic error detail, proper nouns).
- [ ] **`section.label` + `conflict.label`** (built in `Planning.elm` / `Merge.elm`, deferred from 065/068): localize. Thread `Language` into the label builders (or expose endpoints for the view to format); update `smoke:sections`/`smoke:merge` harnesses to pass a `Language`. "Start"/"Finish" → "Salida"/"Meta"; "Target pace · km N" etc.
- [ ] **Exhaustiveness check (spec DoD):** temporarily add a third `Language` constructor, confirm `elm make` enumerates every untranslated `case` site, then revert. Document the result in the PR.
- [ ] **`<html lang>`** tracks the toggle (wired TASK-059) — confirm in the build/code; note the manual check.
- [ ] Glossary final pass; CI green: type-check, build, `smoke`, `smoke:i18n`, `smoke:sections`, `smoke:merge`, `smoke:changelog`, `smoke:calibration`, `smoke:aidcsv`. **Manual browser check:** toggle through every surface in Spanish.

**Notes:** The capstone. If `section.label`/`conflict.label` localization turns out to be a large math-layer refactor (not just threading a param), carve it into a follow-up backlog item rather than bloat this PR — but attempt it first. Known intentional English: data exports (`.trail`/CSV/GPX), dynamic parse/HTTP error *detail*, format hints (`m:ss`/`h:mm`), unit suffixes (`km`/`m`/`bpm`/`/km`), `Δ ele`/`Δ vs plan` compact headers, category letters (S/M/L/XL), proper nouns (Coros/Strava/UTMB/Pace Strategy/Waypoint Alerts). On close: epic COMPLETE — update CURRENT to no-active-task, surface the standing manual checks + the units backlog item (TASK-070).

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
