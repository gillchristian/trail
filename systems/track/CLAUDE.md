# CLAUDE.md — track (system entry · STUB)

**track** is the **Execute** system in the product arc Plan (**trail**) → Execute (**track**) →
Reflect (**reflect**): a race-day execution/tracking companion. **This is a knowledge-only stub** —
no code yet. When code arrives, build from this directory (`systems/track/`).

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

## Status: STUB

Knowledge only — no code/build target yet. The MVP work-item sequence + the `.trace`/`.trail`
integration contracts are in `systems/track/knowledge/reference/project-brief.md`. Start there.

## Quick map (track)

- `systems/track/knowledge/README.md` — system manifest (Locations, `track/`, `TRACK-`).
- `systems/track/knowledge/reference/project-brief.md` — what track is + the MVP sequence.
- `knowledge/framework/` (repo root) — shared working system (changes = `MONO-` tasks).
- Repo-wide rules + system index: the root manifest (`/knowledge/README.md`).
