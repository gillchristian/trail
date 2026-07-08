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

### MONO-005 — Land the cross-system whiteboard (framework-loops review)

**Source:** user request (2026-07-08) — framework v3 reviewed against the Claude Code
"Getting started with loops" article (2026-07-06); the review document becomes the
first cross-system whiteboard entry.
**Branch:** `mono/mono-005-whiteboard-loops-review`
**Acceptance criteria:**
- [ ] `knowledge/whiteboard/README.md` exists (cross-system conventions + the
  MONO--edit discipline) and indexes the review entry; the index link's target
  path exists on the branch.
- [ ] `knowledge/whiteboard/framework-loops-review.md` carries the review: Status
  line, Context, strengths, the 16 tiered improvements, "Considered and rejected",
  "Where we landed", "Follow-ups" (verify: grep the section headings).
- [ ] Triage done (review follow-up #1): MONO-006…MONO-009 queued in `BACKLOG.md`'s
  MONO- namespace mapping tiers 1–3; Tier 4 recorded as parked in the whiteboard
  entry; TASK-072 (trail browser-drive verification) queued in trail's parking
  lot; the whiteboard Status + Follow-ups point at the queued ids (verify: grep
  the ids in both files).
- [ ] Root manifest Layout: the `whiteboard/` line no longer reads "(none yet)" and
  points at the index (verify: grep).
- [ ] `knowledge/framework/` untouched: `git diff master --stat --
  knowledge/framework/` is empty (quoted in the PR).
- [ ] Delivered per `pr`: squash-merged PR from the branch above; before merging, a
  fresh-context review of the diff against these criteria (practicing the
  review's own #1) — findings fixed or explicitly rebutted in the PR description.
**Notes:** docs-only — no build/test gates apply beyond the file checks above. The
review itself (six-dimension analysis, adversarial verification of findings) ran
in-session before this task; MONO-005 lands the durable record + the triage, not
the analysis.

---

### Monorepo migration COMPLETE ✅ (context, 2026-06-24)

The **monorepo migration epic (MONO-000 → MONO-004) is COMPLETE** (2026-06-24). Trail is now one
system in a five-system monorepo (`systems/{trail,cadence,gateway,track,reflect}`) on a two-tier
federated knowledge base (shared root `framework/` + root manifest; per-system v3 instances).

- **MONO-000** framework v2→v3 path indirection · **MONO-001** trail → `systems/trail/` ·
  **MONO-002** cadence import → `systems/cadence` + `systems/gateway` (bootstrap FF merge; deployed) ·
  **MONO-003** track + reflect knowledge stubs · **MONO-004** parallelism & workspace wiring.
  All merged; full record in `DONE.md` + the journal. Contract: `reference/specs/monorepo-migration-spec.md`.
- **Deploys live + confirmed:** gateway on fly (app `cadence`, `data` volume/`tokens.db` intact);
  trail + cadence on Vercel, each rooted at its own `systems/<s>/` dir.
- **Optional cleanup (non-blocking):** trail's Vercel "include files outside the Root Directory"
  toggle is ON — it can be turned OFF (trail is self-contained); a dashboard step, no rush.

**Active task: MONO-005 (above).** New work is **per-system**: pull it into that system's own
`CURRENT.md` under its branch prefix (`trail/`/`TRAIL-`, `cadence/`/`CAD-`, `gateway/`/`GW-`,
`track/`/`TRACK-`, `reflect/`/`REFLECT-`); shared/structural work is a `MONO-` task. **Pull the next
item only on a fresh user steer.** Open follow-ups: reflect's scope (its BLOCKER-001), and trail's
own parked items below.

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
