# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Entry template

```markdown
### TASK-NNN — <title>

**Source:** BACKLOG / parking lot / user request
**Branch:** <kind>/task-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, anything decided while planning.
```

## Active

### TASK-039 — Fix section-overlap double-count in `Planning.sectionsForRace`

**Source:** BACKLOG parking lot (scoped during TASK-025), promoted 2026-06-15.
First of a five-task batch the user promoted on 2026-06-15: TASK-039, 040, 041,
042, 022 — worked one at a time, each its own PR.
**Branch:** `fix/task-039-section-overlap`

**Problem.** `sectionsForRace` (`Planning.elm:457`) assigns kms to sections with
an overlap test `km.distStart < b && km.distEnd > a`. A km window straddling an
aid-station distance `b` satisfies the test for *both* the section ending at `b`
and the one starting at `b`, so:
- its index appears in two sections' `kmIndices` → `sectionSeconds`
  (`Main.elm:5060`/`5236`) and `sectionActualSeconds` (`6332`) double-count its
  seconds; the cum column `runningAfterSection` (`5071`) inflates; it shows in
  two section cards' `containedKms` (`5234`);
- `sumKmField` (`Planning.elm:502`, which ignores its `a`/`b` args) adds its
  whole gain/loss twice → `section.gain`/`.loss` (`5109-5110`, `5357-5360`)
  double-count;
- section-mode CSV (`Csv.elm:188`) double-counts likewise.

The `sumKmField` comment *claims* "sum the full km value when its center falls
inside the range" — but the code does an overlap test, not a center test.

**Approach.** Assign each km to exactly one section by **midpoint containment**
(`a ≤ (distStart+distEnd)/2 < b`) — a clean partition: no double-count, no
dropped km, and it makes the code match `sumKmField`'s own documented intent.
Pro-rating the straddling km's gain/loss/seconds across the two sides was
considered and rejected for now (per-km plan seconds are indivisible; gain/loss
would need re-deriving the km's elevation at the split point) — bounded
whole-km attribution is the conventional, reversible choice. Record the
decision (ADR if it clears the INDEX bar, else journal + code comment).

**Acceptance criteria:**
- [ ] **Partition.** For a race with an aid positioned mid-km, every km index
  appears in exactly one section's `kmIndices` (none in two, none dropped).
- [ ] **No elevation double-count.** Σ over sections of `section.gain` equals
  the sum of all per-km `.gain` (same for `.loss`), within rounding — it was
  strictly greater when a km straddled an aid.
- [ ] **No time double-count.** Σ over sections of `sectionSeconds` equals the
  total plan moving seconds; the section-table cum column ends exactly at the
  total. (Same for `sectionActualSeconds` when an actual is linked.)
- [ ] Misleading comments in `sectionsForRace`/`sumKmField` corrected to
  describe midpoint assignment.
- [ ] An aid landing exactly on a km boundary (no straddle) is unchanged.
- [ ] Local CI green (type-check, build, smoke, smoke:aidcsv). Verification of
  the partition/no-double-count invariants is by a section smoke harness over
  the compiled `Planning.sectionsForRace` (preferred — quotable + regression
  guard) or, failing that, an app reproduction; output quoted in the journal.

**Notes.** The section-card **Δ vs plan** moving-vs-clock bug (the other half of
the old parking-lot entry) stays deferred — unblocked by this fix but its own
task. Out of scope here.
