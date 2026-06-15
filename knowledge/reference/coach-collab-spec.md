# Coach collaboration via `.trail` merge — spec

**Status:** **adopted 2026-06-15.** Decisions promoted to
[`decisions/0009-trail-file-sync.md`](../decisions/0009-trail-file-sync.md);
work items ticketed as **TASK-046 … TASK-051** (see `planning/BACKLOG.md`).
**Driver:** the user wants to share a race plan with their coach, get
notes/feedback, and fold those notes back into the local plan — without a
backend.
**Self-contained by design:** §1 records the options considered and rejected and
why, so this file carries its own rationale.

> ## Reality corrections (2026-06-15, from reading the code)
>
> The spec below was written against a slightly stale mental model. Three
> premises were corrected while ticketing (full detail in ADR-0009's
> *Grounding* section). Read these before §2 and §4:
>
> 1. **A stable share id is new, but `Race` already has a UUID `id`.** That id
>    is the IDB primary key and is *deliberately regenerated on import*
>    (`Main.elm:447`) so a file can be imported twice. WI-1's identity needs a
>    *separate* id that survives the round-trip — not the existing one.
> 2. **Aid stations already have stable ids** (`AidStation.id = "a" ++ seq`, from
>    the per-race `aidStationSeq` counter; they round-trip). The "currently
>    distance-keyed" premise in §4 / §6 is wrong. The real hazard is that the
>    *shared* counter collides across forks — so the stable-aid-id sub-task
>    (TASK-049) is **reframed** from "add ids" to "make ids fork-collision-safe."
> 3. **The `.trail` `version` field is a strict-equality gate** (`ProjectFile.elm`
>    `D.fail`s on mismatch), *not* a `D.oneOf` default. WI-1 must explicitly
>    widen the accepted set to {v1, v2}; v1 back-compat is not automatic.

---

## 0. Decisions (now ADR-0009)

This arc makes two real architectural decisions, captured in
[`decisions/0009-trail-file-sync.md`](../decisions/0009-trail-file-sync.md)
(with §1 below as its "alternatives considered" body):

1. **Sync model: three-way merge (git / MRDT model), not a CRDT.** The workflow
   is two parties, asynchronous, file-passing, effectively turn-based — a common
   ancestor is always available. Three-way merge against that ancestor is
   simpler, pure-Elm, and modellable as types. Revisit only if trail ever
   becomes genuinely multi-party / real-time.
2. **Design axiom: *freeze the course, merge the plan.*** Course geometry (track
   points) is immutable for the lifetime of a shared planning session. Only the
   planning layer — aid stations, per-km plan, race metadata — participates in
   merge. This collapses the hardest merge cases by fiat and is what makes
   field-level merge *safe*: both copies are addressed to the same coordinate
   space.

**Whole arc is Layer 0.** No backend, works fully offline, no accounts. Coach
collaboration rides entirely on the existing `.trail` export/import channel
(email, Dropbox, USB stick — the transport is the user's problem, not ours).

**Brief impact (TASK-046).** `project-brief.md`'s *Out of scope* currently says
"No social / sharing features" and "No multi-user." Nuance it the same way the
Strava softening was recorded: **async, file-based, single-document
collaboration (export → annotate → merge) is now in scope as a Layer-0 feature;
server-side multi-user, accounts, and hosted documents remain out of scope.**

---

## 1. Alternatives considered and discarded

Recorded so the decisions above are legible and aren't relitigated. (Also folded
into ADR-0009.)

### 1.1 How far trail data leaves the device (product direction)

- **Full multiplayer (accounts, hosted documents, real-time co-edit).**
  *Discarded.* Crosses the brief's no-backend / no-multi-user lines and turns
  trail from a single-player instrument into a collaboration surface. Heavy, and
  unnecessary for a two-person asynchronous loop.
- **Read-only share link + server-hosted snapshot + web comments.** *Deferred,
  not chosen.* It's the minimum that breaks the local-first invariant — trail
  data would leave the browser onto a server — and it also breaks the `cadence`
  backend's charter (cadence holds *no* trail data; it's an OAuth + read-only
  Strava proxy only). Adopting it would force one of: a new cadence
  responsibility, a brand-new service, or trail's first backend. Revisit only if
  file-passing proves too clunky in practice.
- **File-based async sharing via the `.trail` round-trip.** *Chosen.* Preserves
  Layer-0 local-first fully, needs zero backend, reuses an artifact that already
  round-trips, and stays accountless.

### 1.2 Authentication (only relevant if we'd gone server-side)

- **Reuse Strava OAuth as the auth layer.** *Discarded for this use case.*
  Strava OAuth authenticates *the athlete as a data source* (to link
  activities). The coach is a *collaborator* who may not be on Strava and
  shouldn't have to OAuth a Strava account just to leave notes — wrong identity
  for the purpose, and it would constrain the collaborator set to Strava users.
- **Roll our own login.** *Discarded / not needed.* Only required at the
  full-multiplayer rung, which we're not taking.
- **Net:** the auth question dissolves — file-passing needs no identity provider
  at all. "Who made a change" is handled by a stamped name / device-UUID (see
  WI-4), not by accounts.

### 1.3 Merge strategy (the core technical fork)

- **Naive last-write-wins whole-snapshot overwrite.** *Discarded as the
  default.* Silently clobbers disjoint concurrent edits — e.g. the coach's
  per-km notes would erase the owner's aid-station changes, or vice versa. (A
  guarded LWW with a human diff-preview was considered as a cheaper fallback, but
  it pushes merge work onto the human on every import; rejected in favor of
  automation.)
- **Three-way merge against a common ancestor (git / MRDT model).** *Chosen
  (rung 2).* The workflow is turn-based with an available ancestor, so disjoint
  edits auto-merge and only true same-field collisions need a human. Pure Elm, no
  library, outcomes expressible as types. (Framing per Kleppmann/DDIA:
  *mergeable-persistent structures use three-way merge; CRDTs use two-way
  merges.*)
- **Full CRDT / operation-log (Automerge, Yjs, or hand-rolled).** *Discarded
  (rung 3).* CRDTs earn their complexity in real-time, many-replica,
  no-coordination settings; ours is two-party, turn-based, with an ancestor —
  two-way commutative merge is overkill. The JS/Wasm libraries would mean
  threading an opaque document through Elm ports, surrendering the "if it
  compiles it works" guarantee that is the project's whole ethos; a hand-rolled
  Elm CRDT is heavy. And CRDTs guarantee *state* convergence, not *semantic
  validity* — a converged plan could still be domain-invalid (e.g. an aid station
  left at a distance the other side removed), so a validation pass would be
  needed on top anyway. The three-way family gives correct merges for this data
  shape without any of that. ("You might not need a CRDT.")

### 1.4 History representation

- **Unify history and merge into one operation log (event sourcing); the
  changelog *is* the merge substrate.** *Discarded.* Forces event-sourcing across
  the whole Elm update layer and inherits the semantic-validity problem above.
  The two artifacts serve different goals: the merge substrate must replay
  deterministically; the changelog only has to narrate for humans.
- **Keep them separate: three-way merge owns correctness (WI-3); a derived,
  structured-but-cosmetic changelog owns the human view (WI-4).** *Chosen.* The
  changelog is never read back to reconstruct state — delete it and merge still
  works.

### 1.5 Course mutability

- **Allow course edits / treat the course as mergeable.** *Discarded.* Aid
  distances and per-km plans are only meaningful against one track; making the
  course mergeable creates the hardest conflict class (geometry reconciliation)
  for no real benefit. *Freeze the course, merge the plan* (§0.2) removes the
  class entirely.

---

## 2. WI-1 — `.trail` format v2: identity + integrity guard (TASK-047)

**Goal:** an imported `.trail` can only land on the race it belongs to, built on
the same course.

**Changes:**
- **`raceId` (UUID):** a *stable share id*, minted once at race creation,
  persisted in IDB, embedded in every `.trail` export. (See Reality correction
  #1 — this is distinct from the existing IDB-key `id`, which is regenerated on
  import.)
- **`courseHash`:** a hash of the canonical course, computed at GPX-import time
  and stored on the race. Recommend hashing a *canonical serialization of the
  decoded track points* (lat/lon/ele rounded to fixed precision) rather than the
  raw GPX bytes, so cosmetically-different-but-equivalent files still match. (See
  Q1.)
- **Import guard:** on "update from file", reject when incoming `raceId` ≠ target
  race's `raceId` ("this file is for a different race"); reject/warn when
  `courseHash` ≠ target ("this plan was built on a different course — start a
  fresh share"). Only a matching pair proceeds to merge (WI-3).

**Back-compat:** v1 `.trail` files (no `raceId`/`courseHash`) follow the legacy
whole-snapshot import path. A v1 file imported onto a race mints identity on the
way in. (See Reality correction #3 — the version gate is strict-equality today,
so WI-1 must widen it to accept {v1, v2} explicitly.)

**Acceptance:**
- File whose `raceId` ≠ target → blocked, clear message, no state change.
- File whose `courseHash` ≠ target → blocked/warned per Q1.
- Matching file → proceeds to merge.
- Existing v1 `.trail` files still import.

**Dependencies:** none — foundation.

---

## 3. WI-2 — Course freeze (invariant + enforcement) (TASK-048)

**Goal:** codify *freeze the course, merge the plan* so the merge layer can
assume a stable coordinate space.

**Reality check:** trail already has no course-point editor (the course comes
from GPX upload; changing it means re-uploading). So this is mostly an
**invariant to state and enforce**, not a heavy feature:
- The merge layer (WI-3) never reads or writes track points — course is excluded
  from the merge surface entirely.
- A re-uploaded / changed course produces a different `courseHash`, which WI-1's
  guard already catches.

**Acceptance:**
- Merge output is identical on the track points to the local pre-merge course.
- Course change (re-upload) → `courseHash` changes → prior shared files are
  rejected on import with the explanatory message.

**Dependencies:** WI-1 (`courseHash`).

---

## 4. WI-3 — Three-way merge (rung 2) (TASK-050)

**Goal:** fold a coach's `.trail` into the local plan so disjoint edits both land
and overlapping edits are surfaced for the human, not silently clobbered.

**Ancestor delivery (recommend 3a):**
- **3a — embed the base in the file.** Each export carries
  `{ base: <ancestor planning-layer snapshot>, current: <this planning-layer snapshot>, version }`.
  Importer diffs `base→current` (theirs) and `base→local` (yours, reachable from
  the same `version`). Self-contained; doesn't depend on local history
  retention. Because the course is frozen, `base`/`current` exclude track points,
  so the size cost is trivial. (Alternative 3b — local history lookup by
  `version` — is smaller on disk but breaks if the base was pruned. See Q2.)
- **Version identifier — recommend a small version vector** keyed by
  author/device id. It lets the importer *classify* a file before touching the
  merge UI: incoming strictly descends from local → **fast-forward**, apply
  directly, no conflict review; true divergence → **three-way merge** with the
  review UI. Avoids a merge screen when the coach only added on top of exactly
  the owner's version. (Q4.)

**Merge surface (field-level / per-key; write it concretely per type, no generic
merge framework — three reuses before extraction):**
- **Race metadata** (name, date): scalar, three-way against base.
- **Aid stations:** keyed set, keyed by the stable aid id. Depends on the
  fork-collision-safe id (TASK-049). Union adds from both sides; honor removes;
  three-way merge per-aid fields.
- **Per-km plan:** already keyed by km index. Three-way merge `{note, targetPace}`
  per field per km.
- **Profile snapshot:** **owner-authoritative — exclude from merge** (a coach
  shouldn't rewrite the athlete profile). (Q3.)
- **Actual splits:** observed data — **owner-authoritative, never merged.**

**Conflict model (types, not runtime surprises):** represent each merged field as
`Merged a | Conflict { base : a, mine : a, theirs : a }`. Disjoint edits resolve
to `Merged`; same-field concurrent edits resolve to `Conflict` and surface in a
review step where the human picks (or, for the per-km note string, optionally
hand-merges — Q5). After resolution, race state advances to a new version and
emits changelog entries (WI-4).

**Integration note:** the per-field diffs this work item computes (`base→theirs`,
`base→mine`, and the resolved result) are exactly the structured change data WI-4
wants to render. WI-4 should consume WI-3's diff output rather than re-deriving
it.

**Acceptance:**
- Coach edits per-km notes while owner edits aid stations → merges with **zero
  conflicts**, both sets present.
- Both edit the same per-km note → **one conflict**, human resolves, result
  applied.
- Merge is deterministic; no `merge failed` runtime path.
- Track points untouched (WI-2).
- Fast-forward import (coach strictly ahead of owner's exact version) applies
  with no conflict UI.

**Dependencies:** WI-1, WI-2, TASK-049 (fork-safe aid ids); feeds WI-4.

---

## 5. WI-4 — Change history: structured log + dedicated feed view (TASK-051)

**Goal:** a human-facing "who changed what, over time" view. **Explicitly not**
the merge substrate — derived, cosmetic, never replayed to reconstruct state
(delete it and merge still works). This is the resolution of the "full history
vs. visual representation" tension: WI-3 owns correctness; this owns the view.

**Priority:** nice-to-have, built last. But because it's last, invest in a real
structured model + feed view rather than a flat text list — the structured data
is what lets the display be enhanced later.

**Display surface:** a **separate view — a dedicated tab, modal, or drawer**, not
inline on the race page. Render it as an **activity feed** (think GitHub / Linear
activity streams): entries grouped by change-set with an author + timestamp
header, then typed rows with per-type visual treatment (icon + phrasing per
change kind).

**Structured model (the part worth the effort):** each log entry is
`{ entryId, author, timestamp, source, changes: [ChangeDescriptor] }`, where each
`ChangeDescriptor` is a **typed** change so the feed can style each kind
distinctly. Suggested taxonomy (extend as needed):
- `AidAdded` / `AidRemoved` / `AidMoved {fromKm, toKm}` / `AidRenamed` /
  `AidRetimed`
- `KmNoteAdded` / `KmNoteEdited` / `KmNoteCleared` (carry the km index)
- `KmPaceSet` / `KmPaceChanged {from, to}` / `KmPaceCleared`
- `RaceRenamed {from, to}` / `RaceDateChanged {from, to}`
- `CourseUploaded` (structural event — shown even though the course isn't merged)
- `Merged {fromAuthor, count}` — a merge change-set, ideally expandable into the
  underlying typed descriptors it applied

Each descriptor carries the minimal payload its row needs (km index, aid id +
label, cheap old→new values). Keep payloads small; this is narration, not an op
log.

**Where entries come from:** appended on commit of a local mutation and on merge.
A merge entry's `changes` are the resolved per-field diffs from WI-3 (see WI-3
integration note) — no parallel diff engine.

**Author identity:** a free-text name or a per-device UUID stamped at edit/merge
time — no accounts, no login. Shared with WI-3's conflict attribution and version
vector.

**Persistence & sharing:** stored on the race in IDB; included in `.trail` export
so both sides see the history. **Changelog merge is trivially conflict-free:**
entries are immutable and keyed by `entryId` (e.g. `(authorId, localSeq)`), so
importing the coach's file *unions* the two logs by key — no dedup beyond the
key, no ordering conflict.

**Acceptance:**
- The history lives in its own tab/modal/drawer, not on the main race page.
- After several edit / export / merge cycles, the feed shows ordered change-sets
  with author + timestamp and **per-type styled rows** (an added aid station and
  an edited pace render differently).
- Importing the coach's file brings his entries in; union by `entryId` → no
  duplicates.
- Removing the entire change history does not affect a subsequent merge (proves
  the decoupling).

**Dependencies:** consumes WI-3 diff output; author-identity sub-task shared with
WI-3; otherwise independently buildable.

---

## 6. Suggested sequencing

1. ADR (§0) + brief-update task. — **done: ADR-0009 + TASK-046.**
2. **WI-1** — format v2 + identity/integrity guard (foundation). — **TASK-047.**
3. **WI-2** — course-freeze invariant (light; guard + exclusion). — **TASK-048.**
4. **Sub-task** — fork-collision-safe aid-station ids. — **TASK-049.**
5. **WI-3** — three-way merge. — **TASK-050.**
6. **WI-4** — structured change history + feed view (last; partly parallelizable
   with WI-3 once author identity lands). — **TASK-051.**

---

## 7. Open questions to resolve before / during ticketing

Resolve §7 with the user before implementing WI-1 (Q1) and WI-3 (Q2–Q5); the
rest can be answered as the tasks come up. Recommendations noted; final call is
the user's.

- **Q1 — `courseHash` input.** Canonical decoded track (rounded lat/lon/ele —
  tolerant of cosmetic GPX diffs, recommended) vs. raw file bytes (simplest,
  brittle). And on mismatch: hard-block vs. warn-and-allow.
- **Q2 — ancestor delivery.** Embed base in file (3a, recommended,
  self-contained) vs. local history lookup by version (3b, smaller files,
  retention-dependent).
- **Q3 — profile snapshot & actual splits in merge.** Confirm owner-authoritative
  (recommended exclude) vs. mergeable.
- **Q4 — version scheme.** Small version vector keyed by author/device
  (recommended — enables fast-forward vs. three-way classification) vs. plain
  monotonic counter / content hash.
- **Q5 — conflict-resolution UX.** Dedicated merge-review screen vs. inline
  per-field picker; and for the per-km note string specifically, pick-one vs.
  offer a hand-merge textarea.
