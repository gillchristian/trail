# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-003 — WI-3: trackable library
**Source:** BACKLOG (epic "Tracker MVP"; spec `reference/mvp-plan.md` §6.5, §7 WI-3)
**Branch:** track/track-003-trackable-library
**Acceptance criteria:**
- [ ] **create** a trackable (label + category) — via the library UI
- [ ] **edit** a trackable — changes persist
- [ ] **delete** a trackable
- [ ] **persist + reload** — trackables survive relaunch (verified by a fresh-store reload + a UI relaunch test)
**Notes:**
- `TrackableElement` (label + `TrackableCategory`) already exists in `TrackCore.swift` (WI-2). WI-3 adds the **storage** + the **CRUD UI**; it's the source for race palettes (WI-4 consumes it).
- **Storage:** a flat list persisted as `trackables.json` at the persistence root (sibling to `Races/`), written atomically (config, not the append-only log). Extract the `temp → fsync → rename` primitive shared with `race.json` into a small `DurableFile` helper (rule-of-three exception: durability primitives belong in one place; WI-2 tests cover the refactor).
- **UI:** a Trackable Library screen reached from a Races-list toolbar action (§6); `List` + add/edit (sheet form: label TextField + category Picker) + swipe-delete. New file `TrackableLibrary.swift` (store + views).
- Verification: unit tests (storage round-trip + store upsert/edit/delete + reload) + a UI test (open library → add → relaunch → persists). Scope: NOT the race-palette picker (that's WI-4); NOT promote-ad-hoc-to-library (WI-4 config).

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
