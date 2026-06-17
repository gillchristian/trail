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

### TASK-054 — WI-5: identity & authorship (foundation)

**Source:** BACKLOG (coach-collab arc, companion spec Part 1)
**Branch:** ships as per-slice PRs (pure-core-first). **Slice 1 ✓ #109 · Slice 2 ✓ #110 · Slice 3 ✓ #112**; slice 4 (flows) next.
**Decisions:** ADR-0012 — **Q-I1** *build the explicit link action* · **Q-I2** *dedicated IDB store* · **Q-I3** *names-only* (user, 2026-06-16).

**Acceptance criteria:**
- [ ] Stable `userId` (UUID v4) minted at **exactly two points** — first export w/ no identity; import-as-someone-else w/ no identity — and **never** on the "yourself" path (which adopts the file's owner id). *(Smoke the mint/adopt decision fn; trace the two sites.)*
- [ ] `me = {userId, displayName}` persists in a **dedicated IDB store** (DB-version bump + migration), distinct from `AthleteProfile.Profile`. *(Manual: store created on upgrade; `me` survives reload.)*
- [ ] Races persist `owner : userId`; a race with no `owner` adopts `me` on first touch. Names live only in the directory + denormalized in `.trail`. *(Smoke codec + owner default.)*
- [ ] Directory `{ [userId]: {displayName, nameUpdatedAt} }` resolves all name display; rename = one row, all owned races relabel with no per-race write. *(Manual: rename → relabel.)*
- [ ] `.trail` denormalizes the `(userId, displayName, nameUpdatedAt)` pairs it references. *(Smoke codec round-trip.)*
- [ ] Import branches: `file.owner.userId == me.userId` → **no prompt**; owner ≠ me → prompt yourself/someone-else (*yourself* **adopts** the file's owner id; *someone-else* w/ no identity chains a name prompt + mints). *(Manual: 3 branches.)*
- [ ] Name **LWW**: a name applies only when incoming `nameUpdatedAt` is newer; an older file never reverts a name. *(Smoke the LWW register.)*
- [ ] **Q-I1 link action:** explicit *"this device is already `<name>` — link to `<ownerName>`?"* reconciles a dual-id (mint-then-import-own-older). *(Manual.)*
- [ ] Back-compat: pre-identity `.trail` + IDB records decode via `D.oneOf` defaults. *(Smoke decoders; manual load of a pre-WI-5 race.)*

**Implementation plan — pure-core-first, mirroring the TASK-050/052 split (verifiability):**
1. ✓ **Slice 1 — pure `Identity` core** (PR #109): types + name-LWW register + the mint/adopt **decision** as pure fns + `subsetFor` + codecs; new `smoke:identity` (21 checks). Headless-verified; no existing code touched.
2. ✓ **Slice 2 — `owner` on Race** (PR #110): `owner : String` (a userId) + encoder + `decodeRace` back-compat default + `buildDraftRace` seed; `smoke:trailsync` owner round-trip/default checks. Headless-verified; rides `encodeRace` so the `.trail` carries it.
3. ✓ **Slice 3 — IDB identity store + boot** (PR #112): the dedicated `identity` store (DB v3→v4) + `Storage` ports + `main.js` handlers; `me : Maybe Me` + `directory` loaded into the model at boot. Headless-verified (storage smoke: v4 store + bundle round-trip + v3→v4 migration); real boot = the user's browser check. (`.trail` `people` denormalization moved to slice 4, where the import flow consumes it.)
4. **Slice 4 — flows** *(browser-verified — IN PROGRESS, branch `feat/task-054-identity-flows`)*: export-mint name prompt; import yourself/someone-else (adopt / mint / review); `owner` backfill on touch/export; the **Q-I1 link action**; `.trail` `people` denormalization + import-merge; `resolveName` wired into labels (changelog author, owner display).

   **Slice-4 design decisions (recorded before coding, 2026-06-17):**
   - **UUID mint via flags, not a port.** A fresh `newUserId` (JS `crypto.randomUUID()`) rides in `flags` alongside `deviceId`; Elm consumes it only at a mint point. Correct because `me` mints **at most once per device** (both mint points gate on `me == Nothing`), so a per-boot candidate is consumed ≤ once. Keeps the whole mint flow *synchronous in Elm* — no async port round-trip, less compile-only surface. Mirrors the existing `deviceId`-via-flags pattern.
   - **Prompt state machine** (`identityFlow`): `FlowIdle | FlowName PendingAfterName | FlowOwnership PendingImport | FlowLink PendingImport`. Import decode *pauses* into a prompt (carrying the decoded draft + the file's denormalized `people` + resolved owner name); the race is saved only on confirm, so **cancel = no state change** (the file's people are merged into the directory only on completion, never on cancel).
   - **Q-I1 link = re-own.** "Yourself" with an existing different identity (the dual-id case) → explicit link confirm → adopt the file's owner id as `me.userId` **and migrate local races owned by the old id → new id** (bounded; else your own old races would read as someone-else's). Plain *adopt* (no link) only when `me == Nothing`.
   - **`authorId : UserId` on `ChangeEntry`** (additive, defaults `""`): the changelog `author` stays `deviceId` (entryId uniqueness — ADR-0012), and `authorId` carries the *person* for person-named feed labels. Legacy/`""` entries fall back to the device comparison (→ "You"). This is what lets the feed drop the seat-relative "Coach" label (the bug WI-5 fixes).
   - **`.trail` `people`** = `Identity.subsetFor (owner :: authorIds) directory` embedded by `ProjectFile.encode`; `decode` returns `(Race, Directory)`; import LWW-merges it. `ProjectFile`/`TrailSyncHarness` signatures change accordingly.
   - **Surfaces:** name prompt + ownership + link modals (alongside the delete/history modals); a clearly-separated **Identity card** on `#/profile` (rename = one directory row, authoritative `Dict.insert`); **owner display** ("Plan by `<name>`") on the race detail, resolving `race.owner` through the directory (demonstrates rename → relabel with no per-race write). `model.now` (frozen boot time, as the changelog already uses) supplies `nameUpdatedAt`/timestamps.
   - **Verification:** all headless gates green, then **hand to the user for in-browser verification before merge** (prompts, IDB writes, owner stamping, the link action, person-named feed) — the unverifiable-by-me UI case, as TASK-051 was.

**Progress (2026-06-17):** slices 1–3 shipped + headless-verified (all 8 smokes green; DB now v4 with the identity store). Still inert at runtime by design (deferred-mint: `me`/owner appear only at first share) — **slice 4 makes it live + visible** and needs in-browser verification (the prompts, owner stamping, names, the link action), like the WI-4 feed. UX is specced in companion §1.4 + the prototype; will draft and the user verifies in-browser.

**Notes:** `userId` layers **over** the existing `deviceId` — do **not** remove `deviceId` or re-key `entryId`/the version vector by `userId` (ADR-0012 grounding). Home view (TASK-055) consumes `owner` but is a separate task. No role badge (Q-I3).

---

**Arc state (2026-06-16):** companion spec ingested (#104) → TASK-052 dropped, folded into TASK-056 (#106) → Q-I1–Q-I3 resolved + **ADR-0012**. Build order **TASK-054 → TASK-055 → TASK-056 (last)**. Done: TASK-046–051, 053 ✓.

**Recommended in-browser checks (standing, pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview; TASK-045 section table/card with a linked actual.

---

## Standing reminders (not active tasks)

- **Calibration is paused (user, 2026-06-15).** The two core continuous rates
  shipped (TASK-043 vmh, TASK-044 flat pace); the harder roadmap §7 fits
  (descent / fatigue / Riegel / sustainable-HR / decoupling) stay queued —
  promote only on a fresh go-ahead.
- **Three manual checks recommended** (headless env can't do them): browser
  round-trip after the TASK-040 IDB migration; print-preview of the TASK-042
  table; section table/card with a **linked actual** for TASK-045 (clock Time,
  Actual − Time = Δ, monotonic Cum ending at total clock).
- **Coach-collab arc:** engine + feed shipped (TASK-046–051, 053). Now in the
  identity/UI strand — TASK-054 (WI-5) active; then TASK-055 (home), TASK-056
  (merge UI, last). **Q-U1–Q-U5 gate TASK-056** — resolve with the user before
  that surface.
