# Running track on your iPhone (race-day testing)

How to get the **track** app onto your phone for a real race. Written for someone who hasn't
deployed an iOS app before. The app is otherwise ready — icon, microphone prompt, and signing
style are already set up (see *What's already configured* at the bottom).

## TL;DR

For testing your own app on your own phone, the simplest path is **direct install from Xcode with
a free Apple ID** — no $99 developer account, no TestFlight. The one catch: a free account's
install **stops working after 7 days**, so just re-run it from Xcode within a week of the race.

TestFlight *is* an option, but it needs the paid Apple Developer Program ($99/year) and more setup.
Only worth it if you want over-the-air installs (no cable) or builds that last 90 days. For one
race, use the direct path below.

---

## Option A — Direct install from Xcode (free, recommended)

**You need:** your Mac with Xcode, an Apple ID (free is fine), a USB cable, and the iPhone on
iOS 17 or later.

1. **Connect the iPhone** to the Mac with a cable. On the phone, tap **Trust** and enter your
   passcode if asked.
2. **Open the project:** in Terminal, `open systems/track/Track/Track.xcodeproj` (or double-click it
   in Finder).
3. **Pick the destination:** in Xcode's top toolbar, set the scheme to **Track** and the run
   destination (the device dropdown next to it) to **your iPhone** — it appears once the phone is
   connected and unlocked.
4. **Set up signing (one time):** click the blue **Track** project in the left sidebar → select the
   **Track** target → **Signing & Capabilities** tab.
   - Tick **Automatically manage signing**.
   - **Team:** choose your Apple ID. If the list is empty, click **Add an Account…**, sign in with
     your Apple ID, then pick the **"(Personal Team)"** that appears.
   - If you see *"com.gillchristian.Track is not available"* or a bundle-id error, change the
     **Bundle Identifier** to something unique to you, e.g. `com.<yourname>.Track`. (Only affects
     your install.)
5. **Run it:** press **▶** (or ⌘R). Xcode builds, signs, installs, and launches the app on the phone.
6. **Trust the developer (first time only):** if the phone says *"Untrusted Developer,"* go to
   **Settings → General → VPN & Device Management →** tap your Apple ID **→ Trust**. Then tap the
   Track icon to open it.

### The 7-day catch (important)

A free Apple ID signs the app for **7 days**. After that it refuses to open (a vague "cannot verify
app" error). To refresh: plug the phone back in and press **Run** in Xcode again — another 7 days.

➡️ **So: install (or re-install) within 7 days before the race — ideally the day before.** You only
need the Mac + cable for installing, not during the race itself.

*(A paid developer account signs for a full year and removes this catch — see Option B.)*

### Installing over Wi-Fi (optional)

After pairing once via cable, open **Window → Devices and Simulators** in Xcode and tick **Connect
via network**. Then you can Run wirelessly while the phone and Mac are on the same Wi-Fi. Still needs
the Mac, so it's for convenience at home, not at the race.

---

## Option B — TestFlight (needs the paid program, $99/year)

Worth it only if you'll keep iterating for weeks, want builds that last **90 days**, or want to
install **over the air** (no Mac/cable). Rough flow:

1. Enroll in the **Apple Developer Program** at developer.apple.com ($99/year).
2. In **App Store Connect**, create an app record for `com.gillchristian.Track`.
3. In Xcode, set your (paid) **Team** under Signing & Capabilities.
4. **Product → Archive** → in the Organizer, **Distribute App → App Store Connect → Upload**.
5. Wait ~5–15 min for processing, then add yourself as an **internal tester** in App Store Connect.
6. On the phone, install the **TestFlight** app, sign in, and install the Track build.

More steps and a yearly fee — skip it for a single race.

---

## Race-day checklist

- [ ] **Installed/refreshed within 7 days** of the race (free account). Ideally the day before.
- [ ] **Pre-create the race in the app** beforehand: name, aid stations (+ their notes), and the
      palette of things you'll track. Do this while it's a *Configured* race — once you tap **Start**
      the app locks onto the race.
- [ ] **Dry run:** start a throwaway race, tap a few tiles, **record a voice note** (grant the mic
      permission when asked the first time), mark an aid arrival, then **Finish race** and confirm the
      summary + clip playback look right. Delete the throwaway race afterward.
- [ ] **Auto-Lock → Never** (or a long time) for the race: **Settings → Display & Brightness →
      Auto-Lock**. The app is foreground-only — if the screen sleeps the app suspends, so you can't
      record while it's asleep. (Your data is safe regardless — every action is written to disk
      immediately, and reopening the app drops you straight back into the active race.)
- [ ] **Battery:** bring a power bank — screen-on + audio drains it.
- [ ] **Airplane mode is fine** — the app needs no network, and it saves battery.

Reassurance for mid-race: once a race is started you **can't accidentally navigate away**, and if the
phone sleeps or the app gets killed, **reopening it returns straight to the active race**.

---

## What's already configured (you don't need to do these)

- **App icon:** Trail's mountain-peak logo.
- **Microphone:** the permission prompt text is set, so recording works (you'll be asked once).
- **Version** 1.0 (build 1); **deployment target iOS 17.0** — your phone must run iOS 17+.
- **Automatic signing** — you just pick your Team (step 4 above).
- **No network, no GPS, no background mode** — the only permission is the microphone.

## Build/verify commands (for reference)

From `systems/track/Track/`:

```sh
# Confirm it compiles for real-device hardware (without signing — signing is your Team in Xcode):
xcodebuild build -project Track.xcodeproj -scheme Track -sdk iphoneos \
  -configuration Debug -derivedDataPath build-device \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
# → ** BUILD SUCCEEDED **
```

The actual install is done from the Xcode UI (Run), because it needs your Apple ID to sign.
