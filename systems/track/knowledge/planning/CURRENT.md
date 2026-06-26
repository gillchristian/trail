# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-011 — race-day hardening (portrait lock + keep screen awake)
**Source:** found while smoke-testing the device build for TRACK-010 (the user asked me to figure out what
else is missing for race-readiness).
**Branch:** track/track-011-race-day-hardening
**Acceptance criteria:**
- [ ] **Portrait-locked** (iPhone) — a one-handed, glanced-at-mid-run app shouldn't flip to landscape.
      _(verify: built `Info.plist` `UISupportedInterfaceOrientations~iphone` = Portrait only)_
- [ ] **Screen stays awake during a race** — the app is foreground-only, so a screen sleep would stop you
      recording; hold the idle timer off while the tracking view is up, release it on leave.
- [ ] Guide updated (the Auto-Lock checklist item is now optional).
**Notes:** Orientation is two `INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone` build settings → Portrait.
Screen-awake is `UIApplication.shared.isIdleTimerDisabled` in `TrackingView.onAppear/onDisappear` (in-progress
only). Both are config/side-effect changes with no clean automated test; verified by build + the launch-test
UI-configuration count dropping 4→2 (proves the orientation lock) + manual reasoning.

_(**TRACK-010 complete** (✓ PR #174): on-device testing prep. Trail's mountain-peak **app icon** (SVG →
full-bleed opaque 1024 via QuickLook, no alpha); a **device-install guide** (`reference/device-testing.md` —
free-Apple-ID Xcode install + the 7-day caveat, TestFlight alt, race-day checklist); audited the rest (mic
string ✓, free-team-compatible entitlements ✓, automatic signing, iOS 17 target). Verified: simulator +
device-arm64 builds succeed; unit tests 64. `DEVELOPMENT_TEAM` left for the user's Apple ID. Also un-reserved
the deferred-WI task ids in `BACKLOG.md` (assigned on promotion; `WI-N` stays the spec ref).)_

_(**TRACK-009 complete** (✓ PR #173): always-in-race-mode — the active race is locked to the
forefront. (1) **Can't leave a started race** — `TrackingView` hides its back button (also disables swipe-back);
the AID finish flow is the only exit, and the back button returns on the finished (read) view. (2) **Reopen into
the active race** — a cold launch with an in-progress race opens straight to its tracking view (no list flash),
via a typed `NavigationStack(path: [RaceRoute])` whose initial path is computed in `RacesView.init` from
`RaceStore.inProgressRace`. Browsing configured/finished races + the library is unchanged (push + back). `RaceStore`
gained `inProgressRace` + `race(for:)`. Verified: **BUILD SUCCEEDED**; **TrackTests 63→64 · TrackUITests 6→7**.)_

_(**TRACK-008 complete** (✓ PR #172): tracking-view fixes from the first simulated race. (1)
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
