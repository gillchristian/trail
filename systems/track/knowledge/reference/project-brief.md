# Project brief — Track (Execute) · STUB

## What it is

**Track** is the **Execute** leg of the product arc: **Plan (trail) → Execute (track) → Reflect
(reflect)**. Where trail *plans* a race (course, aid stations, per-km pacing), track is the race-day
companion that *executes* that plan — a live tracking/execution app (mobile-first; Live Activity a
deferred goal) that ingests a plan and records the actual run.

**Status: stub.** No code yet — this brief carries the already-designed MVP sequence so a future agent
can start without re-deriving it.

## MVP work-item sequence (designed; promote into BACKLOG when track is picked up)

1. **Skeleton** — app scaffold + navigation.
2. **Domain + persistence** — the core run/plan model + local storage.
3. **Library / race-config** — manage races and their config.
4. **CSV import** — bring in a race / aid-station table (reuse trail's CSV shape where it fits).
5. **⏸ PAUSE — tracking-view design.** The live tracking view needs a design pass before building
   (it's the load-bearing UX). Resolve the design with the user before step 6.
6. **Tracking view** — the live race-day execution screen.
7. **Post-race view** — review the completed run.

**Deferred (not in the MVP):** `.trace` export, `.trail` ingestion, Live Activity.

## Integration contracts (`.trace` / `.trail`)

Track sits between trail and reflect via two file contracts. The **canonical specs live in the shared
`knowledge/reference/specs/`** (the cross-system tier) — record/extend them there, not here:

- **`.trail`** — trail's plan/project file (course + plan + aid stations). Track *ingests* a `.trail`
  to know the plan it's executing. `.trail` is **trail's existing format** (defined in `systems/trail/`);
  add a shared contract pointer in `knowledge/reference/specs/` when track wires the ingestion.
- **`.trace`** — track's **execution-record** export (the actual run), consumed downstream by reflect.
  **Not yet specified** (track is a stub). Define the `.trace` contract in
  `knowledge/reference/specs/` when track's execution model lands. Forward pointer only for now.

## Out of scope (for the stub)

- Anything beyond knowledge: no code, no build target, no backend.
- Re-specifying `.trail` (trail owns it) or prematurely fixing the `.trace` schema.

## Open questions

- The **tracking-view design** (the step-5 pause) — the main unknown before building.
- The **`.trace` schema** — defer until the execution model exists.
