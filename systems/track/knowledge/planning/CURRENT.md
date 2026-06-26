# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-010 — on-device testing prep (icon + run-on-phone guide)
**Source:** user request (get the app ready to test on the phone for the next race; use Trail's icon)
**Branch:** track/track-010-device-testing-prep
**Acceptance criteria:**
- [ ] **App icon** = Trail's mountain-peak logo, as a 1024×1024 **opaque, no-alpha** iOS icon (iOS masks
      its own corners). _(verify: simulator build compiles the AppIcon; visual check)_
- [ ] **Device-install guide** the user can follow — direct Xcode install on a **free** Apple ID
      (recommended; covers signing, the 7-day expiry, trust step) + TestFlight as the paid alternative,
      plus a race-day checklist. At `reference/device-testing.md`.
- [ ] **Nothing else blocks device testing** — confirm the mic usage string (present ✓), entitlements are
      free-team-compatible (macOS-sandbox keys only ✓), automatic signing, iOS 17.0 target.
- [ ] **Verify** the app builds for real-device arm64 (no-signing) — signing itself is the user's Team.
**Notes:** Icon rasterized from `systems/trail/public/icon.svg` (full-bleed square, `rx` removed) via QuickLook
(WebKit — ImageMagick's SVG renderer dropped the gradients), flattened to opaque sRGB. `DEVELOPMENT_TEAM` is
left unset deliberately (it's the user's Apple ID, chosen in Xcode). Also un-reserved the deferred WI task ids in
`BACKLOG.md`: they carry no speculative `TRACK-NNN` now (assigned on promotion) — avoids the recurring collision
with ad-hoc tasks; `WI-N` stays the `mvp-plan.md` spec reference.

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
