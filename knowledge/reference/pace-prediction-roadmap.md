# Pace Prediction Roadmap

**Status:** largely implemented — the predictor + athlete-profile + Strava-sync
arc shipped (TASK-014..021 + 024/024b; see `planning/DONE.md`). Only **TASK-022**
(calibration from past activities) remains open. Kept as the design record: the
*why* and the trade-offs behind what was built.
**Source:** `archive/trail_race_planner_spec.md` (an exploration the user did with another agent — archived 2026-05-18), cross-referenced against the current codebase, ADR-0003, and two adjacent projects (`strava-mcp`, `cadence`).

This doc *was* the plan; most of it is now built. The sections below are kept in
their original proposal voice where that voice is still the clearest record of
the reasoning — but the status header above is authoritative on what shipped.

---

## 0. TL;DR

- The distributor (Tobler distribution, ADR-0003) answers a narrow question well: *given a target total time, how should it split across kms?* It does **not** predict what the target should be, doesn't model the athlete, and doesn't learn — so we layered a predictor on top of it rather than changing it.
- That **Layer B time predictor** (component-based: climb time + descent time + runnable + aid) **shipped** as `Predictor.predict` (`src/Predictor.elm`), fed by **athlete profiles** that hold the coefficients (`AthleteProfile.elm`, settings at `#/profile`) and driven by a bidirectional **aggressiveness slider** mapping between "intensity" and "predicted total time" (TASK-018/019/020).
- Most of the predictor's value is **gated on past-activity data** (climb rate, sustainable HR by duration, Riegel fade exponent). Without data it falls back to population tiers and the result is fuzzy. That argued for a **two-phase build**: profiles + slider with hand-set defaults first, **then** Strava ingestion to fit those defaults. Phase 1 shipped; the data-driven fit (**TASK-022 — calibration**) is the one piece still open.
- The "no backend ever" constraint in `project-brief.md` was the real architectural tension. It was **resolved as a hybrid** (§8): Layer 0 stays fully local; Layer 1 is opt-in Strava sync via the `cadence` backend (TASK-024/024b shipped). The constraint's wording in the brief is corrected by TASK-037.
- The actual-vs-planned comparison **shipped as TASK-016** (PR #19) — useful even with zero predictor work, and the per-km actual times it captures are exactly the data **TASK-022** will use for calibration.

---

## 1. What's in the spec

The spec is a comprehensive heuristics reference. The pieces, grouped by how immediately useful they are to *this* project:

### A. Course-only computations (no athlete data needed)

- **Equivalent flat distance** — `D + ascent/100 + descent/1000` (refined Naismith-Scarf, 1:10). A single derived number, useful as a sanity-check display on the race card.
- **Elevation density** — `gain / distance`, bucketed into flat / rolling / hilly / mountainous / very-mountainous / extreme. A label, no math.
- **Segment classification by grade** — already implicit in our per-km slope; we just don't bucket it.

### B. Population-default lookup tables

- Climb rate (vm/h) by performance tier: elite 1100–1400 down to hiker 300–500.
- Descent pace (min/km) by grade × technicality (4×4 table).
- Technicality multiplier on flat pace (5 buckets).
- Aid-station time budget by style (5 buckets, 30 s – 30 min/station).
- Altitude penalty (5 bands).
- Heat / cold penalty (3 bands).
- Night-running penalty (+10–20% on technical segments).

These are **the defaults a profile carries**. They're not the model — they're the priors that get refined from data.

### C. Athlete model (needs data to fit)

- Vertical climb rate as a function of cumulative race time — exponential decay.
- Sustainable HR by race duration — empirical curve from past races.
- Fatigue coefficient — pace inflation per hour after a threshold.
- HR drift / cardiac decoupling — rise in HR at constant pace, used as a leading indicator.
- Riegel `k` for ultra projection — fit from `(distance, time)` pairs.
- Descent skill — quad-damage degradation past 2000 m cumulative descent.

Every one of these is **uncomputable without past activity data**. They're aspirational; ingestion has to come first.

### D. Components we won't touch yet

- Running power / Critical Power model — requires Stryd-class hardware. Skip.
- Multi-day stage races — out of scope per `project-brief.md`.
- Adventure-mode / navigation penalty — out of scope.
- Self-supported penalty — out of scope.

### E. Pacing-output heuristics

- "Even effort, not even pace" framing.
- Power-hike threshold around 12–15 % grade.
- Risk markers (DNF probability, bonk-zone identification) — needs a lot of data.
- The "stretch target guardrail" — flag when target requires unsustainable HR for the duration. Useful, but downstream.

---

## 2. The two-engine model (separation of concerns)

The cleanest mental model: **predictor** and **distributor** are different problems.

```
┌────────────────────────────────────┐         ┌──────────────────────────────┐
│  PREDICTOR (shipped, Layer B)      │  seed   │  DISTRIBUTOR (current)       │
│  course + profile + intensity      │  ─────▶ │  target_total + locks → kms  │
│  → predicted total time +          │  total  │  (Tobler, ADR-0003)          │
│    per-km / per-section splits     │         │                              │
└────────────────────────────────────┘         └──────────────────────────────┘
```

**Why split them:** the distributor is mathematically simple, deterministic, and works with zero athlete data. It stays exactly as ADR-0003 describes. The predictor is the new piece: it answers *"what total time is realistic?"* and *"how does it shift if I dial intensity up or down?"*

The output of the predictor flows into the distributor as a seed value. The user can accept it, modify it, or ignore it entirely (input a number from intuition). The distributor doesn't care where the target came from.

**How it landed in the code:** `Planning.distribute` didn't change. We added a `Predictor.predict` function alongside it (`src/Predictor.elm`). The two are composed by the UI, not by Elm types — exactly as sketched here.

---

## 3. Profile data model

A profile is an athlete-level bundle of constants. It's not race-level. MVP = one active profile globally; future = named profiles for "summer", "post-taper", etc.

Proposed shape (Elm-ish pseudocode, not committed):

```elm
type alias Profile =
    { id : ProfileId
    , name : String
    , -- climbing
      verticalRateVmh : Float           -- baseline, on moderate grades
    , climbFatigueK : Float             -- exp(-k * t), default 0.03
    , -- descending
      descentSkill : DescentSkill       -- Cautious | Average | Confident | Expert
    , quadDamageThresholdM : Float      -- cumulative descent before fatigue penalty kicks in
    , -- flat / runnable
      flatTrailPaceMinKm : Float        -- on moderate trail at sustainable effort
    , technicalitySkill : TechSkill     -- Novice | Average | Experienced | Expert
    , -- general fatigue
      fatigueThresholdH : Float         -- when pace inflation starts (default 2.0 h)
    , fatigueSlopePerH : Float          -- pace inflation rate (default 0.015 = 1.5 %/h)
    , -- aid stations
      aidStyleDefault : AidStyle        -- Elite | Lean | Standard | Relaxed
    , -- optional, gated on HR data
      lthrBpm : Maybe Int
    , maxHrBpm : Maybe Int
    , -- bookkeeping
      source : ProfileSource            -- HandTuned | FittedFrom <activity ids>
    , confidence : Confidence           -- Low | Medium | High, based on data sufficiency
    , updatedAt : Posix
    }
```

Important: **every field has a population-tier default**. A brand-new profile is "Mid-pack" preset = `{ vmh = 750, fatigueSlope = 0.02, descentSkill = Average, ... }`. The user can override individual fields without filling everything in.

Storage: same IDB store pattern as races. Single object store `profiles`, plus a `settings` singleton holding `activeProfileId`.

---

## 4. Aggressiveness slider — bidirectional binding

This is the core UX insight from the user's message. The slider is bound to the predicted total time, and either side can drive the other.

### Mechanics

For a given course + profile, the predictor is a function `T(intensity)` where intensity is a scalar (call it `i`, conventionally 0.85 = ultra-conservative, 1.00 = goal, 1.10 = push, 1.20 = all-in). `T` is monotonic in `i`: higher intensity → faster predicted time.

Concretely, the predictor breaks the course into climb / descent / runnable / aid components (Layer B from spec §3) and applies `i` as a multiplier on climb rate and flat pace (inverse multiplier on pace), then sums.

**Forward (slider → time):** UI slider position → `i` → `T(i)`. Show the predicted finish.

**Inverse (time → slider):** user types a target → numerically invert (binary search or analytic if components are linear in `i`) to get `i`. Show where that `i` falls on the slider.

**Edge cases:**
- Target faster than `T(1.20)` — slider pegs right with a red "beyond all-in" warning ("this target requires X% above your fastest sustainable intensity").
- Target slower than `T(0.85)` — slider pegs left with a neutral "well below conservative" note.
- No profile / no data — slider still works but with population defaults; confidence label is "Low".

### Why both directions matter

The user's example: "if I input 2 h for a 20 k race with lots of elevation that'd be aggressive, and 4 h would be not." The slider makes that visible — they enter a number, see *where it lands*, and can react. They aren't being told what to run; they're being shown what their number implies.

### Worked example

20 km / 1200 m gain / moderate technicality, mid-pack profile (vmh = 750, flat trail pace = 6:00/km):
- Predictor at `i = 1.0`: climb 1200/750 = 1.6 h, descent (assume 1200 m / ~6:30/km) ≈ 0.9 h, runnable ~8 km at 6:00/km = 0.8 h, aid 0.1 h → **3.4 h**.
- At `i = 1.10`: ≈ **3.1 h**.
- At `i = 0.85`: ≈ **4.0 h**.
- User enters 2:30 → solve for `i` → ~1.36 → slider pegs right, warning shown.
- User enters 4:30 → `i` ~ 0.76 → slider below "conservative", neutral note.

These numbers will be wrong in absolute terms until the profile is calibrated. They will be **directionally useful** from day one.

---

## 5. UI surfaces

Two distinct surfaces, by audience:

### 5a. The slider (in-planner, primary)

In the race planning view, above the existing total-time input:

```
┌─────────────────────────────────────────────────────────┐
│  Target total time                                      │
│  [ 03:24 ]    Predicted: 03:30 (mid-pack profile)       │
│                                                         │
│  Effort   ◄─────●──────────────────►                    │
│           conservative  goal  push  all-in              │
│           (your time → 1.04× intensity — "push")        │
│                                                         │
│  Confidence: Low — no past races. Improve →             │
└─────────────────────────────────────────────────────────┘
```

The slider is a single primary control. The numerical target stays editable. They're linked.

### 5b. Profile settings (out-of-race, secondary)

A new top-level route `#/settings/profile` (or `#/profile`) with:

- Preset picker — load Mid-pack / Strong mid-pack / Sub-elite / Custom into the form.
- All profile fields editable with sensible inline help ("Vertical climb rate (vm/h). Strong mid-pack ≈ 850. Check your watch for past climbs.").
- Confidence indicator + "data points contributing to this value" once Strava ingestion exists.
- Profile import/export (round-trip JSON, like `.trail` files).

**This is one screen, not a wizard.** Keep it dense and editable. Power-users will tune it; new users will leave it at preset defaults.

### 5c. Course summary (passive, always-on)

Add to the race card / overview:
- Equivalent flat distance.
- Elevation density label.
- Predicted finish band for the active profile (e.g., "Mid-pack: 3:10 – 4:00, goal ~3:30").

No interaction — just framing.

---

## 6. Strava integration — what, how, phasing

### What we want from Strava

For **planned-vs-actual** comparison (post-race):
- The completed activity's GPX track.
- Per-km splits or the time-stream + distance-stream so we can recompute per-km splits at our own boundaries.

For **calibration** (past races / long runs):
- Same data plus HR stream, optionally cadence and power.
- Aggregate stats per activity.

### What's actually available from the Strava API

- **GPX file download via API: NOT supported.** You can reconstruct one from the streams endpoint (lat/lng + altitude + time). This is fine and arguably better — streams include HR / cadence which a vanilla GPX would drop.
- `/athlete/activities` — paginated list of summaries.
- `/activities/{id}` — full detail (incl. `splits_metric` Strava-computed 1 km splits).
- `/activities/{id}/streams?keys=time,distance,latlng,altitude,heartrate,velocity_smooth,grade_smooth` — time-series at full resolution.
- Rate limit: 100 req / 15 min, 1000 / day.

### Phasing

**Phase 1 — manual upload, fully local.** No backend.
- User picks a race in trail.
- "Link actual run" button → file picker.
- Two accepted inputs: a Strava `.gpx` export (manual from `strava.com/activities/{id}/export_gpx`), or a `.fit` file from the watch.
- We parse the file, snap to the race course (already have Haversine in `Gpx.elm`), compute per-km actual splits at *the same boundaries the plan used*, render planned-vs-actual diff inline in the planning table.
- This works today, no OAuth, no Fly.io, no nothing.

**Phase 2 — Strava OAuth helper (optional).** Backend exists, app degrades without it.
- A tiny OAuth-proxy service (probably an extension of the existing `cadence` backend, since it already has the auth flow and a SQLite token store).
- The trail app stores the refresh token + a session token in IDB. On every Strava call, the helper exchanges → fresh access token → trail app makes the actual API call client-side, or the helper proxies it (simpler).
- The trail app remains usable offline; Strava panel just shows "not connected" without the helper.
- "Link actual run" gains a second mode: multi-select from recent activities (with search), pull streams, reconstruct GPX, compute splits, done.

**Phase 3 — calibration ingestion.** Same auth as Phase 2 but bulk.
- "Calibrate from past activities" wizard.
- Select N hard / long efforts (or all of them).
- We pull streams for each, extract climb segments, descent segments, runnable segments; compute the athlete-level fits described in §7.
- Updated profile written back to IDB. User sees diff: "Vertical rate 750 → 870 vm/h based on 8 activities."

### Where the OAuth helper lives — **resolved**

Decision (2026-05-15): **extend `cadence`'s existing backend.** The full spec is in `cadence-backend-spec.md`; the cadence side has its own `knowledge/` scaffold and is implementing it as 5 PRs (TASK-001..TASK-005 over there).

Implications for trail:

- **The local-first constraint softens deliberately** (see §8 below). Strava sync becomes an opt-in feature, gated on a backend reachable + a session token in IDB. The app still works fully offline for all non-Strava flows.
- **Phase 1 manual import is no longer required as a fallback.** We could still build it (a `.gpx` file picker for a completed run) — it's useful when offline or when the user wants to import a `.fit` from Coros directly. But it's no longer the *only* path to actual-vs-planned.
- **TASK-016 (planned-vs-actual) stays valuable as the foundation.** The GPX-parsing, snap-to-course, and diff-rendering logic is identical whether the GPX came from a file picker or was reconstructed from Strava streams. Build the math first; swap the source later.
- **TASK-024 (the trail-side OAuth integration) is now unblocked** and tracks cadence's five PRs. It can start as soon as cadence ships TASK-003 (state-routing) — that's the minimum cadence surface trail needs.

The two backends-not-picked (Cloudflare Worker, strava-mcp extension) are not "second choices" — they're closed. If cadence ever proves the wrong host, that's a fresh decision, not a fallback.

---

## 7. Calibration — what becomes possible

Once we have past-activity streams, these are the fits worth running (ordered by value-per-effort):

| Fit | Inputs needed | Output | Replaces |
|---|---|---|---|
| Vertical rate baseline | ≥5 climbs of >100 m at sustained effort | `vmh` per activity duration bin | Hand-set vmh field |
| Climb fatigue curve | ≥1 long race or 4 h+ effort with climbs throughout | `vmh(t) = vmh_max * exp(-k * t)`, fit `k` | Default `k = 0.03` |
| Sustainable HR by duration | ≥3 races across a 3× duration range | `hr_sustain(duration)` curve | None — new capability |
| Riegel `k` | ≥2 race distances logged | `T2 = T1 * (D2/D1)^k` | None — new capability |
| Fatigue slope (pace) | ≥3 long runs >2 h with grade-adjusted pace | `pace(t) = base * (1 + slope * max(0, t-threshold))` | Default 1.5 %/h |
| Descent technique | ≥5 sustained descents, ideally on rough trail | per-grade per-technicality multiplier | Lookup table |
| Decoupling rate | ≥3 long runs with HR stream | pace/HR drift % per hour | Risk flag |

**Minimum data for usable predictions** (from spec §20.4): around 5 quality activities for ±15 %, 2+ races across distance range for ±10 %. We surface confidence honestly; don't pretend more than the data supports.

**Feedback loop after each race:** after the user links the actual run, compare predicted vs. observed per segment. Identify which coefficients drove the biggest residuals. Surface to user ("climbing rate held up better than predicted — vmh updated +8 %"). This is the "post-race analysis closes the loop" from spec §20.1.

---

## 8. Local-first stance — **resolved as "hybrid"**

`project-brief.md` originally said *"Local-first. Works fully offline after first load. No backend, ever."* The Strava integration softens this — but only by carving out an opt-in slice.

The shape we landed on (option 3 from the prior version):

- **Layer 0 — fully local.** All race storage, plan editing, GPX export, `.trail` round-trip, manual GPX upload for actual-vs-planned. Works offline forever. The promise of the original brief.
- **Layer 1 — opt-in Strava sync.** Requires a session token in IDB and the cadence backend reachable. Surfaces: link a race to a Strava activity, fetch streams for actual-vs-planned, calibrate the profile from past activities. Without the backend reachable, these UI surfaces show a "not connected" state and the app's Layer 0 features keep working.

TASK-024 has since landed (PR #25/#26), so the brief now needs this update — tracked as **TASK-037**. The agreed wording: *"Local-first. Layer 0 features (planning, storage, export) work fully offline. Layer 1 (Strava sync) is an opt-in enhancement that needs the cadence backend; the app degrades gracefully when it's unreachable."*

The implementation discipline: **no UI surface that exists only when the backend is reachable**. Strava sync is always *additive* to a fully-local experience.

---

## 9. Open questions

Things I'd want the user to weigh in on before committing tasks:

1. **Profile scope: one or many?** MVP = one global profile. Future: multiple named profiles for taper / heat / etc. — does that ever matter, or is one fine forever?
2. **Slider granularity: presets or continuous?** Four labelled stops (conservative / goal / push / all-in) is simpler; a continuous slider is more honest. The spec proposes both; the bidirectional inverse only works smoothly if it's continuous.
3. **Predictor failure mode: silent or loud?** When data is sparse, do we hide the prediction or show it with a big confidence-low badge? Spec §21 worked example argues for *loud* — "Predicted finish: 16h ± 1h45min (low confidence)."
4. **Actual-vs-planned: same view or separate?** Two reasonable shapes: extend the planning table with an "actual" column (compact, side-by-side) or a dedicated "race report" view (richer, more narrative). The existing parking-lot item assumes the former.
5. **Strava integration: hard line or soft line on the constraint?** The local-first answer dictates Phase 2 vs. never.
6. **Coros `.fit` export support?** Coros watches record `.fit`. If the user's actual-run file comes from Coros directly (not via Strava), we'd need a `.fit` parser. There's no Elm one; we'd need a JS port via `@garmin/fit-sdk` or hand-roll. Strava → GPX export side-steps this.
7. **Calibration interactivity: opaque fit or transparent?** "We updated your vmh from 750 to 870 based on these 8 activities" — should the user be able to see *which* activities, weight them, opt out individually? My instinct: yes, transparency builds trust in the model.

---

## 10. Suggested task breakdown for `BACKLOG.md`

Sized per `framework/working-style.md` (15–60 minutes each unless flagged L for "split when picked up"). Order is roughly value-per-effort.

**Foundation — low cost, high value, no Strava needed:**

- TASK-014 — Course summary card additions: equivalent flat distance + elevation density label, shown on the race index and overview. (S)
- TASK-015 — Per-km segment classification by grade (steep climb / moderate climb / rolling / moderate descent / steep descent) — derived from `Km.slope`, shown as a colour tag in the planning table. (S)
- TASK-016 — Planned-vs-actual upload: accept `.gpx` of a completed run, snap to course, compute per-km actual splits at the planned km boundaries, render side-by-side diff column in the planning table. **(M, high leverage — works without anything else.)**
- TASK-017 — Profile data model + IDB store + minimal settings page. Hand-set fields, preset picker (Mid-pack / Strong mid-pack / Sub-elite), one active profile global. (M)

**Predictor — depends on profile being in place:**

- TASK-018 — `Predictor.predict` module implementing Layer B (climb time + descent time + runnable + aid) with profile + intensity inputs. Pure function, unit-tested. (M)
- TASK-019 — Bidirectional slider UI on the planning page: intensity ↔ target time. Inverse via binary search of the predictor. Edge labels and warnings. (M)
- TASK-020 — Confidence indicator surfacing: predictor output annotated with confidence based on profile source (HandTuned = Low, Fitted from N activities = Medium/High). (S)

**Strava — phased; Phase 2+ requires a backend decision first:**

- TASK-021 — Strava activity-export-via-streams parser: given a JSON dump of streams, reconstruct enough to match a course. Local-only; could be fed by a manual MCP dump for now. (M)
- TASK-022 — Profile calibration from past activities: fit `vmh`, optional `lthr` band, fatigue slope. Surface "what changed and why." (L — split into per-fit subtasks.)
- TASK-023 — Decision on the OAuth helper (or no helper). Either an ADR for "we host a helper" or a decision to stay manual. (Decision task, not code.)
- TASK-024 — If Helper: OAuth proxy endpoints (likely extending `cadence`), Strava activity-list browser inside trail, multi-select link-to-race UX. (L)

**Out further:**

- Riegel-fit `k`, decoupling analysis, sustainable-HR-by-duration curve fitting, risk flags ("target requires X HR you've never sustained for Y h").
- Per-km gain/loss separately for slope factor (already in parking lot; folds into TASK-018 if we pick it up there).

---

## 11. Appendix — formulas and defaults we'd compute

### A. Course derived numbers

```
equivalent_flat_km        = distance_km + gain_m / 100 + loss_m / 1000
elevation_density_m_per_km = gain_m / distance_km
density_bucket             = pick by table (5–20 rolling, 20–40 hilly, 40–55 mountainous, 55–70 very, >70 extreme)
```

### B. Predictor (Layer B sketch)

```
i = intensity (scalar, 0.80–1.25)

climb_time_h        = gain_m / (profile.vmh * i)                         -- with fatigue decay applied per segment
descent_time_h      = sum over descent segments of distance / descent_pace(grade, technicality, profile.descentSkill)
runnable_time_h     = runnable_km / (60 / (profile.flatTrailPace / i))   -- pace inverted: faster pace at higher i
aid_time_h          = aid_count * aidStyleSecondsPer(profile.aidStyle) / 3600

predicted_total_h   = climb + descent + runnable + aid
predicted_total_h  *= fatigue_multiplier(predicted_total_h, profile)     -- iterate once to converge

solve_for_intensity(target_h) = numeric inverse of T(i), bracketed by [0.80, 1.25], bisection 8 iterations
```

`fatigue_multiplier(t, profile)`:

```
threshold = profile.fatigueThresholdH
slope     = profile.fatigueSlopePerH
return 1 + slope * max(0, t - threshold)
```

### C. Population defaults (when profile is a fresh preset)

| Tier | vmh | flatTrailPace | fatigueSlope | descentSkill | aidStyle |
|---|---|---|---|---|---|
| Beginner | 550 | 7:00 | 0.030 | Cautious | Standard |
| Mid-pack | 750 | 6:00 | 0.020 | Average | Lean |
| Strong mid-pack | 850 | 5:30 | 0.015 | Confident | Lean |
| Sub-elite | 1000 | 5:00 | 0.010 | Expert | Elite |

### D. Confidence rubric

| Profile source | Confidence | Predictor margin to display |
|---|---|---|
| HandTuned, no data | Low | ±20% |
| Fitted from <5 activities | Low | ±15% |
| Fitted from 5–15 activities, no races | Medium | ±10% |
| Fitted, includes ≥1 race | Medium-High | ±8% |
| Fitted, includes ≥2 races across distance range | High | ±5% |

---

## 12. What this doc is and isn't

**This was:** a proposal, written so a future session (or the user) could pick it apart, agree with parts, and reject parts. The structure mirrors how the spec would land in this codebase, not how an external paper would describe the math. Most of it was then agreed and built — see the status header at the top and `planning/DONE.md` (TASK-014..021, 024/024b); the sections kept their proposal voice because that voice is still the clearest record of the reasoning.

**What's still open:** only **TASK-022** (calibration from past activities). Everything else here shipped as a proper task with acceptance criteria (and, where non-trivial, an ADR).

**Sources cross-referenced:** the spec doc itself, ADR-0003, `src/Planning.elm`, `project-brief.md`, `strava-mcp/src/strava/client.ts` (for what the Strava API actually returns), `cadence/server/handlers/*.go` (for what a working OAuth + backfill loop looks like).
