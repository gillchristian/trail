# 0011 — Three-way merge engine for coach collaboration (WI-3)

**Date:** 2026-06-15
**Status:** accepted

## Context

WI-3 (the coach-collaboration arc, ADR-0009) folds a coach's returned `.trail`
into the local plan: disjoint edits from both sides should both land, and only
genuine same-field collisions should reach a human. WI-1 gave us the identity
guard + course hash; WI-2 gave us the frozen-course / mergeable-planning-layer
boundary. This ADR records the merge engine and the four design choices the user
made (spec Q2–Q5, 2026-06-15). The engine ships pure + smoke-tested as TASK-050;
the integration + review UI is TASK-052.

## Decision

**Three-way merge over the `PlanningLayer`** (WI-2's mergeable subset), written
concretely per type — no generic merge framework (three reuses before
extraction):

- **Conflict model as types, not runtime failure.** `field3 base mine theirs`
  resolves to the changed side when only one changed, else reports a typed
  conflict. `mergePlanningLayer base mine theirs : MergeResult` returns
  `{ merged, conflicts }` where `merged` is a fully-built layer with every
  conflict **defaulted to mine** (so it always applies cleanly) and `conflicts`
  lists each genuine collision with a `ConflictKey`, a label, and the mine/theirs
  display values.
- **Resolution by folding.** `resolve key theirs acc` applies one "take theirs"
  choice onto the merged layer. The review UI (TASK-052) starts from
  `merged` and folds `resolve` over the conflicts the user flips. Pure dispatch.
- **Scalars** (name/date/location/url/notes, target time) merge three-way.
  **Per-km plan** merges three-way per `{time, notes}`, keyed by km index.
  **Aid stations** merge as a keyed set by (fork-safe, TASK-049) id: union of
  adds, honoured removes, per-field three-way for aids present on both sides;
  an edit-vs-remove collision surfaces as a presence conflict (defaulting to
  keep-mine). `aidStationSeq` takes the max.
- **Version vector (Q4):** `Dict deviceId Int`. `classifyVersions mine theirs`
  → `Same | FastForward | Behind | Diverged`, so the importer can apply a clean
  fast-forward (coach strictly ahead of the owner's exact version) with no
  conflict review, and only run the merge on true divergence. Reuses the
  per-device id from TASK-049.
- **Ancestor delivery (Q2):** the `.trail` embeds `{ base, current }` planning
  snapshots; the importer uses the embedded base as the common ancestor.
  Self-contained, no local-history dependency; trivial size since the course is
  excluded.
- **Owner authority (Q3):** actual splits and the cover image are owner-only —
  they're not in `PlanningLayer`, so a coach's file can't overwrite them.
- **Conflict UX (Q5):** a dedicated merge-review screen (TASK-052); for the
  per-km note string, pick-one (mine/theirs) for v1, free-text hand-merge left
  as a later enhancement.

## Alternatives considered

- **Per-field vs. whole-aid conflicts.** Chose per-field (an owner renaming an
  aid while a coach retimes the *same* aid auto-merges) — matches the spec; the
  cost is more `ConflictKey` cases, which are mechanical.
- **Every field wrapped as `MergeField` vs. mine-default `merged` + `resolve`.**
  Chose the latter: `merged` is always a valid layer, the UI reconstructs the
  final layer by folding `resolve` over only the flipped conflicts (no need to
  rebuild the whole layer from per-field choices), and both halves are trivially
  smoke-testable.
- **Version vector vs. plain counter / content hash (Q4).** Vector — only it
  distinguishes fast-forward from divergence, which is what avoids a needless
  merge screen.
- **Embed base vs. local-history lookup (Q2).** Embed — robust regardless of
  what history either side pruned; trail keeps no plan history today anyway.
- **CRDT.** Rejected at the arc level (ADR-0009): two-party, turn-based, ancestor
  always available.

## Consequences

**Easy:** disjoint edits auto-merge; conflicts are a typed list the UI renders
directly; the merge is deterministic with no `merge failed` path; the course is
untouchable (WI-2). The engine is fully verified headlessly (`smoke:merge`):
disjoint coach-note + owner-aid → 0 conflicts both landing, same-note → 1 typed
conflict that `resolve` flips, honoured removes, disjoint adds, scalar merges,
and all four version-vector relations.

**Hard / to revisit:** services lists compare by structural equality, so a pure
reorder reads as a conflict (acceptable — order is stable in practice).
Edit-vs-remove on an aid is surfaced at presence granularity, not per field. The
embedded-base model assumes the turn-based two-party flow where both sides share
an ancestor; genuine multi-party history would need more than a single embedded
base. The base *provenance* (when it's set/advanced) and version *bumping* on
each edit are integration concerns owned by TASK-052, not this pure engine.
