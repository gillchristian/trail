# 0012 — Identity & authorship for `.trail` collaboration: person-level userId over device id

**Date:** 2026-06-16
**Status:** accepted

## Context

WI-3's merge-review UI must label two versions of a value — "yours" and the
other person's. Labelling by *role* ("Coach's suggestions") is wrong from the
other seat: when the athlete sends to the coach, the coach imports and sees the
*athlete's* edits labelled "Coach." The fix is to label by **person**, which
means each person needs a stable identity that travels with their changes —
without accounts and without a backend (Layer 0). This ADR settles that identity
model and the three questions the merge-UI spec routed to the user (Q-I1–Q-I3).

Builds on ADR-0009 (the `.trail` three-way-merge arc + Layer-0 scope) and the
companion spec `reference/merge-ui-identity-spec.md` (§1.2 decisions, §1.3
alternatives).

## Decision

**1. The id is the identity; the name is a mutable label.** A person is a
locally-minted `userId` (UUID v4 — no coordination, no server). The display name
is a label attached to that id and can change freely.

**2. One device-global identity record, `me = { userId, displayName }`,** kept
**separate from the athlete performance profile** (`AthleteProfile.Profile`,
`#/profile`): identity is device-level and singular; the performance profile is
race-level and may be plural. Do not nest one inside the other.

**3. Races store `owner : userId` only** — never a denormalized name.

**4. A local directory resolves names from ids:**
`{ [userId]: { displayName, nameUpdatedAt } }`, holding your own id plus every id
you have ever seen. All name display goes through it.

**5. The `.trail` denormalizes the `(userId, displayName, nameUpdatedAt)` pairs
it references,** so an importer can show names for people not yet in their
directory.

**6. Name propagation is lazy, last-write-wins, keyed by id, ordered by
`nameUpdatedAt`.** On import, update a directory entry only when the incoming
name is newer — so importing an *older* file never reverts a name to a stale
value.

**7. Mint a `userId` at exactly two points, never elsewhere:** (a) first export
with no identity yet; (b) import-as-someone-else with no identity yet. **Never
mint on the "yourself" path — that always *adopts* the file's owner id** (the
device-link: how a second device claims the same person). This discipline keeps
one person from accumulating two ids.

**8. Ids are claims, not credentials.** No signing, no anti-spoofing — correct
for a small trusted circle of athlete + coach; this layer must not later be
mistaken for auth.

### Resolved questions (user, 2026-06-16)

- **Q-I1 — dual-id linking: build the explicit link action.** Beyond the
  adopt-first discipline (which already covers the normal multi-device flow —
  import your own plan, choose "yourself", adopt its id), add an explicit *"this
  device is already `<name>` — link to `<ownerName>`?"* action for the residual
  case (you mint a fresh id on a device, then import your own older file carrying
  a different id). Chosen over punting because *the same person across devices*
  is the core case this whole model serves.
- **Q-I2 — identity store: a dedicated IndexedDB store.** `me` + the directory
  persist in their own IDB store (DB-version bump + migration), alongside
  races/profiles — not localStorage. (`deviceId` stays in localStorage as the
  device-scoped collision key; see Grounding.)
- **Q-I3 — role badge: names-only.** Labels are person names ("You" / `<name>`)
  with no derived "· coach / · athlete" badge. Zero inference, correct from every
  seat; a badge can be added later with no rework (owner is already stamped).

## Alternatives considered (spec §1.3)

- **Hardcoded "Coach"/"Athlete" role labels.** Rejected — seat-relative; wrong
  whenever the file flows the other way. The bug that started the thread.
- **Device-id-of-creator = the person.** Rejected — a person is not their
  device; their phone has a different id and would be mislabelled. Identity must
  travel with the person. (We keep `deviceId` for *device-scoped* concerns — see
  Grounding — but it is not the person.)
- **Pure local inference of role from the file-creation event.** Rejected as the
  mechanism — the owner-vs-reviewer bit isn't present in a lone creation event;
  no single-device heuristic is fully correct.
- **Role dropdown defaulting "trail-import = coach".** Default rejected
  (mislabels your own second device the moment you move a race via `.trail`);
  would survive only as a manual override if ever needed.
- **Names-only, no role concept at all.** Chosen for v1 labels (Q-I3) — fully
  robust, zero-inference.
- **A backend / accounts to own identity.** Out of scope by the Layer-0
  constraint; identity is bootstrapped peer-to-peer via files.

## Consequences

**Makes easy:** person-correct labels from every seat; rename is one
directory-row update (every owned race reflects it, no per-race migration); the
home view's personal-vs-others split falls out of `owner == me.userId`; a second
device claims one identity by adopting on import.

**Makes hard / to revisit:** the explicit link action (Q-I1) adds reconciliation
surface to build and test. Ids-as-claims means no spoofing protection — fine for
athlete + coach, but must not be mistaken for auth if the circle ever widens. The
dedicated IDB store (Q-I2) adds a DB-version migration.

**Grounding in the current code (verified 2026-06-16):**

- **A device-global id already exists and is already the author identity.**
  `deviceId` (localStorage `trail.deviceId`, `main.js:188`) keys the changelog
  author (`authorLabel`, `Main.elm:6769`), the version vector
  (`Merge.bumpVersion`), the fork-safe aid-id prefix (`Merge.mintAidId`), and the
  changelog `entryId` (`author ++ "-" ++ seq`). This ADR **adds `userId` over
  `deviceId`; it does not replace it.** `userId` = human identity (`owner`, name
  labels, directory); `deviceId` stays the *device-scoped collision key*. The
  same person on two devices shares one `userId` but has two `deviceId`s — which
  is exactly why `entryId` and the version vector stay `deviceId`-keyed
  (re-keying by `userId` would let two of one person's devices collide on their
  local seq and the WI-4 union would silently drop entries).
- **`AthleteProfile.Profile` already exists** (`src/AthleteProfile.elm:46`), so
  decision 2's separation is a real, not hypothetical, collision.
- **`Race` has no `owner` field yet.** WI-1's `shareId`/`raceId`
  (`main.js:87,86`) identify the *document*, not the *person* — `owner` is new
  and distinct.

## Related

ADR-0009 (merge arc + Layer-0 scope), ADR-0010 (course identity / `shareId`),
ADR-0011 (merge engine). The §2.2 merge-review **UI reframe** (suggestions /
person-not-role / card list / no red-green) will get its own ADR when **TASK-056**
is built. Tasks: **TASK-054** (this), **TASK-055** (home view), **TASK-056**
(merge integration + review UI).
