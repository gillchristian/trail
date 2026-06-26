# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-005 complete** (✓ PR #167): WI-5 aid-station CSV import — `AidStationCSV.parse`
(Foundation-only; format lifted from `systems/trail/src/AidCsv.elm`: RFC-4180 quoting, `;`/`,` delimiter,
`|`/`/`/`;` services split, km/mi headers, lenient row-skip) importing the 3 columns the tracker models
(name / `distance_km` / services; rest/cutoff/notes ignored → WI-9); `CreateRaceView` "Import from CSV…"
`.fileImporter`; `[PlannedAidStation].distanceToNextKm`; `RaceDraft.replaceAidStations`. Fixed a CRLF
tokenizer bug (Swift `\r\n` is one `Character` → normalize newlines first). Verified: BUILD + TEST
SUCCEEDED (**40 unit + 2 UI**); the Files-app picker is system UI so import is proven by parser +
integration unit tests, not a picker tap.)_

_**Next up: TRACK-006 (WI-6)** — race tracking view, the in-race four-tab surface (`tracking-view-spec.md`):
Nutrition/Others category grids → `intake`; AID tab → `aidStationEntered`/`aidStationExited` (+ plan-less
ad-hoc stations) + the **Finish race** control → `raceEnded`; Feed projection; foreground tap-record-tap-stop
voice → mono AAC/m4a in the bundle; Undo toast → `retraction`. Every action appends + fsyncs (`mvp-plan.md`
§6.3, §7 WI-6). **AC** (§7 WI-6): run a race through all four tabs with every event durably logged, clips on
disk, aid visits pairing by `visitID`, Undo producing a retraction the Feed honors. Deps: TRACK-002/004/005
(done). Race-end trigger is resolved (Finish-race control in the AID tab); resolve residual OQ-2…6 at build.
The big one (L). Copy its AC into the template below and branch `track/track-006-…`._

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
