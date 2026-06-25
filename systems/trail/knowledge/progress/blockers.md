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

## BLOCKER-001 — Deploy gateway to fly.io (MONO-002) — opened 2026-06-24
**Task affected:** MONO-002
**What I need:** run `fly deploy systems/gateway` (fly app `cadence`, unchanged) and confirm `/` health is OK and the `data` volume + `tokens.db` are **intact** (NOT recreated — losing the volume drops live Strava tokens). The image builds locally from the `systems/gateway` context (`docker build` green), so it's a straight cutover.
**What I observed:** Dockerfile + fly.toml de-`server/`-ed; `dockerfile = 'Dockerfile'`, app stays `cadence` (renaming would orphan the volume — Locked decision 7).
**Why it's yours:** deploys are manual by decision (Locked decision 15); I don't deploy autonomously.
**Workaround in place:** none needed — the repo work is landed on `master`; this is the live cutover.

## BLOCKER-002 — Re-point cadence's Vercel project (MONO-002) — opened 2026-06-24
**Task affected:** MONO-002
**What I need:** in the **cadence** Vercel project, re-point the Git connection → this monorepo (`gillchristian/trail`) and set Root Directory → `systems/cadence`. Confirm the build goes green and the Strava redirect URL + custom domain + env vars (esp. `VITE_API_URL` → gateway) survive the re-point.
**What I observed:** cadence's frontend is landed at `systems/cadence/` and builds locally (`npm run build` green, 720 modules). The old cadence repo is now superseded.
**Why it's yours:** a Vercel dashboard / Git-connection step I can't perform.
**Workaround in place:** none — purely the deploy re-point.

## Resolved

_(none)_
