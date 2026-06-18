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

### TASK-066 — Translate: profile / calibration / Strava / elevation toolbar

**Source:** BACKLOG (i18n epic). **Deps:** TASK-061 (done, PR #134).
**Branch:** `feat/task-066-profile-translations`
**Acceptance criteria:**
- [ ] `#/profile` page (`viewProfileSettings`): page title/intro, the performance-profile field rows (Vertical rate, Flat trail pace, Fatigue threshold/slope, Descent skill, Technicality, Aid stops, LTHR, Max HR — labels + help text), the HR-calibration opt-in, Save + confirmation.
- [ ] Calibration panel: "Calibrate from your runs" + description, the two result rows (climb rate / flat pace) + their explanations, Apply.
- [ ] Strava card: title, description, connection status, Connect/Disconnect, backend URL label — **and the Strava activity-picker modal** (`viewStravaPickerModal`/`viewStravaActivityRow`/`viewStravaPickerSearch`, deferred from 065): search/recent headings, loading/searching/error, "Close", empty-search states.
- [ ] Identity card (the collaboration display-name card on `#/profile`).
- [ ] `AthleteProfile.elm` labels (presets, descent/tech skill, aid style) + `Profile.elm` toolbar (Fit width/True scale, the legend) — both modules gain a `Language` arg.
- [ ] New Spanish terms in glossary; no `_ ->`; CI green incl. `smoke:calibration`. **Manual browser check:** `#/profile` + the Strava picker read Spanish.

**Notes:** `AthleteProfile.elm`/`Profile.elm` are separate modules — pass `Language` (they don't have model). Their label fns (`presetLabel` etc., `formatKmShort`/`formatM` in Profile) take `Language`; the elevation-chart legend decimals route through `Format`. Confirm `AthleteProfile`/`Profile` don't import `Translations` in a way that cycles (Translations imports Route+Types; those modules are leaf-ish — likely fine, but check). Spec WI-4 surface task. On close, pull TASK-067 (activity feed / changelog).

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
