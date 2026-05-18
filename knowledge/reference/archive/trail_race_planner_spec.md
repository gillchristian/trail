# Trail Race Pace Planner — Heuristics & Reference Spec

A specification document for building a trail race time prediction and pace planning system. Contains the underlying models, formulas, reference tables, and worked examples.

---

## 1. Purpose

Predict finishing time (or required pace) for trail/mountain ultra races given:
- Course distance (km)
- Cumulative elevation gain (m)
- Cumulative elevation loss (m) — often equal to gain but not always
- Course technicality
- Athlete's flat-running fitness baseline
- Target time OR target finishing band

The system should expose **two layers of model**:
- **Layer A (heuristic):** Linear flat-equivalent distance conversion. Fast, useful for quick comparisons across races.
- **Layer B (component-based):** Decomposes moving time into climbing, descending, runnable, and aid-station components with adjustable coefficients. Significantly more accurate, especially for non-linear courses.

Default user-facing predictions should use Layer B. Layer A is useful for sanity checks and race-to-race comparisons.

---

## 2. Layer A — Flat-Equivalent Distance Heuristic

### 2.1 Origin

Based on **Naismith's Rule (1892)** as reformulated by **Scarf (1998)**, which expresses climb cost as horizontal-distance equivalence.

### 2.2 Core formulas

**Naismith-Scarf (1:8 ratio) — analytically derived, tested on fell running:**
```
equivalent_distance_km = distance_km + (ascent_m / 125)
```
i.e., 125 m of climb = 1 km of flat equivalent.

**Trail/ultra-running convention (1:10 ratio) — conservative, widely used:**
```
equivalent_distance_km = distance_km + (ascent_m / 100)
```
i.e., 100 m of climb = 1 km of flat equivalent.

**Refined with descent term (recommended for Layer A):**
```
equivalent_distance_km = distance_km + (ascent_m / 100) + (descent_m / 1000)
```
i.e., 100 m of climb = 1 km, 1000 m of descent = 1 km.

### 2.3 Predicted time

```
predicted_time_h = equivalent_distance_km / flat_equivalent_pace_kmh
```

Where `flat_equivalent_pace_kmh` is the pace the athlete can sustain for a flat ultra of comparable duration (NOT their road marathon pace).

### 2.4 Known limitations of Layer A

The linear model breaks in the following ways:
- **Treats descent as essentially free.** True only for non-technical, moderate grades. Steep technical descent can approach climbing in time cost.
- **No fatigue term.** Late-race climbs cost disproportionately more than early ones.
- **No technicality term.** A 10% smooth fire road and a 10% rocky/rooty trail have very different speeds at identical grades.
- **No altitude term.** Above ~2500 m aerobic ceiling drops measurably.
- **Hides individual variance** — descent skill, climbing economy, and flat pace are independently distributed across athletes.

Layer A's residual error against actual race times typically runs ±10–20% for ultras.

---

## 3. Layer B — Component-Based Time Model

### 3.1 Structure

Decompose course into segments by terrain type, compute time per segment, sum.

```
total_time = climbing_time + descending_time + runnable_time + aid_time + adjustments
```

### 3.2 Segment classification

For each course segment (between two waypoints or aid stations), classify by average grade:

| Grade range | Classification | Movement mode |
|---|---|---|
| ≥ +10% | Steep climb | Power-hike or hike-march |
| +4% to +10% | Moderate climb | Run-hike mix |
| -4% to +4% | Rolling/runnable | Run |
| -4% to -10% | Moderate descent | Run |
| < -10% | Steep descent | Controlled run / careful descent |

Optional refinement: classify by absolute grade thresholds AND total vertical gained per segment (a 12% grade for 50 m is different from 12% for 800 m).

### 3.3 Component formulas

**Climbing time:**
```
climbing_time_h = ascent_m / vertical_rate_vmh
```
Where `vertical_rate_vmh` (vertical meters per hour) is the athlete's sustainable climbing rate. See §4.1.

**Descending time:**
```
descending_time_h = sum(segment_distance_km / descent_pace_kmh)
```
With `descent_pace_kmh` depending on grade and technicality. See §4.2.

**Runnable terrain time:**
```
runnable_time_h = runnable_distance_km / flat_trail_pace_kmh
```
Typically the athlete's flat trail pace, NOT road pace. Apply technicality multiplier from §4.3.

**Aid station time:**
```
aid_time_h = sum(stop_duration_min) / 60
```
Budget separately per station; do not fold into moving time. See §4.4.

---

## 4. Reference Tables (Coefficients)

### 4.1 Vertical climb rate by performance tier

Sustainable rate across a full ultra, on moderate-grade climbs (~10-20%). Steeper or more technical climbs reduce these by 10-25%.

| Tier | Vertical rate (vm/h) | Notes |
|---|---|---|
| Elite | 1100–1400 | World-class mountain runners |
| Sub-elite / podium club | 900–1100 | Top 5–10% of competitive ultra fields |
| Strong mid-pack | 800–900 | Trained, experienced trail runner |
| Mid-pack | 700–800 | Solid recreational ultra runner |
| Back-of-pack / cutoff zone | 500–700 | Less trained or strategic hiker |
| Hiking pace (steep) | 300–500 | Default for very steep terrain |

**Fatigue degradation:** Reduce vertical rate by ~5% per 4 hours of cumulative race time after hour 8. So a 900 vm/h baseline becomes ~810 vm/h by hour 16.

### 4.2 Descent pace by technicality and grade

Pace in min/km (lower = faster). Assumes runner is competent descender.

| Grade | Smooth (fire road) | Moderate trail | Technical (rocky/rooty) | Very technical (alpine, scree) |
|---|---|---|---|---|
| -4% to -8% | 4:30 | 5:00 | 6:00 | 8:00 |
| -8% to -12% | 4:30 | 5:30 | 7:00 | 10:00 |
| -12% to -18% | 5:00 | 6:30 | 8:30 | 12:00 |
| > -18% | 6:00 | 8:00 | 11:00 | 15:00+ |

**Descent quad-fatigue degradation:** Add 30 seconds/km per 1000 m of cumulative descent after the first 2000 m. So a runner doing their 4th major descent on a 9000-m-loss course should expect ~2 min/km slower than table values.

### 4.3 Flat / rolling pace and technicality multiplier

Start with the athlete's **flat trail pace** (typically 10-25% slower than road pace for the same effort). Apply terrain multiplier:

| Terrain | Multiplier |
|---|---|
| Paved / gravel road | 1.00 |
| Smooth singletrack | 1.05–1.10 |
| Moderate trail (some roots, rocks) | 1.15–1.25 |
| Technical singletrack | 1.30–1.50 |
| Very technical (alpine boulders, scree) | 1.50–2.00+ |

### 4.4 Aid station time budgets

| Style | Per-station avg | Total for 10-station race |
|---|---|---|
| Elite/disciplined | 30–90 sec | 8–15 min |
| Lean | 2–4 min | 20–40 min |
| Standard | 5–10 min | 50–100 min |
| Relaxed | 10–20 min | 1.5–3 h |
| Crew-meeting / drop bag | 15–30 min per major | Variable |

**Default assumption if not specified:** lean (~3 min per station, longer for major aid stations with drop bag access).

### 4.5 Course classification by elevation density

```
elevation_density_m_per_km = total_ascent_m / distance_km
```

| Density (m/km) | Classification | Examples |
|---|---|---|
| 0–5 | Flat | Road ultras, urban events |
| 5–20 | Rolling | Many lowland trail races |
| 20–40 | Hilly | Moderate trail ultras |
| 40–55 | Mountainous | UTMB, CCC, Western States |
| 55–70 | Very mountainous | Hardrock, Tor des Géants pieces |
| > 70 | Extreme | Vertical races, sky races |

### 4.6 Altitude adjustment

For sustained running above moderate altitude:

| Altitude | Pace/effort penalty |
|---|---|
| < 1500 m | None |
| 1500–2000 m | ~2–3% slower |
| 2000–2500 m | ~4–6% slower |
| 2500–3000 m | ~6–10% slower |
| 3000–3500 m | ~10–15% slower |
| > 3500 m | 15%+, individual variance dominates |

Apply only to segments above the threshold, not the whole race.

### 4.7 Heat / cold modifiers

| Condition | Penalty |
|---|---|
| < 5°C or > 25°C | +5% |
| < 0°C or > 30°C | +10–15% |
| > 35°C | +20% or DNF risk |

### 4.8 Night running penalty

For non-acclimatized runners on technical terrain in darkness, apply +10–20% pace penalty to night segments. Less for runners with extensive night-training, more for technical descents at night.

---

## 5. Adjustment Layers

### 5.1 Fatigue model (recommended)

Apply a time-dependent multiplier to all moving paces:

```
fatigue_multiplier(t) = 1 + max(0, (t - 8) * 0.015)
```
Where `t` is cumulative race hours. This adds ~1.5% pace slowdown per hour after hour 8. Conservative; can be tuned per athlete based on past race data.

For very long races (>24h), include sleep deprivation:
```
sleep_penalty = 1 + 0.05 if t > 20 else 0
sleep_penalty = 1 + 0.15 if t > 30 else previous
```

### 5.2 Cumulative descent damage

Apply additional penalty after first 2000 m of cumulative descent:
```
descent_damage_per_km = 0.5 min per 1000 m cumulative descent above 2000 m
```

### 5.3 Aggregate Layer B formula

```python
def predict_segment_time(seg, athlete, race_state):
    if seg.is_climb:
        base_rate = athlete.vertical_rate_vmh * fatigue_multiplier(race_state.elapsed_h)
        time_h = seg.ascent_m / base_rate
    elif seg.is_descent:
        base_pace = lookup_descent_pace(seg.grade, race.technicality)
        damage = max(0, race_state.cumulative_descent_m - 2000) / 1000 * 0.5
        adjusted_pace = base_pace + damage
        adjusted_pace *= fatigue_multiplier(race_state.elapsed_h)
        time_h = seg.distance_km * adjusted_pace / 60
    else:  # runnable
        pace = athlete.flat_trail_pace_min_km * technicality_multiplier(race.technicality)
        pace *= fatigue_multiplier(race_state.elapsed_h)
        time_h = seg.distance_km * pace / 60

    if seg.altitude_m > 1500:
        time_h *= altitude_penalty(seg.altitude_m)
    if race.is_night_segment(seg) and seg.is_technical:
        time_h *= 1.15
    return time_h
```

---

## 6. Athlete Profile (input model)

The system needs to fit/estimate these per athlete:

| Parameter | How to estimate |
|---|---|
| `flat_road_marathon_min` | Self-reported recent marathon |
| `flat_trail_pace_min_km` | Self-reported or derived (~marathon pace + 30–60 sec/km) |
| `flat_ultra_pace_min_km` (50 km / 100 km) | Self-reported recent ultra |
| `vertical_rate_vmh` | Self-reported from training data (Strava/Garmin segment efforts) |
| `descent_skill` | Subjective: cautious / average / confident / expert |
| `technical_skill` | Subjective: novice / average / experienced / expert |
| `heat_tolerance` | Subjective or inferred from past hot-race performance |
| `altitude_acclimatization` | Days at altitude in past 30 days |

The model should let users override defaults from any tier in §4.1–§4.7 with their own data.

---

## 7. Validation Benchmarks (Sanity Checks)

If a user inputs a target time, cross-check feasibility against these floors:

### For sub-15h on 100–110 km / 4000–4500 m courses:
- Marathon: under 3:30 (ideally 3:15–3:25)
- Flat 50 km: under 5:00–5:15
- Flat 100 km: under 9:30–10:00
- 50 km / 2500 m mountain race: 5:30–6:00
- Sustained vertical: 900–1000 vm/h for 2h test efforts

### For sub-30h UTMB (174 km / 9900 m):
- Marathon: under 3:20
- Flat 100 km: under 9:00
- CCC (101 km / 6100 m): under 17h
- Vertical: 800–900 vm/h sustained late in long efforts

### For finishing UTMB at cutoff (~46h30):
- Marathon: under 4:30
- Sustained power-hiking 600+ vm/h late in race
- Long-run habit of 6–8h efforts

Flag predictions that violate these floors with warnings.

---

## 8. Pacing Strategy Heuristics

These are output-facing recommendations, not inputs to the model:

### 8.1 Even-effort, not even-pace

Effort should remain constant; pace will vary widely with terrain. The planner should output pace targets PER SEGMENT, not a single average pace.

### 8.2 Negative split is rare in ultras

For races > 50 km with significant elevation, plan for:
- First third: 5–10% slower than average effort
- Middle third: average effort
- Final third: hold form, expect natural slowdown

### 8.3 Climb pacing

Power-hike threshold: above ~12–15% grade, hiking is usually more efficient than running for non-elite athletes. The planner should suggest hike/run boundaries based on athlete tier.

### 8.4 Aid station discipline

Pre-budget time per station. Display "time spent vs budget" cumulatively. The single most common avoidable time loss in ultras.

### 8.5 The "30-km rule"

In races > 80 km, the last 30 km determines the finish time more than the first 50 km. Predictions should weight late-race fatigue heavily.

---

## 9. Worked Examples

### Example 1: UTMB (174 km / 9900 m gain / ~9900 m loss)

**Layer A (refined):**
```
equivalent_distance = 174 + (9900/100) + (9900/1000)
                    = 174 + 99 + 9.9
                    = 282.9 km
```

For 31h target: 282.9 / 31 = 9.13 km/h = **6:34 min/km flat equivalent**.

**Layer B for 31h target:**
| Component | Estimate |
|---|---|
| 9900 m climbing @ ~900 vm/h (degraded to ~750 by end) | ~11 h |
| 9900 m descending across long technical sections | ~11 h |
| ~50 km runnable rolling @ 6:00/km | ~5 h |
| Aid stations (12 major, lean discipline) | ~2–3 h |
| **Total** | **~29–30 h moving + AS** |

Sub-30h is plausible for a sub-elite. 31h gives margin.

### Example 2: 108 km / 4300 m, 15h target

**Course profile:** 40 m/km elevation density = mountainous (low end).

**Layer A (refined):**
```
equivalent_distance = 108 + 43 + 4.3 = 155.3 km
```
For 15h: 155.3 / 15 = 10.35 km/h = **5:48 min/km flat equivalent**.

**Layer B:**
| Component | Estimate |
|---|---|
| 4300 m climbing @ ~800 vm/h | ~5.4 h |
| ~30 km descent @ 6:30/km moderate | ~3.25 h |
| ~48 km runnable @ 6:00/km | ~4.8 h |
| Aid stations (lean) | ~0.75 h |
| **Total** | **~14.2 h** |

15h target has ~45 min buffer. Achievable for strong mid-pack athlete.

### Example 3: 108 km / 4300 m, 22h cutoff

**Layer A:** Same equivalent distance (155.3 km). Required pace: 155.3 / 22 = 7.06 km/h = **8:30/km flat equivalent**.

**Layer B for 22h:**
| Component | Estimate |
|---|---|
| 4300 m climbing @ ~700 vm/h | ~6.1 h |
| ~30 km descent @ 7:00/km | ~3.5 h |
| ~48 km runnable @ 8:00/km | ~6.4 h |
| Aid stations (standard) | ~2 h |
| Fatigue/buffer | ~3 h |
| **Total** | **~21 h** |

Cutoff is genuinely achievable for a fit hiker-runner. Bigger concern is late-race climb degradation, not pace.

---

## 10. Suggested Implementation Flow

### Inputs
1. Course: GPX or manual entry (distance, gain, loss, optional waypoints)
2. Athlete profile (§6)
3. Target: time OR finish band ("strong mid-pack", "cutoff", etc.)
4. Environmental: expected temperature range, time of day, season

### Pipeline
1. **Parse course** → segments with grade, distance, technicality, altitude
2. **Layer A estimate** → quick equivalent-distance and predicted finish
3. **Layer B estimate** → component decomposition with fatigue/adjustments
4. **Sanity check** vs validation benchmarks (§7)
5. **Generate pacing plan** → per-segment target pace, cumulative time, aid budget
6. **Output**: predicted finish band, per-aid-station splits, effort cues, risk flags

### Outputs to surface
- Predicted finish time with confidence interval (±10% on Layer B is typical)
- Per-segment pace/effort target
- Per-aid-station cumulative split target
- Aid time budget remaining
- Risk flags (unrealistic target, weather, technicality skill gap, altitude exposure)
- Comparison: "this race is equivalent to a flat X km" for athlete intuition

### Calibration loop
Allow users to import past race results to fit personal coefficients:
- Personal `vertical_rate_vmh` (likely tier-correct but specific)
- Personal `flat_trail_pace` and `descent_skill` levels
- Personal `fatigue_coefficient` (some athletes degrade faster/slower than default 1.5%/h)

After 2–3 imported races, predictions should tighten to ±5% for similar-profile courses.

---

## 11. Edge Cases and Failure Modes

| Case | Handling |
|---|---|
| Net-downhill courses (descent > ascent) | Layer A formula still works; Layer B should cap descent benefit |
| Multi-day stage races | Reset fatigue partially each day; consider sleep recovery |
| Highly altitude-dominant courses (Hardrock, Andes) | Force altitude penalty as primary factor |
| Asymmetric loops (one giant climb, one giant descent) | Layer B segment decomposition is essential; Layer A misleads |
| Self-supported / unsupported events | Reduce aid budget, increase fatigue coefficient |
| Adventure-mode courses with navigation | Add 10–25% time penalty for route-finding |
| Cutoff-pressure races | Output should show buffer at each cutoff, not just final |

---

## 12. Open Calibration Questions

These are worth treating as tunable parameters rather than fixed constants, ideally informed by user-imported data:

1. The 1:8 vs 1:10 ratio choice — let users see both predictions
2. Fatigue slope (default 1.5%/h after hour 8) — varies significantly by athlete
3. Descent damage threshold (default 2000 m) — varies by quad durability
4. Technicality multipliers — subjective, hard to standardize across courses
5. Vertical rate degradation curve — likely non-linear, not the 5%/4h shorthand

These should be tunable in the model and exposed in the planner as "advanced settings" or fitted from imported data.

---

## 13. GPX Parsing & Course Preprocessing

### 13.1 Required output from GPX

For each track in the GPX, extract a point series with:
- `lat`, `lon`, `elevation_m`, `time` (if present), `cumulative_distance_m`

Then derive:
- `cumulative_ascent_m`, `cumulative_descent_m`
- Per-point `grade_pct` (smoothed)
- Per-point `altitude_m`

### 13.2 Elevation smoothing

Raw GPS elevation is noisy. Apply smoothing before computing gain/loss:

```python
# Recommended pipeline
1. Downsample to ~1 point per 10-20 m of horizontal distance
2. Apply low-pass filter (Savitzky-Golay or simple rolling mean, window ~50-100 m)
3. Snap to SRTM/Mapzen elevation data if available (more accurate than GPS barometric)
4. Discard elevation changes below a threshold (e.g., <2 m noise floor)
```

Without smoothing, total ascent values can be inflated 30–50%+ vs the "official" race profile. Strava itself does heavy smoothing; expect ~5–15% disagreement between sources.

### 13.3 Segmentation strategy

Once smoothed, split the course into segments using one of these strategies (allow user choice):

**Strategy A — Fixed distance:** 1 km segments. Simple, uniform.

**Strategy B — Grade-based:** New segment when grade changes class (climb / runnable / descent). Better for component modeling.

**Strategy C — Aid-station bounded:** Segments span aid stations. Best for race-day pacing displays.

Hybrid: use Strategy C as the user-facing structure, with Strategy B sub-segments inside each aid-to-aid section.

### 13.4 Per-segment fields

For each segment, compute and store:

| Field | Notes |
|---|---|
| `distance_km` | |
| `ascent_m`, `descent_m` | Sum of positive/negative elevation deltas |
| `avg_grade_pct` | (ascent - descent) / distance |
| `avg_abs_grade_pct` | (ascent + descent) / distance — captures "lumpy" rolling |
| `max_grade_pct` | Worst sustained climb in segment |
| `mean_altitude_m` | For altitude penalty |
| `segment_class` | climb / descent / rolling / mixed |
| `technicality` | Inferred from external data or user override; default `moderate` |
| `expected_time_of_day` | For night-segment flag |

### 13.5 Technicality inference

GPX alone cannot infer technicality. Options to source it:
- User manual override per segment
- Strava segment metadata (rare for trail)
- External APIs (Trailforks, AllTrails — limited and often paid)
- Default by region/race type (race organizer often specifies)

A reasonable MVP: ask user to classify the whole course (smooth / moderate / technical / very technical), apply uniformly. Add per-segment override later.

---

## 14. Power / HR-Based Pacing Layer

### 14.1 Why add it

Pace-based pacing fails on variable terrain because the metric itself varies wildly. **HR and power are terrain-invariant** — they reflect physiological cost directly. For trail running, HR is the practical primary metric; power (via Stryd or similar) is more accurate but requires extra hardware.

### 14.2 HR zone model

Standard 5-zone model anchored to **lactate threshold heart rate (LTHR)**:

| Zone | % LTHR | Sustainable for | Use case |
|---|---|---|---|
| Z1 | <81% | Multi-hour, all day | Recovery, very long ultras |
| Z2 | 81–89% | 3–8 h | Ultra race effort |
| Z3 | 90–93% | 1–3 h | Marathon to 50k effort |
| Z4 | 94–99% | 20–60 min | Threshold workouts, 10k-half |
| Z5 | 100%+ | <20 min | VO2max, race finishes |

LTHR estimation: 30-min time-trial average HR, OR ~95% of max HR for trained runners.

### 14.3 Sustainable HR by target duration

Empirical guidance for HR ceiling by race duration (% of LTHR):

| Race duration | Sustainable HR ceiling |
|---|---|
| <1 h | 100–105% LTHR (Z4-Z5) |
| 1–2 h | 95–100% (high Z3 / Z4) |
| 2–4 h | 88–94% (mid Z3) |
| 4–6 h | 84–90% (low Z3 / high Z2) |
| 6–10 h | 80–86% (Z2) |
| 10–15 h | 76–82% (low Z2) |
| 15–24 h | 72–78% (Z1-Z2 boundary) |
| 24–48 h | 68–75% (Z1) |
| >48 h | 65–72% (deep Z1) |

These are population averages. **Individual variance is large** — calibrate from user's own race HR data once available (see §16.4).

### 14.4 HR-based prediction inversion

Given a target finish time, derive target HR ceiling, then convert back to expected paces per segment using the athlete's pace-at-HR profile (built from past data):

```python
target_hr = sustainable_hr_for_duration(target_finish_h, athlete.lthr)
for segment in course:
    # Athlete's flat pace at this HR, on this terrain class
    base_pace = athlete.pace_at_hr(target_hr, terrain=segment.technicality)
    # Apply grade adjustment
    segment_pace = base_pace * grade_factor(segment.avg_grade_pct)
    segment_time = segment.distance_km * segment_pace
```

### 14.5 HR drift / cardiac decoupling

Even at constant pace, HR rises over hours. Apply drift correction:
```
drift_per_hour = 1.5% to 3% of LTHR (3% for hot conditions or unconditioned athletes)
```
This means if your target sustainable HR is 145 at hour 1, plan for 140 cap at hour 6. The pacing engine should reduce target HR linearly across race time to keep the *physiological* effort constant.

### 14.6 Running power (Stryd / footpod)

Critical Power model (borrowed from cycling, adapted for running):
```
P(t) = CP + W' / t
```
Where:
- `CP` = Critical Power, sustainable indefinitely (or ~45 min for running)
- `W'` = anaerobic work capacity above CP (Joules)
- `t` = duration

For ultra prediction:
```
target_power = CP * intensity_factor(target_duration_h)
```

Intensity factor table (Stryd-style):

| Duration | IF (% of CP) |
|---|---|
| <1 h | 100–105% |
| 1–3 h | 90–95% |
| 3–6 h | 80–88% |
| 6–12 h | 72–80% |
| 12–24 h | 65–72% |
| >24 h | 60–68% |

Power has the major advantage of being **grade- and surface-corrected by design** — a constant power output represents constant physiological effort across any terrain. For users with Stryd or equivalent, power should be the primary pacing metric.

---

## 15. Strava Data Ingestion

### 15.1 Export options

**Option A — Bulk export (one-time):**
Strava account settings → "Get Started" under "Download or Delete Your Account" → "Download Request." Delivers a ZIP with:
- `activities.csv` (summary table — one row per activity)
- Individual files per activity (GPX, FIT, or TCX depending on source device)

Good for initial profile bootstrapping. Cumbersome for ongoing sync.

**Option B — Strava API (recommended for production):**
- OAuth flow to authorize the app
- `/athlete/activities` — list with summaries
- `/activities/{id}` — full detail
- `/activities/{id}/streams` — time-series data (distance, time, heartrate, watts, altitude, grade_smooth, cadence, temp)

Rate limits: 100 requests per 15 min, 1000 per day. Use streams endpoint sparingly (full streams are large); cache locally.

**Option C — FIT files directly** (if user uploads from device): Skip Strava entirely. FIT contains everything you need and is more accurate (no Strava-side smoothing).

### 15.2 Per-activity fields to extract

From summary:
- `distance_m`, `moving_time_s`, `elapsed_time_s`
- `total_elevation_gain_m` (Strava-smoothed; note caveat in §13.2)
- `average_heartrate`, `max_heartrate`
- `average_watts`, `max_watts`, `weighted_average_watts` (if power available)
- `type` (Run / TrailRun / Hike / Workout)
- `workout_type` (Race / Long Run / Workout / Default)
- `suffer_score` (Strava's effort proxy — useful for cross-activity comparison)
- `average_temp`
- `start_date_local`

From streams (full time-series):
- `time[]`, `distance[]`, `altitude[]`, `heartrate[]`, `watts[]`, `velocity_smooth[]`, `grade_smooth[]`, `cadence[]`, `temp[]`

### 15.3 Strava splits analysis

Strava computes auto-splits (1 km or 1 mile). For each split, it exposes:
- `distance`, `elapsed_time`, `moving_time`
- `average_speed`, `average_heartrate`
- `elevation_difference`
- `pace_zone`

**Computing GAP (Grade-Adjusted Pace) per split:**
Strava doesn't always expose GAP directly via API, but you can compute it:

```python
def gap_pace(actual_pace_min_km, grade_pct):
    # Minetti et al. (2002) energy cost of running on incline
    # Simplified polynomial approximation
    cost_factor = (0.0285 * grade_pct**2 +
                   0.0907 * grade_pct +
                   1.0)  # 1.0 at 0% grade
    return actual_pace_min_km / cost_factor
```

**Per-split decoupling check:**
For each split, compute `pace / hr` (or `power / hr`). If this ratio degrades across the activity, the runner is in *aerobic decoupling* — paying physiological debt faster than aerobic input. A decoupling rate >5% across a long run is a red flag for race day. <5% is sustainable.

### 15.4 Activity classification

Automatically classify imported activities:

| Class | Heuristic |
|---|---|
| Race | `workout_type == 1` OR title contains race keywords OR distance matches known race distance + max HR is sustained |
| Long run | `distance > 25 km` AND average HR in Z2 |
| Workout | `workout_type == 3` OR intervals detected (HR/pace oscillation) |
| Easy run | `distance < 15 km` AND average HR in Z1-low Z2 |
| Recovery | `distance < 10 km` AND average HR in Z1 |

Different classes feed different parts of the athlete profile (§16).

---

## 16. Athlete Profile Fitting from Past Activities

The profile is no longer a static set of self-reported values — it's a continuously updated model fit from imported activities.

### 16.1 Profile parameters to fit

| Parameter | Source | Update method |
|---|---|---|
| `lthr` | Best 30-min HR effort from race or workout | Take max across last 12 months |
| `max_hr` | Max instantaneous HR across recent activities | Decaying max over 12 months |
| `cp_running` (if power) | 20-min FTP test or modeled from race data | Refit per quarter |
| `flat_road_pace_threshold` | Recent road race / threshold workout | Take best recent |
| `flat_trail_pace_easy` | Easy-run pace on trail at Z2 HR | Median across last 30 days |
| `vertical_rate_by_duration` | Climb segments from past activities | Fit curve (see §16.2) |
| `descent_pace_by_grade_and_technicality` | Descent segments from past activities | Fit curves |
| `fatigue_coefficient` | Pace degradation over long activities | Fit slope (see §16.3) |
| `hr_drift_coefficient` | HR rise at constant pace in long runs | Fit slope |
| `decoupling_threshold` | Point where pace:HR breaks down | Identify from longest runs |
| `sustainable_hr_by_duration` | Race HR by race duration | Empirical points + curve fit |
| `heat_response` | Pace/HR delta on hot days | Fit interaction term |

### 16.2 Fitting vertical rate by duration

For each activity, extract sustained climb segments. For each:
```
vmh = segment_ascent_m / segment_duration_h
duration_at_climb_start = cumulative_race_time_at_segment_start
```

Plot `vmh` vs `duration_at_climb_start` for the athlete. Fit a decay curve:
```
vmh(t) = vmh_max * exp(-k * t)
```
Where `k` is the athlete's specific fatigue rate for climbing. A young aerobic athlete might have `k = 0.02` (slow decay); a less-trained one `k = 0.05`.

Use this curve in Layer B predictions instead of the static §4.1 tier value.

### 16.3 Fitting the fatigue coefficient

For each long activity, compute pace per km adjusted for grade (GAP, §15.3). Fit:
```
gap_pace(t) = base_pace * (1 + fatigue_slope * max(0, t - threshold))
```
Where:
- `base_pace` is fitted from the first hour
- `threshold` is when degradation starts (typically 1.5–3 h)
- `fatigue_slope` is per-hour pace inflation

A well-trained ultra runner: `fatigue_slope ≈ 0.5–1.5%/h` after a 2h threshold.
A less-trained runner: `fatigue_slope ≈ 2–4%/h` after 1h.

### 16.4 Fitting sustainable HR by duration

This is the empirical version of §14.3. For each *race* activity (filtered class), record:
```
(race_duration_h, average_hr_during_race / lthr)
```

Plot and fit. The shape is typically: flat near 100% LTHR up to ~1h, then exponential decay. Use the athlete's own curve in predictions rather than the population averages.

**Minimum data points to start trusting the fitted curve: 3 races across at least a 3× duration range** (e.g., 1h, 4h, 12h).

### 16.5 Confidence intervals

The profile should expose uncertainty per parameter:
- `vertical_rate_vmh = 850 ± 50` (after 5 activities) vs `±150` (after 1 activity)
- Predictions should propagate uncertainty: "expected finish 14h30 ± 45 min"

After ~10–15 quality activities including 2+ races, predictions should reach ±5–10% accuracy on similar courses. Cross-domain predictions (e.g., predicting a high-altitude race from sea-level data) keep wider intervals.

---

## 17. Non-Linear Scaling — Short Race to Ultra Projection

### 17.1 The problem

You have 20k and 42k race data. You want to predict a 108k race. **Linear extrapolation of pace catastrophically fails** because:
- HR sustainable at 42k effort is unsustainable for 108k
- Glycogen depletion changes the metabolic substrate mix
- Muscular damage accumulates non-linearly with distance
- Mental and decision-making fatigue compound

### 17.2 Riegel's formula (the classical answer)

```
T2 = T1 * (D2 / D1)^k
```

Default `k = 1.06` works for flat distances up to marathon. For ultras, `k` is higher and grows with the distance ratio.

Adjusted exponents for ultra projections:

| Projection range | Recommended `k` |
|---|---|
| 10k → marathon | 1.06 |
| Marathon → 50k | 1.07–1.08 |
| Marathon → 50 mi | 1.08–1.10 |
| Marathon → 100k | 1.10–1.13 |
| Marathon → 100 mi (flat) | 1.13–1.17 |
| Add for mountain race | +0.02 to +0.05 |

**Example with user's data:**
```
T_42k = 4h00 (example)
T_108k_predicted = 4.0 * (108 / 42)^1.10 = 4.0 * 2.81 = 11.25h flat equivalent
```

Then apply Layer A or B vert adjustment on top.

### 17.3 Multi-point power-law fit (preferred)

If the athlete has multiple race distances logged, fit `k` directly:
```
log(T) = log(C) + k * log(D)
```
Linear regression on `(log D, log T)` pairs. `k` is the slope.

Athletes with `k < 1.06` are well-conditioned for distance (good fade resistance). Athletes with `k > 1.12` lose disproportionately at longer distances and should target conservative paces.

### 17.4 HR-based projection (more robust)

Rather than projecting pace forward, project sustainable HR for the target duration (using the fitted curve from §16.4), then translate HR back to pace via the athlete's pace-at-HR profile:

```python
# Step 1: predict target duration via Riegel (rough)
rough_duration = riegel_project(known_races, target_distance)
# Step 2: get sustainable HR for that duration
target_hr = athlete.sustainable_hr_for_duration(rough_duration)
# Step 3: get pace at that HR on flat
target_flat_pace = athlete.pace_at_hr(target_hr, terrain='moderate')
# Step 4: apply Layer B with this pace as input
refined_prediction = layer_b_predict(course, athlete, target_flat_pace, target_hr)
# Step 5: iterate (Step 1 used rough duration; now refine)
```

After 2–3 iterations the prediction converges.

### 17.5 The decoupling-based reality check

For the user's longest available activity (e.g., a 42k race or a 4-5h long run), compute the aerobic decoupling rate (pace:HR drift, §15.3). Project forward:
- If decoupling at hour 4 of a 4h race was 5%, expect that to extend further over 10+ hours
- A 108k effort at ~6h ratio degradation would be unsustainable; HR ceiling must be lowered

This grounds the projection in the athlete's actual physiology rather than population curves.

---

## 18. Race Intensity Profile — "Push vs Conservative" Slider

### 18.1 The control

User-exposed slider or preset selector:

| Preset | HR target | Risk |
|---|---|---|
| Conservative finish | 80th percentile of sustainable HR for duration | Low DNF, ~10% slower than potential |
| Goal race | Median sustainable HR for duration | Standard race effort |
| Push (PR attempt) | 95th percentile sustainable HR | Higher DNF risk, optimal performance ceiling |
| All-in (gamble) | 100% of sustainable HR ceiling | DNF risk significant if anything goes wrong |

Each preset translates to a multiplier on the target intensity:

```python
intensity_multiplier = {
    'conservative': 0.95,
    'goal': 1.00,
    'push': 1.04,
    'all_in': 1.08,
}
```

Applied to: `target_hr`, `target_power`, `vertical_rate_target`, and the inverse on `target_pace`.

### 18.2 What changes per preset

| Component | Conservative | Goal | Push |
|---|---|---|---|
| HR target | -5 bpm | Baseline | +3 bpm |
| Climbing rate | -10% | Baseline | +5% |
| Flat pace | +5% (slower) | Baseline | -3% (faster) |
| Aid station time budget | Generous | Lean | Minimal |
| Hydration/fuel cadence | Conservative | Standard | Aggressive |

### 18.3 Risk model output

Each preset should be shown with predicted finish AND risk markers:
- DNF probability (rough, fitted from athlete's race history if available)
- Bonk-zone identification (where in the race the chosen effort is most likely to crack)
- Recovery cost (days of recovery expected post-race)

---

## 19. Distance-Specific Heuristics from Past Data

This formalizes the user's insight: "I can sustain ~163 HR for 20k but not for 50k."

### 19.1 Build a personal duration-effort table

For each race or hard effort in the athlete's history, extract:
```
(duration_h, distance_km, avg_hr, avg_power, avg_pace, avg_gap_pace, course_type)
```

Bin by duration and compute the athlete's typical maxes:

| Duration bin | Personal max avg HR | Personal max avg power | Personal best avg GAP |
|---|---|---|---|
| <0.5 h | 175 | 320 W | 4:05/km |
| 0.5–1 h | 168 | 295 W | 4:20/km |
| 1–2 h | 160 | 270 W | 4:40/km |
| 2–4 h | 152 | 245 W | 5:00/km |
| 4–8 h | 142 | 220 W | 5:30/km |
| 8–16 h | 132 | 200 W | 6:15/km |
| 16–32 h | 122 | 180 W | 7:00/km |

For target races, look up the duration bin and apply the athlete's personal ceiling.

### 19.2 Extrapolating into untested duration ranges

If the athlete has data up to 4h but is racing 14h, extrapolate using:
- Riegel-style power law on the duration:HR ratio
- Damped: don't allow predictions to drop below ~65% LTHR (physiological floor for trained athletes)
- Cross-reference with §16.4 fitted curve

Mark extrapolated bins as **low-confidence** and widen the prediction interval accordingly.

### 19.3 The "stretch target" guardrail

If the user requests a target time that requires an HR (or power) higher than their personal data shows sustainable for that duration, flag it:

> "This target requires 152 avg HR for 14h. Your highest sustained HR for >8h is 135. Target is aggressive — consider goal or conservative preset."

This is the most useful single safety feature: preventing overconfident extrapolation from short-race data.

---

## 20. System Architecture — Continuous Learning Loop

### 20.1 Components

```
┌─────────────────────────────────────────────────────────────┐
│                   Activity Ingestion                        │
│   Strava API / FIT upload / GPX import                     │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Activity Classification                        │
│   race / long run / workout / easy / recovery              │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│              Feature Extraction                             │
│   GAP curves, climb segments, descent segments,            │
│   HR drift, decoupling, splits, conditions                 │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│          Athlete Profile Update                             │
│   Refit vertical rate curve, sustainable HR curve,         │
│   fatigue coefficient, descent coefficients, technique     │
│   levels — with confidence intervals                       │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│        Race Predictor (called per race)                     │
│   Inputs: GPX, athlete profile, target/preset, conditions  │
│   Outputs: predicted finish, per-segment pace plan,        │
│   per-aid splits, risk flags, decoupling forecast          │
└────────────────────┬────────────────────────────────────────┘
                     ▼
┌─────────────────────────────────────────────────────────────┐
│        Post-Race Analysis (closes the loop)                 │
│   Compare predicted vs actual, identify which              │
│   coefficients were off, feed back to profile fitter       │
└─────────────────────────────────────────────────────────────┘
```

### 20.2 Data model sketch

```python
class Athlete:
    profile: AthleteProfile           # All fitted parameters with CIs
    activities: List[Activity]
    races: List[Race]                 # Subset of activities, with results

class Activity:
    id: str
    type: ActivityType
    classification: ActivityClass
    summary: ActivitySummary          # Distance, time, gain, avg HR, etc.
    streams: ActivityStreams          # Time-series data
    derived: DerivedMetrics           # GAP curve, decoupling, climb/descent segments
    conditions: ActivityConditions    # Temp, time of day, altitude exposure

class Race(Activity):
    course: Course                    # Parsed GPX of the race
    target: RaceTarget                # What was planned
    result: RaceResult                # What happened
    plan_vs_actual: PlanComparison    # Where prediction was off

class Course:
    segments: List[Segment]
    aid_stations: List[AidStation]
    technicality: Technicality
    altitude_profile: AltitudeProfile

class Prediction:
    finish_time: TimeWithCI           # e.g., 14h30 ± 45min
    per_segment_plan: List[SegmentPlan]
    per_aid_splits: List[AidSplit]
    risk_flags: List[RiskFlag]
    decoupling_forecast: float        # Predicted aerobic decoupling at finish
    confidence: float                 # 0-1, based on data sufficiency
```

### 20.3 The feedback loop

After each completed race or major training run:

1. Compare predicted vs actual finish time and per-segment splits
2. Identify which coefficients drove the largest residuals
3. Apply Bayesian-style updates: high-confidence priors move slowly, low-confidence parameters update faster
4. Surface to user: "Your climbing rate held up better than predicted (+8%). Vertical rate fit updated."

This makes the system **better with each race** rather than static.

### 20.4 Minimum data for usable predictions

| Data state | Prediction quality |
|---|---|
| Cold start (no data) | Population defaults; ±20% on Layer B |
| 5+ varied activities, 0 races | ±15%; flat-pace and easy-effort grounded |
| 1 race + 10 activities | ±10–12%; key calibration point |
| 2+ races across distance range | ±6–10%; Riegel fit established |
| 5+ races including target-similar profile | ±3–5%; high confidence |

Surface this to the user: don't pretend confidence the data doesn't support.

---

## 21. Worked Example — Predicting 108k from 20k + 42k Data

**Input:**
- Athlete data: 20k race in 1h35 (avg HR 168), 42k road marathon in 3h45 (avg HR 158)
- Target race: 108 km / 4300 m gain / moderate technicality
- LTHR estimated: 165 (from 20k race effort)

**Step 1 — Riegel projection to 108k flat equivalent:**
Fit `k` from two data points:
```
log(1.583) = log(C) + k * log(20)
log(3.75)  = log(C) + k * log(42)
→ k = (log 3.75 - log 1.583) / (log 42 - log 20) = 1.165
```
Project to 108k flat:
```
T_108k_flat = 3.75 * (108/42)^1.165 = 3.75 * 2.99 = 11.21 h
```

**Step 2 — Add elevation via Layer A (refined):**
```
equivalent_distance = 108 + 43 + 4.3 = 155.3 km
flat_pace_42k = 3.75 * 60 / 42 = 5:21/km
But the projected 108k pace > 42k pace (fade), so use derated pace.
Derated flat pace at 108k effort: 11.21 * 60 / 108 = 6:14/km
Predicted time = 155.3 km * 6:14/km / 60 = 16.1 h
```

**Step 3 — HR-based sanity check:**
- 42k avg HR was 158 = ~96% LTHR (Z3-Z4 boundary).
- For 14–16h race, athlete's curve suggests Z2 max = ~80% LTHR = 132.
- That's a 26-bpm drop in sustainable HR.
- The athlete has *no data* at this HR for long duration — flag as **low confidence**.

**Step 4 — Layer B with personalized coefficients (best estimate):**
- Vertical rate: no real climb data → use mid-pack default 750 vm/h, degrading.
- Climbing: 4300 / 750 = 5.7 h, fatigue-adjusted to ~6.5 h.
- Descent: 30 km at moderate pace ~6:30/km adjusted for damage = ~3.5 h.
- Runnable 48 km at sustainable HR pace ~6:30/km = ~5.2 h.
- Aid stations (lean): ~1 h.
- **Layer B total: ~16.2 h.**

**Step 5 — Output with appropriate humility:**
> Predicted finish: **16h ± 1h45min** (low confidence; widen to 14h–18h band).
> Critical assumptions: vertical rate (no climb data), HR sustainability at >8h (no long-duration data).
> **Recommendations to tighten prediction**: complete one 6+ hour training run with sustained climbing; log HR data through full duration; ideally complete one 50k+ race before relying on this projection for race-day pacing.

This honest output is more valuable than a confident "15h32" answer that's actually a guess.

---

## References

- Naismith, W.W. (1892). Original 1h/3mi + 1h/2000ft rule.
- Scarf, P. (1998). "An empirical basis for Naismith's rule." Fell running analysis.
- Langmuir, E. (1984). Descent corrections for Naismith.
- Riegel, P.S. (1981). "Athletic records and human endurance." Power-law endurance projection.
- Minetti, A.E. et al. (2002). "Energy cost of walking and running at extreme uphill and downhill slopes." Source for GAP polynomial.
- Monod, H. & Scherrer, J. (1965). Critical Power model — applied to running by Jones et al.
- Various ultrarunning practitioner sources for the 1:10 conservative variant and ultra-Riegel exponents.
- Strava API documentation: developers.strava.com/docs/reference/
