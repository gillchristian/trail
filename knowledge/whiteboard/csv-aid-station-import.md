# CSV aid-station import

> Status: resolved 2026-06-04 — all six open questions answered by the user; promoted to **TASK-031** (`feat/task-031-aid-csv-import`). Design below stands; the **Resolution** section records the final calls.

## Context

The only way to enter aid stations today is the manual form (`viewAidForm`,
`Main.elm`): one modal at a time, name + distance (from-start or
from-previous) + rest-minutes + service chips. Fine for a 20k with 2–3
stops. Painful for the season targets — 110k / 130k / UTMB have 15–30
stations, and Cocodona-class races even more. Organisers always publish an
aid table; re-typing it stop-by-stop is exactly the friction that makes
someone abandon planning.

This is already latent in the backlog parking lot: *"Race-organiser
bulk-import (paste a list of aid stations with distances)."* This entry
refines that item into a concrete shape (CSV file **and/or** paste), with
the parser as the shared core.

User prompt that opened it: "thinking of adding a feature to import aid
stations through a CSV file — how could it look, what to consider."

## What exists today (grounding facts)

- **Model** (`Types.AidStation`): `id` (`"a" ++ aidStationSeq`, per-race
  sequence — stable across re-import, no uuid), `name`, `distance` (Float,
  **meters from start** — canonical), `restSeconds` (Int), `services`
  (`Water|Food|Medical|WC|DropBag`, serialized `water/food/medical/wc/drop_bag`),
  `notes` (String — **set nowhere in the UI today**; `validateAidForm`
  hardcodes `""`).
- **Validation** (`validateAidForm`): name required; distance numeric, ≥ 0,
  ≤ `race.distance + 5` m; rest a whole ≥ 0 number of minutes.
- **File-read infra**: `File.Select.file` → `readFile` →
  `Task.perform (GotContent name) (File.toString file)`. Routed in
  `StartParse` by filename (`isProjectFile` → `ProjectFile.decode`, else
  `Gpx.parseGPX`). That pipeline lives on the **home page** and creates a
  **new race** — wrong scope for aid import (see decision e).
- **Errors**: decoders return `Result String a`; failure shows one string
  via `UploadFailed`.
- **Persistence**: `Storage.saveRace (encodeRace race)` → JS assigns id →
  `RaceSaved` round-trips and merges into the model.
- **Downloads**: `Download.file { filename, content, mime }` port. Two CSV
  exports already exist (`ExportCsvKms`, `ExportCsvSections`) built in
  `Csv.elm` with RFC-4180 quoting. **Those are planning-table reports, not
  a re-importable aid list** — there is no aid round-trip via CSV today
  (only the full `.trail` file round-trips aid stations).

## Options considered

### Input affordance — file vs paste
- **CSV file picker** — what was asked. Native dialog; awkward on iOS.
- **Paste-a-table textarea** — what the backlog originally imagined.
  Lower friction, works on mobile, paste straight from an organiser page.
- **Landing:** they differ only in how a *string* arrives. Build **one pure
  parser** (`String -> (List AidStation, List RowError)`) and feed it from
  both. v1 can ship just one affordance and add the other for free later.

### Format / columns
Canonical, lenient header-matched (case-insensitive; accept `km` / `dist_km`
/ `distance` for distance):

| column | req | notes |
|---|---|---|
| `name` | yes | |
| `distance_km` | yes | **from start, absolute.** km only (brief: no miles). |
| `rest_min` | no | minutes (matches form unit); default 2. |
| `services` | no | pipe-separated in one cell: `water\|food\|wc` (avoids the CSV comma-quote dance). |
| `notes` | no | would be the **first** way to set aid notes. |

- **From-start only** for CSV. From-previous exists in the form because
  typing incrementally by hand is easier; an organiser table is always
  cumulative-from-start. Supporting from-previous in CSV needs an ordering
  assumption + a mode flag — not worth it.
- **Services layout** alt: one boolean column per service (`water,food,…` =
  `x`/`1`). Spreadsheet-friendly for organiser service matrices; wider
  header. Parser should accept either; canonical export uses pipe form.
- **No recognizable header** → assume positional
  `name, distance_km, rest_min, services, notes`. Lenient > strict;
  organiser data is messy.

### Merge semantics (existing stations present)
- **Replace (recommended)** — matches the "here is my station list" mental
  model; predictable. Destructive → **confirm**, stating how many existing
  stops will be removed. Re-issue ids from a fresh sequence and bump
  `aidStationSeq` past the highest. Safe: plan data is keyed by **km index**,
  not aid id, so replacing stations never orphans the per-km plan; sections
  (derived from aid distances) just recompute.
- **Append** — secondary option; risks duplicates.
- **Merge-by-name/distance** — clever, surprising, over-engineered for v1.

### Validation / partial failure
- **All-or-nothing** — simplest, matches the existing one-string error path.
- **Import valid rows + per-row report (recommended)** — "23 imported, 2
  skipped: row 7 distance NaN; row 19 beyond route end." The whole point is
  bulk + messy input, so partial success earns its keep. Pairs with a
  preview (below). Parser returns `(List AidStation, List RowError)`.

### Preview before commit
- **Strong recommendation:** parse → show the table + row errors →
  `[Import N]` / `[Cancel]`. The current upload flow is fire-and-forget, but
  that creates a new race; aid import **mutates an existing race**, so it
  should not auto-commit. Preview + replace-confirm is the biggest safety
  win.

### Entry point / wiring (decision e)
- Lives on the **race detail page**, in the Aid-stations section — a
  secondary "Import CSV" button beside "+ Add" (you need a course to place
  stations on). This is a **separate file-read path** scoped to the current
  race; reuse `readFile`/`File.Select`, but do **not** fold it into the
  global `GotContent`/`StartParse` router (that's keyed to creating races and
  would tangle the state machine). New messages roughly: `OpenAidImport`,
  `AidImportPicked File`, `AidImportContent String`, `AidImportConfirm`,
  `AidImportCancel`; import sub-state on the model (or inside `AidEditor`).

### Matching export (round-trip)
- Add **"Export aid stations CSV"** alongside import so the format is
  self-documenting (export a sample to see the columns) and the round-trip
  is real (export → edit in a spreadsheet → re-import). Cheap via `Csv.elm`
  patterns + the `Download.file` port. **Naming caveat:** this is a *third*
  CSV export distinct from the two planning-table reports — label them
  clearly ("Planning table CSV" vs "Aid stations CSV").

## Things to consider (gotchas)

- **Real CSV parsing, not `String.split ","`.** Handle quoted fields with
  embedded commas/newlines, doubled quotes, CRLF vs LF, a UTF-8 BOM (Excel
  prepends one), trailing blank lines, and locale `;` delimiters. This is
  the most likely "it didn't work" bug. Keep it a pure, unit-tested module
  (project values "if it compiles it works" + tested pure modules like
  `Predictor`).
- **Miles.** Brief hard-constraint is km-only *display*. US organiser tables
  (Cocodona) are in miles. v1: document "CSV is km." Possible v2: a km/mi
  toggle on the import dialog that converts at the boundary (storage stays
  metric) — an input convenience, not a display-unit change, so it doesn't
  break the constraint.
- **Cutoff times.** Organiser tables always include them and a planner cares
  about margin-vs-cutoff. The model has **no cutoff field** — adding one is a
  `Types` + planning-UI change, a separate feature. Tempting to grab a
  `cutoff` column now; keep it out of import v1, note it as related.
- **Notes path.** Importing notes is the first way to populate
  `AidStation.notes`. Either also expose notes in the manual form, or accept
  CSV as the only notes path for now.
- **Duplicate / same-distance rows.** Model doesn't forbid two stops at the
  same km; warn rather than reject.
- **Performance:** non-issue (tens of rows, not thousands).

## Where we landed

Recommend doing it, **parser-first**, in two phases:

- **v1 (S–M):** race-page "Import aid stations" → file picker *or* paste
  textarea → pure CSV parser (`(List AidStation, List RowError)`) → preview
  table with per-row errors → **Replace-with-confirm** → persist. Ship a
  matching **"Export aid stations CSV"**. km-from-start; services
  pipe-separated; lenient header matching.
- **v2 (later):** miles toggle, append/merge modes, smarter column
  auto-detection, and possibly a `cutoff` column once the model grows one.

Not promoting to a task without an explicit go-ahead; open questions below
are for the user.

## Open questions for the user

1. **File, paste, or both** for v1? (Parser is shared either way; paste is
   the mobile-friendlier one.)
2. **Replace vs append** as the default when stations already exist?
3. **Partial import + row report**, or all-or-nothing?
4. Worth shipping the **matching CSV export** in the same pass? (Recommended
   — makes the format discoverable.)
5. **Miles toggle** now, or document km-only for v1?
6. Grab a **`cutoff` column** while we're here, or defer the data-model
   change?

## Resolution (2026-06-04)

User answered all six → promoted to **TASK-031**:

1. **File** input (picker). Parser still written pure so paste can reuse it
   later for free.
2. **Replace** with visual feedback (a confirm/preview step).
3. **Partial OK**, surfaced in a **preview** so the user can bail and fix the
   file instead of committing a partial set.
4. **Yes** — ship the matching CSV export.
5. **Support miles** — the *column name* picks the unit (`distance_km` vs
   `distance_mi`); always convert to metric on ingest.
6. **Yes** — introduce `cutoff` this task. Modeled as `Maybe Int` =
   **elapsed seconds from start** (CSV `h:mm[:ss]`). The app has no race
   start-time-of-day field, so clock-time cutoffs can't compute margin —
   clock-time + a start-time field is a noted follow-up. Cutoff is settable
   via CSV **and** the manual form, and shown in the aid-station list. Using
   it for margin-vs-plan warnings is a separate backlog item.

Also locked: required columns are **name + distance**; everything else
optional, with `rest` defaulting to the active profile's
`aidStyleSecondsPerStation`.

## Follow-ups

- **TASK-031** (this) — `feat/task-031-aid-csv-import`. Acceptance criteria
  in `planning/CURRENT.md`.
- Deferred: clock-time cutoffs (needs a race start-time field); margin-vs-cutoff
  warnings in the planning view; miles support in the *manual* form (CSV only
  for now); paste-a-table input affordance (parser already supports it).

- Refines backlog parking-lot item *"Race-organiser bulk-import (paste a
  list of aid stations with distances)"* — if promoted, reframe that item to
  cover paste **and** CSV via the shared parser.
- If built, the pure parser + matching export are unit-testable and worth an
  ADR only if the format becomes a published contract; otherwise a backlog
  task + journal entry suffice.
