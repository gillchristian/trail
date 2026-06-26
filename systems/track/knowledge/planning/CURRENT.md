# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-002 — WI-2: domain model + durable persistence
**Source:** BACKLOG (epic "Tracker MVP"; spec `reference/mvp-plan.md` §4 types, §3 persistence, §2 invariants, §7 WI-2)
**Branch:** track/track-002-domain-persistence
**Acceptance criteria:**
- [ ] create a race, append events programmatically, **force-quit/relaunch with zero loss** (fsync per append + crash-tolerant load; verified by a fresh-instance reload + a torn-last-line test)
- [ ] `status` / `effectiveEnd` / `aidStationVisits` projections correct — incl. visit pairing by `visitID`, the implicit-depart ("forgot to Finish") rule, and `endTimeCorrected` resolution
- [ ] a **retraction hides its target everywhere** — all projections pre-filter retracted ids (the retracted event *and* its retraction vanish)
- [ ] **orphan-audio (not dangling-ref) is the only crash artifact** — write-audio → fsync → *then* append the `voiceNote` event
**Notes:**
- The durability-critical spine (L). Implements the full §4 Swift types; race-bundle read/write; append-only `events.log` (one JSON/line, **fsync after every append**); **atomic `race.json`** (temp + fsync + rename); crash recovery on launch (tolerate a torn last line); retraction pre-filtering.
- **Load-bearing invariants** (§2, do not violate): no background exec; append-only log (Undo + finish-edit are *events*, not mutations); offline; capture-now-process-later; status/effective-end/visit-state are **projections**, never stored flags.
- **Reorganize:** lift the WI-1 stub `Race`/`RaceStorage` out of `ContentView.swift` into a Foundation-only core file (sets up the ADR-0001 SPM-core split later). Keep the `@Observable` store + views in the SwiftUI layer.
- Verification = XCTest (projections + persistence round-trip + torn-line recovery + retraction + audio-ordering) — fast, simulator-hosted; app still builds + lists races. Audio *recording UI* is WI-6; WI-2 implements the persistence ordering with stand-in bytes.

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
