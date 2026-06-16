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
**Branch:** ships as per-slice PRs (pure-core-first). **Slice 1 ✓ PR #109 · Slice 2 ✓ PR #110**; slices 3–4 next.
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
3. **Slice 3 — IDB identity store + boot** *(browser-verified)*: the dedicated `identity` store (DB v3→v4) + `Storage` ports + `main.js` handlers; load `me : Maybe Me` + `directory` into the model at boot; `.trail` name (`people`) denormalization + import-merge into the directory. Store mechanics → `smoke` (fake-indexeddb); real boot → browser.
4. **Slice 4 — flows** *(browser-verified)*: export-mint name prompt; import yourself/someone-else (adopt / mint / review); `owner` backfill on touch/export; the **Q-I1 link action**; `resolveName` wired into labels.

**Progress (2026-06-16):** slices 1–2 shipped + fully headless-verified (all 8 smokes green). Inert at runtime by design (deferred-mint: `me`/owner appear only at first share); slices 3–4 make it live and need in-browser verification (IDB upgrade, boot, prompts, link action) — like the WI-4 feed.

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
