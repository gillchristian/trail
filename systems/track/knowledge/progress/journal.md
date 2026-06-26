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
