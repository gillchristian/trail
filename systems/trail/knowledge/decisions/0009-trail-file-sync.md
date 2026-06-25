# 0009 — `.trail` file sync for coach collaboration: three-way merge, frozen course

**Date:** 2026-06-15
**Status:** accepted

## Context

The user wants to share a race plan with their coach, get notes/feedback, and
fold those notes back into the local plan — asynchronously, with no backend.
The two parties pass a `.trail` file back and forth (email, Dropbox, USB — the
transport is the user's problem). This is a two-party, turn-based,
file-passing workflow, so a common ancestor is always available. The whole arc
must stay **Layer 0**: offline-capable, accountless, no trail-owned backend.

Two architectural questions fall out of that: *how* do two diverged copies
reconcile, and *what* in a race is even allowed to diverge.

## Decision

**1. Sync model: three-way merge against a common ancestor (the git / MRDT
model), not a CRDT.** Disjoint edits on the two sides auto-merge; only true
same-field collisions surface to a human. It is pure Elm, needs no library, and
its outcomes are expressible as types (`Merged a | Conflict { base, mine, theirs }`)
rather than runtime failure paths. Framing per Kleppmann/DDIA: mergeable-persistent
structures use three-way merge; CRDTs use two-way merges and earn their
complexity only in real-time, many-replica, no-coordination settings — not ours.

**2. Design axiom: *freeze the course, merge the plan.*** Course geometry (track
points) is immutable for the lifetime of a shared planning session. Only the
*planning layer* — aid stations, the per-km plan, race metadata — participates
in the merge. Both copies are addressed to the same coordinate space, which is
what makes field-level merge safe and collapses the hardest conflict class
(geometry reconciliation) by fiat.

**Scope:** the entire arc (identity guard → course freeze → three-way merge →
change-history feed) is Layer 0. No backend, no accounts; collaboration rides
the existing `.trail` export/import channel. The brief's *Out of scope* lines
("No social / sharing features", "No multi-user") are nuanced — the same way the
"No backend, ever" line was softened for the Strava arc — to: **async,
file-based, single-document collaboration (export → annotate → merge) is in
scope as a Layer-0 feature; server-side multi-user, accounts, and hosted
documents remain out of scope.** (Brief edit tracked as its own task.)

## Alternatives considered

### How far trail data leaves the device (product direction)

- **Full multiplayer (accounts, hosted docs, real-time co-edit).** Rejected.
  Crosses the no-backend / no-multi-user lines and turns trail from a
  single-player instrument into a collaboration surface — heavy, and unnecessary
  for a two-person asynchronous loop.
- **Read-only share link + server-hosted snapshot + web comments.** Deferred,
  not chosen. It is the minimum that breaks the local-first invariant (trail
  data leaves the browser onto a server) and also breaks the `cadence` backend's
  charter (cadence holds *no* trail data; it is an OAuth + read-only Strava proxy
  only). Adopting it forces a new cadence responsibility, a new service, or
  trail's first backend. Revisit only if file-passing proves too clunky.
- **File-based async sharing via the `.trail` round-trip.** Chosen. Preserves
  Layer-0 local-first fully, needs zero backend, reuses an artifact that already
  round-trips, stays accountless.

### Authentication (only relevant had we gone server-side)

- **Reuse Strava OAuth as the auth layer.** Rejected for this use case. Strava
  OAuth authenticates *the athlete as a data source*; the coach is a
  *collaborator* who may not be on Strava and shouldn't OAuth a Strava account
  just to leave notes — wrong identity, and it would constrain collaborators to
  Strava users.
- **Roll our own login.** Not needed — only required at the full-multiplayer
  rung, which we are not taking.
- **Net:** file-passing needs no identity provider. "Who made a change" is a
  stamped name / device-UUID, not an account.

### Merge strategy (the core technical fork)

- **Naive last-write-wins whole-snapshot overwrite.** Rejected as the default.
  Silently clobbers disjoint concurrent edits (the coach's per-km notes erase the
  owner's aid-station changes, or vice versa). A guarded LWW with a human
  diff-preview was considered as a cheaper fallback but pushes merge work onto
  the human on every import.
- **Three-way merge against a common ancestor.** Chosen (see Decision 1).
- **Full CRDT / op-log (Automerge, Yjs, or hand-rolled).** Rejected. CRDTs earn
  their complexity in real-time, many-replica settings; ours is two-party,
  turn-based, with an ancestor. The JS/Wasm libraries mean threading an opaque
  document through Elm ports, surrendering "if it compiles it works"; a
  hand-rolled Elm CRDT is heavy. CRDTs also guarantee *state* convergence, not
  *semantic validity* — a converged plan could still be domain-invalid (e.g. an
  aid left at a distance the other side removed), so a validation pass would be
  needed anyway. ("You might not need a CRDT.")

### History representation

- **Unify history and merge into one operation log (event sourcing); the
  changelog *is* the merge substrate.** Rejected. Forces event-sourcing across
  the whole Elm update layer and inherits the semantic-validity problem above.
- **Keep them separate: three-way merge owns correctness; a derived,
  cosmetic changelog owns the human view.** Chosen. The changelog is never read
  back to reconstruct state — delete it and merge still works.

### Course mutability

- **Allow course edits / treat the course as mergeable.** Rejected. Aid
  distances and per-km plans are only meaningful against one track; making the
  course mergeable creates the hardest conflict class (geometry reconciliation)
  for no real benefit. *Freeze the course, merge the plan* removes the class
  entirely. (Trail already has no course-point editor — the course comes from
  GPX upload — so this is mostly an invariant to state and enforce.)

## Consequences

**Makes easy:** disjoint edits (coach annotates per-km notes while owner moves
aid stations) auto-merge with zero conflicts; conflicts are typed values, not
runtime surprises; the feature ships with no backend, offline, accountless; the
changelog is a pure cosmetic derivation that can be deleted without affecting
correctness.

**Makes hard / to revisit:** if trail ever becomes genuinely multi-party or
real-time, three-way merge against a single ancestor stops being enough and the
CRDT decision must be reopened. Same-field concurrent edits still need a human
resolution UI — automation can't remove that, only minimise it.

**Grounding in the current code (verified 2026-06-15 — the originating spec's
premises were partly stale; recorded here so the work items aren't built on
them):**

- **A stable share id is genuinely new.** `Race` already has a UUID `id`
  (minted JS-side via `crypto.randomUUID()`) and it *is* embedded in `.trail`
  exports — but the import path deliberately **discards and regenerates** it
  (`Main.elm:447`, `id = raceIdFromString ""`) so the same file can be imported
  twice as two races. So the existing `id` is the IDB primary key, not a stable
  cross-round-trip identity. The identity guard (WI-1) needs a *separate* id that
  survives the round-trip.
- **Aid stations already have stable ids** (`AidStation.id`, issued by the
  per-race `aidStationSeq` counter as `"a" ++ seq`, and they round-trip in the
  JSON). The spec's "aid stations are currently distance-keyed" premise is
  outdated. The real merge hazard is that the *shared* counter mints identical
  ids (`"a5"`, `"a6"`, …) on both forks, so two independently-added aids collide.
  The stable-aid-id sub-task is therefore reframed from "add ids" to "make ids
  fork-collision-safe."
- **The `.trail` `version` field is a strict-equality gate** (`ProjectFile.elm`
  `D.fail`s on any version ≠ `currentVersion`), *not* a `D.oneOf` default. So a
  v2 bump must explicitly widen the accepted set to {v1, v2}; back-compat is not
  automatic the way the per-field `decodeRace` defaults are.

**Open questions (resolved per work item, not here — see BACKLOG §Open
questions / the originating spec §7):** course-hash input + mismatch behavior
(Q1, gates WI-1); ancestor delivery, profile/splits authority, version scheme,
conflict UX (Q2–Q5, gate WI-3). Recommendations are recorded with each task;
final calls are the user's.
