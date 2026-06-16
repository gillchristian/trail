# Merge review UI + identity & authorship — spec

**Status:** proposal — ready for hand-off. Turn the work items below into `TASK-NNN`
entries in `planning/BACKLOG.md` (numbers assigned by you).
**Companion to** `coach-collab-spec.md` (the in-`reference/` copy of
`coach-collaboration-spec.md`). That doc specs the merge *engine*
(WI-1 format guard, WI-2 course freeze, WI-3 three-way merge, WI-4 change-history
feed). This doc specs two things that grew out of designing WI-3's "review step":
- **WI-5 — Identity & authorship.** Who authored a change, and how two devices know
  who's who without accounts. Foundation; **WI-3's UI and WI-4 depend on it.**
- **WI-3 · UI — Suggestion-review surface.** The screen where a human resolves the
  overlaps WI-3's engine couldn't auto-merge.
**Self-contained by design:** each part records the paths considered and rejected, so
the rationale travels with the file. The merge engine, three-way-vs-CRDT reasoning,
and the *freeze-the-course, merge-the-plan* axiom live in the companion doc; this doc
assumes them.

---

> **Reality corrections — grounded against the code at ingestion (2026-06-16).**
> The spec was written before checking the current model; read these before
> implementing WI-5. (Same convention as `coach-collab-spec.md`'s corrections.)
>
> 1. **A device-global id already exists and is *already* the author identity.**
>    `deviceId` is minted + persisted in `localStorage` (`trail.deviceId`,
>    `src/main.js:188`) and is already wired as: the changelog **author**
>    (`authorLabel`: `author == deviceId` → "You", `src/Main.elm:6769`), the
>    **version-vector key** (`Merge.bumpVersion deviceId`), the **fork-safe
>    aid-id prefix** (`Merge.mintAidId deviceId seq`), and the **changelog
>    `entryId`** (`author ++ "-" ++ seq`). So WI-5 **adds a person-level `userId`
>    as the human-identity layer — it does not remove `deviceId`.** Split the
>    roles: `deviceId` stays the *device-scoped collision key* (version vector,
>    aid-id prefix, `entryId` uniqueness — two devices of one person must not
>    collide there); `userId` becomes the *human identity* (`race.owner`, author
>    attribution + name labels, the directory). §1.3's discard of "device-id =
>    person" is about *identity/labels*, not the collision key. Do **not** re-key
>    `entryId` by `userId` — two devices sharing a `userId` would then collide on
>    their local seq and the WI-4 union would silently drop entries.
> 2. **`me` must not nest in the performance profile — and that collision is
>    real here.** `src/AthleteProfile.elm:46` already defines `type alias Profile`
>    (the race-level *performance* profile, `#/profile`). The identity record
>    `me = { userId, displayName }` is device-global (natural home: alongside
>    `trail.deviceId` in localStorage, or a small IDB store — Q-I2) and is a
>    *different thing* from `AthleteProfile.Profile`. §1.2's warning is not
>    hypothetical.
> 3. **No `owner` on `Race` yet.** WI-5 adds `owner : userId`; the home view
>    (§1.5) has no owner concept today. `shareId`/`raceId` already exist per-race
>    (`src/main.js:87,86`, WI-1) — those identify the *document*; `owner`
>    identifies the *person*. Distinct fields, distinct purposes.

---

# Part 1 — WI-5: Identity & authorship

## 1.1 How we got here (the labyrinth)

The merge UI needs to label two versions of a value — "yours" and the other person's.
The first instinct was to label by **role**: "Coach's suggestions." That breaks,
because a role is only correct from one seat: when the athlete sends to the coach, the
coach imports and sees the *athlete's* edits labelled "Coach." The relativity is the
bug.

The fix is to **label by person, not by role** — a name is correct from every seat.
That turned the problem from "infer who the coach is" into "give each person a stable
identity that travels with their changes." Working through how to do that *without
accounts and without a backend* (the project's Layer-0 constraint) led to a small
distributed identity scheme. The paths we walked and abandoned to get there are in 1.3.

## 1.2 Decisions

1. **The id is the identity; the name is a mutable label.** A person is a `userId`
   (locally-minted UUID v4 — no coordination, no server). The display name is just a
   label attached to that id and can change freely.
2. **One singular identity record per device,** call it `me`: `{ userId, displayName }`.
   **Keep it separate from the athlete *performance* profile** — that name collision
   will bite otherwise: identity is device-level and singular; the performance
   "profile" is race-level and may be plural. Do not nest one inside the other. The
   identity record is a device-global store.
3. **Races store `owner: userId` only** — never a denormalized name.
4. **A local directory resolves names from ids:**
   `{ [userId]: { displayName, nameUpdatedAt } }`, holding your own id plus every id
   you've ever seen. All name display goes through it.
5. **The `.trail` denormalizes the `(userId, displayName, nameUpdatedAt)` pairs it
   references,** so an importer can show names for people not yet in their directory.
6. **Ids are claims, not credentials.** No signing, no anti-spoofing — a hand-edited
   file could assert any id. Correct trade for a small trusted circle of athlete +
   coach; this layer must not later be mistaken for auth.

**Consequence — rename is one update, not a migration.** Because races reference owner
by id and names resolve through the directory, renaming touches a single row; every
owned race displays the new name automatically. The only place a name is ever *copied*
is an exported file snapshot.

**Name propagation is lazy and last-write-wins, keyed by id.** A remote device learns
a new name only on its next import from that person. To keep "newest wins" coherent,
`nameUpdatedAt` orders it: on import, update a directory entry **only when the incoming
name is newer.** Without this, importing an *old* file from someone reverts their name
to a stale value — the name would flicker by file age. With it, it's a tiny LWW
register on `displayName`, keyed by `userId`, ordered by `nameUpdatedAt`.

## 1.3 Alternatives considered and discarded

- **Hardcoded "Coach" / "Athlete" role labels in the merge UI.** *Discarded.* A role
  is seat-relative; it's wrong whenever the file flows the other direction. This is the
  bug that started the whole thread.
- **Device-id-of-creator = athlete.** *Discarded.* The id is stable per device, but a
  person is not their device — their phone has a different id and gets mislabelled. The
  identity must travel with the person, not the hardware.
- **Pure local inference of role from the file-creation event** (e.g. "created from
  GPX = athlete, created from `.trail` = coach"). *Discarded as the mechanism.* The bit
  that disambiguates "I'm the athlete on a second device" from "I'm a coach reviewing"
  is *owner vs reviewer*, and that bit is not present in a lone creation event. No
  single-device heuristic can be fully correct; you need one piece of portable
  identity. (Retained only as a weak default — see the dropdown below.)
- **Role dropdown in settings as the *primary* mechanism, defaulting "trail-import =
  coach".** *Default discarded; dropdown kept as override only.* The "import = coach"
  default mislabels your own second device the moment you move a race to it via
  `.trail` (the only transport, since there's no sync). Role is instead derived from
  ownership (1.4); the dropdown survives only as the manual escape hatch.
- **Names-only, no role concept at all** ("Alex's suggestions" instead of "Coach's
  suggestions"). *Considered, not chosen — documented as the cheap fallback.* It's
  fully robust and zero-inference. We keep a derivable role badge only because it costs
  almost nothing: owner is one stamped field and the role is one comparison
  (`me.userId == race.owner`). If the role badge ever causes trouble, dropping to
  names-only is a safe retreat.
- **A backend / accounts to own identity.** *Out of scope by constraint.* The whole
  arc is Layer 0; identity is bootstrapped peer-to-peer via files instead.

## 1.4 The model in motion — prompts and flows

**Mint a `userId` in exactly two places, and never anywhere else:**
1. **First export with no identity yet** → prompt "What's your name?" → mint `userId`,
   set name. (The athlete-from-GPX first share.)
2. **Import-as-"someone else" with no identity yet** → chain into "What's your name?"
   → mint. (A reviewer's first contact — so their edits are attributed from the first
   change, not deferred to their first export.)

**Never mint on "yourself" — that path always *adopts*.**

**Prompt logic:**
- **Export**, `me` has no identity → "What's your name?" (mint, per above). Otherwise
  stamp silently with `me`.
- **Import** where `file.owner.userId == me.userId` → **no prompt**; import as owner.
- **Import** where owner ≠ me, or you have no identity → ask:
  *"Importing as `<ownerName>` (yourself), or as someone else?"*
  - **Yourself** → **adopt** `file.owner.userId` as your identity (the device-link:
    this is how a second device claims the same person-id). Never mint here.
  - **Someone else** → you're a reviewer; the race keeps the file's owner. If you have
    no identity, chain into "What's your name?" (mint #2).

**Why the mint discipline matters (the one sharp edge).** If a device mints its own id
and *later* claims a different owner-id as "me," you have two ids for one person and an
identity-merge mess. Steering the new-device flow toward "import your own plan, claim
it, adopt its id" means dual-id almost never arises. The residual case — you establish
a fresh identity on a device, *then* import an older file you also own under a
different id — is genuine. Handle it as an explicit **"this device is already
`<name>`; link to `<ownerName>`?"** action, not a silent merge — or punt it from v1
(see Q-I1).

## 1.5 Home view (falls out for free)

- **Personal vs someone-else's** = `race.owner == me.userId`. Use **owner, not
  last-editor** — a race you own that your coach edited still reads as yours.
- **Filter / group by person** on `owner`, labelled from the directory.
- **Emergent property:** on a coach's device every athlete plan they hold reads as
  "someone else's," filterable by athlete, cleanly separated from any races of their
  own.

## 1.6 Acceptance criteria

- A person has a stable `userId` (UUID v4) minted at one of exactly two points (1.4);
  never minted on the "yourself" path.
- `me` is a single device-level record, distinct from any performance profile.
- Races persist `owner` as a `userId`; names are never stored on the race, only in the
  directory and (denormalized) in exported files.
- Renaming updates one directory row; all owned races reflect it with no per-race
  migration.
- Importing a file whose `owner.userId == me.userId` does **not** prompt.
- Importing where owner ≠ me prompts yourself / someone-else; "yourself" adopts the
  file's owner id, "someone else" with no identity chains a name prompt and mints.
- Name updates apply only when `nameUpdatedAt` is newer; importing an older file never
  reverts a name.
- Home view distinguishes personal vs others' races by `owner` and supports filtering
  by person.
- Back-compat: pre-identity `.trail` and IDB records decode via `D.oneOf` defaults; a
  race with no `owner` adopts `me` on first touch.

**Dependencies:** none upstream. **Depended on by** WI-3 · UI and WI-4 (authorship in
the feed). Build before, or alongside the early part of, the merge UI.

---

# Part 2 — WI-3 · UI: Suggestion-review surface

This is the human-facing realization of the "review step" already scoped inside WI-3
of the companion doc. The engine produces, per overlapping field,
`Conflict { base, mine, theirs }`; this surface lets the owner resolve those.

## 2.1 How we got here (the labyrinth)

We ran an explicit divergence pass over the resolution UI, then converged. The single
most useful move was a **reframe**: for trail runners this is not "merge conflict
resolution," it's *"review your coach's suggestions and decide what to keep."* That
pulled the strongest patterns out of the document-review world (track-changes) rather
than dev tools (diff viewers), and it set the vocabulary.

Three questions collapsed the option space; the answers below drove the design:
1. **Symmetric or asymmetric?** → leaning co-editors (symmetric), but see 2.2 — the
   engine is symmetric while the *experience* is seat-relative, and that resolved the
   tension.
2. **Abstract or course-grounded?** → a card list first (cheap), with the
   course-anchored version held open as a later upgrade.
3. **One surface or two?** → its own dismissable surface, not folded into the WI-4
   history feed.

## 2.2 Decisions

1. **Reframe + vocabulary.** Present it as reviewing *suggestions*. Avoid "conflict,"
   "merge," "diff," "theirs." Use "changes," "suggestions," "your version / their
   version." Person-named throughout (from WI-5): "You" vs `<name>`, with an optional
   quiet role badge ("`<name>` · coach") when role is derivable by owner-match.
2. **Show only the true-collision residue.** By the time this opens, the version
   vector has skipped the fast-forward case and WI-3 has auto-merged every disjoint
   edit. Foreground the few real overlaps; include a one-line reassurance about the
   auto-merged majority ("5 other changes were added automatically").
3. **Primitive: a card list** (chosen for v1 — cheap to build). Each overlap is one
   card: a context label (what + where) and **two neutral, equal options** — yours and
   the other person's — as tappable choices. **No red/green** (it reads as
   error/correct on a neutral pick); distinguish sides by **identity** instead (name +
   initial, a subtle per-person tint), with selection shown by a ring + check.
4. **Symmetric engine, seat-relative UI.** The three-way merge privileges neither
   side (the "co-editor" instinct, already true in WI-3). The *experience* is always
   from the importer's seat, and the screen-level exit (2.5) makes the importer's plan
   the safe baseline. "Suggestions" names that lived asymmetry without making the data
   model asymmetric.
5. **Forced per-card choice** (nothing pre-selected) to honor the symmetric framing;
   **Apply enables only once every card is resolved.** (Alternative considered:
   pre-select "you" as default — friendlier, fewer taps, but it tilts the screen back
   to your-version-as-default. Not chosen; revisit via Q-U2.)
6. **Internal consistency.** Because "keep mine" is always one of the two choices,
   dismissing the whole screen is just the bulk version of "keep mine on everything":
   Apply = your picks; dismiss = your version throughout. No semantic gap between
   per-field resolution and whole-screen rejection.
7. **Forward-compat for the bold upgrade.** Each card carries its km/location in its
   data even in v1, so a later course-anchored renderer reads the same structure — the
   upgrade is a new renderer, not a rework.

## 2.3 Alternatives considered and discarded

**Diffing primitive (families):**
- **Dev diff — side-by-side or stacked, red/green.** *Discarded.* Familiar to
  engineers, alien to runners; red reads as "error," green as "correct," miscolouring
  a neutral choice; side-by-side columns die on a phone.
- **Suggestion / track-changes accept–reject** (Google-Docs model). *Adopted as the
  framing and vocabulary*; the card primitive (below) is its symmetric form.
- **This-or-that chooser — two equal cards / toggle.** *Chosen* as the card primitive.
- **Domain-native on the course** — ghost pins on the elevation profile, in-place
  pickers per segment. *Deferred, not discarded.* Most trail-native and
  differentiating, but heavier, and non-spatial fields (race name/date) need a
  fallback. Kept reachable by the 2.2(7) forward-compat data. This is the v2 upgrade.
- **Conversation / annotation thread folded into the WI-4 feed.** *Discarded for
  resolution.* Resolution stays its own surface; the feed stays a read view.

**Orthogonal axes:**
- **Pacing** — dense table vs one-at-a-time wizard vs summary-then-list. *Chose* a
  short summarised card list; a wizard is unnecessary given how rare/few overlaps are.
- **Spatial grounding** — abstract rows vs profile-anchored. *Chose* abstract for v1
  (profile-anchored deferred as above).
- **Authorship colour** — red/green vs identity colour. *Chose* identity colour.
- **Default stance** — neutral-forced vs default-to-yours vs accept-all-coach. *Chose*
  neutral-forced.
- **Scope shown** — conflicts-only vs conflicts-plus-reassurance. *Chose* to include
  the reassurance line.
- **Placement** — modal vs inline-below-import vs dedicated screen vs drawer. *Chose*
  an own dismissable surface: modal for a short list, or a wide drawer to keep the plan
  visible behind it (Q-U1).

## 2.4 Layout (a static mockup was prototyped; this describes it)

- **Header:** title with the suggester's name ("`<name>`'s suggestions"); subtitle
  "N changes overlap with edits you made."
- **Reassurance row:** muted, with a check icon — "M other changes from `<name>` were
  added automatically."
- **One card per overlap:**
  - context label: an icon + what/where, e.g. "Target pace · km 14" or
    "Aid station · km 28 · El Mirador";
  - two equal option rows — `You` (initial, neutral tint) with your value, and
    `<name>` (initial, a second tint) with their value;
  - selection state = 2px ring + check on the chosen row; nothing pre-selected.
- **Footer:** a progress readout ("X of N chosen") on the left; on the right, secondary
  **"Keep my version"** and primary **"Apply changes"** (disabled until X == N).

## 2.5 Behaviour

- **Two explicit exits**, not a bare dismiss:
  - **Apply changes** (enabled once all resolved) → applies the chosen value per
    overlap; race advances to a new version; emits WI-4 changelog entries; merge
    completes.
  - **Keep my version** → rejects the **entire** import; no state change.
- **The close (X) is a synonym for "Keep my version,"** never a third outcome. If the
  user has already made one or more picks, confirm before discarding:
  *"Discard your choices and keep your own version?"* (Q-U4.)
- **Mobile-first:** options stack; never side-by-side columns.
- **Reversible:** applying produces a new version with a changelog entry, so the merge
  is undoable; lean on that rather than warning dialogs.

## 2.6 Acceptance criteria

- Only true overlaps are shown; the count of auto-merged changes is surfaced as
  reassurance.
- Each overlap shows two equal, person-named options with **no pre-selection and no
  red/green**; sides are distinguished by identity, selection by ring + check.
- Apply is disabled until every overlap has a pick; Apply applies the chosen values,
  bumps the version, and writes WI-4 entries.
- "Keep my version" and the close control both reject the whole import with no state
  change; a confirm appears only when picks already exist.
- Labels resolve names (and any role badge) through the WI-5 directory; nothing is
  hardcoded as "coach"/"athlete."
- Each card's data includes its km/location (forward-compat for the course-anchored
  renderer).
- Layout is single-column / mobile-safe.

**Dependencies:** WI-5 (person-named labels, role badge); WI-3 engine (produces the
`Conflict` set and applies the resolved result); emits into WI-4.

---

# Shared open questions

- **Q-I1 — dual-id linking.** Explicit "link this device to `<ownerName>`" action, or
  punt from v1 and rely on adopt-first discipline?
- **Q-I2 — identity store location.** Confirm a device-global identity record separate
  from performance profiles (recommended), and where it lives in IDB.
- **Q-I3 — role badge.** Show a derived "· coach / · athlete" badge via owner-match, or
  go names-only (the documented fallback)?
- **Q-U1 — placement.** Modal (short list) or wide drawer (plan visible behind)?
- **Q-U2 — default stance.** Forced choice per card (recommended) vs pre-select "you".
- **Q-U3 — same-field text overlap.** For a per-km note edited on both sides:
  pick-one, or offer a hand-merge textarea? (Carried from companion-doc Q5.)
- **Q-U4 — confirm-on-dismiss.** Confirm only when picks exist (recommended), and final
  copy.
- **Q-U5 — course-anchored upgrade.** Confirm it's explicitly v2, and that v1 card data
  carries location so the upgrade needs no migration.

---

# Hand-off brief for the project agent

> Read this with `coach-collab-spec.md`; it assumes that doc's engine and the
> *freeze-the-course, merge-the-plan* axiom. Build **WI-5 (identity) first** — WI-3's
> UI and WI-4 depend on it. Promote the WI-5 decisions (§1.2) and the merge-UI reframe
> (§2.2) into the existing or a new ADR as needed, using the "alternatives considered"
> sections (§1.3, §2.3) as the bodies. Then create BACKLOG tasks: WI-5 identity &
> authorship (with the two-mint-points discipline and the `nameUpdatedAt` LWW rule as
> acceptance criteria), the home-view personal/other + filter, and WI-3 · UI
> suggestion-review surface. Resolve Q-I1–Q-I3 before WI-5 implementation and Q-U1–Q-U5
> before the UI. Honor house rules: branch → PR → squash-merge per logical unit;
> commits/PRs under the user's name only; back-compat for `.trail` and IDB via
> `D.oneOf` defaults; model merge and resolution outcomes as types, not runtime failure
> paths; write per-type logic concretely (three reuses before extraction). The entire
> arc is Layer 0 — no backend, offline-capable, accountless; identity is bootstrapped
> peer-to-peer through files, and its ids are claims, not credentials.
