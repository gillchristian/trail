# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Active

### TRACK-000 — Swift/iOS toolchain bootstrap + orientation
**Source:** BACKLOG (epic "Tracker MVP") — the user-requested prerequisite that gates all code.
**Branch:** `track/track-000-swift-ios-bootstrap`
**Decision (ADR-0001):** standard checked-in Xcode project (`.xcodeproj` under `systems/track/`,
created via Xcode's New-Project wizard); **iOS 17.0** deployment target.

**Acceptance criteria:**
- [x] Swift *language* toolchain verified — CLT Swift 5.10 compiles + runs the domain-model spine
  (value types, enum-with-associated-values, `Codable` round-trip). See `reference/local-ci.md`.
- [ ] Full **Xcode** installed; version recorded in `reference/local-ci.md`. *(Blocked — user
  installing; CLT-only today, so no `xcodebuild` / iOS SDK / Simulator.)*
- [ ] A minimal **SwiftUI** app **builds + runs in the iOS Simulator from `systems/track/`** —
  capture the `xcodebuild` output + a `simctl` screenshot.
- [ ] build · run · test commands documented **and verified** in `reference/local-ci.md`.
- [x] ADR records the tooling + deployment-target decision (`decisions/0001-…`).
- [x] Swift/SwiftUI **orientation note** exists (`reference/swift-orientation.md`).

**Notes / phasing** (Xcode is a large install; TRACK-000 is split so the un-blocked half ships value now):
- **Phase A — done, no Xcode needed:** orientation note, ADR-0001, this entry, seeded `local-ci.md`;
  the Swift language toolchain proven against the domain model.
- **Phase B — pending Xcode:** (1) user installs Xcode; (2) user creates the project via the
  New-Project wizard into `systems/track/` (instructions handed off); (3) I scaffold a minimal
  SwiftUI screen, build via `xcodebuild`, run in the Simulator, screenshot, finalize `local-ci.md`,
  journal, then open the PR + squash-merge the **complete** TRACK-000.
- **Do not merge TRACK-000** until the Simulator run is verified (the unchecked AC above).

## Entry template

```markdown
### TRACK-NNN — <title>
**Source:** BACKLOG / user request
**Branch:** track/track-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, decisions while planning.
```
