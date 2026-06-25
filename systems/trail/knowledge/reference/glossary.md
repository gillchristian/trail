# Glossary

Domain-specific terms used in this project. Add entries the moment a term first appears with a specific meaning.

## Format

**Term** — definition. (origin or context if useful.)

## Entries

Terms whose meaning differs from what you'd guess first:

- **Target (time, per km)** — *clock* time for the km: moving time **plus** aid-station rest falling inside that km. Displayed in the km card, km table, and CSV. (TASK-025; manual-typed targets subtract in-km rest before storing.)
- **Pace** — *moving-only* min/km; never includes aid rest. Target and Pace deliberately disagree on kms containing an aid station.
- **cutoff** — on an `AidStation`, elapsed **seconds from race start** (not clock-of-day). Optional; settable via CSV and the manual form. (TASK-031.)
- **section** — the stretch of kms between two consecutive aid-station distances (start/finish count as boundaries). The planning table toggles km-mode / section-mode.
- **Plans / Executions** — the home-page split: races without `actualSplits` ("Plans") vs. races with a linked actual run ("Executions"). The cut is linked-actual vs. not. (TASK-028.)
- **locked km** — a km whose time the user edited manually (`Manual`); it keeps its value while unlocked kms redistribute the remaining time budget.

Core vocabulary:

- **true-1:1 profile** — elevation rendering where vertical m/px = horizontal m/px; the project's founding feature (no vertical exaggeration).
- **GAP** — grade-adjusted pace; pace normalized for slope. Implemented Tobler-based (ADR-0003).
- **Tobler** — Tobler's hiking function, the speed-vs-slope curve used to distribute a target time across kms (normalized so flat = 1.0).
- **aid station** — a support point on the course at a distance-from-start; carries name, rest seconds, services, optional cutoff/notes. Stored on the `Race`, exported as GPX waypoints.
- **Service** — what an aid station offers: water, food, medical, wc, drop bag, warm food, crew (`Types.Service`, 7 variants).
- **Pace Strategy** — the Coros watch feature that consumes our exported GPX-with-waypoints (ADR-0002).
- **`.trail` file** — the project-file export: `{format, version, race}` envelope round-tripping GPX + plan + aid stations.
- **VMH** (`verticalRateVmh`) — vertical **climb** rate: metres of ascent per hour on moderate grades (`src/AthleteProfile.elm`). The predictor's climb base rate — `climb_time = gain / (VMH × intensity)` (`src/Predictor.elm`). Despite the "vitesse m/h" etymology it is **not** a flat-ground speed; the flat rate is a separate field (see **flat trail pace**). (TASK-017/018.)
- **flat trail pace** (`flatTrailPaceSecPerKm`) — seconds per km on moderate runnable trail at sustainable effort; the predictor's base for runnable and descent segments, distinct from VMH. (TASK-017/018.)
- **intensity** — the predictor's effort multiplier (0.80–1.25) driven by the aggressiveness slider; 1.0 = profile baseline (TASK-018/019).
- **distance category** — the S / M / L / XL bucket badge on each race card, by total course distance (`distanceCategory`, `src/Main.elm`). (TASK-011.)
- **elevation density** — gain per km (`gain / distance`, m/km), bucketed flat → extreme and shown as a colour-coded tag on the race card and detail header (`elevationDensity` / `densityLabel`). (TASK-014.)
- **flat-equivalent distance** — `distance + gain/100 + loss/1000` (refined Naismith-Scarf 1:10): the flat distance of comparable effort, shown on the race detail header (`equivalentFlatKm`). (TASK-014.)
- **actual splits** — per-km times from a linked real run (manual GPX upload or Strava streams), diffed against the plan.
- **crest** — sibling repo this project lifted `Gpx.elm` and the 1:1 profile rendering from.
- **cadence** — sibling repo whose backend handles Strava OAuth + API proxying for trail (spec in `reference/cadence-backend-spec.md`).
