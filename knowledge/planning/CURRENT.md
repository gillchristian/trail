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

### MONO-001 — Restructure trail in place (PR 1)

**Source:** BACKLOG — Monorepo migration epic (spec `reference/monorepo-migration-spec.md`, MONO-001)
**Branch:** `mono/mono-001-restructure-trail` (create off master)
**Preconditions:** MONO-000 merged (PR #152, `f2b0bd9`). ✓
**Goal:** move trail's code into `systems/trail/` (history-preserving `git mv`), split its
knowledge into the **shared tier** (root `framework/` + a new **root manifest** +
`reference/specs/`) and a **trail v3 instance** under `systems/trail/knowledge/`, and split
the manifest + `CLAUDE.md` into root (dispatch + repo-wide rules) and system (trail-local
rules + Locations). Trail still builds and deploys from the new path.

**Acceptance criteria:**
- [ ] Code moved to `systems/trail/` via `git mv` (`src/ public/ samples/ scripts/ index.html elm.json vite.config.js package.json package-lock.json .envrc .nvmrc MORNING.md`). `git log --follow systems/trail/src/Main.elm` shows pre-move history.
- [ ] All gates pass **run from `systems/trail/`**: `npx elm make src/Main.elm --output=/dev/null`, `npm run build`, `npm run smoke`, `npm run smoke:aidcsv` (+ the other smokes). Output quoted in the journal.
- [ ] Knowledge split: `framework/` stays at root (single shared copy); `{planning,progress,decisions,reference,whiteboard}/` → `systems/trail/knowledge/`; the migration spec → shared `knowledge/reference/specs/`.
- [ ] Manifest split: root `knowledge/README.md` (ROOT MANIFEST — repo-wide delivery/identity/VCS rules + bootstrap-exceptions note + system index) + `systems/trail/knowledge/README.md` (trail-local: branch prefix `trail/`, id-ns `TRAIL-`, Locations pointing at trail's new paths + root framework, local-ci, brief pointer). **No rule duplicated across tiers.**
- [ ] Dispatch: root `CLAUDE.md` → "which system? read that system's `CLAUDE.md`" + reading chain + repo non-negotiables; `systems/trail/CLAUDE.md` = trail's entry (→ root manifest → system manifest).
- [ ] Cold-read chain resolves: root `CLAUDE.md` → root manifest → `systems/trail/knowledge/README.md` (Locations) → root `knowledge/framework/`.
- [ ] Path-dependent config fixed (`vite.config.js` base/root/publicDir; `package.json` scripts; any `scripts/*` assuming repo-root cwd). `.gitignore` consolidated at root; `.claude/` merged at root.
- [ ] **Vercel (trail) — user action:** Root Directory → `systems/trail`. Surfaced to the user; Vercel build succeeds after they set it (manual confirm, like other deploy steps). Likely logged as a blocker / coordinated at merge time.

**Notes:** Don't move `dist/ elm-stuff/ node_modules/` (regenerate). Append-only history
(journal/DONE/old ADRs) referencing old paths: **leave untouched** (tombstone convention) —
fix only *live* pointers (CLAUDE quick-map, local-ci, manifest cross-links). The MONO epic's
planning rides with trail (origin system) for now; `MONO-` stays the shared-tier namespace.
**Namespaces:** trail's own feature backlog stays `TASK-` (history); new trail work
post-split uses `TRAIL-`. The `section.label`/units parking-lot items (TASK-070/071) move
with trail's planning.

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
