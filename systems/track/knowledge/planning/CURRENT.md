# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-008 — tracking-view fixes from the first simulated race
**Source:** user request (issues found running a simulated race on the WI-6/WI-7 build)
**Branch:** track/track-008-tracking-view-fixes
**Acceptance criteria:**
- [ ] **Aid-station notes.** A free-text `notes` field on planned stations, editable in the create form,
      shown when the active station expands on the AID tab. _(unit: round-trip + tolerant decode +
      `notes(forVisitOrdinal:)`; UI: configure a note → arrive → it shows)_
- [ ] **Undo-toast replacement.** A new tracked action's toast replaces the previous one and **persists**
      (the bug: the prior toast's cancelled auto-dismiss task fell through and cleared the replacement).
      Chose replace over stacking — matches the established most-recent-only Undo model. _(UI: arrive→finish
      → toast shows the new action and survives a settle)_
- [ ] **Recording across views.** The recording keeps running while switching among the tracking tabs;
      the stop-less **Feed** tab is unreachable while recording (disabled + skipped by the swipe); leaving
      the view mid-record stops+saves the clip (so it can't be silently dropped). _(unit: tab swipe skips
      Feed; manual sim: Feed locked, recording survives tabs, clip lands in Feed)_
**Notes:** Also makes the AID **Upcoming** row fully tappable (`contentShape` — the Spacer gap was dead).
Relabelled the active-station services card "Services" (was mislabelled "Notes") now that real notes exist.
Recording-based UI tests stay out of the committed suite (XCUITest audio is unreliable); verified manually.

_(**TRACK-007 complete** (✓ PR #171): WI-7 post-race race view — replaced the WI-6 minimal
finished placeholder with `FinishedRaceView` (`TrackingView.swift`): a sectioned summary (big total duration +
start→effective-end span + counts) + an **Aid stations** per-visit **dwell** section (exit − entry; "—" when the
exit was never marked) + **Intake totals** (per item, most-consumed first) + the **chronological timeline**
(oldest→newest, retractions applied, the finished row showing the effective end) + **inline clip playback**
(`AVAudioPlayer`, one clip at a time — the only place audio plays) + an **Edit finish time** sheet →
`endTimeCorrected`. Domain (`TrackCore.swift`, pure folds): `RaceSummary` + `summary`; `FeedEntry.voiceNote`
now carries the clip filename; `RaceTracker.correctEndTime` (append, never a mutation) + `summary` + `clipURL`.
**No `mvp-plan.md` §4 change** — the event kinds landed in WI-2. All 5 AC met: view a finished race ✓ ·
chronological timeline ✓ · play a clip inline ✓ · correct the finish via a correction event ✓ · replaces the
placeholder ✓. Verified from `systems/track/Track/`: **BUILD SUCCEEDED** (no warnings); **TrackTests 54→59 ·
TrackUITests 3→4** + clip playback confirmed manually (XCUITest audio is unreliable, so the suite stays
recording-free). Screenshots: `reference/design/track-007-{summary,timeline}.png`.)_

_**MVP feature-complete.** Next up: WI-8 (`.trace` export) and WI-9 (`.trail` ingestion) are **deferred**
(`mvp-plan.md` §7–8): `.trace` waits until ≥2–3 real races settle the event vocabulary. The intended next step
is the first **real test** — running an actual ultra on the WI-6/WI-7 build (the hand-off brief's "done")._

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
