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

### MONO-002 — Import cadence: systems/cadence + systems/gateway (PR 2, bootstrap exception)

**Source:** BACKLOG — Monorepo migration epic (spec `reference/specs/monorepo-migration-spec.md`, MONO-002)
**Branch:** `mono/mono-002-import-cadence` (create off master)
**Preconditions:** MONO-001 merged (PR #154, `9c24ab5`). ✓ Cadence repo expected at `/Users/bb8/dev/cadence`.
**Goal:** fold cadence `client/` → `systems/cadence/` and `server/` → `systems/gateway/`
(flattened), import cadence's history via the one sanctioned non-squash merge, upgrade its
v1 knowledge into two v3 instances (unified history → gateway under a tombstone; cadence
starts fresh), and re-point both deploy targets.

**⚠ Delivery exception (sanctioned, recorded):** `git subtree add --allow-unrelated-histories`
brings cadence's history in inline → **exactly one merge commit on `master`**, the only
non-squash merge permitted for this task. Record it in the root manifest's *Bootstrap
exceptions* note. No other non-squash merge.

**Acceptance criteria:**
- [ ] `systems/gateway`: `go build ./...` + `go test ./...` pass from the new root; Docker image builds from the `systems/gateway` context (`docker build -f systems/gateway/Dockerfile systems/gateway`).
- [ ] Gateway flatten edits: `fly.toml` `dockerfile = 'Dockerfile'` (app stays `cadence` — Locked decision 7); Dockerfile COPY/WORKDIR paths de-`server/`-ed; image verified to build from the new context **before** any live deploy.
- [ ] `systems/cadence`: `npm install && npm run build` (tsc + vite) passes from `systems/cadence`.
- [ ] Exactly **one** non-squash merge commit on `master` from this PR, recorded in the root manifest's bootstrap-exceptions note.
- [ ] `tokens.db`/`tokens.json` absent from the tree + present in `.gitignore`; `server/.env.example` → `systems/gateway/.env.example` present.
- [ ] Knowledge routed (spec table): gateway gets cadence ADRs 0001–0004 + `caching.md` + project-brief server slice + planning + journal/blockers (tombstoned "covers pre-monorepo cadence client+server"); `trail-integration.md` → shared `reference/specs/`; v1 `philosophy/` discarded with a one-line gateway-README tombstone. Cadence starts a fresh v3 instance (manifest branch `cadence/`, id-ns `CAD-`, empty planning, fresh journal/blockers, client-slice brief). Both read cold; no orphaned `philosophy/` refs in live pointers.
- [ ] `.github/workflows/fly-deploy.yml` → root `.github/workflows/`, path-filtered `systems/gateway/**`, deploy step pointed at the new dir. `FLY_API_TOKEN` noted as a "when you wire CI" prereq (not a migration blocker — manual deploys).
- [ ] **fly (gateway) — user action:** image builds locally; then **ask the user** to run `fly deploy systems/gateway` + confirm `/` health and the `data` volume / `tokens.db` intact (not recreated). Do not deploy autonomously.
- [ ] **Vercel (cadence) — user action:** re-point the cadence project's git connection → monorepo; Root Directory `systems/cadence`; build green; Strava redirect URL + domain + env vars intact.

**Notes:** Locked decision 7 — fly app stays `cadence` (renaming orphans the `data` volume);
the *dir* is `gateway`, the *app* independent. Drop cadence's root `package.json`/lock
(workspace orchestration superseded). Merge cadence's `.claude/` at root. Subtree mechanics:
resolve the one-merge-commit constraint at execution (subtree add, then flatten/route as
further commits, landing exactly one merge commit on master). Two user deploy actions at the
end (fly, cadence Vercel) — prepare + surface, never autonomous.

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
