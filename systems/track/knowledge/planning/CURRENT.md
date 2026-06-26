# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-003 complete** (✓ PR #165): WI-3 trackable library — `TrackableLibrary.swift`
(`TrackableLibraryStore` + list + create/edit sheet, reached from a Races-toolbar action) over
`TrackableLibraryStorage` (atomic `trackables.json` at the persistence root). Extracted the shared
`temp→fsync→rename` primitive into `DurableFile`. Verified: BUILD + TEST SUCCEEDED (**22 unit + 2 UI**)._

_**Next up: TRACK-004 (WI-4)** — create / configure race: name + optional date; manual aid stations;
palette from the library (multi-select) **+ ad-hoc create** (label + category, optionally promote to
the library); save → **Configured** (`mvp-plan.md` §6.2, §7 WI-4). **AC** (§7 WI-4): a configured race
is persisted and appears in the list as Configured. This replaces the WI-1 `addStubRace` placeholder
with the real create form and wires the WI-3 library in as the palette source. Deps: TRACK-002 (+
TRACK-003 for palette) — both done. Copy its AC into the template below and branch `track/track-004-…`.
(TRACK-005 — aid-station CSV import — follows.)_

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
