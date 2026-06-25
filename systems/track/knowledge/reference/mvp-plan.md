# Tracker — MVP Plan

**Status:** Draft for build. Race-tracking view designed in `tracking-view-spec.md`.
**Summary:** A lean, native iOS app to capture food intake, aid-station arrivals, and voice notes *during* a trail/ultra race, plus a minimal post-race review. Passive recorder. Plan-less by default; adapts to a Trail plan when one is supplied. Outputs a self-contained `.trace`. Feeds an eventual third (Reflect) app, but closes its own loop so it's dogfoodable standalone.

---

## 1. Product framing

The tracker owns **events and experience**; the watch owns **signals**. GPS, HR, pace, elevation, splits are already solved by the watch/Garmin/Coros/Suunto — don't duplicate them. What's cumbersome on a watch and missing from existing apps is everything discrete and subjective: nutrition timing and how it *sat*, GI distress, mood, pain, "reached aid 2," "saw a deer," a breathless voice note at hour 6.

Position on the recorder↔assistant spectrum: **passive recorder**, locked. No nudges, no alerts (watches already provide a basic nutrition alert). When a plan is present, the UI may *show and adapt to* it for tracking, but plan-less tracking is a first-class path, not a degraded one.

Three-app spine (event sourcing): **Plan (Trail) → Execute (this app) → Reflect (app 3)**. Trail emits a plan; the tracker emits an append-only event log; app 3 is a projection — a fold over that log joined with a GPS stream. GPS pairing, time-only analysis, and presentation all belong to app 3.

---

## 2. Architecture principles (invariants)

These are load-bearing; the build must not violate them.

- **No background execution (v1).** Nothing happens unprompted. Elapsed time is derived from a stored start timestamp, not a running process. iOS may background/kill the app between interactions — fine: each interaction is *open → append a `Date()`-stamped event → flush → done*. This removes the entire background-mode / keep-alive / background-location surface. (Voice capture is foreground tap-record-tap-stop, avoiding even the audio background mode.)
- **Append-only event log, resilient to shutdown.** The in-race log is never rewritten. Force-quit or a dead battery loses at most the single in-flight write. All edits — the editable finish time *and* Undo — are **new events** (corrections / retractions), resolved by the projection. One rule, no exceptions.
- **Durability is a primary constraint, not an afterthought.** Race data is *unrepeatable* — you cannot re-run hour 9 of a 100-miler. Losing aid-station logs late in a long race is catastrophic. fsync on every event append; atomic writes for config; crash recovery on launch.
- **Offline / local-first.** Mountain races have no signal. No cloud dependency during the race, ever. No server anywhere in v1.
- **Capture now, process later.** Nothing clever happens during the race — no live transcription, no live pairing, no inference. The in-race app is a dumb, crash-proof recorder. Intelligence lives post-race or in app 3.
- **Plan-less first.** Every feature must work without a `.trail`. Plan ingestion only *enriches* (pre-populates palette / aid stations, enables deviation classification later).
- **`.trace` is output-only and self-contained.** It must be readable on its own (app 3 may receive *just* a `.trace`): denormalized inline labels, with the plan's identity embedded as optional re-linking metadata when a plan was used.
- **Status and effective values are projections, not stored flags.** Race status, effective end time, and aid-station visit state are derived by folding events.

---

## 3. Tech stack & persistence

- **Language/UI:** Swift + SwiftUI, native iOS. iOS first; Android deferred. Cross-platform UI (Compose Multiplatform) rejected on *idiomatic* grounds — it renders the same UI on both, the opposite of the platform-native intent. KMP (shared logic, native UI) is a *later* decision made at the Android boundary with real code in hand; not adopted now (it's an abstraction layer with build-complexity cost, and there's exactly one near-term platform — rule of three).
- **Minimum iOS:** pin at WI-1; can stay permissive (no ActivityKit/background to constrain it).
- **Persistence — a race is a directory bundle:**

  ```
  Races/
    <raceID>/
      race.json        # metadata: name, date, aidStations, palette, planRef
                       #   rewritten atomically (temp + fsync + rename) on config edits (pre-race only)
      events.log       # APPEND-ONLY, one JSON object per line; fsync after every append
      audio/
        <eventID>.m4a  # voice clips, referenced by event
  ```

  This decouples orthogonal concerns: mutable config (`race.json`, edited pre-race when a rewrite is safe) vs the append-only, durability-critical in-race log (`events.log`). Listing races = scan the directory. Race status / timeline = fold the log. The eventual `.trace` = serialize (resolved metadata + resolved events + audio) into one self-contained container.

  **Write ordering invariant for voice notes:** write the audio file → fsync → *then* append the `voiceNote` event referencing it. A crash between leaves an orphan audio file (harmless) but never a dangling event ref (the safe failure direction).

  *Alternatives considered.* **SQLite/GRDB** — single-file DB, free querying/scale, WAL durability; more machinery for a first mobile app and overkill at a handful of races. Revisit if directory-scan listing strains (rule of three). **SwiftData/Core Data** — rejected for a durability-critical first app: reliability rough edges and too much hidden magic where data loss = lost race. Plain bundle wins for MVP: the log *is* a file, minimal framework to fight, inherently crash-recoverable.

---

## 4. Domain model (Swift)

```swift
// ── Identity ──────────────────────────────────────────────
typealias RaceID = UUID
typealias EventID = UUID
typealias TrackableID = UUID

// ── Trackable library ─────────────────────────────────────
struct TrackableElement: Identifiable, Codable, Equatable {
    let id: TrackableID
    var label: String            // "Maurten 320 Drink Mix"
    var category: TrackableCategory
}

enum TrackableCategory: String, Codable, CaseIterable {
    case nutrition, hydration, gear, other
}
// Tab mapping: {nutrition, hydration} -> Nutrition tab; {gear, other} -> Others tab (confirm).

// ── Race (metadata; events stored separately) ─────────────
struct Race: Identifiable, Codable {
    let id: RaceID
    var name: String
    var createdAt: Date          // when created in the app
    var date: Date?              // scheduled race date (nice-to-have); != createdAt, != raceStarted
    var aidStations: [PlannedAidStation]   // optional; may be empty (plan-less)
    var palette: [TrackableElement]        // SNAPSHOT of selected library items + ad-hoc
    var planRef: PlanRef?                  // optional link to a Trail .trail plan
}

struct PlannedAidStation: Identifiable, Codable {
    let id: UUID
    var ordinal: Int             // 1-based
    var name: String             // may be "" -> display "AS 1"
    var services: [String]       // mirrors Trail CSV; cell encoding lifted from Trail's parser
    var distanceKm: Double?      // from Trail CSV; powers distance-to-next
}

struct PlanRef: Codable {
    let planID: UUID             // Trail plan identity (reuses WI-1/WI-5 identity work)
    let integrityHash: String   // lets app 3 verify the exact plan version
}

// ── Event log (append-only) ───────────────────────────────
struct RaceEvent: Identifiable, Codable {
    let id: EventID
    var at: Date                 // logical wall-clock; the JOIN KEY for app 3's GPS pairing
    let kind: RaceEventKind
}

enum RaceEventKind: Codable {
    case raceStarted
    case raceEnded
    case endTimeCorrected(to: Date)                          // correction, not mutation
    case aidStationEntered(visitID: UUID, ordinal: Int?, label: String)  // arrival; label inline
    case aidStationExited(visitID: UUID)                     // departure ("Finish"); pairs by visitID
    case intake(trackableID: TrackableID?, label: String)   // label denormalized; one tap = one item
    case voiceNote(audioFilename: String, durationSec: Double)
    case retraction(target: EventID)                         // Undo: hides target; never deletes
    // deferred: case deviation(...), feeling(rpe:tags:), marker(kind:)
}

// ── Projections (derived, never stored) ───────────────────
// All projections first drop retracted events: collect the `retraction.target` ids,
// then fold the survivors — both the retracted event and its retraction vanish.
enum RaceStatus { case configured, inProgress, finished }

enum VisitState: Equatable {
    case inProgress                 // entered; no exit; no later entry -> you are here now
    case departed(at: Date)         // explicit exit recorded (approximate; GPS may refine dwell)
    case departedExitUnrecorded     // open visit superseded by a later entry -> forgot to Finish; GPS reconstructs
}

struct AidStationVisit {            // fold of entered/exited, paired by visitID
    let visitID: UUID
    let ordinal: Int?
    let label: String
    let enteredAt: Date             // approximate anchor (as tapped); GPS may refine
    let state: VisitState
}

extension Array where Element == RaceEvent {
    var status: RaceStatus {
        let started = contains { if case .raceStarted = $0.kind { return true }; return false }
        let ended   = contains { if case .raceEnded   = $0.kind { return true }; return false }
        if ended { return .finished }
        if started { return .inProgress }
        return .configured
    }

    /// Effective finish = latest correction, else the raceEnded event's own time.
    var effectiveEnd: Date? {
        if let corrected = last(where: { if case .endTimeCorrected = $0.kind { return true }; return false }),
           case let .endTimeCorrected(to) = corrected.kind { return to }
        if let ended = last(where: { if case .raceEnded = $0.kind { return true }; return false }) { return ended.at }
        return nil
    }

    // aidStationVisits: open on .aidStationEntered; .aidStationExited(visitID:) -> .departed(at:).
    // After folding, any still-open visit with a LATER entry -> .departedExitUnrecorded (forgot to Finish);
    // the lone open visit with no later entry is the current station (.inProgress). (Retracted pre-filtered.)
}
```

Design notes folded into the types:
- Deviation is **not** in the MVP event set — it's plan-coupled (meaningless without a plan) and ships with `.trail` ingestion, not the base logger.
- Two finish-related events: `raceEnded` (the End trigger — location TBD, see tracking-view spec OQ-1) and `endTimeCorrected(to:)` (the editable correction). The corrected event's own `at` is *when you corrected*; `to` is the corrected finish time. The projection resolves it.
- Aid stations are **intervals**: `aidStationEntered` + `aidStationExited` paired by `visitID`, projected into three states (`inProgress` / `departed(at:)` / `departedExitUnrecorded`). **A new arrival implicitly departs any still-open visit** with no recorded exit, covering "forgot to tap Finish." Tap timestamps are **approximate anchors**, not ground truth: app 3 refines real arrival/departure and dwell from the GPS velocity trace, which generally outweighs the taps; `departedExitUnrecorded` means "rely entirely on GPS for departure." A station may be visited more than once (loops/out-and-backs), each a distinct `visitID`. Entry `label` is denormalized; `ordinal` links to the plan when known.
- `intake.label` (and the aid-entry label) are denormalized so the future `.trace` reads alone; the optional IDs are back-refs for app 3 when context is available.
- **Undo = retraction, not deletion.** `retraction(target:)` hides the targeted event; every projection pre-filters retracted ids. With `endTimeCorrected`, nothing in the app ever mutates history.
- Quantity is never stored: each intake tap is one item, so total per item is a **projection** (count of intake events for that label). Keeps the event as the atom — the post-race "3 × gel" falls out of the fold. "Grabbed 3 at once" = 3 taps (or a future batch affordance), never a quantity field.

---

## 5. Data lifecycle & formats

**Inputs (both optional):**
- **Aid-station CSV** — the same import/export format Trail uses; columns **name, services, distance**. Parsed into `[PlannedAidStation]`. Distance lets the views show distance-to-next. (Lift the exact cell encoding/delimiter for `services` from Trail's parser.)
- **`.trail` plan** — full ingestion (palette + schedule + UI adaptation + `planRef`) is **deferred** to a post-MVP work item. MVP supports the aid-station CSV path only.

**Output:**
- **`.trace`** — **deferred until the event vocabulary settles** (>=2-3 real races), consistent with "freeze formats late." When it lands it's a self-contained **zip** container: a manifest (resolved metadata + resolved events) plus all assets (audio), carrying inline labels and `planRef` as optional re-linking metadata. Manifest schema finalized at WI-8.

Until `.trace` export exists, the on-disk bundle *is* the race record; the post-race view reads it directly.

---

## 6. Screens & navigation

Root: `NavigationStack` with **Races** as home; **Trackable Library** reachable from a toolbar action. No "Plans" surface here — plans live in Trail. (Mirrors Trail's Plans/Executions split; the tracker holds only the Executions side.)

### 6.1 Races list (home)
- Rows: name, race/created date, **status badge** (Configured / In-progress / Finished), duration when finished. Status/duration are projections.
- `+` -> Create race.
- Tap a row -> race detail that branches on status: Configured -> "Start"; In-progress -> tracking view; Finished -> race view (read).

### 6.2 Create / configure race
- Name. Optional **date** (nice-to-have).
- **Aid stations (optional):** import Trail CSV *or* add manually; reorderable; may be left empty (plan-less).
- **Palette:** add from Library (multi-select) **+ ad-hoc create** (label + category; optionally promote to Library). Stored as a snapshot on the race.
- Save -> race enters **Configured**.

### 6.3 Race tracking view — **DESIGNED -> see `tracking-view-spec.md`**
Four cyclic, swipeable tabs: **Nutrition · AID · Others · Feed**. Three are tracking tabs (two trackable grids + the AID manager); Feed is a read-only event stream. Persistent on the tracking tabs: a record-voice button (bottom-right) and an Undo-toast slot (bottom-left); Feed has neither. Full layout, behavior, and open questions live in the tracking-view spec.

- **Emits:** `raceStarted` (on entry, from the race detail's Start), `aidStationEntered`/`aidStationExited`, `intake` (per palette tile), `voiceNote` (tap-record-tap-stop), `retraction` (Undo), and `raceEnded` (a "Finish race" control in the AID tab, with confirm).
- **Constraints (unchanged):** foreground-only; huge tap targets; glanceable; usable sweaty/gloved/in rain; system light/dark; every action appends + fsyncs; no GPS / background / nudges.

### 6.4 Race view (post-race / read)
- Chronological **event stream** (fold of `events.log`), resolved (effective end + retractions applied).
- Voice clips **playable inline** (playback lives here, not in the in-race Feed).
- **Edit finish time** -> appends `endTimeCorrected` (the editable-end requirement lives here): e.g. phone died, set finish to 2:53 instead of the 3:30 power-on.
- Summary header: name, start, effective end, total duration, counts (aid-station visits / intakes / notes), plus per-visit time (exit - entry from the visit fold). Per-item intake totals are counts of intake events.
- (Deferred) Export `.trace`.

### 6.5 Trackable library
- List of `TrackableElement` (label + category). CRUD. Source for race palettes. Ad-hoc items from race config can be promoted here.

---

## 7. Work items (sequenced backlog)

Each: scope -> acceptance criteria (AC).

- **WI-1 — Project skeleton.** Xcode/SwiftUI app, `NavigationStack`, empty Races-list root, persistence root dir, pin iOS deployment target. **AC:** launches; empty races list; a stub race persists to disk and survives relaunch.
- **WI-2 — Domain model + persistence.** Types in §4; race-bundle read/write; append-only `events.log` with fsync; atomic `race.json`; write-audio-then-append ordering; status / effectiveEnd / aidStationVisits projections; retraction pre-filtering. **AC:** create race, append events programmatically, force-quit/relaunch with zero loss; status, effective end, and visit pairing correct; a retraction hides its target everywhere; orphan-audio (not dangling-ref) is the only crash artifact.
- **WI-3 — Trackable library.** CRUD UI + storage. **AC:** create/edit/delete trackables; persist; reload.
- **WI-4 — Create/configure race.** Name, optional date, manual aid stations, palette from library + ad-hoc, save. **AC:** configured race persisted; appears in list as Configured.
- **WI-5 — Aid-station CSV import.** Parse Trail's CSV (columns **name, services, distance**) into `[PlannedAidStation]`. **AC:** import a Trail CSV; name/services/distance populate; stations editable; views can derive distance-to-next.
- **WI-6 — Race tracking view.** Per `tracking-view-spec.md`: four cyclic tabs (Nutrition/AID/Others/Feed); category grids -> `intake`; AID tab -> `aidStationEntered`/`aidStationExited` (plus plan-less ad-hoc stations); Feed projection; foreground tap-record-tap-stop voice -> mono AAC/m4a in the bundle; Undo toast -> `retraction`. Each action appends + fsync. **AC:** run a race through all four tabs with every event durably logged, clips on disk, aid visits pairing by `visitID`, and Undo producing a retraction the Feed honors. **Resolve the race-end trigger (spec OQ-1) before building.**
- **WI-7 — Race view.** Event timeline, clip playback, end-time correction, summary with per-visit time. **AC:** view a finished race; play a clip; correct the finish via correction event; summary reflects effective end and visit durations.
- **WI-8 — `.trace` export.** *Deferred* until >=2-3 races settle the vocabulary. Self-contained **zip** container: manifest (resolved metadata + events) + all assets (audio).
- **WI-9 — `.trail` ingestion.** *Deferred.* Palette + schedule + UI adaptation + `planRef`; unlocks deviation classification and a dedicated AID notes field.
- **WI-10 — Live Activity.** *Deferred.* Foreground-started, system-rendered timer; gated by the 8h active cap (12h incl. stale) and a WidgetKit extension; no-server continuity needs a restart-on-foreground hack.

**Critical path:** WI-1 -> WI-2 -> WI-3/WI-4 -> WI-5 -> (resolve race-end) -> WI-6 -> WI-7. First real test: run an actual race on the WI-6/WI-7 build.

---

## 8. Out of scope / deferred (explicit)

Background execution · GPS/location (never in the tracker) · Strava (app 3, on a generic track) · deviation classification (needs a plan) · RPE/feeling · generic markers · nudges/alerts · Apple Watch (never) · Android (later) · `.trace` format freeze · full `.trail` parse · Live Activity · in-race audio playback (post-race only).

---

## 9. Decisions & residuals

**Resolved:**
- **Aid-station CSV** — mirror Trail's import/export columns: **name, services, distance**. Distance powers distance-to-next.
- **`.trace` container** — **zip** bundling a manifest (resolved metadata + events) + all assets (audio). Decided in principle; finalized at WI-8.
- **Audio** — AAC/m4a, **mono**, favor quality (clips are short); size is the only constraint to watch.
- **Voice capture** — foreground **tap-record-tap-stop**; no background audio mode.
- **`intake` quantity** — **removed**. One tap = one item. Total quantity per item is a **projection** (count of intake events), never stored.
- **Aid stations are intervals** — `aidStationEntered` + `aidStationExited` (paired by `visitID`); in-progress/passed are projections; app 3 gets time-per-station free.
- **Undo = retraction** — `retraction(target:)`, not deletion; all projections pre-filter retracted ids.
- **`TrackableCategory`** — keep the typed enum (try it and see).
- **Race date** — optional `date` field added (nice-to-have); distinct from `createdAt` and the `raceStarted` event.
- **Product minimum-version** — emerges from iteration; no feature-freeze yet.

**Residuals (small, time-of-implementation):**
- Exact Trail CSV cell encoding/delimiter for `services` — lift from Trail's parser when building WI-5.
- iOS deployment target — pin at WI-1; can stay permissive (no ActivityKit/background to constrain it).
- `.trace` manifest schema — finalize at WI-8, after the event vocabulary settles.
- Tracking-view open questions (AID notes source; category->tab mapping; feed ordering) — tracked in `tracking-view-spec.md`; **Race-end resolved:** a distinct "Finish race" control in the AID tab (with confirm) emits `raceEnded`.

---

## 10. Hand-off brief

- Solo build. Workflow: branch -> PR -> squash-merge; commits under Christian only.
- Build order: WI-1 -> WI-2 (skeleton + durable domain), then WI-3/WI-4, then WI-5; resolve the race-end trigger, then WI-6; then WI-7. WI-8+ deferred.
- **Invariants the agent must not violate:** `events.log` is append-only (no rewrites; corrections / retractions are events) · write-audio-then-append-event ordering · status, effective end, and aid-visit state are projections, never stored flags · `.trace` is output-only and self-contained · no background execution · no GPS · foreground-only · plan-less paths must work without a `.trail`.
- Definition of "done" for the increment: Christian can create a race, run it through a real ultra capturing aid-station visits / intakes / voice notes with zero data loss across a multi-hour foreground/background/kill cycle, undo a mis-tap mid-race, then scroll an annotated timeline and play back clips afterward — standalone, with no app 3.
