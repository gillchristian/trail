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

### MONO-000 — Framework v2→v3: path indirection (PR 0)

**Source:** BACKLOG — Monorepo migration epic (spec `reference/monorepo-migration-spec.md`, MONO-000)
**Branch:** `mono/mono-000-framework-v3-path-indirection`
**Goal:** the framework resolves instance-area locations by *role* from the manifest's
Locations block instead of hardcoded `../` siblings. Pure framework change — **no file
moves, no new systems**. Trail keeps working because its manifest declares the same
locations it already had. De-risks PRs 1–3 (they all instantiate v3 instances and must
point at a working v3 framework).

**Acceptance criteria:**
- [ ] Grep over `knowledge/framework/` returns **no** `\.\./(planning|progress|decisions|reference|whiteboard)/` path-literals — role names only. (verify: grep returns empty)
- [ ] Instance-free guard still clean: `grep -riE '\btrail\b|\belm\b|batman|gillchristian|coros|samples/' knowledge/framework/` returns nothing (the `context7`-in-"e.g." carve-out still applies).
- [ ] Manifest skeleton in `SETUP.md` gains the **Locations block** convention (framework/planning/progress/decisions/reference/whiteboard → paths); framework refers to areas by role, the manifest maps roles→paths; the one remaining hardcoded hop is `CLAUDE.md` → manifest.
- [ ] Trail's manifest (`knowledge/README.md`) + `CLAUDE.md` updated to the v3 convention, declaring the **current (pre-move)** trail paths; trail behaves identically.
- [ ] `framework/README.md` stamped **Framework v3 (2026-06-24)** with a one-line changelog (path indirection; manifest Locations block). This repo stays the canonical upstream.
- [ ] Fresh-agent cold read: `CLAUDE.md → manifest → framework` resolves every area with zero prior context (dry-run reasoning recorded in the journal).
- [ ] Trail's loop unchanged — gates green, output quoted in the journal: `npx elm make src/Main.elm --output=/dev/null` · `npm run build` · `npm run smoke` · `npm run smoke:aidcsv`.

**Notes:** First of the 5-PR monorepo migration. The spec is the contract; locked
decisions are settled (don't reopen). `MONO-` is its own id namespace (not the global
`TASK-` counter). Ingestion (backlog epic + spec parked in `reference/`) rides on this
branch as the orientation step.

---

### Trail feature work — parked (no active *trail* task)

The **i18n epic is COMPLETE** (2026-06-18): TASK-058–069 all shipped + verified.
English + Spanish, hand-rolled and type-driven (ADR-0014); default from
`navigator.language`, footer `English / Español` toggle, persisted in IDB, never in
`.trail`. Machinery (`Language`/`Settings`/`Context`/`Format`/`Translations`) +
every UI surface localized; the add-a-3rd-constructor exhaustiveness check proved a
missing translation can't compile (304 sites flagged). Spec `reference/i18n-spec.md`,
glossary `reference/i18n-glossary.md`. **Pull the next item only on a fresh user
steer.** Two scoped follow-ups remain in the parking lot, neither prioritized:
**TASK-070** (units metric/imperial — the deliberate descope) and **TASK-071**
(`section.label` display/canonical split — the one i18n residue). Do **not**
auto-promote either.

**Standing manual checks (headless env can't drive the compiled app — for the user):**
- **i18n end-to-end:** toggle to Español in the footer → header/home/cards, race
  detail + edit dialog, map, aid stations + CSV preview, all three plan views,
  `#/profile` (incl. the skill dropdowns still **save** correctly), Strava picker,
  activity drawer, and the delete/identity/merge modals all read Spanish; decimals
  show `42,2 km` / `12,5 %`; pace/clock stay `M:SS`/`H:MM:SS`; reload keeps the
  choice; a fresh `es-*` browser profile defaults to Spanish; `<html lang>` flips.
- **Known intentional English:** `.trail`/CSV/GPX exports, dynamic parse/HTTP error
  *detail*, format hints (`m:ss`/`h:mm`), unit suffixes, `Δ ele`/`Δ vs plan`,
  category letters (S/M/L/XL), `section.label`'s Start/Finish (→ TASK-071), proper
  nouns (Coros/Strava/UTMB/Pace Strategy/Waypoint Alerts).

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

- **i18n epic COMPLETE (2026-06-18).** English + Spanish, type-driven, no library —
  TASK-058–069 all shipped (machinery 058→060, translation sweep 061→068, QA 069).
  Spec `reference/i18n-spec.md`, ADR-0014, glossary `reference/i18n-glossary.md`.
  **Units (metric/imperial) descoped** to TASK-070; the one i18n residue
  (`section.label` Start/Finish) is TASK-071. Both parking-lot, unpromoted. Keep
  any future translation terms consistent via the glossary.
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
