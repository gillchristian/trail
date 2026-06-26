# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

_(none active. **TRACK-008 complete** (✓ PR #172): tracking-view fixes from the first simulated race. (1)
**Aid-station notes** — a free-text `notes` field on `PlannedAidStation` (tolerant decode), editable per station
in the create form, shown when the active station expands (the mislabelled services card is now correctly
**"Services"**); `Race.notes(forVisitOrdinal:)`. (2) **Undo-toast replacement bug** — a new action's toast was
cleared within a frame by the prior toast's cancelled auto-dismiss `Task.sleep` (a bare `try?` swallowed the
`CancellationError` and fell through to `dismissToast()`); fixed to return on cancellation (replace, not stack —
the most-recent-only model). (3) **Recording across views** — the stop-less Feed is disabled + swipe-skipped
while recording (`TrackingTab.next/previous(excludingFeed:)`), and `onDisappear` stops+saves an in-progress clip.
Also: the AID **Upcoming** row is fully tappable now (`contentShape`). All 3 AC met. Verified from
`systems/track/Track/`: **BUILD SUCCEEDED** (no warnings); **TrackTests 59→63 · TrackUITests 4→6**; recording +
Feed-lock confirmed manually (XCUITest audio is unreliable, so the suite stays recording-free).)_

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
