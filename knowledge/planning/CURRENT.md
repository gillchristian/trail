# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TASK-026 — show avg HR per km on linked actuals

Recorded from the 2026-05-18 brainstorm (whiteboard:
`training-as-analysis.md`). Strava already returns the `heartrate`
stream alongside time/distance/latlng/altitude, and `StravaApi.elm`
already requests it. The decoder, the data model, and the UI haven't
caught up. We surface average HR per km wherever an actual is linked
*and* the source carried HR data. File-uploaded `.gpx` actuals have
no HR for now (the GPX-with-time parser doesn't read `<extensions>
<gpxtpx:hr>`); they display nothing for HR. This is the only
analysis-side feature admitted out of the brainstorm — see the
whiteboard for the "must sharpen planning" rule.

**Acceptance criteria:**

- [ ] `ActualPoint` carries `hr : Maybe Int`.
- [ ] `StravaStreams.parse` decodes the `heartrate` stream (default
      `[]` if missing, for back-compat with old saved actuals never
      re-linked) and populates `ActualPoint.hr`.
- [ ] `ActualGpx.parse` (file-upload path) sets `hr = Nothing` on
      every point.
- [ ] New `ActualGpx.computeHrPerKm : ActualTrack -> Maybe (Dict Int
      Int)` returns `Nothing` if no point has HR; otherwise
      `Just (Dict.fromList ...)` with km-index → average bpm.
- [ ] `Types.ActualSplits` gains `hrPerKm : Maybe (Dict Int Int)`.
- [ ] `encodeActualSplits` writes the field (null when Nothing).
- [ ] `decodeActualSplits` defaults `hrPerKm` to Nothing when absent
      (back-compat for actuals saved before this PR).
- [ ] Both ActualSplits construction sites (file upload, Strava
      link) compute and persist `hrPerKm`.
- [ ] Per-km card: when HR is available for this km, display an
      "Avg HR" stat next to / under Actual + Δ.
- [ ] Km table: when `actualSplits.hrPerKm` is `Just`, add an "HR"
      column to the right of Δ vs plan, showing the avg bpm or "—"
      when the km has no HR data.
- [ ] Build clean (`npm run build`).
- [ ] Bundle-string check: new labels ("Avg HR", "HR" column).
- [ ] Journal entry + PR opened and merged.

User flagged in `samples/aid-station.png`: km has 15 m gain, slope 1.5 %, an
aid station "Second · 13.7 km · 1 min rest" inside it. Display shows
**Target time 6:11 / Pace 6:11/km / Actual 7:14**. Today the math treats
`result.seconds` as moving time only (aid rest is subtracted from the
budget before distribute). But the user — and any reasonable reader — sees
the row and expects Target to be **clock time** (what you'd see on the
watch: moving + the 1:00 you'll be standing at the aid). With clock-time
target, the pace would be `(6:11 − 1:00) / 1 km = 5:11/km` and Δ vs plan
would be apples-to-apples against the actual.

Today the math is right for totals but the display is misleading at the km
level whenever an aid station falls inside that km. Internal storage stays
as moving time per km; only the display layer adds the in-km aid rest.

**Acceptance criteria:**

- [ ] Per-km card "Target time" field shows clock time = `result.seconds +
      restInThisKm` (moving + aid rest in that km).
- [ ] Per-km card "Pace" stays moving-only = `result.seconds / distance`,
      unchanged from today.
- [ ] When user types into the Target field on a km with aid rest, the
      typed value is parsed as clock time → `Manual (typed − restInThisKm)`
      stored.
- [ ] When `restInThisKm > 0`, the per-km card shows a small hint near the
      target field that reads e.g. "incl. 1:00 aid" so the user understands
      what's being included.
- [ ] km table "Target" column shows clock time per km.
- [ ] km table "Pace" column stays moving-only.
- [ ] Section table "Section time" stays as today (it already aggregates
      kms; aid rest already shows in its own row).
- [ ] Section card stats: no change required — section pace already comes
      from `sectionSeconds / sectionDistance` and `sectionSeconds` is the
      sum of `result.seconds` (moving). Verify the labels read sensibly.
- [ ] Total row at the bottom of the km table stays as today — already
      sums to clock time (target was always clock time at the total).
- [ ] Δ vs plan in km card / km table / section table now compares
      clock-time-planned vs clock-time-actual. Should yield smaller |Δ|
      for kms with aids in them, all else equal.
- [ ] Build clean (`npm run build`).
- [ ] Manual sanity check on the sample: km with 1:00 aid, target 6:11 ⇒
      pace 5:11/km. With actual 7:14 ⇒ Δ vs plan = +1:03 still (the user's
      example numbers must hold).
- [ ] Journal entry + PR opened and merged.
