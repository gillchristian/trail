# Backlog

Ordered. The top *unchecked* item is next. Promote into `CURRENT.md` when started.

Conventions:
- Completed tasks stay here, checked `[x]` with their PR number.
- `TRACK-` ids, monotonically increasing. **TRACK-000** is the user-requested Swift/iOS bootstrap
  prerequisite (an index-0 foundational task, mirroring the repo's `MONO-000` precedent); the
  designed MVP work items WI-1…WI-10 then map 1:1 to **TRACK-001…TRACK-010**.
- Full acceptance criteria for the spec-covered items (TRACK-001…010) live in `reference/mvp-plan.md`
  §7 (per-WI) and, for the tracking view, `reference/tracking-view-spec.md`. Write them into
  `CURRENT.md` when a task is promoted.

## Active

### Tracker MVP (epic, 2026-06-25)

The native-iOS race-day **Execute** app. Canonical specs in `reference/`: **`mvp-plan.md`** (scope,
architecture invariants, Swift domain model, persistence, the WI-1…WI-10 sequence + acceptance
criteria) and **`tracking-view-spec.md`** (the in-race four-tab surface, drives TRACK-006); hand
wireframes + Excalidraw source in **`reference/design/`**. **Styling follows Trail** (dark-first
`#020617`/slate, amber `#fbbf24` / race-red `#E52E3A` / green `#22c55e` accents, race-card feel —
see `project-brief.md` → *Visual design*); port the mood into a SwiftUI token layer, not the
wireframes' sketch chrome. **Load-bearing invariants** (do not violate — `mvp-plan.md` §2): no
background execution; append-only `events.log` with fsync per append (Undo + finish-edit are
*events*, not mutations); offline/local-first; capture-now-process-later; plan-less first; status /
effective-end / visit-state are projections. **Critical path:** TRACK-000 → 001 → 002 → 003/004 →
005 → 006 → 007; first real test is running an actual race on the 006/007 build. WI-8/9/10
(`.trace` export, `.trail` ingestion, Live Activity) are **deferred** → parking lot.

- [x] TRACK-000 — **Swift/iOS toolchain bootstrap + orientation (prerequisite — net-new, gates everything).** ✓ PR #161 The build owner has not used Swift or built for iOS; de-risk the toolchain *before* WI-1. Install Xcode + command-line tools (record the exact version in a new `reference/local-ci.md`); get a minimal "hello" **SwiftUI** app building and **running in the iOS Simulator from `systems/track/`** (self-contained, per the monorepo's build-from-own-dir rule; track has no CI/deploy yet). Decide + record (ADR) the project tooling — **Xcode project vs Swift Package Manager** — and how it sits in the monorepo, plus the **iOS deployment target** (can stay permissive — no ActivityKit/background to constrain it, `mvp-plan.md` §3). Write a short Swift/SwiftUI orientation note (language: optionals, value types, struct/enum/protocol, `Codable`; UI: `View`, `@State`/`@Binding`/`@Observable`, `NavigationStack`, `Grid`/`List`) — enough to read/write the WI-1 skeleton. **AC:** Xcode version recorded in `reference/local-ci.md`; a SwiftUI app builds + runs in the Simulator from `systems/track/` (capture the build command output / a screenshot); build·run·test commands documented in `reference/local-ci.md`; an ADR records the tooling + deployment-target decision; the orientation note exists. — (M, spike)
- [ ] TRACK-001 — **WI-1: project skeleton.** Xcode/SwiftUI app, `NavigationStack`, empty Races-list root, persistence root dir, pinned iOS deployment target. **AC** (`mvp-plan.md` §7 WI-1): launches; empty races list; a stub race persists to disk and survives relaunch. Deps: TRACK-000. — (S/M)
- [ ] TRACK-002 — **WI-2: domain model + durable persistence.** Types in `mvp-plan.md` §4; race-bundle read/write; append-only `events.log` with fsync; atomic `race.json`; write-audio-then-append ordering; `status` / `effectiveEnd` / `aidStationVisits` projections; retraction pre-filtering. The durability-critical spine. **AC** (§7 WI-2): create race, append events programmatically, force-quit/relaunch with zero loss; status/effective-end/visit-pairing correct; a retraction hides its target everywhere; orphan-audio (not dangling-ref) is the only crash artifact. Deps: TRACK-001. — (L)
- [ ] TRACK-003 — **WI-3: trackable library.** CRUD UI + storage for `TrackableElement` (label + category); source for race palettes. **AC** (§7 WI-3): create/edit/delete trackables; persist; reload. Deps: TRACK-002. — (S)
- [ ] TRACK-004 — **WI-4: create / configure race.** Name, optional date, manual aid stations, palette from library + ad-hoc, save → Configured. **AC** (§7 WI-4): configured race persisted; appears in list as Configured. Deps: TRACK-002 (TRACK-003 for palette). — (M)
- [ ] TRACK-005 — **WI-5: aid-station CSV import.** Parse Trail's CSV (columns **name, services, distance**) into `[PlannedAidStation]`; lift Trail's exact cell encoding/delimiter for `services` from its parser. **AC** (§7 WI-5): import a Trail CSV; name/services/distance populate; stations editable; views can derive distance-to-next. Deps: TRACK-004. — (S/M)
- [ ] TRACK-006 — **WI-6: race tracking view.** Per `tracking-view-spec.md`: four cyclic tabs (Nutrition/AID/Others/Feed); category grids → `intake`; AID tab → `aidStationEntered`/`aidStationExited` (+ plan-less ad-hoc stations) + the **Finish race** control → `raceEnded`; Feed projection; foreground tap-record-tap-stop voice → mono AAC/m4a in the bundle; Undo toast → `retraction`. Each action appends + fsync. **Race-end trigger is resolved** (spec OQ-1 — Finish-race control in the AID tab); resolve the small residual OQ-2…6 at build time. **AC** (§7 WI-6): run a race through all four tabs with every event durably logged, clips on disk, aid visits pairing by `visitID`, Undo producing a retraction the Feed honors. Deps: TRACK-002, TRACK-004, TRACK-005. — (L)
- [ ] TRACK-007 — **WI-7: race view (post-race).** Chronological event stream (resolved: effective end + retractions); inline clip playback; **edit finish time** → `endTimeCorrected`; summary (counts + per-visit time). **AC** (§7 WI-7): view a finished race; play a clip; correct the finish via a correction event; summary reflects effective end + visit durations. Deps: TRACK-002, TRACK-006. — (M)

## Parking lot

Deferred MVP tail (from `mvp-plan.md` §7 — promote with appetite / once the vocabulary settles):

- [ ] TRACK-008 — **WI-8: `.trace` export.** Self-contained **zip** (manifest = resolved metadata + events, + audio assets). **Deferred** until ≥2–3 real races settle the event vocabulary; finalize the manifest schema then, in shared `knowledge/reference/specs/`. — (M)
- [ ] TRACK-009 — **WI-9: `.trail` ingestion.** Palette + schedule + UI adaptation + `planRef`; unlocks deviation classification and a dedicated AID-notes field. **Deferred.** — (M/L)
- [ ] TRACK-010 — **WI-10: Live Activity.** Foreground-started, system-rendered timer; WidgetKit extension; gated by the active-time cap + a restart-on-foreground continuity hack. **Deferred.** — (M)
