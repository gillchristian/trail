# 0001 — iOS project tooling & deployment target
**Date:** 2026-06-25 · **Status:** accepted

## Context

TRACK-000 bootstraps the toolchain for track, a native **SwiftUI iOS** app. The build owner is new
to Swift and to iOS development, works **solo**, and most plumbing is **agent-driven** inside a
monorepo that prizes "each system builds from its own dir." Two foundational choices gate WI-1:
**how the Xcode project is defined** (the app container), and the **minimum iOS version**. An iOS
*app* target (app bundle, `Info.plist`, Simulator destination, signing) needs an Xcode project —
plain SwiftPM targets libraries/CLIs cleanly but not an app bundle.

## Decision

1. **Standard checked-in Xcode project.** A normal `.xcodeproj` created with Xcode's
   *New Project ▸ iOS App (SwiftUI)* wizard, committed under `systems/track/`. The user runs the
   wizard once; the agent drives all Swift code and `xcodebuild`/`simctl` after.
2. **Deployment target: iOS 17.0.** Buys the modern SwiftUI surface (`@Observable`/Observation,
   `NavigationStack`, current `simctl`/Xcode 15 defaults) with no exotic dependencies.

## Alternatives considered

- **XcodeGen** (`project.yml` checked in, `.xcodeproj` generated + gitignored). Git-clean and fully
  agent-scaffoldable. *Rejected for now:* an extra tool + an indirection that no iOS tutorial shows,
  which fights the owner's learn-iOS goal; the pbxproj git-noise it solves doesn't bite a solo repo
  (rule of three — revisit when a 2nd committer or CI appears).
- **SwiftPM only** (`Package.swift`). Cleanest text + `swift build/test`. *Rejected:* awkward for an
  iOS app bundle / Simulator run.
- **SwiftPM core library + thin Xcode app shell.** The pure domain/persistence logic (WI-2) as an
  SPM package the app depends on — enables `swift test` of projections/folds **without a Simulator**.
  *Deferred, not rejected:* the likely evolution once WI-2's logic exists and wants fast unit tests;
  premature on day zero (`working-style.md`: three usages before extracting).

## Consequences

- **Easy:** tutorial-/Xcode-aligned (open-and-go), Xcode manages the bundle + signing, lowest
  friction for a newcomer; the Simulator needs no Apple ID (on-device signing is a later concern).
- **Hard / watch:** `project.pbxproj` is noisy in git and fragile to hand-edit — **mitigation:**
  minimise direct pbxproj edits (add files via Xcode or regenerate), keep the app a thin shell.
  **Revisit XcodeGen** if pbxproj churn bites or a second committer/CI lands. iOS 17 floor excludes
  pre-17 devices — fine for a personal dogfood app; loosening to iOS 16 costs `@Observable` (fall
  back to `ObservableObject`).
