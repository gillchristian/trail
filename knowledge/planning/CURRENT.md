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

### TASK-051 — WI-4: change-history feed (drawer)

**Source:** BACKLOG (coach-collab epic, spec §5) — user picked it next
(2026-06-16), with 3 Tailwind-UI feed refs for inspiration + gamified styling.
**Branch:** feat/task-051-history-feed
**Design (with user):** feed lives in a right-side **drawer**; open button is a
right-aligned link on the race-page header row, mirroring "← Back to races"
styling (icon + "Activity" + count). Timeline + colored circular icon badges
(trail's badge DNA), gamified dark styling — not a flat copy of the refs.
**Acceptance criteria:**
- [x] New pure `Changelog` module: two-way `diff` + `union` + entry constructors;
  the typed `ChangeDescriptor`/`ChangeEntry` + codecs live in `Types` (so `Race`
  can hold them without an import cycle). Verified `smoke:changelog` (every
  descriptor kind, codec round-trip, union dedupe).
- [x] `Race` gains `history : List ChangeEntry` (codecs, `.trail` carries it,
  oneOf default []); new races seed a `CourseUploaded` entry (`buildDraftRace`).
- [x] Local edits log via `commitRaceEdit` (diffs before→after) at the
  `saveRaceMeta` edit sites; empty diff → no entry (target/slider/actualSplits
  don't spam). author = deviceId, ts = now; echo carries history back. Verified
  type-check/build + reasoning; **pending user in-browser**.
- [x] Drawer UI (right slide-over, gamified `trail-drawer-in`) renders the
  history as a timeline w/ per-type colored badges + author/relative-time;
  "Activity" button (+ count) on the header row mirroring the back link.
  Verified type-check/build; **pending user in-browser**.
- [x] All 9 gates green incl. `smoke:changelog`; type-check `Success!` + build
  `✓ built`.
**Notes:** `diff` only emits the spec taxonomy (aids, km note/pace, name, date) —
target-time/slider + location/url/notes changes produce no descriptor, so the
feed isn't spammed by exploratory slider moves. Merge entries (`Merged`) plug in
with TASK-052. `describe`/styling per descriptor lives in the Main view; the
`Changelog` module stays pure data + diff.

---

_(paused note below TASK-051. Coach-collab arc core shipped and green:
**TASK-046** (brief) ✓, **047** WI-1 identity/guard ✓, **048** WI-2 course freeze
✓, **049** fork-safe aid ids ✓, **050** WI-3 merge **engine** ✓ — ADRs 0009/0010/0011,
gates `smoke:trailsync` + `smoke:merge`.

**Why paused (not blocked-by-effort):** the two remaining items are a different
verification class — their value is interactive **browser** behavior I can't drive
headlessly, and TASK-052's base/version orchestration is stateful distributed
logic where "it compiles" ≠ "it's correct." Shipping them compile-only would be
"should-work code I haven't run" (`when-stuck.md`). They're fully specced + ADR'd,
ready to resume:
- **TASK-052** — WI-3 part 2: merge integration + dedicated review UI (persist
  `mergeBase`+`version`, `.trail` carries `{base,current,version}`, bump on edit,
  import→merge entry point, review screen). Q2–Q5 already resolved.
- **TASK-051** — WI-4: structured change-history feed.

**Recommended in-browser checks** (headless env can't do them):
- **Coach-collab arc:** upload a GPX → export `.trail` → confirm it carries
  `shareId` + `courseHash` (v2); a v1 `.trail` still imports; add an aid →
  device-tagged id.
- **Standing (pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview;
  TASK-045 section table/card with a linked actual.)_

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
- **After TASK-046:** the epic continues with TASK-047 (WI-1), where **Q1**
  (courseHash input + mismatch behavior) must be resolved with the user first.
