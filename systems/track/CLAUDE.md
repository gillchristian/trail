# CLAUDE.md — track (system entry · in build)

**track** is the **Execute** system in the product arc Plan (**trail**) → Execute (**track**) →
Reflect (**reflect**): a race-day execution/tracking companion. **Code has started** — the
Swift/SwiftUI app builds + runs in the iOS Simulator. **TRACK-000** (toolchain bootstrap) and
**TRACK-001** (WI-1 skeleton) are done; **TRACK-002** (WI-2 durable domain spine) is next. Build from
`systems/track/Track/` (commands in `knowledge/reference/local-ci.md`).

**Read these, in order, before doing anything else:**
1. the repo-root manifest `/knowledge/README.md` (repo-wide rules track inherits),
2. this system's manifest `systems/track/knowledge/README.md` (track-local rules + **Locations** + the planned MVP sequence),
3. `knowledge/framework/README.md` at the repo root (the shared working system),
4. the `pr` profile in `knowledge/framework/delivery.md`.

## Non-negotiables (track)

1. **One task at a time.** Pull from `systems/track/knowledge/planning/CURRENT.md`; if empty, promote the top of `BACKLOG.md`. Acceptance criteria first.
2. **Delivery: pr** (inherited ceiling). Branches → PRs you merge yourself, squash-only; `master` sacred. Branch prefix `track/`; ids `TRACK-NNN`.
3. **User-only attribution.** No `Co-Authored-By: Claude …` trailer, no "🤖 Generated with Claude Code" footer.
4. **Verify before declaring done** — once code exists, from `systems/track/`; record the gates in `reference/local-ci.md` as they appear.
5. **Journal everything** in `systems/track/knowledge/progress/journal.md`.
6. **When stuck, follow `knowledge/framework/when-stuck.md`.** Log blockers to `systems/track/knowledge/progress/blockers.md`, then pivot.

## Status: in build — WI-1 done (TRACK-000/001)

The Swift/SwiftUI app lives at `Track/` and builds + runs in the iOS Simulator (see
`knowledge/reference/local-ci.md`). **Done:** TRACK-000 (toolchain bootstrap, PR #161), TRACK-001 (WI-1
project skeleton — a Races list over a `Documents/Races/<id>/race.json` bundle, PR #162). The canonical
specs are `knowledge/reference/mvp-plan.md` + `knowledge/reference/tracking-view-spec.md` (wireframes in
`knowledge/reference/design/`), with `knowledge/reference/project-brief.md` as orientation. **Next:
TRACK-002** — WI-2 domain model + durable persistence (the append-only `events.log` / fsync spine;
`mvp-plan.md` §4 + §7). Start from `CURRENT.md`.

## Quick map (track)

- `systems/track/knowledge/README.md` — system manifest (Locations, `track/`, `TRACK-`).
- `systems/track/knowledge/planning/BACKLOG.md` — the seeded work items (`TRACK-000…010`); what's next.
- `systems/track/knowledge/reference/project-brief.md` — what track is + the MVP sequence (orientation).
- `systems/track/knowledge/reference/mvp-plan.md` + `tracking-view-spec.md` (+ `design/`) — canonical MVP specs.
- `knowledge/framework/` (repo root) — shared working system (changes = `MONO-` tasks).
- Repo-wide rules + system index: the root manifest (`/knowledge/README.md`).
