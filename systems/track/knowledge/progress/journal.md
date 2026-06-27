# Journal

Append-only. Newest at the bottom. Each entry is a snapshot for future-me with no memory of this session.

## Entries

---
## 2026-06-24 — track: scaffolded as a v3 stub (MONO-003)

**Task:** MONO-003 (monorepo) — scaffold the track system as a knowledge-only stub.
**What:** Created `systems/track/` as a v3 knowledge instance (manifest, CLAUDE, skeleton
planning/progress/decisions/whiteboard, a brief). **No code.** `framework/` is the shared root copy
(not duplicated — resolved via Locations). The brief carries the already-designed MVP work-item
sequence + the `.trace`/`.trail` integration-contract pointers (shared `reference/specs/`).
**Next:** await a steer to start track. When picked up: promote item 1 (Skeleton) from the brief's MVP
sequence into `BACKLOG.md` as `TRACK-001`, write acceptance criteria, branch `track/track-001-…`.

---
## 2026-06-25 — track: ingested the MVP spec + seeded the backlog (TRACK-000…010)

**Task:** user request — process the tracker MVP plan + tracking-view spec + the four tab wireframes
and ingest them into track's backlog. Track was a knowledge-only stub (MONO-003); this is the
"pick up track" moment (a planning-seed, not a TRACK-NNN work item itself).

**What:**
- **Lifted the specs into the instance.** Moved the loose repo-root files into `reference/`:
  `tracker-mvp-plan.md` → `reference/mvp-plan.md`, `tracker-tracking-view-spec.md` →
  `reference/tracking-view-spec.md` (dropped the redundant `tracker-` prefix; fixed the 7 internal
  cross-refs between them). Wireframes + Excalidraw source → `reference/design/`
  (`track-{nutrition,aid-stations,others,feed}.webp`, `tracker.excalidraw`); added a wireframes
  pointer in the tracking-view spec.
- **Rewrote `reference/project-brief.md`** from the generic stub 7-step into the real designed MVP:
  pointers to the canonical specs; the load-bearing invariants (no background exec; append-only
  fsync'd log; offline; capture-now-process-later; plan-less-first; projections-not-flags); the
  Swift/SwiftUI + directory-bundle stack; the TRACK-000…010 mapping; the `.trace`/`.trail` deferral;
  and a **Visual design** section (follow Trail).
- **Seeded `planning/BACKLOG.md`** under one epic ("Tracker MVP, 2026-06-25"):
  **TRACK-000** = Swift/iOS toolchain bootstrap (the user's explicit prerequisite; the build owner is
  new to Swift/iOS) — an index-0 foundational task mirroring the repo's MONO-000 precedent, full AC
  inline. **TRACK-001…007** = WI-1…7 (critical path, Active); **TRACK-008/009/010** = WI-8/9/10
  (`.trace` / `.trail` / Live Activity — deferred → parking lot). Full per-WI AC live in
  `mvp-plan.md` §7.
- **Styling steer (user):** track follows Trail's design language (dark-first `#020617`/slate, amber
  `#fbbf24` / race-red `#E52E3A` / green `#22c55e`, race-card feel). Captured in the brief's *Visual
  design* section + the epic header — port the mood into a SwiftUI token layer, not the wireframes'
  sketch chrome (Elm+Tailwind doesn't transfer; the aesthetic does).
- **Refreshed status** STUB → "pre-code (speced + backlogged)" in the system manifest + `CLAUDE.md`;
  pointed `CURRENT.md` at TRACK-000 as next (not started — "ingest into the backlog" was the ask).

**Verified:** docs-only (no code yet). The 7 root artifacts relocated (repo root clean of them); spec
cross-refs resolve to the new filenames; brief/backlog/manifest cross-link consistently. Note the
tracking-view **race-end question (OQ-1) is already resolved** in the spec (Finish-race control in the
AID tab) — TRACK-006 is unblocked on that point.

**Delivery:** branch `track/seed-mvp-backlog` → PR #160 (squash-merge to master).

**Next:** TRACK-000 — install Xcode, get a SwiftUI hello-world running in the Simulator from
`systems/track/`, decide Xcode-project-vs-SPM + the iOS deployment target (ADR), seed
`reference/local-ci.md`. Then TRACK-001 (WI-1 skeleton).

---
## 2026-06-25 — TRACK-000 started: Swift/iOS bootstrap (Phase A done; Phase B blocked on Xcode)

**Task:** TRACK-000 — Swift/iOS toolchain bootstrap + orientation (`CURRENT.md`). Branch
`track/track-000-swift-ios-bootstrap`.

**Environment probe:** macOS 14.3, Apple Silicon. **Only Command Line Tools installed** — `swift`
5.10 is present, but **no full Xcode** → no `xcodebuild`, no iOS SDK, no Simulator (`simctl` missing).
`brew` present; no xcodegen/xcodes/tuist.

**Decision (user · ADR-0001):** standard checked-in Xcode project (created via the New-Project
wizard), not XcodeGen/SPM — chosen for learnability (the build owner is new to iOS). Deployment
target **iOS 17.0** (revisitable; loosening to 16 costs `@Observable`).

**Phase A — done on the branch (no Xcode needed):**
- Verified the Swift *language* toolchain: compiled + ran a domain-model smoke (value types, enum
  with associated values, `Codable` round-trip) with CLT `swift` → passes (output quoted in
  `reference/local-ci.md`).
- Wrote ADR-0001 (+ INDEX), `reference/swift-orientation.md` (an Elm/Go → Swift primer anchored to
  track's domain), seeded `reference/local-ci.md`, and promoted TRACK-000 into `CURRENT.md` with
  phased acceptance criteria.

**Phase B — blocked on the user:** install Xcode (large App Store download), then create the project
via the wizard into `systems/track/`. Then I scaffold a minimal SwiftUI screen, build via
`xcodebuild`, run in the Simulator + screenshot, finalize `local-ci.md`, journal, and PR +
squash-merge the **complete** TRACK-000. **Not merging until the Simulator run is verified.**

**Next:** await "Xcode installed + project created," then Phase B (exact install + wizard steps
handed to the user).

---
## 2026-06-25 — TRACK-000 COMPLETE: Swift/iOS toolchain bootstrapped + first app runs in the Simulator

**Task:** TRACK-000 (Phase B). Branch `track/track-000-swift-ios-bootstrap` → PR #161 (squash-merged).

**Install reality (recorded for future-me — these were the time-sinks):** the App Store only offers
the newest Xcode (26.x → needs macOS 26.2); on **macOS 14.3** the ceiling is **Xcode 15.3** (iOS 17.4
SDK). `xcodes` via brew won't build on a CLT-only machine (needs `xcbuild` from full Xcode — a
catch-22), so 15.3 came from Apple Developer Downloads. It expanded/ran from `~/Downloads`, so
`xcode-select` failed until it was moved to `/Applications`. The iOS 17.4 **simulator runtime** is a
*separate* ~7 GB download (`xcodebuild -downloadPlatform iOS`) — the SDK alone gives compile +
Previews but no bootable simulator.

**What landed:**
- Standard Xcode project (ADR-0001) at `systems/track/Track/`; scheme `Track`, bundle
  `com.gillchristian.Track`. Removed the wizard's nested git repo; added `systems/track/.gitignore`.
- `ContentView` = a Trail-themed smoke screen (`#020617` ground, `#fbbf24` runner, "Track").
- **Verified:** `xcodebuild … -sdk iphonesimulator` → **BUILD SUCCEEDED**; booted iPhone 15 (iOS
  17.4), installed + launched, **simctl screenshot** at
  `reference/design/track-000-hello-simulator.png` — the app renders in the Simulator. The Swift
  *language* smoke (Codable event-log round-trip) was verified earlier on CLT swift.
- Docs: `reference/local-ci.md` finalized with the verified build/run/screenshot flow; ADR-0001 +
  `reference/swift-orientation.md` from Phase A.

**Deferred (correct scoping):** the wizard set the deployment target to **17.4**; **TRACK-001 pins
it** (WI-1 explicitly owns "pin iOS deployment target") — to 17.0 per ADR-0001.

**Next:** TRACK-001 (WI-1) — `NavigationStack` + empty Races-list root + persistence root dir + pin
the deployment target. The orientation note's Part 4 sketches the skeleton.

---
## 2026-06-25 — TRACK-001 COMPLETE: WI-1 project skeleton (Races list + durable race bundle)

**Task:** TRACK-001 (WI-1, `mvp-plan.md` §7). Branch `track/track-001-project-skeleton` → **PR #162**
(squash-merged). First real code on top of TRACK-000's bootstrap.

**What landed** (all in the existing `Track/Track/ContentView.swift` — see decision below):
- **`RacesView`** — `NavigationStack` root with the Races list. Empty state ("No races yet", amber
  `figure.run`); `+` toolbar button; swipe-to-delete. Status badge / duration / detail navigation are
  later WIs (they need `events.log` projections / the configure flow).
- **`Race`** — a deliberately minimal stub (`id`/`name`/`createdAt`), a forward-compatible slice of the
  full §4 model. **WI-2 grows it** (aidStations/palette/planRef) + adds the append-only log.
- **`RaceStorage`** — each race is a directory bundle `Documents/Races/<id>/race.json`, written
  `.atomic` (temp+rename); `loadAll()` scans the root, newest-first, skipping unreadable bundles.
  Root is **injectable** (`init(root:)`) so tests use a throwaway temp dir. WI-2 adds `events.log`
  (fsync per append) + `audio/` + hardened error handling — WI-1 deliberately stops at atomic
  `race.json` (the §3 "config" write), not the durability spine.
- **`@Observable RaceStore`** — list state; `addStubRace()` is a **placeholder** for WI-4's create flow
  (named so persistence is demonstrable). `-uitest-reset` launch arg clears the bundle root (UI-test hook).
- **Styling** — `Theme` enum (Trail tokens: #020617/#0b0b21/#fbbf24/#E52E3A/#22c55e) + **amber
  `AccentColor`** asset (tints `+`). Respects system light/dark (no forced scheme); the richer
  race-card styling lands with the tracking view (WI-6).

**Decisions:**
- **Deployment target pinned 17.4 → 17.0** (ADR-0001) across all three targets in `project.pbxproj`.
  Build confirms `--deployment-target 17.0`.
- **No new files added to the project.** Per ADR-0001 ("minimise pbxproj surgery; thin shell; add files
  via Xcode" — which an agent can't do interactively), WI-1's few types live in the wizard's
  `ContentView.swift`; the only build-setting change is the deployment-target value. **WI-2 reorganizes**
  into per-concern files (or adopts the ADR's pre-approved SPM-core-library split) when the domain grows.
- **Promoted the scheme to shared + committed** (`xcshareddata/xcschemes/Track.xcscheme`). It was
  autogenerated in **gitignored** `xcuserdata`, so `-scheme Track` / the test action weren't reproducible
  from a clean clone. The shared scheme pins the Test action to `TrackTests` + `TrackUITests`.

**Verified** (from `systems/track/Track/`, iOS 17.4 Simulator / iPhone 15):
- `xcodebuild build … -sdk iphonesimulator` → **BUILD SUCCEEDED**.
- `xcodebuild test …` → **TEST SUCCEEDED** — `TrackTests` 4 passed (RaceStorage round-trip = save →
  fresh-instance reload = "survives relaunch", delete, newest-first sort); `TrackUITests`
  `testStubRacePersistsAcrossRelaunch` passed (launch empty → tap `+` → `terminate()`/relaunch → row
  persists).
- Screenshots: `reference/design/track-001-empty-races.png` (empty), `track-001-races-list.png`
  (a row that survived a full simulator **reboot**). On-disk `race.json` confirmed
  (`{ createdAt, id, name }`, pretty/sorted). Commands recorded in `reference/local-ci.md`.

**Next:** **TRACK-002 (WI-2)** — domain model + durable persistence: the full §4 types, the append-only
`events.log` with **fsync per append**, atomic `race.json`, write-audio-then-append ordering, and the
`status`/`effectiveEnd`/`aidStationVisits` projections with retraction pre-filtering. The L-sized
durability spine — AC: append events programmatically, force-quit/relaunch with zero loss. This is also
the natural point to reorganize the WI-1 stub types out of `ContentView.swift` into their own files.

---
## 2026-06-25 — TRACK-002 COMPLETE: WI-2 domain model + durable persistence (the event-log spine)

**Task:** TRACK-002 (WI-2, `mvp-plan.md` §2/§3/§4/§7). Branch `track/track-002-domain-persistence` →
**PR #164** (squash-merged). The durability-critical spine — race data is unrepeatable.

**What landed:**
- **New `TrackCore.swift`** (Foundation-only, no SwiftUI). Lifted the WI-1 stub `Race`/`RaceStorage`
  out of `ContentView.swift`; this is the pure core (sets up the ADR-0001 SPM-core split cleanly when
  it's wanted). Added to the Track target via 4 `project.pbxproj` edits (build file / file ref / group /
  Sources phase — file refs `AA000…0001/0002`, verified by a clean build).
- **Full §4 model:** `Race` (+ tolerant `init(from:)` so WI-1 race.json still loads),
  `TrackableElement`/`TrackableCategory`, `PlannedAidStation`, `PlanRef`, `RaceEvent` + `RaceEventKind`
  (Codable **synthesized** for the enum-with-associated-values — confirmed on this toolchain).
- **Projections** (`extension Array where Element == RaceEvent`): `resolved` (drops retracted events
  *and* their retractions), `status`, `effectiveEnd` (latest correction › raceEnded.at › nil),
  `aidStationVisits` (pair by `visitID`; a new arrival implicitly departs the open visit →
  `.departedExitUnrecorded`; lone open → `.inProgress`). All fold `resolved`, so **a retraction hides
  its target everywhere**.
- **`RaceStorage` — the spine:** bundle `Races/<id>/{race.json, events.log, audio/}`. **events.log
  append-only, `fsync` (FileHandle.synchronize) after every append**; **atomic race.json** (write
  `race.json.tmp` → fsync → `replaceItemAt`/`moveItem`); **crash-tolerant load** (`split` on `\n` +
  `compactMap` decode — a torn last line is dropped, losing at most the in-flight write);
  **appendVoiceNote** writes audio → fsync → *then* appends the event (orphan audio is the safe
  failure, never a dangling ref). Compact encoder for the log (one JSON/line), pretty for race.json.
- `ContentView.swift` trimmed to the SwiftUI layer (Theme + `RaceStore` + views), store on the new API
  (`saveRace`/`loadAllRaces`/`deleteRace`). No UI change.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4):
- `xcodebuild build … -sdk iphonesimulator` → **BUILD SUCCEEDED** (no warnings).
- `xcodebuild test …` → **TEST SUCCEEDED** — **TrackTests: 17 passed** (race round-trip + atomic
  overwrite + legacy decode; events append/reload + torn-line recovery; status/effectiveEnd; visit
  pairing + forgot-to-Finish; retraction hides intake/aid-visit and reverts a retracted finish;
  voice-note ordering + orphan-not-dangling). **TrackUITests** relaunch-persistence still green (the
  refactor didn't break the running app). Pure-logic tests run in <0.03 s. Commands in `local-ci.md`.

**Decisions / notes:**
- **One Foundation-only core file** rather than several — bounds the pbxproj surgery to a single
  file-add (ADR-0001 "minimise pbxproj edits"); still cleanly separates core from the SwiftUI layer.
- Default `JSONDecoder`/`Encoder` date strategy (deferredToDate, full precision) — exact `Date`
  round-trip; tests use whole-second fixed dates for determinism.
- Edge left as-is (won't happen in practice, projection reflects literal events): a retracted
  `raceEnded` with a surviving `endTimeCorrected` → status inProgress but effectiveEnd non-nil.

**Next:** **TRACK-003 (WI-3)** — trackable library: CRUD UI + storage for `TrackableElement` (label +
category); the source for race palettes (`mvp-plan.md` §6.5, §7 WI-3). First UI-bearing feature on top
of the WI-2 core (a `TrackableElement` store + a list/edit screen). Smaller (S).

---
## 2026-06-25 — TRACK-003 COMPLETE: WI-3 trackable library (CRUD + storage)

**Task:** TRACK-003 (WI-3, `mvp-plan.md` §6.5, §7). Branch `track/track-003-trackable-library` →
**PR #165** (squash-merged). First UI feature on the WI-2 core.

**What landed:**
- **New `TrackableLibrary.swift`** (SwiftUI): `TrackableLibraryStore` (`@Observable`, mirrors
  `RaceStore`) + `TrackableLibraryView` (a `List` with swipe-delete + an empty state) + a
  create/edit **sheet** (`TrackableEditor`: label `TextField` + category `Picker`; `Save` disabled on
  blank). Reached from a new **leading toolbar action** on `RacesView` (`openLibrary` →
  `NavigationLink` push). Category rows show an SF Symbol per category (presentation-only extension).
- **`TrackableLibraryStorage`** (in `TrackCore.swift`): the library is a flat list persisted as
  **`trackables.json`** at the persistence root (sibling to `Races/`), written atomically (config,
  not the append-only log). `load()`/`save()`; root injectable for tests.
- **Refactor:** extracted the shared `temp → fsync → rename` primitive into **`DurableFile`**
  (`sync` + `atomicWrite`); `RaceStorage.saveRace` and `appendVoiceNote` now call it, as does the
  library store — one correct durability primitive (a deliberate rule-of-three exception: durability
  code shouldn't be duplicated; the 17 WI-2 tests guard the refactor). Added `TrackableCategory.displayName`.
- Added `TrackableLibrary.swift` to the Track target via 4 `project.pbxproj` edits (file refs
  `AA…0003/0004`). The pbxproj-add procedure is now routine (2-tab section entries, 4-tab list entries).

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4):
- `xcodebuild build … -sdk iphonesimulator` → **BUILD SUCCEEDED** (no warnings).
- `xcodebuild test …` → **TEST SUCCEEDED** — **TrackTests: 22** (17 WI-2 + 5 library: storage
  round-trip, store upsert-create/edit, create + delete persistence across reload). **TrackUITests: 2**
  — `testTrackablePersistsAcrossRelaunch` drives the real screen (open from the Races toolbar → empty
  state → `+` → type a label → Save → row appears → `terminate()`/relaunch → persists). No static
  screenshot: the UI test exercises the new surface end-to-end (the WI-1 dark+amber look is unchanged).

**Notes / scope:** the race-palette picker that *consumes* the library is **WI-4** (create/configure
race), as is promote-ad-hoc-to-library. WI-3 is the library itself. UI-test note: the row is a
`.buttonStyle(.plain)` Button, so its label absorbs the child Texts — the test matches on
`buttons` with a `label CONTAINS` predicate rather than `staticTexts`.

**Next:** **TRACK-004 (WI-4)** — create / configure race: name + optional date, manual aid stations,
palette from the library (multi-select) + ad-hoc create, save → **Configured** (`mvp-plan.md` §6.2,
§7 WI-4). Wires the library into race creation and replaces the WI-1 `addStubRace` placeholder with the
real form. (M.)

---
## 2026-06-25 — TRACK-004 COMPLETE: WI-4 create / configure race + status badge

**Task:** TRACK-004 (WI-4, `mvp-plan.md` §6.2, §7). Branch `track/track-004-create-configure-race` →
**PR #166** (squash-merged). Replaces the WI-1 stub create flow with the real form; wires WI-3's
library in as the palette source.

**What landed:**
- **`RaceDraft`** (in `TrackCore.swift`, Foundation-only): the create/configure editing buffer — name
  + optional date, aid stations with auto-maintained **1-based ordinals** (add/delete/reorder), and a
  palette **snapshot** toggled/matched by id. Pure value logic so the ordinal/palette rules are
  unit-testable without the SwiftUI layer. `build(createdAt:)` freezes it into a `Race`.
- **`CreateRaceView.swift`** (new SwiftUI file): a `Form` sheet presented from the Races `+`. Sections:
  race (name `TextField` required + Save-disabled-when-blank; optional date toggle → `DatePicker`);
  aid stations (rows with ordinal prefix + name field; section-header `EditButton` drives
  reorder/delete; "Add aid station"); palette (library items as checkmark toggle rows + ad-hoc rows;
  "Add custom item" → `AdHocItemEditor`: label + category + **Add to library** opt-in promote).
- **`RaceStore`** (`ContentView.swift`): `add(_:)` (persist + insert newest-first) and a
  **`status(for:)` projection** that folds `events.log` (configured race → `.configured`); dropped
  `addStubRace`. The `+` toolbar presents the sheet. New **`StatusBadge`** on each row (amber
  Configured / race-red In-progress / green Finished); the row date shows the scheduled date (day) when
  set, else `createdAt` (with time).
- **`RaceStorage.reset()` / `TrackableLibraryStorage.reset()`** + `TrackableCategory.symbolName` made
  internal (shared by the library + palette rows). Registered `CreateRaceView.swift` in the Track
  target (4 `project.pbxproj` edits, ids `AA…0005/0006`).

**Durability bug fixed (latent since WI-1, surfaced by the new sheet):** the `-uitest-reset` wipe lived
in the stores' `init`s. SwiftUI re-evaluates a view's `@State = Store()` **default expression on every
re-creation** of that view — so presenting/dismissing the create sheet re-ran the destructive reset and
**deleted the just-created race** before relaunch. Proven by NSLog: two `RESET running` lines in one
pid, the second *after* the race was created. The on-disk persistence was always sound — a `simctl`
terminate/relaunch reloaded the race fine (`races=1`). **Fix:** moved the one-time reset to
`TrackApp.init` (runs once per process); the stores' inits now only `load()` (reconstruction-safe).

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4):
- `xcodebuild build … -sdk iphonesimulator` → **BUILD SUCCEEDED** (no warnings).
- `xcodebuild test …` → **TEST SUCCEEDED** — **TrackTests: 28** (+6 WI-4: `RaceDraft` name
  validation/trim, ordinal renumber on delete + move, palette snapshot-by-id, `build` → configured
  race; `RaceStore.add` persists + `.configured` across reload). **TrackUITests: 2** — the WI-1 stub
  test became `testConfiguredRacePersistsAcrossRelaunch` (tap `+` → wait for the field hittable → type
  name → wait for Save enabled → Save → row + **Configured** badge → `terminate()`/relaunch → persists).
- Screenshot of the Configured list (two seeded races, both badged): `reference/design/track-004-races-configured.png`.

**Notes / scope:** out of scope (later WIs) — CSV import (WI-5); race detail / Start / tracking /
duration-when-finished (WI-6/7); editing an existing race's config. UI-test hardening: the heavier
3-section sheet races its presentation animation, so the test waits for the name field to be `hittable`
and for Save to become `isEnabled` (which also confirms the typed name registered) before tapping.

**Next:** **TRACK-005 (WI-5)** — aid-station CSV import: parse Trail's CSV (columns **name, services,
distance**) into `[PlannedAidStation]`; lift Trail's exact `services` cell encoding/delimiter from its
parser. AC (§7 WI-5): import a Trail CSV; name/services/distance populate; stations editable; views can
derive distance-to-next. Deps: TRACK-004. (S/M.)

---
## 2026-06-26 — TRACK-005 COMPLETE: WI-5 aid-station CSV import

**Task:** TRACK-005 (WI-5, `mvp-plan.md` §5, §7). Branch `track/track-005-aid-station-csv-import` →
**PR #167** (squash-merged).

**Resolved the residual first.** The plan said "lift the exact services cell encoding/delimiter from
Trail's parser." An `Explore` agent read `systems/trail/src/AidCsv.elm` and found Trail's real format
is **richer** than the plan's "name/services/distance" shorthand: columns
`name,distance_km,rest_min,services,cutoff,notes`, a header row, **RFC-4180 quoting**, comma-*or*-`;`
delimiter, services **pipe-joined** (import also accepts `/` and, under a comma delimiter, `;`), and
km/mi distance headers. Decision: import only the **three columns the tracker models** (name,
`distance_km`→`distanceKm`, services) and ignore `rest_min`/`cutoff`/`notes` (plan richness → WI-9);
keep services as **raw cell tokens** (the tracker is a passive recorder, not Trail's typed `Service`
enum).

**What landed:**
- **`AidStationCSV`** (Foundation-only, `TrackCore.swift`): an RFC-4180 tokenizer (quoted fields with
  embedded delimiters/newlines + doubled `""`), delimiter detection (`;` only if it out-counts `,` on
  line 1), header→column mapping with a positional fallback to Trail's order, km/mi handling, and
  `splitServices` (`|`/`/`/`;`, trim, drop empties) — lifted from Trail's `splitServices`. Lenient like
  Trail: optional header; a row missing a name or parseable distance is skipped + counted
  (`Result.skippedRows`).
- **`[PlannedAidStation].distanceToNextKm(after:)`** — cumulative legs, so a view can show "→ next
  aid: N km".
- **`RaceDraft.replaceAidStations(with:)`** (renumber to 1-based) + **`CreateRaceView`** import button +
  `.fileImporter` (`.commaSeparatedText`/`.plainText`, security-scoped read, UTF-8) → replaces the
  aid-station list with a result alert. Footer updated.

**Bug found + fixed (Swift grapheme gotcha):** the first full run failed — the two CRLF test inputs
parsed to **zero** stations and the test then trapped on `stations[0]` (this is the crash report that
surfaced mid-run: an `Index out of range` in the **test process**, not the app). Cause: Swift treats
`"\r\n"` as a **single `Character`** (one grapheme cluster), so a Character-by-Character tokenizer
never matched CRLF against `"\n"`/`"\r"` — CRLF files never split into rows (everything collapsed into
the header → no data rows). Fix: `parse()` normalises CRLF/CR → LF up front; the tokenizer now only
needs `"\n"`. Added a count-guard in the quoted-field test so a future regression fails as an assertion
rather than trapping the suite. LF inputs were unaffected (lone `\n` is its own Character), which is
why only the explicit-`\r\n` tests failed.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4):
- `xcodebuild build … -sdk iphonesimulator` → **BUILD SUCCEEDED** (no warnings).
- `xcodebuild test …` → **TEST SUCCEEDED** — **TrackTests: 40** (+12 WI-5: canonical Trail export,
  services separators, RFC-4180 quoted comma-name + doubled quote, miles→km, malformed-row skip,
  headerless positional, `;`-delimiter + EU decimal, CRLF+BOM, empty input; `distanceToNextKm`;
  `replaceAidStations` renumber; CSV→draft→`Race`→bundle round-trip). **TrackUITests: 2** (the
  create-form test also asserts the `importAidCsv` affordance).

**Notes / scope:** the `.fileImporter` **Files-app picker is system UI — not XCUITest-automatable**, so
the import is verified by the parser + integration unit tests (real Trail CSV in → correct stations →
persisted `Race`) and the in-form affordance assertion, rather than an end-to-end picker tap. Import
**replaces** the aid-station list (deliberate "load a plan's stations" action). Out of scope: CSV
*export*; `.trail` ingestion (WI-9); `rest_min`/`cutoff`/`notes`.

**Next:** **TRACK-006 (WI-6)** — race tracking view (the in-race four-tab surface; `tracking-view-spec.md`).
The big one (L): category grids → `intake`, AID tab → enter/exit + Finish race, Feed projection,
foreground voice notes, Undo→retraction; every action appends + fsyncs. Deps: TRACK-002/004/005.

---
## 2026-06-26 — TRACK-006 COMPLETE: WI-6 race tracking view

**Task:** TRACK-006 (WI-6, `tracking-view-spec.md`; `mvp-plan.md` §6.3, §7). Branch
`track/track-006-race-tracking-view` → **PR #168** (squash-merged, `c320e81`). Close PR:
`docs/track-006-close`. The big one (L) — first build a race can actually be run on.

**Resolved the open questions first** (spec §8; OQ-1 race-end was already resolved):
- **OQ-2 notes** → render the current station's **services** (a dedicated plan-notes field waits for `.trail`, WI-9).
- **OQ-3 category→tab** → Nutrition = `{nutrition, hydration}`, Others = `{gear, other}` (matches the §4 type comment).
- **OQ-4 feed ordering** → **newest-first**.
- **OQ-5 grid overflow** → grids **scroll**.
- **OQ-6 undo breadth** → **toast-only / most-recent** for MVP.

**No `mvp-plan.md` §4 domain change.** The whole event spine WI-6 needs — `aidStationEntered/Exited`,
`retraction`, the three-state `VisitState`, and `resolved`/`aidStationVisits`/`status`/`effectiveEnd` —
already landed in WI-2. WI-6 is the SwiftUI surface + *pure* view projections + a session view-model.

**What landed:**
- **`TrackCore.swift`** (Foundation-only, unit-tested): `TrackingTab` (cyclic `next`/`previous` + the
  category→tab buckets), `Race.paletteItems(for:)` / `services(forVisitOrdinal:)` / `aidBoard(for:)`,
  the `AidBoard` + `FeedEntry` render models, `[RaceEvent].feedEntries` (resolves aid-exit labels from
  the matching arrival as it folds; drops retracted, omits corrections) + `.startedAt`, `RaceFormat.duration`,
  and **`RaceTracker`** — the `@Observable` session model: each action does a durable append (fsync) then
  mirrors it in memory; `start` / `track` / `arrive` / `finishAid` / `startAdHocAid` / `finishRace` /
  `addVoiceNote` / `undoLast`; `lastAction` drives the Undo toast (Start/Finish are deliberately not toast-undoable).
- **`TrackingView.swift`** (new file): the four-tab shell + a **cyclic** horizontal swipe (`simultaneousGesture`,
  so the grids/lists keep scrolling and tiles keep their taps); the two trackable grids (`LazyVGrid`,
  category-tinted high-contrast tiles); the **AID manager** (Passed → Current + green Finish → services notes →
  Upcoming-marks-arrival in planned mode; past visits + **Start new aid station** in plan-less mode; a distinct
  **Finish race** control with a confirm dialog); the read-only **Feed** (newest-first, category-colored icons,
  no chrome); the **record-voice button** + `AudioRecorder` (AVFoundation, foreground tap-record-tap-stop, mono
  AAC/m4a, `AVAudioApplication.requestRecordPermission`); the **Undo toast** (→ `retraction`, ~10s auto-dismiss
  via `.task(id:)`); `RaceDetailView` (status branch: Configured → `StartRaceView`, In-progress → `TrackingView`,
  Finished → a **minimal** read placeholder — full post-race view is WI-7); a `#Preview`.
- **`ContentView.swift`**: list rows → `RaceDetailView` (`NavigationLink`); `RaceStore.refreshStatuses()` on
  reappear (status/duration are projections, refreshed after start/finish in the detail); **duration-when-finished**
  on the row.
- **`project.pbxproj`**: registered `TrackingView.swift`; added `INFOPLIST_KEY_NSMicrophoneUsageDescription`.

**Bug caught by the UI test (and fixed before merge):** the cyclic swipe did nothing — a `DragGesture` on a
container only receives touches where the container is hit-testable, and a `VStack`'s empty/transparent regions
aren't. A scripted left-drag (Nutrition→AID) failed until I added **`.contentShape(Rectangle())`** to the tracking
surface. This was a real defect for users too (swiping over empty space), not just a test artifact.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4):
- `xcodebuild build … -sdk iphonesimulator` → **BUILD SUCCEEDED** (no warnings).
- `xcodebuild test …` → **TEST SUCCEEDED — TrackTests 52** (+12 WI-6: cyclic tab math, palette buckets,
  `feedEntries` label-resolution/retraction/correction, `AidBoard` planned-progression / forgot-to-Finish /
  plan-less, `RaceFormat.duration`, and the `RaceTracker` flows incl. relaunch + durable voice note) **·
  TrackUITests 3.** The new UI test `testTrackingDurablyLogsAnEventAcrossRelaunch` drives the real app:
  create → Start → **swipe** Nutrition→AID → ad-hoc arrival → **Undo toast** appears → Feed lists it →
  terminate/relaunch → the in-progress race reopens and the event is still logged (append + fsync survived).
- Live tracking-view screenshots (captured via `XCUIScreen.main` from the UI test, extracted with
  `xcresulttool`): `reference/design/track-006-aid-tab.png` (current visit + Finish + Start-new-aid + Finish-race
  + Undo toast + record button + tab bar) and `track-006-feed.png` (newest-first stream).

**Notes / scope:** the **live mic** is Simulator-limited (the AVAudioApplication permission alert is system UI),
so voice-note durability is proven by the WI-2 `appendVoiceNote` ordering test + a new `RaceTracker` durability
test + the in-app affordance, mirroring WI-5's `.fileImporter` precedent — not a real mic capture. The intake-grid
tile→`intake` path shares the same append spine and is unit-covered (`testRaceTrackerStartTrackUndoFinish`); the
UI test drives the AID path to avoid the lazy create-form palette setup. Out of scope → **WI-7 (TRACK-007)**:
inline clip playback, edit-finish-time (`endTimeCorrected`), the full per-visit summary; WI-6 ships only a minimal
finished placeholder so the finish flow is reachable + verifiable.

**Next:** **TRACK-007 (WI-7)** — race view (post-race; `mvp-plan.md` §6.4, §7 WI-7): resolved chronological
event stream, inline clip playback, edit-finish-time → `endTimeCorrected`, summary (counts + per-visit time).
Replaces the WI-6 minimal finished placeholder. Deps: TRACK-002, TRACK-006. (M.)

---
## 2026-06-26 — TRACK-006 follow-up: cancel a started aid station (user-reported)

**Trigger (user):** "There's no undo for a new aid station. If I start one the only option is to finish it."
Real gap: the Undo toast is **most-recent-only and auto-dismisses (~10s)**, so once it's gone (or another
action replaces it), a mistakenly-started aid station could only be **Finished** — which logs a bogus
*departed* visit instead of removing it. Branch `track/track-006-aid-cancel` → **PR #170** (squash-merged).

**Fix:** a persistent **Cancel arrival** control on the in-progress station row (`RaceTracker.cancelAid(_:)`
→ appends a `retraction` targeting that visit's *arrival* event, found by `visitID`). Same one-rule
invariant as Undo — a retraction, never a mutation. The fold then drops the visit: in planned mode the
station returns to **Upcoming**; a plan-less ad-hoc visit just disappears. If the toast still referenced
that arrival, it's cleared. Styled as a small white-tinted bordered chip under the arrival time — clearly
secondary to the prominent green Finish, so it can't be mis-tapped for it.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4): **BUILD SUCCEEDED** (no warnings);
**TrackTests 54** (+2: cancel restores the planned station to Upcoming and removes it from the Feed; cancel
of a plan-less ad-hoc visit) **· TrackUITests 3** (the durability test now also asserts the `cancelAid`
affordance renders on the current station). Refreshed `reference/design/track-006-aid-tab.png` to show the
Cancel control. Note: this tightens the spec's OQ-6 resolution (toast-only) — per-station cancel is now in
for the in-progress station; broader per-row Feed retraction stays deferred.

---
## 2026-06-26 — TRACK-007 COMPLETE: WI-7 race view (post-race)

WI-7 (`mvp-plan.md` §6.4, §7), the **last MVP-critical** item. Branch `track/track-007-race-view` →
**PR #171** (squash-merged). Replaces the WI-6 minimal finished placeholder with the full post-race surface.

**What.** A finished race now opens to: a **summary** — big total duration, start→effective-end span, and
counts (aid visits / intakes / notes); an **Aid stations** section with per-visit **dwell** (exit − entry,
"—" when the exit was never marked — GPS reconstructs it later, app 3); **Intake totals** (per item, a count
of intake events, most-consumed first); the **chronological timeline** (oldest→newest, retractions applied,
the finished row showing the *effective* end); **inline clip playback** (the one place audio plays — kept out
of the in-race Feed); and **Edit finish time** → `endTimeCorrected`.

**Domain (`TrackCore.swift`), all pure folds over the resolved log:** `RaceSummary` + `summary` projection;
`FeedEntry.Kind.voiceNote` now carries the `audioFilename` (so the post-race view can play it; the in-race
Feed ignores it); `RaceTracker.correctEndTime(to:)` appends `endTimeCorrected` (never a mutation — `effectiveEnd`
already prefers the latest correction), plus `summary` + a `clipURL(filename:)` accessor. **No `mvp-plan.md` §4
change** — every event kind it needs (`endTimeCorrected`, `voiceNote`, `retraction`) landed in WI-2.

**View (`TrackingView.swift`):** `FinishedRaceView` as a sectioned `List`; a small `AVAudioPlayer` wrapper
(`AudioPlayer`, one clip at a time, the row glyph + a11y value reflect play state); an `EditFinishView` sheet
with a live duration preview and a finish-never-before-start bound. Refactor: `FeedEntry.Kind` icon/tint/title
are now shared by the in-race `FeedRow` and the post-race `TimelineRow` (via a `FeedIcon` + a private extension).

**Decisions.** Timeline is **oldest→newest** — "chronological" (§6.4), deliberately unlike the in-race Feed's
newest-first (OQ-4); it reads as the race's story start→finish. Corrections are **not** their own timeline rows
(the effective end is applied where the finish renders). Per-item intake totals included (cheap; in §6.4).
`.trace` export stays deferred (WI-8).

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4): **BUILD SUCCEEDED** (no warnings);
**TrackTests 54→59** (+5: summary counts/dwell incl. unrecorded-exit → nil; intake-total ranking + 1-count
tie-break by label; retraction + correction honoured; `correctEndTime` preserves the original `raceEnded` and
survives relaunch; feed carries the clip filename + `clipURL` resolves it) **· TrackUITests 3→4** (+1:
`testFinishedRaceShowsSummaryTimelineAndEditFinish` — finish end-to-end → summary + timeline render →
edit-finish flow commits). **Clip playback verified manually** in the Simulator (record → finish → play; the
control flips to "playing" — a temporary recording-based UI test, mic pre-granted via `simctl privacy grant`,
confirmed it, then removed): audio in an XCUITest is unreliable, so the committed suite stays recording-free,
matching WI-6's choice. Screenshots: `reference/design/track-007-{summary,timeline}.png`.

**Next:** WI-8 (`.trace` export) and WI-9 (`.trail` ingestion) are **deferred** (§7–8): `.trace` waits until
≥2–3 real races settle the event vocabulary. With WI-7 done, the MVP is feature-complete — the first real test
is running an actual ultra on the WI-6/WI-7 build (the hand-off brief's definition of "done").

---
## 2026-06-26 — TRACK-008 COMPLETE: tracking-view fixes from the first simulated race

The first real test (a simulated race) surfaced three issues. Branch `track/track-008-tracking-view-fixes` →
**PR #172** (squash-merged). Not a planned WI — user-reported field fixes.

**1. Aid-station notes (new).** Added a free-text `notes` field to `PlannedAidStation` (with a tolerant
`init(from:)` — same reasoning as `Race`: `notes` post-dates the first bundles, so default it rather than fail
the whole aid-station array and drop the race from the list). Editable per station in `CreateRaceView` (a
multiline field under the name; note: a `TextField(axis:.vertical)` surfaces as a **text view** in XCUITest).
Shown when the active station expands on the AID tab via a new `AidInfoCard(title:text:)`. The pre-existing
services card was mislabelled "Notes" — now correctly **"Services"** (so both can show, distinctly).
`Race.notes(forVisitOrdinal:)` mirrors `services(forVisitOrdinal:)`. (Spec had deferred a dedicated notes field
to WI-9/`.trail`; brought forward on request for manual entry.)

**2. Undo-toast replacement bug.** Tracking a second item dismissed the first toast but showed no new one.
**Root cause:** `autoDismissToast` used a bare `try? await Task.sleep(10s)`. A new action bumps
`lastAction.token`, which is the `.task(id:)` key → SwiftUI **cancels** the running task and starts a fresh one.
The cancelled sleep throws `CancellationError`, but `try?` swallowed it and execution fell through to
`dismissToast()` — clearing the just-set replacement within a frame. Fixed: `do/catch` that **returns** on
cancellation. Chose **replace** (not stack): the design is most-recent-only Undo (the cancel-aid journal note
already calls the toast "most-recent-only"); stacking adds mid-race complexity for little gain.

**3. Recording lost when leaving for the Feed.** The recorder (a `@State` on `TrackingView`) already survives
switching among the tracking tabs — but the read-only **Feed** has no record/stop control, so switching there
left a recording un-stoppable and the clip never got saved ("never showed in the Feed"). Fix: while recording,
Feed is **disabled** in the tab bar and **skipped** by the cyclic swipe (new testable
`TrackingTab.next/previous(excludingFeed:)`), and `TrackingView.onDisappear` stops+saves any in-progress clip
(a Back tap mid-record no longer drops it — `AudioRecorder.stopIfRecording`).

**Also:** the AID **Upcoming** row (`UpcomingAidRow`, a `.plain` button whose label has a `Spacer`) had a dead
center — a tap landing in the gap between the name and "Mark arrival" did nothing. Added `contentShape(Rectangle())`
so the whole row is the tap target. (Surfaced while writing the notes UI test, whose `arrive.tap()` hit the gap.)

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4): **BUILD SUCCEEDED** (no warnings);
**TrackTests 59→63** (+4: note round-trip; tolerant decode of a note-less station; `notes(forVisitOrdinal:)`;
`TrackingTab` swipe skips Feed while recording) **· TrackUITests 4→6** (+2: a new action replaces the Undo toast
and it persists past a settle; aid-station notes show at the active station). Recording + Feed-lock verified
**manually** (Feed disabled while recording; recording survives tab switches; the clip lands in the Feed) — a
temporary mic-granted UI test confirmed it, then removed to keep the suite recording-free (matching WI-6/WI-7).

**Next:** unchanged — WI-8/WI-9 deferred; the MVP stands feature-complete, now a bit more robust for the next
real-race test.

---
## 2026-06-26 — TRACK-009 COMPLETE: always-in-race-mode (active race locked to the forefront)

User UX feedback from race testing: the active race should always be front-and-centre — you shouldn't be able
to leave it mid-race, and reopening the app should drop you straight back into it ("race mode" during a race).
Branch `track/track-009-active-race-lock` → **PR #173** (squash-merged).

**Behavior.** (1) **Can't leave a started race** — while in progress, `TrackingView` hides its back button,
which also disables the swipe-back-to-pop gesture, so there's no way out until the race is finished. The finish
flow (AID tab → Finish race, with confirm) is the only exit; the back button returns on the finished (read)
view, so post-race review is leavable. (2) **Reopen into the active race** — a cold launch with an in-progress
race opens straight to its tracking view, no flash of the list. Browsing configured/finished races + the library
is unchanged (normal push + back).

**Implementation.** `RacesView` became a typed `NavigationStack(path: [RaceRoute])` (`.race(id)` / `.library`),
value-based `NavigationLink`s + `navigationDestination`. The initial path is computed in `RacesView.init` from
`RaceStore.inProgressRace` (→ `[.race(id)]`), so the jump is **flash-free** and only fires at construction (a
killed-and-reopened app); a warm resume keeps the existing `@State path`. No `scenePhase` juggling needed — if a
race is in progress you're *already* locked onto it, so there's no "on the list with an active race" state to
resync. `TrackingView` gained `.navigationBarBackButtonHidden(true)`. `RaceStore` gained `inProgressRace` +
`race(for:)`. At most one in-progress race exists once the lock holds; legacy multi-in-progress → newest wins.

**Decision: lock via `navigationBarBackButtonHidden`, not a `fullScreenCover`.** The cover gives a structurally
unescapable modal, but it fights the start-race transition (a pushed StartRaceView → cover) and the title bar.
Hiding the back button on the pushed `TrackingView` is the smaller change, keeps the existing browse-then-push
flow, and (verified) also kills the swipe-back gesture — so it's escape-proof in practice.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4): **BUILD SUCCEEDED** (no warnings);
**TrackTests 63→64** (+1: `RaceStore.inProgressRace` across configured→started→finished + `race(for:)`) **·
TrackUITests 6→7** (+1: `testActiveRaceLocksAndReopensOnLaunch` — start → assert no "Races" back button → kill →
relaunch lands directly on the tracking view, not the list). Also **updated** the WI-6 durability test
(`testTrackingDurablyLogsAnEventAcrossRelaunch`): its relaunch assertion expected the list's in-progress badge,
but the new behavior reopens the tracking view — so it now asserts that directly (and that `addRace` is absent,
i.e. we're not on the list). A good sign the lock works: the change *forced* that test to update.

**Next:** unchanged — WI-8 (`.trace`) / WI-9 (`.trail`) deferred. The MVP is feature-complete and now behaves
like a race-day companion: start a race and the app stays on it, through a kill/relaunch, until you finish.

---
## 2026-06-26 — TRACK-010 COMPLETE: on-device testing prep (icon + run-on-phone guide)

User wants the app on their phone for the next race: use Trail's icon, and a guide for running it (they asked "is
it TestFlight?"). Branch `track/track-010-device-testing-prep` → **PR #174** (squash-merged). Worked autonomously.

**Audited what's needed for a real-device install** — most of it was already in place:
- **Microphone usage string** — already set (`INFOPLIST_KEY_NSMicrophoneUsageDescription`). This was the big risk
  (a missing string crashes the app on the first record tap); it's fine.
- **Signing** — `CODE_SIGN_STYLE = Automatic`, no `DEVELOPMENT_TEAM` (correct — that's the user's Apple ID, set
  in Xcode). **Entitlements** are only macOS-sandbox keys (`app-sandbox`, `files.user-selected.read-only`),
  harmless on iOS and not in the free-team restricted set — so a free Apple ID works.
- **Version** 1.0 / build 1, **deployment target iOS 17.0**, no network/GPS/background. Minimal footprint.
- The real gap was the **app icon** (the `AppIcon.appiconset` had a placeholder `Contents.json`, no image).

**Icon.** Rasterized Trail's `systems/trail/public/icon.svg` (the navy mountain-peak with amber/green
trail-marker dots — same palette as the app's `Theme`). For iOS: removed the SVG's `rx` rounding so the
background is a **full-bleed opaque square** (iOS masks its own corners), rendered at **1024×1024 via QuickLook**
(WebKit renders the gradients faithfully — ImageMagick's internal SVG renderer dropped the gradient + the peak
path, leaving only the dots), then flattened to **opaque sRGB, no alpha** (App Store-clean). Wired it as the
single modern iOS icon (`Contents.json` → one `universal/ios/1024x1024` entry; dropped the vestigial mac slots
from the multiplatform template).

**Guide.** `reference/device-testing.md` — written for someone new to iOS deployment. Recommends **direct install
from Xcode on a free Apple ID** (no $99, no TestFlight) with the full signing/trust steps and the **7-day
free-provisioning expiry** caveat (re-Run within a week of the race); covers **TestFlight** as the paid
alternative (90-day builds, OTA) and why it's overkill for one race; plus a **race-day checklist** (install within
7 days, pre-configure the race, dry-run incl. mic-permission grant, **Auto-Lock → Never**, power bank, airplane
mode OK) and reassurance that the TRACK-009 lock keeps you in the race through sleeps/kills.

**Verified** (from `systems/track/Track/`): **Simulator BUILD SUCCEEDED** — `actool` generated all icon sizes
(`AppIcon60x60@2x.png` … `76x76@2x~ipad.png`) from the single 1024, confirming the asset is valid. **Device
arm64 build (no signing) BUILD SUCCEEDED** (`-sdk iphoneos CODE_SIGNING_ALLOWED=NO`) — the app compiles for real
hardware; only the user's Team-based signing remains, which is a one-click Xcode step. Unit tests still **64**
(no Swift changed). Could not do the final signed install myself (needs the user's Apple ID) — that's the guide.

**Housekeeping.** Stopped pre-reserving `TRACK-NNN` for the deferred WIs in `BACKLOG.md` (they were colliding with
ad-hoc tasks each time one was pulled). They're now tracked by `WI-N` only and get a `TRACK` id on promotion.

**Next:** the app is ready for a real-device race test. After the first real race, revisit WI-8 (`.trace` export)
once the event vocabulary has settled (the `mvp-plan.md` deferral condition).

---
## 2026-06-26 — TRACK-011 COMPLETE: race-day hardening (portrait lock + keep screen awake)

Found while smoke-testing the TRACK-010 device build (installed to the simulator, screenshotted): the app
rendered in **landscape** — it allowed rotation — and being foreground-only it would also sleep mid-race. Two
gaps for a one-handed, glanced-at, hours-long race-day app. The user had explicitly asked me to figure out
what else is missing, so I fixed both. Branch `track/track-011-race-day-hardening` → **PR #175** (squash-merged).

**1. Portrait-lock (iPhone).** Both build configs' `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` →
`UIInterfaceOrientationPortrait` only (was Portrait + LandscapeLeft + LandscapeRight). The whole UI (tab bar,
grids, bottom-corner toast/record chrome) is portrait-designed, and accidental rotation mid-run is exactly the
kind of thing a tired/jostled runner doesn't want. iPad orientations left untouched (the race device is a phone).

**2. Keep the screen awake during a race.** The app is foreground-only — a screen auto-lock would stop you
recording and hide the tabs. `TrackingView.onAppear` sets `UIApplication.shared.isIdleTimerDisabled = true`,
`onDisappear` clears it (next to the existing stop-and-save-recording-on-disappear). Scoped to the in-progress
tracking view only, so the list / configured / finished screens sleep normally. Better than telling the user to
change Auto-Lock by hand (the guide's checklist item is now optional). `UIApplication` is reachable without an
explicit `import UIKit` (SwiftUI pulls it in).

**Verified** (from `systems/track/Track/`): **BUILD SUCCEEDED**; full suite **TrackTests 64 · TrackUITests 7**,
no failures. Neat confirmation of the orientation lock: `TrackUITestsLaunchTests` (which runs once per target UI
configuration) dropped from **4 → 2** runs — fewer orientations to launch-test. The built `Info.plist` shows
`UISupportedInterfaceOrientations~iphone = [UIInterfaceOrientationPortrait]`. Both changes are config/side-effect
with no clean automated test; verified by build + that signal + reasoning. Also marked TRACK-010 complete in
`CURRENT.md` (it was merged but I'd missed flipping its CURRENT entry — bundled its close docs in the one PR).

**Next:** unchanged — the app is genuinely race-ready now (icon, portrait, screen-awake, locked to the active
race, durable). The user installs it via `reference/device-testing.md`; deferred WIs wait on real-race data.

---
## 2026-06-26 — TRACK-012 COMPLETE: fix iOS device signing (empty the macOS entitlements)

The user hit *"Entitlements file 'Track.entitlements' was modified during the build, which is not supported"*
on their **first real device build** in Xcode. Branch `track/track-012-fix-ios-entitlements` → **PR #176**.

**Cause.** `Track.entitlements` carried **macOS App Sandbox** keys — `com.apple.security.app-sandbox` and
`com.apple.security.files.user-selected.read-only` — a leftover from the multiplatform project template. iOS
signing strips keys it doesn't support, and rewriting the source entitlements file mid-build is the exact thing
that error forbids. My simulator and `CODE_SIGNING_ALLOWED=NO` device builds never sign, so I never hit it — and
in the TRACK-010 audit I wrongly called these "free-team-compatible / harmless on iOS." **Lesson: runtime-harmless
≠ sign-time-harmless; an entitlements audit needs a *signed* build.**

**Fix.** Empty the file to `<dict/>`. The app needs **no** entitlements on iOS — the mic is an Info.plist usage
string (not an entitlement), and the CSV `.fileImporter` uses security-scoped URLs (no entitlement). Kept the
`CODE_SIGN_ENTITLEMENTS` reference pointing at the now-empty file (minimal; no `project.pbxproj` surgery).

**Verified — with a *real signed device build*** (not just no-signing): the user's `DEVELOPMENT_TEAM` was now in
the working tree, so `xcodebuild -sdk iphoneos -destination generic/platform=iOS -allowProvisioningUpdates
DEVELOPMENT_TEAM=…` actually ran `codesign --sign … --entitlements …Track.app.xcent` and reported
`** BUILD SUCCEEDED **`. So the app signs cleanly for a device now. (The user had independently removed the
App Sandbox **capability** in Xcode's Signing & Capabilities — the same fix from the UI side; the empty
capabilities list is correct, the app needs none.) Guide gained a Troubleshooting section incl. this error.

**Left uncommitted (intentionally):** the user's `project.pbxproj` working-tree changes — their personal
`DEVELOPMENT_TEAM = U959A2354F` and Xcode-added `CFBundleDisplayName`/`LSApplicationCategoryType` + some
reordering. Personal/local signing state; flagged to the user to commit if they want it tracked. The committed
fix is just the emptied entitlements (+ guide).

**Next:** unchanged — real-race test is the next signal; deferred WIs wait.

---
## 2026-06-27 — TRACK-013 COMPLETE: raw race export (safety-net zip — JSON + audio → share / Files)

The user is configuring their first real race and said they're afraid of losing the data once it finishes — could we
do the export feature, even unfinished: "generate JSON out of the list of events and zip everything (incl. the audio
files) and save to files (or share, maybe even better)." That's a deliberately *preliminary* slice of the deferred
**WI-8 (`.trace`)**, which the backlog itself anticipated. Promoted as **TRACK-013**, branch
`track/track-013-race-export` → **PR #177** (squash-merged). Worked autonomously per the framework.

**Framing — this is NOT WI-8 done.** WI-8 is the *finalized* `.trace` (resolved manifest, shared spec in
`knowledge/reference/specs/`), still deferred until ≥2–3 real races settle the event vocabulary. TRACK-013 is the
**lossless raw archive** that gets the data off the phone *now*: `export.json` carries `formatVersion: 0` + a `note`
flagging it as the pre-`.trace` draft, so a future consumer can tell drafts apart. Updated the WI-8 backlog entry to
say so (reconcile on finalize: bump version, decide resolved-vs-raw).

**The export was cheap because the bundle is already self-describing.** Each race is `Races/<id>/race.json` +
append-only `events.log` (JSONL) + `audio/<eventID>.m4a` (WI-2's spine). So "export" = serialise the events into one
readable JSON + carry the raw bundle + zip + share. Engine (`TrackCore.swift`, Foundation-only, testable):
- `RaceExport` (`Codable` wrapper over the already-`Codable` `Race` + `[RaceEvent]`) + `RaceStorage.exportZip(for:)`.
- `export.json` = race metadata + the **full RAW event list read from disk** (retractions **included** — lossless;
  resolving is the finalized format's job). Encoded pretty + sorted-keys + **ISO-8601 dates** (eyeball-readable),
  deliberately distinct from the on-disk compact/numeric coders.
- Staged with the **verbatim bundle** alongside (`race.json`, `events.log`, `audio/`) — belt-and-suspenders: the JSON
  is the convenient view, the raw files are the byte-for-byte safety net. Copying the bundle dir's contents carries
  whatever's on disk (incl. clips) without re-enumerating event kinds.
- Zipped via **`NSFileCoordinator` `.forUploading`** — the Foundation way to zip a directory with **no third-party
  dependency** (the app stays dependency-free). De-risked with a macOS spike *before* wiring: it produces a standard
  archive that `unzip` opens, top-level folder named after the race, **audio bytes preserved exactly** (2048→2048).
  `exportZip` drops the uncompressed staging copy, keeping only `<RaceName>-<stamp>.zip`. Off-main-actor safe:
  `RaceStorage` is a one-`URL` value type (`Sendable`), captured into a `Task.detached` so a clip-heavy race doesn't
  hitch the UI.

**Two entry points, one share sheet.** (1) **Finished-race toolbar** — an Export (share) button next to Edit-finish;
the explicit "once the race finishes" ask, and reachable for *any* finished race (you tap into it from the list). (2)
**Races-list leading swipe** — a robust net that exports straight off the bundle without opening the detail view
(leading=Export blue, trailing=Delete red — two distinct directions). Both build the zip off-main then present
`UIActivityViewController` (`ShareSheet`, in ContentView.swift) — which *is* "Save to Files" **and** AirDrop/Mail in
one, so the share sheet covers the user's "save to files **or** share" outright.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4): **BUILD SUCCEEDED** (no warnings); **TrackTests
64→68 · TrackUITests 7** (+2 launch), **TEST SUCCEEDED**. The 4 new unit tests build a *real* zip on the simulator and
assert: `export.json` round-trips the race + raw events (incl. a retraction); the staging dir holds JSON + raw
log/race.json + the clip **byte-for-byte**; the zip is named/non-empty and the uncompressed copy is gone; the name is
sanitised. The finished-race UI test now also asserts the `exportRace` control. Screenshot (extracted from that test's
attachment — shows the Export icon live in the toolbar): `reference/design/track-013-finished-export.png`. The **share
sheet itself is system UI** (not XCUITest-drivable — same as `.fileImporter` and clip playback), so its presentation
is the one manually-confirmed seam; everything upstream of it is automated.

**Snag worth recording:** the Mac's toolchain has moved to **Xcode 17F113 / iOS 26.5 SDK** since TRACK-000. A bare
`-destination '…name=iPhone 15'` now implies `OS:latest` (26.5) — where iPhone 15 doesn't exist — so the first test
run failed with *"Unable to find a device."* Fix: pin `OS=17.4`. Also: piping `xcodebuild` through `tail`/`grep`
masks its exit code with the filter's (saw a misleading exit 0), so read the captured log for `** TEST SUCCEEDED **`.
Both noted in `reference/local-ci.md`.

**Next:** the user pulls `master`, rebuilds + reinstalls via `reference/device-testing.md`, and has a one-tap export
on the finished view (and a swipe on the list). After the real race, the exported zip's `events.log`/`export.json`
become the concrete data that settles the vocabulary → promote the finalized **WI-8 `.trace`** (and WI-9 `.trail`).

---
## 2026-06-27 — TRACK-014 COMPLETE: edit a race before it has started

User asked: "Can we add an option to edit a race before it has started?" Configured races could only be Started, not
tweaked — so a typo'd name or a wrong aid station meant deleting and re-creating. Promoted as **TRACK-014**, branch
`track/track-014-edit-configured-race` → **PR #178** (squash-merged). Autonomous per the framework.

**Design — reuse the create form; preserve identity; gate to Configured.**
- `CreateRaceView` gained an `editing: Race?` mode: `nil` = create (mint a new race via `build()`), non-nil =
  edit (pre-fill the form from the race, title "Edit Race", and on Save call `applied(to:)` which rebuilds the `Race`
  **keeping `id`/`createdAt`/`planRef`** — only name/date/aid/palette change). One form, two modes; the existing
  trailing-closure call site (`CreateRaceView { store.add($0) }`) is unchanged since `editing` defaults to `nil`.
- `RaceDraft` got `init(from:)` + `applied(to:)` in an **extension** (so the struct's synthesised memberwise/`init()`
  — used as `RaceDraft()` across the tests — survives; adding an init in the main body would suppress it).
- Edit lives on the **Configured (Start) screen** toolbar (a pencil, next to nothing else) — the intuitive spot: you
  open a race, see Start, and can fix it first. **Not** in the in-race view: once a race starts, config is frozen
  (the only post-start edit is the finish-time *correction*, which is an event, not a mutation — mvp-plan.md §2).

**The data-flow wrinkle (worth recording).** The detail screen renders from a `RaceTracker` snapshot
(`RaceDetailView` builds it once), while the Races list renders from `RaceStore.races`. An edit has to reach **both**
in-memory copies, with `race.json` on disk as the source of truth. Chosen resolution:
- `RaceTracker.race` `let` → `private(set) var` + `updateConfiguration(_:)` — guarded (`status == .configured` &&
  same id), it persists via `storage.saveRace` then mirrors `race` in memory. Being `@Observable`, the Start screen
  re-renders **immediately** on save. The guard is what enforces "can't edit a started race" at the model layer.
- `RaceStore.refreshStatuses()` (called on list `.onAppear`) became `reload()` — it now re-reads **metadata** too
  (not just re-projecting status/duration), so an edit made on the detail screen shows up in the list row on return.
  (`RaceStore.update(_:)` also exists for a store-routed edit and is unit-tested, though the shipped UI edits via the
  tracker.) Both copies converge through disk; no shared-mutable-state coupling between tracker and store.

**Verified** (from `systems/track/Track/`, iPhone 15 / iOS 17.4): **BUILD SUCCEEDED** (no warnings); **TrackTests
68→71 · TrackUITests 7→8**, **TEST SUCCEEDED**. Unit: `RaceDraft(from:)`→`applied(to:)` preserves identity while
applying edits; `RaceStore.update` persists + survives a fresh-instance reload + leaves status Configured;
`RaceTracker.updateConfiguration` applies before `start()` and is a **no-op after** (asserts the freeze). UI
(`testEditingAConfiguredRaceAppliesBeforeStart`): create a plan-less race → open it (Start screen, 0 aid stations) →
Edit opens the form **pre-filled** (`raceName` == the race's name — proves it loads existing data) → add an aid
station → Save → the Start screen's `aidStationCount` goes **0→1** with no relaunch (proves the in-place re-render).
Deterministic (button taps + an a11y-id'd count — no fragile text-field clearing).

**Next:** the user pulls `master` + rebuilds to pick up TRACK-013 (export) **and** TRACK-014 (edit) together. Still no
`mvp-plan.md`/domain change since WI-2; the deferred tail (finalized WI-8 `.trace`, WI-9 `.trail`, WI-10 Live Activity)
waits on real-race data.
