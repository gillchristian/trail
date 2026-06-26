# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-007 — WI-7 race view (post-race)
**Source:** BACKLOG (WI-7) / promoted from CURRENT "Next up"
**Branch:** track/track-007-race-view
**Acceptance criteria** (`mvp-plan.md` §6.4, §7 WI-7):
- [ ] **View a finished race:** a resolved summary header — name, start, effective end, total duration —
      plus counts (aid-station visits / intakes / notes), per-visit time (exit − entry from the visit fold),
      and per-item intake totals (counts of intake events). _(unit test on the summary projection + UI test)_
- [ ] **Chronological event timeline** — a fold of `events.log`, resolved (retractions applied; the
      finished row honours the effective end). Oldest→newest. _(UI test asserts the timeline renders)_
- [ ] **Play a voice clip inline** — the one place audio plays (not the in-race Feed). _(manual sim: record →
      finish → play; unit test confirms the feed projection now carries the clip filename)_
- [ ] **Correct the finish** via an `endTimeCorrected` event (append, never a mutation); the summary +
      duration + list-row duration reflect the effective end afterward; the original `raceEnded` stays in the
      log. _(unit test: `correctEndTime` → effectiveEnd/totalDuration; UI test drives the edit-finish flow)_
- [ ] **Replaces** the WI-6 minimal finished placeholder.
**Notes:** Timeline is oldest→newest ("chronological", §6.4) — intentionally unlike the in-race Feed's
newest-first (OQ-4); reads as the race's story start→finish. Per-item intake totals included (cheap; in §6.4).
Reuse the existing pure projections (`effectiveEnd`, `aidStationVisits`, `startedAt`, `feedEntries`, `RaceFormat`);
add a `summary` projection + `RaceTracker.correctEndTime`. `.trace` export stays deferred (WI-8). Clip-playback
correctness is verified manually (audio in an XCUITest is unreliable); the UI test covers the deterministic surface.

_**Next up:** WI-8 (`.trace` export) and WI-9 (`.trail` ingestion) are **deferred** (`mvp-plan.md` §7–8): `.trace`
waits until ≥2–3 real races settle the event vocabulary. WI-7 is the last MVP-critical item — after it, the first
real test is running an actual race on the WI-6/WI-7 build._

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
