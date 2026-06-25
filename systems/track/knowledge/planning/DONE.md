# Done

Tasks that passed all verification gates. Newest at top.

Each entry: id, title, completion date, a summary, the PR number + merge sha, and a journal pointer.

## Completed

### TRACK-000 — Swift/iOS toolchain bootstrap + orientation
**Completed:** 2026-06-25 · **PR:** #161 (squash-merged) · **Journal:** 2026-06-25 "TRACK-000 COMPLETE".
The build owner's first Swift/iOS setup. Installed Xcode 15.3 (the ceiling on macOS 14.3) + the iOS
17.4 SDK & simulator runtime; created a standard Xcode project (ADR-0001) at `Track/` (scheme
`Track`, bundle `com.gillchristian.Track`); a Trail-themed SwiftUI smoke screen that **builds + runs
in the iOS Simulator** (screenshot: `reference/design/track-000-hello-simulator.png`). Shipped the
Swift/SwiftUI orientation note (`reference/swift-orientation.md`) and a verified
`reference/local-ci.md`. Deployment-target pinning deferred to TRACK-001 (WI-1 scope).
