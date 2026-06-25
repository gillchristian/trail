# Tracker — Race Tracking View (design spec)

**Status:** Designed. Implements §6.3 of `mvp-plan.md`; drives WI-6.
**Summary:** The in-race surface. Four cyclic, swipeable tabs — **Nutrition · AID · Others · Feed**. Three are tracking tabs (two trackable grids + the aid-station manager); Feed is a read-only event stream. Built for one-handed, gloved, exhausted use; every action appends an event and fsyncs; nothing mutates history (Undo is a retraction).
**Wireframes:** hand sketches of the four tabs live in `design/` — `track-nutrition.webp`, `track-aid-stations.webp`, `track-others.webp`, `track-feed.webp` (Excalidraw source: `design/tracker.excalidraw`). They fix *layout*, not *styling* — the visual language follows Trail (see `project-brief.md` → **Visual design**); the sketch chrome (rough strokes, ad-hoc tile colors) is not literal.

---

## 1. Shell — four cyclic tabs

- Tabs in order: **Nutrition · AID · Others · Feed**. Swipe left/right to move between them; **cyclic** — past the last wraps to the first and vice-versa.
- **Tracking tabs:** Nutrition, AID, Others. **Read tab:** Feed.
- Appearance follows the **system** light/dark setting.
- **Persistent chrome on the three tracking tabs only:**
  - **Record-voice button** — bottom-right (§5).
  - **Undo-toast slot** — bottom-left (§6).
  - Feed shows neither.
- Race start happens upstream: the race detail's **Start** logs `raceStarted` and opens this view. Race **end** is a distinct **Finish race** control in the AID tab (§3).

---

## 2. Nutrition & Others tabs — trackable grids

- A grid of large tap tiles, one per palette item in that tab's category bucket:
  - **Nutrition tab:** items categorized `nutrition` (and `hydration` — confirm, OQ-3).
  - **Others tab:** items categorized `gear` / `other`.
- **Tap a tile → append `intake`** for that item (one tap = one item). The Undo toast then appears.
- Tiles are large, high-contrast, color-coded; sized for gloved/sweaty taps. If a bucket holds more items than fit, the grid scrolls (OQ-5).

---

## 3. AID tab — aid-station manager

Aid stations are **intervals**: an arrival (`aidStationEntered`) and a departure (`aidStationExited`), paired by a `visitID`. A station may be visited more than once (loops / out-and-backs); each is a distinct visit. "Finish" on a station row finishes the **aid station**, not the race.

**Three visit states** (projected): `inProgress` (you're here now), `departed(at:)` (you tapped Finish — an approximate exit time), `departedExitUnrecorded` (you left without tapping Finish). The last is reached automatically: **a new arrival implicitly departs any still-open visit** with no recorded exit. So forgetting to Finish — realized only when you reach the next station — needs no special action: just mark the next arrival, and the prior visit becomes `departedExitUnrecorded`, its dwell left for GPS. (No mid-race "set the exit time" prompt — you don't know the precise time either.)

**Approximate anchors, not ground truth.** Enter/exit timestamps are as-tapped; app 3 refines real arrival/departure and dwell from the GPS velocity trace, which generally outweighs the taps (you might tap Finish 5 min after actually leaving). The tracker's aid events exist to say *which station, roughly when* — anchors for the GPS join — not to be authoritative intervals. `departed(at:)` is a weak prior (and the fallback when no GPS exists); `departedExitUnrecorded` means rely entirely on GPS for departure.

**Planned mode** (stations came from a plan / CSV), top → bottom:
- **Passed** stations — read rows (departed, with or without a recorded exit time).
- **Current** station — `inProgress`, with a green **Finish** action → logs `aidStationExited` → becomes Passed.
- **Notes of the current aid station** — services and (where present) plan notes.
- **Upcoming** station — the next planned station; **tap to mark arrival** (`aidStationEntered`); implicitly departs the current if it's still open. Renders name + distance-to-next.
- **Finish race** — a distinct control (bottom of the tab, with confirm) → `raceEnded`. Kept visually separate from per-station Finish so a tired thumb can't end the race by accident. *(Resolves OQ-1.)*

**Plan-less mode** (no planned stations): a list of **past** visits + a **Start new aid station** button (mints an ad-hoc `aidStationEntered`, no `ordinal`, auto-label e.g. "Aid 1"), plus the same **Finish race** control. Aid tracking works with zero plan.

---

## 4. Feed tab — event stream (read)

- Chronological list of tracked events, **retractions applied** (a retracted event and its retraction both vanish).
- Each row: a category-colored icon + a label (item name, "Aid 2 — arrived / left", "Voice note", …). A departure with no recorded exit can read "left (time not marked)".
- **Audio is listed but not playable here** — playback is a post-race concern (race view, `mvp-plan.md` §6.4), consistent with capture-now-process-later.
- No record button (not a tracking tab).
- Ordering (newest-first vs oldest-first): OQ-4.

---

## 5. Record-voice button

- Bottom-right, on the three tracking tabs.
- **Tap-record-tap-stop:** first tap starts recording (button shows a clear recording state), second tap stops. On stop → write the clip to the bundle, append `voiceNote(audioFilename:, durationSec:)`, then show the Undo toast.
- Foreground capture only (no background audio mode); mono AAC/m4a.

---

## 6. Undo toast

- Bottom-left, appears after **any** tracking action (intake, aid arrival/departure, voice note).
- Shows **what was just tracked** + an **Undo** button.
- **Undo appends a `retraction(target:)`** referencing the just-created event — it does **not** delete or rewrite. Projections (feed, counts, visits) pre-filter retracted ids. (Because projections are pure folds, retracting an arrival also recomputes any visit it had implicitly departed back to `inProgress`.)
- **Long-lived:** ~10s, up to ~60s (vs the usual 2–5s), because mid-race reaction is slow. Tunable.
- Scope: undoes the **most-recent** trackable event only (the toast is the affordance). Per-row Feed retraction would be a later addition if broader undo is wanted (OQ-6).

---

## 7. Domain / projection impact (reflected in `mvp-plan.md` §4)

- Event enum gains `aidStationEntered(visitID:, ordinal:, label:)`, `aidStationExited(visitID:)`, and `retraction(target:)` (un-deferred). The old single `aidStation` case is removed.
- `AidStationVisit` carries a three-state `VisitState` — `inProgress` / `departed(at:)` / `departedExitUnrecorded`. Fold rule: open on entry, close on matching exit; after folding, any still-open visit that has a **later entry** becomes `departedExitUnrecorded`, and the lone open visit with no later entry is the current station. Feeds the Passed / In-progress / Upcoming rendering and app 3's (GPS-refined) time-per-station.
- All projections drop retracted events first.
- `raceEnded` is emitted by the AID tab's **Finish race** control.

---

## 8. Open questions

1. ~~**Race-end trigger.**~~ **Resolved:** a distinct **Finish race** control in the AID tab (with confirm) emits `raceEnded`, kept separate from per-station Finish. (If instead the last station's Finish should *double* as race-end, that collapses the two — but removes the explicit aid-exit action.)
2. **AID notes source.** Is "Notes of the current aid station" just rendered services, or a dedicated plan-provided notes field (from `.trail`, later)? MVP can render services; a notes field can arrive with `.trail` ingestion.
3. **Category → tab mapping.** Confirm `nutrition` + `hydration` → Nutrition tab and `gear` + `other` → Others tab (esp. where hydration goes).
4. **Feed ordering.** Newest-first (most recent on top) or chronological.
5. **Grid overflow.** Fixed grid vs scroll when a bucket has many items.
6. **Undo breadth.** Toast-only (most-recent) for MVP; per-row Feed retraction later?

---

## 9. Hand-off

Implements WI-6. Prereqs: WI-2 (durable event log + projections, incl. the three-state visit fold), WI-3/WI-4 (palette + aid config), WI-5 (CSV import for planned stations). Invariants: append + fsync per action; Undo = retraction; aid visits pair by `visitID` with implicit departure on next arrival; aid timestamps are approximate (GPS-refined later); foreground-only; system light/dark; no GPS / background / nudges.
