# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-004 complete** (✓ PR #166): WI-4 create / configure race — `CreateRaceView.swift`
(Form sheet: name + optional date; manual aid stations with add/reorder/delete + 1-based ordinals;
palette multi-select from the WI-3 library + ad-hoc create with promote-to-library) over a Foundation-only
`RaceDraft` editing buffer; `RaceStore.add` + a `status(for:)` projection; a **Configured** status badge
on each Races row; replaced the WI-1 `addStubRace` stub. Fixed a latent durability bug — the `-uitest-reset`
wipe lived in the stores' inits (re-run on every view re-creation, so the new sheet wiped the just-created
race); moved it to `TrackApp.init` (once per process). Verified: BUILD + TEST SUCCEEDED (**28 unit + 2 UI**);
screenshot `reference/design/track-004-races-configured.png`.)_

_**Next up: TRACK-005 (WI-5)** — aid-station CSV import: parse Trail's CSV (columns **name, services,
distance**) into `[PlannedAidStation]`; lift Trail's exact `services` cell encoding/delimiter from its
parser (`mvp-plan.md` §5, §7 WI-5). **AC** (§7 WI-5): import a Trail CSV; name/services/distance populate;
stations editable; views can derive distance-to-next. Deps: TRACK-004 (done). Copy its AC into the
template below and branch `track/track-005-…`._

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
