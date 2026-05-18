# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TASK-027 — skeleton/pulse loading state on the home-page drop area

From the 2026-05-18 brainstorm. Today: dropping a UTMB-size GPX
freezes the UI for several seconds with no visual feedback. The
`Parsing` state already exists in the upload state machine, but
because `Gpx.parseGPX` is synchronous and runs inside the same
update handler that flips the state to `Parsing`, the renderer
never gets a chance to draw the Parsing UI before the parse
blocks. The user picked: pulse animation on the whole drop
component (not a spinner, "out of fashion").

Two-part fix:

1. **Defer the heavy parse one tick** so the `Parsing` state
   actually renders before the synchronous parse blocks the
   runtime. Use `Process.sleep 1 |> Task.perform` to bounce
   through the event loop.
2. **Pulse + skeleton styling** on the drop banner when the
   upload state is `Parsing` or `Persisting`. Tailwind's
   `animate-pulse` on the container; replace the inner button
   with a couple of skeleton placeholder bars so the component
   visibly shows "something is happening here, a card is on the
   way."

**Acceptance criteria:**

- [ ] New Msg `StartParse fileName content` runs the actual
      parsing logic that used to live in `GotContent`.
- [ ] `GotContent` now only sets `upload = Parsing fileName` and
      dispatches `StartParse fileName content` after
      `Process.sleep 1`.
- [ ] `StartParse` branches on `isProjectFile` exactly as the
      old `GotContent` did (decoding the `.trail` envelope vs.
      running `Gpx.parseGPX`).
- [ ] `viewUploadBanner` adds `animate-pulse` to the container
      div when the state is `Parsing` or `Persisting`.
- [ ] Inner content during Parsing / Persisting shows: a label
      ("Parsing X…" / "Saving X…"), 2–3 skeleton placeholder
      bars (`bg-slate-700 rounded h-* w-*`), the original sub
      caption, and no clickable button.
- [ ] `cursor-wait` and dragging disabled (today's behavior
      preserved).
- [ ] Build clean (`npm run build`).
- [ ] Bundle-string check: new strings ("Processing your file"
      or similar) present if added.
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
