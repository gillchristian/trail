# Project brief — Track (Execute)

## What it is

**Track** is the **Execute** leg of the product arc: **Plan (trail) → Execute (track) → Reflect
(reflect)**. Where trail *plans* a race (course, aid stations, per-km pacing), track is the race-day
companion that *executes* it — a lean, **native iOS** app to capture food intake, aid-station
arrivals, and voice notes *during* a trail/ultra race, plus a minimal post-race review.

It is a **passive recorder**, not an assistant: no nudges, no alerts (the watch already owns
signals — GPS, HR, pace, splits). Track owns **events and experience** — the discrete, subjective
things that are cumbersome on a watch: nutrition timing, "reached aid 2," a breathless voice note at
hour 6. **Plan-less by default**; a Trail plan only *enriches* it (pre-populates palette / aid
stations). It closes its own loop (dogfoodable standalone) and emits an append-only log that the
eventual Reflect app folds into a projection.

## Status: speced + backlogged — no code yet

The MVP is **fully designed and ingested into `planning/BACKLOG.md`** (epic "Tracker MVP",
2026-06-25). The canonical specs live in this `reference/` area — read them before building:

- **`reference/mvp-plan.md`** — the MVP plan: product framing, architecture invariants, domain
  model (Swift), persistence, screens, and the WI-1…WI-10 work-item sequence with acceptance
  criteria. **Authoritative for scope.**
- **`reference/tracking-view-spec.md`** — the in-race tracking view (drives WI-6 / TRACK-006): four
  cyclic tabs (Nutrition · AID · Others · Feed), the aid-station interval model, the record-voice
  button, the Undo toast.
- **`reference/design/`** — hand wireframes of the four tabs (`track-*.webp`) + the Excalidraw
  source (`tracker.excalidraw`). Layout reference only; styling follows Trail (below).

The one **prerequisite before any code is TRACK-000** — set up the Swift/iOS toolchain (the build
owner has not used Swift or built for iOS before). See BACKLOG.

## Architecture invariants (load-bearing — must not be violated)

Lifted from `mvp-plan.md` §2; the brief restates them because they win conflicts:

- **No background execution (v1).** Each interaction is *open → append a `Date()`-stamped event →
  fsync → done*. iOS may background/kill the app between interactions. Elapsed time is derived from a
  stored start timestamp, not a running process. (No background-location, no keep-alive.)
- **Append-only event log, resilient to shutdown.** `events.log` is never rewritten. All edits —
  the editable finish time *and* Undo — are **new events** (corrections / retractions), resolved by
  projections. Force-quit loses at most the single in-flight write.
- **Durability is a primary constraint.** Race data is unrepeatable — fsync on every append, atomic
  writes for config, crash recovery on launch.
- **Offline / local-first.** No cloud, no server, ever in v1. Mountain races have no signal.
- **Capture now, process later.** The in-race app is a dumb, crash-proof recorder — no live
  transcription / pairing / inference. Intelligence lives post-race or in Reflect.
- **Plan-less first.** Every feature works without a `.trail`. Plan ingestion only enriches.
- **Status / effective end / visit state are projections**, folded from events — never stored flags.

## Tech stack

- **Swift + SwiftUI, native iOS** (iOS first; Android deferred; cross-platform UI rejected on
  idiomatic grounds — see `mvp-plan.md` §3). No Apple Watch (ever).
- **Persistence = a directory bundle per race** (`race.json` rewritten atomically pre-race;
  append-only `events.log`, one JSON object per line, fsync per append; `audio/<eventID>.m4a`).
  SQLite/GRDB and SwiftData rejected for the MVP (`mvp-plan.md` §3). Build/run/test commands get
  recorded in `reference/local-ci.md` as the toolchain lands (TRACK-000/001).

## Visual design — follows Trail

**Match Trail's design language; do not invent a new one** (user directive, 2026-06-25). Trail is
dark-first and race-card flavored. Concrete tokens (from `systems/trail/index.html` + `src/`):

- **Dark-first.** Ground `#020617` (slate-950), text slate-100, `color-scheme: dark`; respects the
  system light/dark setting per the tracking-view spec.
- **Accents.** Amber/gold `#fbbf24` (primary glow), race-red `#E52E3A` / `#ff5f6a`, green `#22c55e`
  (go / finish / success), with a deep-navy second surface `#0b0b21`.
- **Feel.** "Race-card" aesthetic, glow accents, high-contrast, large tap targets.

Trail is Elm + Tailwind; track is SwiftUI — **port the *mood*, not the markup**. Translate these into
a small SwiftUI design-token layer (Color assets / a theme struct). The wireframes' rough strokes and
ad-hoc tile colors are sketch chrome, not the target style.

## MVP work-item sequence (→ TRACK-NNN, seeded in BACKLOG)

Critical path: **TRACK-000 → 001 → 002 → 003/004 → 005 → 006 → 007.** First real test: run an actual
race on the TRACK-006/007 build.

| Task      | Work item (mvp-plan §7)                  | Notes                                   |
|-----------|------------------------------------------|-----------------------------------------|
| TRACK-000 | **Swift/iOS toolchain bootstrap**        | Prerequisite — not in mvp-plan; net-new |
| TRACK-001 | WI-1 Project skeleton                    | Pin iOS deployment target               |
| TRACK-002 | WI-2 Domain model + durable persistence  | The spine — append-only log + fsync     |
| TRACK-003 | WI-3 Trackable library (CRUD)            |                                         |
| TRACK-004 | WI-4 Create / configure race             |                                         |
| TRACK-005 | WI-5 Aid-station CSV import (Trail's)     | Lift Trail's CSV cell encoding          |
| TRACK-006 | WI-6 Race tracking view                  | `tracking-view-spec.md`; race-end ✓     |
| TRACK-007 | WI-7 Race view (post-race)               |                                         |
| TRACK-008 | WI-8 `.trace` export — **deferred**      | Parking lot; freeze after ≥2–3 races    |
| TRACK-009 | WI-9 `.trail` ingestion — **deferred**   | Parking lot                             |
| TRACK-010 | WI-10 Live Activity — **deferred**       | Parking lot                             |

## Integration contracts (`.trace` / `.trail`)

Track sits between trail and reflect via two file contracts. The **canonical specs live in the shared
`knowledge/reference/specs/`** (the cross-system tier) — record/extend them there, not here:

- **`.trail`** — trail's plan/project file. Track *ingests* a `.trail` to know the plan it's
  executing. Trail's existing format (`systems/trail/`); full ingestion is **deferred to TRACK-009**
  (MVP supports the aid-station CSV path only). Add a shared contract pointer in
  `knowledge/reference/specs/` when track wires the ingestion.
- **`.trace`** — track's **execution-record** export, consumed downstream by reflect. **Deferred to
  TRACK-008** until the event vocabulary settles (≥2–3 real races) — a self-contained zip
  (resolved metadata + events + audio). Define the contract in `knowledge/reference/specs/` then.

## Out of scope (MVP)

Background execution · GPS / location (never in track — that's Reflect's join key) · Strava ·
deviation classification (needs a plan) · RPE/feeling · nudges/alerts · Apple Watch (ever) ·
Android (later) · `.trace` freeze · full `.trail` parse · Live Activity · in-race audio playback
(post-race only).

## Open questions

- **TRACK-000 is the gating unknown** — the build owner is new to Swift/iOS; that spike de-risks
  everything after it.
- Tracking-view residuals (small, time-of-implementation), tracked in `tracking-view-spec.md` §8:
  AID-notes source (OQ-2), category→tab mapping (OQ-3), feed ordering (OQ-4), grid overflow (OQ-5),
  undo breadth (OQ-6). **The race-end trigger (OQ-1) is resolved** — a distinct "Finish race"
  control in the AID tab (with confirm).
- `.trace` schema — defer until the execution model exists (TRACK-008).
