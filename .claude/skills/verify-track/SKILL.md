---
name: verify-track
description: Verify a track (systems/track) change before declaring it done — run the recorded verify script (pinned simulator destination, captured-output check, test-floor ratchet) and apply the build/manual obligations. Use when finishing any task that touches systems/track code or project config.
---

# Verifying a track change

`systems/track/knowledge/reference/local-ci.md` is the authority this skill
defers to — commands live only there. If this file and `local-ci.md` disagree,
`local-ci.md` wins and this skill needs a `MONO-` fix.

1. Run the recorded script and quote its final line:

   ```sh
   bash systems/track/scripts/verify.sh
   ```

   Pinned simulator destination, captured-output check for
   `** TEST SUCCEEDED **`, and the test-floor ratchet `local-ci.md` records
   (floors bump in the same PR that adds tests). Exit 0 required.

2. The script covers the **test** gate only. Where the task touches signing,
   entitlements, or device behavior, apply `local-ci.md`'s build-only and
   signed device-build checks (the TRACK-012 lesson: no-signing builds cannot
   catch signing issues). Where it touches UI the suite can't drive (share
   sheet, audio, `.fileImporter`), do the recorded manual simulator check and
   screenshot it into `reference/design/`.

3. Read status from the captured log, never from a filtered pipeline's exit
   code, and quote real output in the journal and PR (verification gate 3).
