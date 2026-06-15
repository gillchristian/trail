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

### TASK-040 — Separate `gpxText` into its own IDB row

**Source:** BACKLOG parking lot, promoted 2026-06-15 (batch task 2 of 5; TASK-039
shipped — PR #72, `633e263`).
**Branch:** `refactor/task-040-gpx-store`

**Problem.** `Race.gpxText : String` (`Types.elm:222`) holds the raw GPX (~3 MB
for a UTMB-size track). It is encoded inline in the race JSON (`Types.elm:313`)
and the whole race object is the value in the `races` IDB store. So **every**
`Storage.saveRace (encodeRace …)` — 14 call sites in `Main.elm`, almost all
plan/aid/metadata/actual edits — re-ships that 3 MB across the port and rewrites
it to IDB, even though the GPX never changes after import. PR #29 only papered
over the drag case (`SliderInput` is live-only, the comment at `Main.elm:1413`;
`SliderCommit` still writes the whole thing).

**Approach (to confirm while building).** Add a second object store `gpx` keyed
by race id (DB v2 → v3). `gpxText` is **immutable after import** (set only in
`buildDraftRace`/`.trail` import; no edit path), so:
- the `races` row carries the race *minus* `gpxText`;
- the `gpx` row (`{ id, gpxText }`) is written **once** at import and never again;
- on load, JS joins `gpxText` back into each race before sending to Elm (the
  decoder at `Types.elm:512` still requires the field — keep it that way);
- plan/aid/meta/actual saves use a light port that writes only the `races` row —
  no `gpxText` in the payload — so the 3 MB never crosses the port on an edit;
- import/`.trail`-import uses a full save that writes both stores.
- v2 → v3 `onupgradeneeded` migrates existing inline-`gpxText` races into the
  `gpx` store (no data loss). `.trail` file format is unaffected — `gpxText`
  still travels in the export envelope; only IDB layout changes (no `.trail`
  version bump). Capture the schema/migration choice in an ADR.

**Acceptance criteria:**
- [ ] New `gpx` object store, `DB_VERSION` 2 → 3, `onupgradeneeded` creates it
  (`src/main.js`).
- [ ] **Migration:** a race stored under v2 (inline `gpxText`) survives the
  upgrade — its GPX moves into the `gpx` store, intact (~3 MB round-trips byte
  for byte), and still loads + parses.
- [ ] **The win:** a plan-only save (slider commit, aid add/edit/delete, target
  commit, metadata edit, actual link/unlink) writes only the `races` row; the
  `gpx` row is not rewritten and `gpxText` is absent from the light save payload.
- [ ] On load, `gpxText` is re-attached so the Elm decoder succeeds and GPX
  export (`GpxExport`) + profile parse (`Gpx.parseGPX race.gpxText`) still work.
- [ ] A freshly imported race (both `.gpx` and `.trail`) persists, and after a
  reload the track + plan + aid stations are intact.
- [ ] `scripts/smoke-storage.mjs` (the hand-copied mirror of `main.js`'s IDB
  logic) updated to the v3 schema and extended: store creation, v2 → v3
  migration, plan-only-save-leaves-gpx-untouched, load-join round-trip with a
  real ~3 MB GPX. `npm run smoke` green.
- [ ] All five local-CI gates green + a **manual app round-trip** (import → edit
  plan → reload → data intact), output/observation quoted in the journal.
- [ ] ADR for the two-store schema + migration.

**Notes.** Keep `race.gpxText` in the Elm model (don't thread GPX out of the
record) — only the *persistence* path splits. The smoke is a copy of `main.js`,
not an import of it, so both files must move together (a drift here is exactly
what TASK-038 cleaned up in the CI docs).
