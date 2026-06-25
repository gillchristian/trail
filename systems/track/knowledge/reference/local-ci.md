# Local CI / build commands — track

Verification commands for track. The Xcode project lives at `systems/track/Track/` — run the
`xcodebuild`/`simctl` commands from there. Mark each **verified** (run, output quoted) vs **pending**.

## Toolchain (verified 2026-06-25)

- **Platform:** macOS 14.3 (Sonoma), Apple Silicon.
- **Swift (language):** 5.10 via Command Line Tools. **✅**
- **Xcode:** **15.3 (15E204a)** — `xcode-select -p` → `/Applications/Xcode.app/Contents/Developer`;
  **iOS 17.4 SDK** + **iOS 17.4 simulator runtime** (21E213). *macOS 14.3 caps Xcode at 15.3* (15.4 /
  16.x need 14.5+; the App Store only offers the newest, 26.x → macOS 26.2), so 15.3 came from Apple
  Developer Downloads; the simulator runtime is a separate ~7 GB `xcodebuild -downloadPlatform iOS`.
- **Project:** standard Xcode project (ADR-0001) at `Track/Track.xcodeproj`; scheme **`Track`**;
  bundle id **`com.gillchristian.Track`**. Deployment target = wizard default **17.4**; **TRACK-001
  pins it** per ADR-0001.

## ✅ Verified — Swift language smoke (no Xcode)

Value types + enum-with-associated-values + `Codable` round-trip (the event-log spine):
`swift <file>.swift` → `encoded 2 events → 191 bytes JSON` / `decoded 2 events` (2026-06-25).

## ✅ Verified — build + run in the iOS Simulator

Run from `systems/track/Track/`. Exact flow used for TRACK-000 (screenshot:
`../knowledge/reference/design/track-000-hello-simulator.png`):

```sh
# build for the Simulator (universal arm64+x86_64; no signing needed for the simulator)
xcodebuild build -project Track.xcodeproj -scheme Track \
  -sdk iphonesimulator -configuration Debug -derivedDataPath build CODE_SIGNING_ALLOWED=NO
# → ** BUILD SUCCEEDED **   (product: build/Build/Products/Debug-iphonesimulator/Track.app)

# boot a simulator (the default device set is created with the runtime; name or UDID both work)
xcrun simctl bootstatus "iPhone 15" -b && open -a Simulator

# install + launch + screenshot
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Track.app
xcrun simctl launch booted com.gillchristian.Track
xcrun simctl io booted screenshot shot.png
```

> `build/` + Xcode per-user state are gitignored (`systems/track/.gitignore`). The Simulator needs
> no Apple ID. Tests run with the first real suite (WI-2):
> `xcodebuild test -project Track.xcodeproj -scheme Track -destination 'platform=iOS Simulator,name=iPhone 15'`.
