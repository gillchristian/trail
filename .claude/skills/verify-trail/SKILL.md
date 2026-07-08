---
name: verify-trail
description: Verify a trail (systems/trail) change before declaring it done — run the recorded local-CI aggregate end-to-end and apply the manual-smoke obligations. Use when finishing any task that touches systems/trail code, build config, or dependencies.
---

# Verifying a trail change

`systems/trail/knowledge/reference/local-ci.md` is the authority this skill
defers to — commands live only there. If this file and `local-ci.md` disagree,
`local-ci.md` wins and this skill needs a `MONO-` fix.

1. From `systems/trail/`, run the recorded aggregate and quote its exit code:

   ```sh
   npm run ci
   ```

   Type-check → production build → every smoke harness; exit 0 required.
   This is what verification gates 5 and 8 (framework `verification.md`)
   feed on.

2. The aggregate covers the gate table, **not the manual smoke**: where the
   task touched UI behavior, apply verification gates 2–3 — run the actual
   app against the change and observe it, per the manual-check notes
   `local-ci.md` records. If the environment cannot drive a browser, say so
   explicitly in the journal entry rather than fake-verifying (the recorded
   browser-drive procedure is trail's TASK-072, still parked).

3. Quote real output in the journal and PR. "Compiles" is not "works"
   (verification gate 3).
