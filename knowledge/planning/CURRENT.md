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

### TASK-060 — WI-3 + WI-5 (language half): `Context` + `Format`

**Source:** BACKLOG (i18n epic). **Deps:** TASK-058, TASK-059 (both done — PR #128, #130).
**Branch:** `feat/task-060-context-format`
**Acceptance criteria:**
- [ ] New `Context { language }` + `toContext : Model -> Context`. **`Context` lives in its own module** (`Context.elm`), not `Main` — `Format` takes a `Context`, and `Main` imports `Format`, so a `Context` defined in `Main` would cycle. Leaf localized views take `Context` (or its `.language`), never `model.settings`.
- [ ] `Format.elm` localizes **decimal quantities** — Spanish renders `,`, English `.` — by wrapping trail's existing hand-rolled rounding (no `myrho/elm-round` dep). Colon-formatted values (pace `M:SS`, clock) are **unchanged** in both languages. **No unit conversion** (descoped). Each formatter total over `Language`.
- [ ] The *display* call sites for distances + decimal floats route through `Format` (threaded via `Context`); **CSV / GPX / `.trail` formatters are left untouched** (data interchange keeps `.`-decimals).
- [ ] Visible proof: with the footer toggle on Spanish, a distance shows `42,2 km`; on English `42.2 km`; pace/clock keep `:` in both (verify: `smoke:i18n` Format ops + **manual browser check**).
- [ ] `smoke:i18n` extended with `Format` ops (Spanish comma, English period, colon-neutral pace/clock). CI green: type-check, build, `smoke`, `smoke:i18n`.

**Notes:** Module shape that avoids cycles — `Context.elm` imports `Language`; `Format.elm` imports `Context` + `Language`; `Main` imports both; `toContext` in `Main`. `Format` takes `Context` (not bare `Language`) so the descoped `units` (TASK-070) reads `ctx.units` later with no signature churn. `Translations` (TASK-061) will take `Language` directly (words never depend on units). Decimal-localization surface is **small** — distances (`formatKm`/`formatKmShort`) + a few decimal floats; integers (elevation in m, HR) and colon values need no swap (per the formatting audit). This is the first task that makes a toggle visibly *do* something. Spec WI-3 + WI-5; ADR-0014. On close, pull TASK-061.

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
