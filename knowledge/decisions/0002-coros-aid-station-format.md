# 0002 — Aid-station GPX format for Coros Pace Strategy

**Date:** 2026-05-15
**Status:** accepted (assumption — requires field validation)

## Context

Coros's Pace Strategy feature (release notes: `samples/coros_pace_strategy.html`) consumes routes from the Coros app's route library. The article states that **a route must include waypoints with waypoint alerts enabled** for Pace Strategy to surface aid-station segmentation:

> "Set time at waypoints: If your route includes waypoints (with waypoint alerts enabled), you can enter the time you expect to take at each aid station."
>
> "If your route doesn't include waypoints with waypoint alerts, you will need to exit Pace Strategy and go back to your route library in the Explore page to edit your route there."

The article does **not** specify the GPX schema. It links to a separate "how to add waypoints" article (360055691511) that we could not retrieve. We have no Coros-shipped sample GPX with aid stations to copy from.

The watch-side "waypoint alert" toggle is a per-route setting applied **after** import in the Coros app — so the file just needs the waypoints to *exist* with sane names and positions; alerts get enabled on the device.

## Decision

Generate **standard GPX 1.1 waypoints** alongside the existing `<trk>`/`<trkseg>`. Each aid station emits:

```xml
<wpt lat="46.0072" lon="7.0123">
  <ele>1450.0</ele>
  <name>Las Truchas 1</name>
  <desc>Aid station — 22.6 km — water, food</desc>
  <sym>Restaurant</sym>
  <type>Aid Station</type>
</wpt>
```

- `lat` / `lon` — snapped to the nearest track point at the declared distance-from-start (Haversine). Never invented coordinates.
- `<ele>` — elevation from the snapped point.
- `<name>` — user-provided aid-station name (or `Aid 1`, `Aid 2`, … if unnamed).
- `<desc>` — optional, generated from the planning data (distance + comma-joined service tags).
- `<sym>` — Garmin-standard symbol hint (`Restaurant`, `Water Source`, `Drinking Water`, `Trail Head`, `Flag, Blue`). Defaults to `Restaurant` for aid stations because Garmin/Coros treat that as the most-aid-station-like icon. Selectable in the UI per aid station, but only from the standard set.
- `<type>` — free-text `Aid Station` for downstream tooling.

Waypoints are emitted **before** the `<trk>` element, per GPX 1.1 convention (waypoints, then routes, then tracks).

## Alternatives considered

- **Garmin `<extensions>` block** with `<gpxx:Waypoint>` etc. — overkill; standard `<wpt>` is universally accepted, including by every consumer we've seen. Skipped.
- **Inline `<rtept>` inside an `<rte>`** — would also reach the route library, but `<rtept>` is for *routes* (turn-by-turn) not POIs; not the right semantic fit. Skipped.
- **Custom Coros extension** — we have no evidence Coros defines one. Skipped.

## Consequences

**Easy now:** the emitted GPX is portable. Strava, Garmin Connect, Komoot, etc. will all show our aid stations as normal POIs. Re-export round-trip is trivial.

**Risk:** if Coros's parser is unusually strict and requires a specific `<sym>` value or extension we haven't guessed, the aid stations may import but not trigger Pace Strategy's aid-station segmentation. **Field test required**: user uploads `samples/20k_oh_meu_deus.gpx` with our exported aid stations to the Coros app before the 20k race next weekend. If Pace Strategy doesn't pick them up:
1. Confirm waypoint alerts were toggled on the device (UI-side, not file-side).
2. If still failing, this ADR is **superseded** by 0002b and we'll need a Coros-shipped reference file.

**Tracking:** result of the field test gets a journal entry. If it fails, a `BLOCKER-NNN` is opened in `progress/blockers.md` and the user is asked to share a Coros-exported reference GPX.
