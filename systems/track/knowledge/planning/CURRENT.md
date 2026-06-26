# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-006 — WI-6 race tracking view
**Source:** BACKLOG (Tracker MVP epic) · **Branch:** track/track-006-race-tracking-view
**Spec:** `reference/tracking-view-spec.md` (drives this WI) + `mvp-plan.md` §6.3, §7 WI-6. Wireframes:
`reference/design/track-{nutrition,aid-stations,others,feed}.webp` (layout only; styling follows Trail).

**Open questions resolved at build** (spec §8; OQ-1 race-end already resolved = Finish-race control in AID):
- **OQ-2 AID notes** → render the current station's **services** (a dedicated plan-notes field arrives with `.trail`, WI-9).
- **OQ-3 category→tab** → Nutrition tab = `{nutrition, hydration}`; Others tab = `{gear, other}` (matches §4 type comment).
- **OQ-4 feed ordering** → **newest-first** (most recent on top) — best for mid-race "what did I just do".
- **OQ-5 grid overflow** → grids **scroll** vertically when a bucket overflows.
- **OQ-6 undo breadth** → **toast-only / most-recent** for MVP; per-row Feed retraction deferred.

**Acceptance criteria** (§7 WI-6 — "run a race through all four tabs with every event durably logged"):
- [ ] Four **cyclic** swipeable tabs Nutrition · AID · Others · Feed; tab bar taps + wrap-around swipe (verify in Simulator).
- [ ] Nutrition/Others grids show the palette items in that tab's categories; tapping a tile appends `intake` (durable). (UI test: tap tile → Feed shows it → relaunch → still there.)
- [ ] AID tab (planned): Passed rows, the in-progress current station with a green **Finish** (`aidStationExited`), services notes, an **Upcoming** row that marks arrival (`aidStationEntered`, implicitly departing the open visit); plan-less: past visits + **Start new aid station** (ad-hoc). Visits pair by `visitID`; the forgot-to-Finish rule holds. (unit-tested projection.)
- [ ] A distinct **Finish race** control (with confirm) appends `raceEnded`; status → finished. (verify)
- [ ] Record-voice button (tracking tabs only): tap-record-tap-stop → mono AAC/m4a written to the bundle → `voiceNote` appended (audio-then-event order). (unit-tested durability; live mic noted as Simulator-limited.)
- [ ] Undo toast (tracking tabs only) after any tracking action; **Undo appends a `retraction`** the Feed/counts/visits honor (the target vanishes). (unit + UI.)
- [ ] Every action appends + **fsyncs**; a relaunch reloads from disk with zero loss (durability invariant). (UI relaunch test.)
- [ ] Races list: row → race detail branching on status (Configured → Start; In-progress → tracking; Finished → minimal read placeholder, full view is WI-7); duration shown when finished.
- [ ] From `systems/track/Track/`: BUILD + TEST SUCCEEDED (no warnings); a Simulator run screenshot of the live tracking view.

**Notes:** No `mvp-plan.md` §4 domain change needed — the event spine (`aidStationEntered/Exited`, `retraction`,
three-state `VisitState`, `resolved`/`aidStationVisits`/`status`) already landed in WI-2. New code is the SwiftUI
tracking surface + pure view projections (`feedEntries`, `AidBoard`, `TrackingTab`) + an `@Observable RaceTracker`
session model (durable append → in-memory mirror). Out of scope → WI-7: clip playback, edit-finish-time, the full
post-race summary (this WI ships only a minimal finished placeholder so the finish flow is reachable + verifiable).

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
