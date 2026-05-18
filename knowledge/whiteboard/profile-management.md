# Profile management

> Status: open — discussion paused. No action yet. The path forward likely
> involves snapshot-into-race + soft references, not hard linking.

## Context

User brainstorm 2026-05-18. Current state: one global `AthleteProfile` lives
in IDB (`settings` store), used by the predictor. The user wants
race-archetype profiles ("20k aggressive" vs "100k conservative") and
referenced Jim Walmsley's different approaches to UTMB vs. WSER as the
real-world motivator.

## Options considered

### A. Quick win: race-archetype presets in the existing single-profile UI

Add a "race archetype" dropdown to the profile page that snaps the existing
profile fields (flat trail pace, fatigue slope, etc.) to canned values. Same
data model. Small. Doesn't break anything.

**Why it's tempting:** ships in an afternoon. Doesn't require any schema
changes or migration logic.

**Why it's wrong:** the single-profile assumption is the bug. Switching the
profile to "100k conservative" before planning Race A and then to "20k
aggressive" before planning Race B *changes the predictor output for Race A
retroactively*. The plan you saved no longer reflects the profile you
actually used. That's the longitudinal-tracking failure mode below.

### B. Multi-profile with hard links from each race

Each profile is a record with an id. Each race has a `profileId`. Profile
page becomes CRUD.

**Why it's tempting:** matches the obvious mental model of "select a
profile, then plan."

**Why it's wrong (user's pushback, the load-bearing argument):**

> Linking to a profile can be useful, but those profiles then have to be
> kept around forever and be immutable, otherwise changing/deleting the
> profile breaks the plan or at least the rendering of which profile was
> selected to make the plan into fruition.

Hard links create lifecycle coupling: edit a profile → silently invalidate
N plans; delete a profile → broken references everywhere. Either you
forbid edits/deletes (annoying), version every profile (heavy), or accept
the broken history (defeats the point).

### C. Snapshot into the race + soft reference

The race carries an inline `AthleteProfile` snapshot — that's the source of
truth for *this* plan. A `profileId` lives alongside as a *soft* reference,
purely informational ("this came from the 'Push hard' profile"). If the
profile is later deleted or renamed, the snapshot is unaffected; the soft
reference just dangles harmlessly.

**Why this is the right shape (user's argument):**

> The source of truth is attached to the race plan. As the races, months,
> and even years pass, the athlete can keep track of their progress. You
> can view a race from 2 years ago with a 'Push hard' profile, but now that
> could be just a normal profile since you've grown as a runner.

The race plan becomes a longitudinal record of the athlete's fitness at
the time. The profile registry is just a convenience for not re-typing the
same numbers across races. Edits to a profile don't rewrite history.

## Design questions still open

If we commit to (C), we need answers to:

1. **Profile registry shape.** Flat list, or grouped by archetype
   (sprint / mid / ultra)?
2. **Default profile on new race.** "Last used"? An explicit pick? Empty
   inline profile that the user fills in?
3. **Editing the snapshot on an existing plan.** Should the per-race
   profile-edit UI live on the race page (inline) or on the profile page
   with a "this is a snapshot — edits only apply here" affordance?
4. **Migration of existing races.** They have no inline profile. Default
   to the global one at migration time? Leave them empty (use today's
   global profile until user explicitly snapshots)?
5. **Predictor wiring.** Today the predictor reads `model.activeProfile`.
   It would need to read `race.profileSnapshot` instead, with the active
   profile as a fallback for un-snapshotted races.
6. **Settings page UX.** Does the profile page still show "active profile"
   as a concept, or does it become "profile registry" only?
7. **Soft reference on deletion.** Show "deleted profile: …" or strip
   silently?

## Where we landed

No code yet. The shape is clear (snapshot + soft reference) but the design
questions above are real and the user wants more thinking before we commit.
The single-global-profile of TASK-017 stays in place; users who want
archetype-based planning are unblocked enough by editing the global profile
between sessions for now.

A reasonable next step is an ADR draft that locks (C) as the chosen shape
and answers the open questions one by one. That can happen any time; it
doesn't need to happen in the next session.

## Follow-ups

- No tasks queued.
- No ADR drafted.
- Re-open when the user has an opinion on the design questions above, or
  when actual usage of the single-profile model produces concrete friction
  worth pointing to.
