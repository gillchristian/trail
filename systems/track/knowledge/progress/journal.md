# Journal

Append-only. Newest at the bottom. Each entry is a snapshot for future-me with no memory of this session.

## Entries

---
## 2026-06-24 — track: scaffolded as a v3 stub (MONO-003)

**Task:** MONO-003 (monorepo) — scaffold the track system as a knowledge-only stub.
**What:** Created `systems/track/` as a v3 knowledge instance (manifest, CLAUDE, skeleton
planning/progress/decisions/whiteboard, a brief). **No code.** `framework/` is the shared root copy
(not duplicated — resolved via Locations). The brief carries the already-designed MVP work-item
sequence + the `.trace`/`.trail` integration-contract pointers (shared `reference/specs/`).
**Next:** await a steer to start track. When picked up: promote item 1 (Skeleton) from the brief's MVP
sequence into `BACKLOG.md` as `TRACK-001`, write acceptance criteria, branch `track/track-001-…`.

---
## 2026-06-25 — track: ingested the MVP spec + seeded the backlog (TRACK-000…010)

**Task:** user request — process the tracker MVP plan + tracking-view spec + the four tab wireframes
and ingest them into track's backlog. Track was a knowledge-only stub (MONO-003); this is the
"pick up track" moment (a planning-seed, not a TRACK-NNN work item itself).

**What:**
- **Lifted the specs into the instance.** Moved the loose repo-root files into `reference/`:
  `tracker-mvp-plan.md` → `reference/mvp-plan.md`, `tracker-tracking-view-spec.md` →
  `reference/tracking-view-spec.md` (dropped the redundant `tracker-` prefix; fixed the 7 internal
  cross-refs between them). Wireframes + Excalidraw source → `reference/design/`
  (`track-{nutrition,aid-stations,others,feed}.webp`, `tracker.excalidraw`); added a wireframes
  pointer in the tracking-view spec.
- **Rewrote `reference/project-brief.md`** from the generic stub 7-step into the real designed MVP:
  pointers to the canonical specs; the load-bearing invariants (no background exec; append-only
  fsync'd log; offline; capture-now-process-later; plan-less-first; projections-not-flags); the
  Swift/SwiftUI + directory-bundle stack; the TRACK-000…010 mapping; the `.trace`/`.trail` deferral;
  and a **Visual design** section (follow Trail).
- **Seeded `planning/BACKLOG.md`** under one epic ("Tracker MVP, 2026-06-25"):
  **TRACK-000** = Swift/iOS toolchain bootstrap (the user's explicit prerequisite; the build owner is
  new to Swift/iOS) — an index-0 foundational task mirroring the repo's MONO-000 precedent, full AC
  inline. **TRACK-001…007** = WI-1…7 (critical path, Active); **TRACK-008/009/010** = WI-8/9/10
  (`.trace` / `.trail` / Live Activity — deferred → parking lot). Full per-WI AC live in
  `mvp-plan.md` §7.
- **Styling steer (user):** track follows Trail's design language (dark-first `#020617`/slate, amber
  `#fbbf24` / race-red `#E52E3A` / green `#22c55e`, race-card feel). Captured in the brief's *Visual
  design* section + the epic header — port the mood into a SwiftUI token layer, not the wireframes'
  sketch chrome (Elm+Tailwind doesn't transfer; the aesthetic does).
- **Refreshed status** STUB → "pre-code (speced + backlogged)" in the system manifest + `CLAUDE.md`;
  pointed `CURRENT.md` at TRACK-000 as next (not started — "ingest into the backlog" was the ask).

**Verified:** docs-only (no code yet). The 7 root artifacts relocated (repo root clean of them); spec
cross-refs resolve to the new filenames; brief/backlog/manifest cross-link consistently. Note the
tracking-view **race-end question (OQ-1) is already resolved** in the spec (Finish-race control in the
AID tab) — TRACK-006 is unblocked on that point.

**Delivery:** branch `track/seed-mvp-backlog` → PR #160 (squash-merge to master).

**Next:** TRACK-000 — install Xcode, get a SwiftUI hello-world running in the Simulator from
`systems/track/`, decide Xcode-project-vs-SPM + the iOS deployment target (ADR), seed
`reference/local-ci.md`. Then TRACK-001 (WI-1 skeleton).

---
## 2026-06-25 — TRACK-000 started: Swift/iOS bootstrap (Phase A done; Phase B blocked on Xcode)

**Task:** TRACK-000 — Swift/iOS toolchain bootstrap + orientation (`CURRENT.md`). Branch
`track/track-000-swift-ios-bootstrap`.

**Environment probe:** macOS 14.3, Apple Silicon. **Only Command Line Tools installed** — `swift`
5.10 is present, but **no full Xcode** → no `xcodebuild`, no iOS SDK, no Simulator (`simctl` missing).
`brew` present; no xcodegen/xcodes/tuist.

**Decision (user · ADR-0001):** standard checked-in Xcode project (created via the New-Project
wizard), not XcodeGen/SPM — chosen for learnability (the build owner is new to iOS). Deployment
target **iOS 17.0** (revisitable; loosening to 16 costs `@Observable`).

**Phase A — done on the branch (no Xcode needed):**
- Verified the Swift *language* toolchain: compiled + ran a domain-model smoke (value types, enum
  with associated values, `Codable` round-trip) with CLT `swift` → passes (output quoted in
  `reference/local-ci.md`).
- Wrote ADR-0001 (+ INDEX), `reference/swift-orientation.md` (an Elm/Go → Swift primer anchored to
  track's domain), seeded `reference/local-ci.md`, and promoted TRACK-000 into `CURRENT.md` with
  phased acceptance criteria.

**Phase B — blocked on the user:** install Xcode (large App Store download), then create the project
via the wizard into `systems/track/`. Then I scaffold a minimal SwiftUI screen, build via
`xcodebuild`, run in the Simulator + screenshot, finalize `local-ci.md`, journal, and PR +
squash-merge the **complete** TRACK-000. **Not merging until the Simulator run is verified.**

**Next:** await "Xcode installed + project created," then Phase B (exact install + wizard steps
handed to the user).
