# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TASK-031 — Aid-station CSV import/export (+ cutoff field)

**Source.** Promoted from the backlog parking-lot item "Race-organiser
bulk-import (paste a list of aid stations with distances)" after the
2026-06-04 design discussion. Design + decisions recorded in
`knowledge/whiteboard/csv-aid-station-import.md`. User resolved all six open
questions: **file** input, **replace** w/ feedback, **partial OK** via
preview+confirm, **ship matching export**, **support miles** (unit by column
name), **introduce cutoff** this task. Required columns: `name` + distance;
the rest optional (rest defaults from the active profile).

**Why.** Manual one-at-a-time entry doesn't scale to the season targets
(110k/130k/UTMB = 15–30 stations). Organisers publish aid tables; importing
one is the high-leverage path.

**Scope decisions (locked):**

- Cutoff = `Maybe Int`, **elapsed seconds from start**, CSV `hh:mm[:ss]`.
  (No race start-time-of-day field exists, so clock-time cutoffs can't
  compute margin — that + a start-time field is a deferred follow-up.)
- Distance unit chosen by column name: `distance_km`/`km`/`distance` → km;
  `distance_mi`/`mi`/`miles` → miles → meters (×1609.344). Storage metric.
- Services cell: pipe/semicolon list, alias-tolerant; unknown token → row
  *warning*, not a row failure.
- Replace semantics: imported list replaces existing; fresh ids continued
  from `aidStationSeq`. Confirm when existing count > 0.
- One feature branch / one PR; commit in logical chunks.

**Acceptance criteria:**

1. [ ] `Types.AidStation` gains `cutoff : Maybe Int`; `encodeAidStation` /
   `decodeAidStation` round-trip it with a `Nothing` back-compat default; the
   `.trail` file and IDB carry it (no version bump — optional field).
2. [ ] New pure module `AidCsv.elm` exposing `parse` and `toCsv`. `parse`
   returns valid stations **and** per-row errors (partial import). Handles:
   quoted fields, doubled quotes, CRLF/LF/CR, leading UTF-8 BOM, `,` and `;`
   delimiters, header-or-positional, km/mi unit by header, `rest_min` default
   from a passed-in `defaultRestSeconds`, services list w/ alias tolerance +
   unknown-token warnings, cutoff `hh:mm[:ss]`, distance bound
   (≤ totalDistance + 5 m).
3. [ ] Aid-stations section: "Import CSV" button → file picker → **preview**
   (parsed stations table + skipped-row reasons + counts) → "Replace/Import N"
   (confirm-replace when existing > 0) / "Cancel". Confirm rebuilds
   `race.aidStations` (fresh sequenced ids) and persists; cancel changes
   nothing.
4. [ ] "Export CSV" button downloads `name,distance_km,rest_min,services,
   cutoff,notes`; the output re-imports cleanly (round-trip).
5. [ ] Manual aid form gains a cutoff input; aid-row display shows cutoff when
   set. (Trimmable to display-only if it balloons.)
6. [ ] Verification: `npx elm make src/Main.elm --output=/dev/null` clean;
   `npm run build` clean; `node scripts/smoke-aid-csv.mjs` drives the **real**
   `AidCsv.parse`/`toCsv` over fixtures (happy, miles, partial errors,
   quoting/BOM/CRLF, cutoff, toCsv→parse round-trip) and prints PASS; dev
   server boots (HTTP 200). Browser click-through steps written up for the
   user (no headless harness in repo).
7. [ ] No Claude attribution. PR opened + merged (squash). `CURRENT.md`→
   `DONE.md` with PR # + merge sha; journal entry; whiteboard entry resolved;
   backlog parking-lot item struck.

**Branch:** `feat/task-031-aid-csv-import`
