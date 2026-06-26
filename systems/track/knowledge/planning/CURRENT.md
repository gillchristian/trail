# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-002 complete** (✓ PR #164): WI-2 domain model + durable persistence —
`TrackCore.swift` (Foundation-only) carries the full §4 model, the `status`/`effectiveEnd`/
`aidStationVisits` projections with retraction pre-filtering, and `RaceStorage` (append-only
`events.log` with **fsync per append**, atomic `race.json`, crash-tolerant load, write-audio-then-append
voice-note ordering). Lifted the WI-1 stub out of `ContentView.swift`. Verified: BUILD + TEST SUCCEEDED
(**17 unit tests** + the UI relaunch-persistence test)._

_**Next up: TRACK-003 (WI-3)** — trackable library: CRUD UI + storage for `TrackableElement` (label +
category); the source for race palettes (`mvp-plan.md` §6.5, §7 WI-3). **AC** (§7 WI-3): create / edit /
delete trackables; persist; reload. The first UI-bearing feature on top of the WI-2 core — needs a
`TrackableElement` store (mirror `RaceStore`) + a List/edit screen, persisted under the persistence
root (a `trackables.json`, sibling to `Races/`). Deps: TRACK-002 (done). Copy its AC into the template
below and branch `track/track-003-…`. (TRACK-004 — create/configure race — is the other unblocked
critical-path item.)_

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
