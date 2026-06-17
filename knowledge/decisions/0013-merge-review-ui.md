# 0013 — Merge-review UI: review *suggestions*, person-named, no red/green (WI-3 · UI)

**Date:** 2026-06-17
**Status:** accepted

## Context

The TASK-050 three-way merge engine (ADR-0011) produces, per overlapping field,
a typed `Conflict { key, label, mine, theirs }`; the version vector already
skips fast-forwards and auto-merges every disjoint edit. What remained for
TASK-056 was the *human* surface that resolves the residual true collisions, and
the integration that routes a returned `.trail` into the engine. This ADR settles
the UI reframe (companion spec `merge-ui-identity-spec.md` §2.2) and the five
questions the spec routed to the user (Q-U1–Q-U5). It builds on ADR-0012 (the
person identity the labels use) and assumes the engine + the *freeze-the-course,
merge-the-plan* axiom (ADR-0009/0011).

## Decision

**1. Reframe: reviewing *suggestions*, not resolving *conflicts*.** For a trail
runner this is "review your coach's changes and decide what to keep," not merge
tooling. Vocabulary avoids "conflict / merge / diff / theirs"; uses "changes /
suggestions / your version / their version". **Person-named throughout** (WI-5):
"You" vs `<name>` resolved through the directory — never the seat-relative "Coach"
the prototype hardcodes (that's the exact bug WI-5 fixes). No role badge (Q-I3).

**2. Show only the true-collision residue + reassurance.** The version vector
skipped fast-forward and the engine auto-merged every disjoint edit, so the
surface foregrounds the few real overlaps and states the rest in one muted line:
"M other changes from `<name>` were added automatically."

**3. Primitive: a card list, identity-distinguished, no red/green.** One card per
overlap — a context label (what + where, e.g. "Target pace · km 14") and two
equal options (You / `<name>`). Sides are told apart by **identity** (name +
initial + a subtle per-person tint) and selection by a 2px ring + check —
**never red/green** (which reads as error/correct on a neutral choice). Each card
carries its km/location in its data (forward-compat for the v2 course-anchored
renderer — Q-U5).

**4. Symmetric engine, seat-relative experience.** The merge privileges neither
side; the *screen* is always from the importer's seat, and "Keep my version" is
the safe baseline. "Suggestions" names that lived asymmetry without making the
data model asymmetric.

### Resolved questions (user, 2026-06-17)

- **Q-U1 — placement: a modal.** A centered dialog (matching trail's other
  modals), mobile-first, single column. Overlaps are few, so a short modal beats
  a wide drawer; the drawer (plan visible behind) stays available as a later
  upgrade if lists ever get long.
- **Q-U2 — default stance: forced per-card choice.** Nothing pre-selected; *Apply*
  enables only once every card is resolved. Honors the symmetric framing over the
  friendlier "pre-select yours" (which tilts the screen to your-version-as-default).
- **Q-U3 — same-field note overlap: a hand-merge textarea.** When a per-km note
  was edited on **both** sides, the card offers an **editable textarea**
  pre-filled with both versions to splice, not a binary pick-one. (Departs from
  the spec's pick-one recommendation — the user's call: a note is prose worth
  combining, not choosing between.) Every *other* conflict kind stays the
  two-equal-options card. **Engine consequence:** `Merge.resolve` only flips a key
  to *theirs*, so the apply path needs a custom-value resolution for the
  hand-merged note (set km *i*'s note to the edited string directly) — a small
  addition layered on the existing `resolve` fold, not a rework.
- **Q-U4 — confirm-on-dismiss: only when picks exist.** Closing (X) or
  "Keep my version" rejects the whole import; it discards with **no** dialog when
  no card has been resolved, and confirms only if the user would lose picks
  already made ("Discard your choices and keep your own version?"). Applying is
  reversible (new version + a WI-4 changelog entry), so we lean on undo over
  warning dialogs.
- **Q-U5 — course-anchored renderer is explicitly v2.** v1 ships the abstract
  card list; the trail-native renderer (ghost pins on the elevation profile) is a
  later upgrade. v1 cards already carry km/location, so the upgrade is a new
  renderer, not a migration.

## Alternatives considered (spec §2.3)

- **Dev-style diff (side-by-side / red-green).** Rejected — alien to runners; red
  reads as "error", green as "correct", miscolouring a neutral choice;
  side-by-side columns die on a phone.
- **Track-changes accept/reject (Google-Docs).** Adopted as the *framing* and
  vocabulary; the symmetric two-option card is its form.
- **Course-anchored pickers on the elevation profile.** Deferred to v2 (Q-U5) —
  most trail-native but heavier, and non-spatial fields (name/date) need a
  fallback. Kept reachable by the forward-compat card data.
- **Folding resolution into the WI-4 history feed.** Rejected — resolution is its
  own dismissable surface; the feed stays a read view.
- **Pre-select "you" per card.** Rejected (Q-U2) — fewer taps but tilts the screen
  to your-version-as-default; forced choice keeps the engine's symmetry honest.
- **Pick-one for note overlaps.** Rejected (Q-U3) — the user wants a hand-merge
  textarea so prose can be combined.

## Consequences

**Makes easy:** correct person labels from every seat (ADR-0012); a calm surface
that foregrounds only real overlaps; an undoable apply (new version + changelog
entry) instead of warning dialogs; a clean v2 upgrade path (the card data already
carries location).

**Makes hard / to revisit:** the hand-merge textarea (Q-U3) needs a custom-value
apply path beyond `Merge.resolve`'s flip-to-theirs (set the km note to an
arbitrary string) — a small, contained addition. Modal-over-drawer (Q-U1) means
the plan isn't visible behind the review; revisit if overlap lists ever grow.
Ids-as-claims (ADR-0012) carries over — labels are trust-on-import, not auth.

**Integration shape (TASK-056):** persist `mergeBase : PlanningLayer` (the
last-synced ancestor) + `version : VersionVector` on `Race`; the `.trail` carries
`{ base, current, version }` (Q2, additive — `D.oneOf` defaults, no format bump).
Because `Race` would then hold a `PlanningLayer`, that type alias moves from
`Merge` into `Types` (the same import-cycle fix used for `ChangeEntry` in WI-4:
`Merge`/`Changelog` import it from `Types`). `version[deviceId]` bumps on each
local commit (`commitRaceEdit`); `mergeBase`/`version` advance at share/merge.
The import entry point: a `.trail` whose `shareId` matches a local race
(courseHash matches per WI-1) routes to merge — `classifyVersions` → FastForward
applies directly (no UI), Diverged opens the review modal, Behind/Same no-op.

## Related

ADR-0009 (merge arc + Layer-0 scope), ADR-0011 (the merge engine this resolves
the output of), ADR-0012 (the person identity the labels use). Spec:
`reference/merge-ui-identity-spec.md` Part 2 + the prototype at
`reference/merge-review-prototype.html` (UX/layout reference only — its "Coach"
labels are the seat-relative bug). Task: **TASK-056** (the arc's last).
