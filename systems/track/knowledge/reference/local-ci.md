# Local CI / build commands — track

Verification commands for track, run **from the system's own dir** (`systems/track/`). This file
grows as the toolchain lands (TRACK-000 → 001+). Mark each command **verified** (run, output quoted)
vs **pending**.

## Toolchain

- **Platform:** macOS 14.3 (Sonoma), Apple Silicon.
- **Swift (language):** 5.10 via Command Line Tools (`swift --version`). **✅ verified.**
- **Xcode (app):** _not yet installed_ — only Command Line Tools today, so no `xcodebuild` / iOS SDK
  / Simulator. **⏳ pending** (TRACK-000 Phase B). **macOS 14.3 caps Xcode at 15.3** (bundles the
  **iOS 17.4 SDK** — covers our iOS 17 target); Xcode 15.4 / 16.x require macOS 14.5+ and the App
  Store only offers the newest (26.x → macOS 26.2). Install 15.3 via `xcodes install 15.3` or Apple
  Developer Downloads, then record `xcodebuild -version` here.

## ✅ Verified now (CLT Swift, no Xcode)

- **Language smoke** — value types + enum-with-associated-values + `Codable` round-trip (the
  event-log spine): `swift <file>.swift`. Confirmed on 2026-06-25:
  ```
  encoded 2 events → 191 bytes JSON
  decoded 2 events; first kind = raceStarted
  Swift language toolchain OK ✓ (enum-with-associated-values Codable synthesis works)
  ```

## ⏳ Pending Xcode (TRACK-000 Phase B — verify + fill the real names)

Once Xcode is installed and the project exists, run these from `systems/track/` and replace
`<App>` / `<bundle-id>` with the real scheme/bundle id (`xcodebuild -list` shows the scheme;
`xcrun simctl list devices available` shows simulator names — `iPhone 15` assumed below):

```sh
# record the version
xcodebuild -version

# build for the Simulator
xcodebuild build -project <App>.xcodeproj -scheme <App> \
  -destination 'platform=iOS Simulator,name=iPhone 15' -derivedDataPath build

# run it in the Simulator + capture a screenshot (the WI-acceptance proof)
xcrun simctl boot "iPhone 15" 2>/dev/null; open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/<App>.app
xcrun simctl launch booted <bundle-id>
xcrun simctl io booted screenshot knowledge/reference/design/track-001-skeleton.png

# tests (once they exist — WI-2+)
xcodebuild test -project <App>.xcodeproj -scheme <App> \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

> The Simulator needs **no Apple ID / paid account** (unsigned runs are fine). A free Apple ID for
> personal on-device signing only matters when testing on a real iPhone (later).
