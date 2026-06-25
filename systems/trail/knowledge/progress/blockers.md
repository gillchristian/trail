# Blockers

Things that genuinely require user input to resolve. Surface these at the very top of any handoff or end-of-session summary.

If this file has entries, **the user needs to see them** as soon as they're back.

## Format

```
## BLOCKER-NNN — short title — opened YYYY-MM-DD HH:MM

**Task affected:** TASK-NNN
**What I tried:** brief list.
**What I observed:** facts only, no speculation about cause unless flagged as such.
**What I currently believe:** my best guess at the underlying issue.
**What would unblock me:** the specific input/decision/access I need.
**Workaround in place:** what I did instead in the meantime (if anything).
```

## Open

_(none)_

## Resolved

## BLOCKER-001 — Deploy gateway to fly.io (MONO-002) — opened 2026-06-24 · resolved 2026-06-24
**Resolution:** user ran `fly deploy systems/gateway` — deploy succeeded, `/` healthy, the `data` volume / `tokens.db` intact (not recreated), and the cadence frontend kept working against the newly deployed server. The flattened-gateway Dockerfile/fly.toml cutover (app stays `cadence`) is live.

## BLOCKER-002 — Re-point cadence's Vercel project (MONO-002) — opened 2026-06-24 · resolved 2026-06-24
**Resolution:** user re-pointed the cadence Vercel project's Git connection → `gillchristian/trail`, Root Directory `systems/cadence/`. (Worth a glance that the Vercel build is green + the Strava redirect/domain/env survived — local `npm run build` is green, so it should follow.)
