# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-001 complete** (✓ PR #162): WI-1 project skeleton — `RacesView`
(`NavigationStack` + empty state + `+`/swipe-delete) over a durable race bundle
(`Documents/Races/<id>/race.json`, atomic write, scan-on-load); stub `Race` model + `@Observable
RaceStore`; Trail `Theme` tokens + amber `AccentColor`; **iOS deployment target pinned 17.0**
(ADR-0001); **scheme promoted to a committed shared scheme**. Verified: BUILD + TEST SUCCEEDED
(4 unit + 1 UI relaunch-persistence test), screenshots in `reference/design/`._

_**Next up: TRACK-002 (WI-2)** — domain model + durable persistence: the full `mvp-plan.md` §4
types, append-only `events.log` with **fsync per append**, atomic `race.json`,
write-audio-then-append ordering, and the `status`/`effectiveEnd`/`aidStationVisits` projections
with retraction pre-filtering (the L-sized durability spine). **AC** (§7 WI-2): create race, append
events programmatically, force-quit/relaunch with zero loss; status/effective-end/visit-pairing
correct; a retraction hides its target everywhere; orphan-audio (not dangling-ref) the only crash
artifact. Also: lift the WI-1 stub types out of `ContentView.swift` into their own files. Copy its
AC from the BACKLOG line into the template below and branch `track/track-002-…`.)_

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
