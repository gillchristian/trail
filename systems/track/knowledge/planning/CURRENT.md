# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-006 complete** (✓ PR #168): WI-6 race tracking view — the in-race four-tab surface
(Nutrition · AID · Others · Feed, cyclic swipe) over an `@Observable RaceTracker` (durable append → in-memory
mirror). Grids → `intake`; AID tab → arrive / `finishAid` / plan-less ad-hoc + a distinct **Finish race**
(`raceEnded`, with confirm); Feed projection (newest-first); foreground tap-record-tap-stop voice → mono AAC/m4a
in the bundle; Undo toast → `retraction`. Pure view projections (`TrackingTab` cyclic + buckets, `feedEntries`,
`AidBoard`) + `RaceDetailView` status branch (Configured → Start, In-progress → tracking, Finished → a **minimal**
read placeholder; full view → WI-7) + duration-when-finished on the list row. **No `mvp-plan.md` §4 change** — the
event spine landed in WI-2. Resolved spec OQ-2…6 (notes=services; Nutrition `{nutrition,hydration}`/Others
`{gear,other}`; feed newest-first; grids scroll; undo toast-only). Verified from `systems/track/Track/`: BUILD
SUCCEEDED (no warnings); **TrackTests 52 · TrackUITests 3** + a real end-to-end relaunch-durability UI test that
**caught a swipe hit-testing bug** (fixed with `contentShape`). Screenshots: `reference/design/track-006-{aid-tab,feed}.png`.)_

_**Next up: TRACK-007 (WI-7)** — race view (post-race; `mvp-plan.md` §6.4, §7 WI-7): the chronological event stream
resolved (effective end + retractions), **inline clip playback**, **edit finish time** → `endTimeCorrected`, and a
summary (counts + per-visit time). Replaces the WI-6 minimal finished placeholder. **AC** (§7 WI-7): view a finished
race; play a clip; correct the finish via a correction event; summary reflects effective end + visit durations. Deps:
TRACK-002, TRACK-006 (done). (M.) Promote it into the template below and branch `track/track-007-…`._

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
