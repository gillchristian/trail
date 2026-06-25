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

### MONO-003 — Scaffold track + reflect stubs (PR 3)

**Source:** BACKLOG — Monorepo migration epic (spec `reference/specs/monorepo-migration-spec.md`, MONO-003)
**Branch:** `mono/mono-003-track-reflect-stubs`
**Preconditions:** MONO-001 merged (PR #154). ✓ Independent of MONO-002 — may land any time after PR 1.
**Goal:** two empty v3 knowledge instances under `systems/track/` and `systems/reflect/` so agents
can pick those systems up later. **Knowledge only, no code; `framework/` not duplicated** (point at
the root copy via Locations).

**Acceptance criteria:**
- [ ] For each of `systems/track/`, `systems/reflect/`: a v3 manifest (`knowledge/README.md` — delivery inherits the root ceiling; branch prefix + id-ns per §3; Locations at the system's own areas + root framework; brief pointer) + a system `CLAUDE.md` entry.
- [ ] Each has skeleton `planning/{CURRENT,BACKLOG,DONE}.md`, `progress/{journal,blockers}.md`, `decisions/INDEX.md`, `reference/project-brief.md`, `whiteboard/README.md`.
- [ ] **Track brief** carries the designed MVP work-item sequence (skeleton → domain/persistence → library/race-config → CSV import → *paused for the tracking-view design* → tracking view → post-race view; deferred: `.trace` export, `.trail` ingestion, Live Activity) + records the `.trace`/`.trail` contracts as pointers into shared `knowledge/reference/specs/`.
- [ ] **Reflect brief** records scope-not-yet-defined + an explicit Unknowns list (log a blocker if a setup input is missing; do **not** invent a backlog).
- [ ] Both read cold via the chain (root `CLAUDE.md` → root manifest → system manifest → root `framework/`); `framework/` **not** duplicated into either; no code / no build target introduced.
- [ ] Root manifest system index notes track + reflect are now scaffolded (stubs).

**Notes:** SETUP adoption flow (copy-if-absent). `track/`/`TRACK-`, `reflect/`/`REFLECT-` (§3). `.trace`
doesn't exist yet (track is a stub) — its contract is a forward pointer; `.trail` is trail's existing
format. No `product-vision.md` authored here (out of MONO-003 scope) — referenced as a pointer if needed.

---

### MONO-002 — merged; deploys confirmed ✅ → closing

Code + knowledge **merged to `master`** (`ae80a5e`..`cfc6aef`, the sanctioned `git subtree` FF; bootstrap
exception recorded in the root manifest). All criteria met:
- ✅ **BLOCKER-001 — fly:** `fly deploy systems/gateway` succeeded (user, 2026-06-24) — `/` healthy, `data` volume / `tokens.db` intact, cadence frontend kept working against the new server.
- ✅ **BLOCKER-002 — Vercel (cadence):** user re-pointed the cadence project → `gillchristian/trail`, Root Directory `systems/cadence/` (2026-06-24).

Moves to DONE in the close PR (with MONO-003).

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
