# Current task

> One task at a time. When this file is empty, pull the next item from `BACKLOG.md`.

## Entry template

```markdown
### TASK-NNN — <title>

**Source:** BACKLOG / parking lot / user request
**Branch:** <kind>/task-NNN-<slug>
**Acceptance criteria:**
- [ ] criterion (how it will be verified)
**Notes:** scope cuts, links, anything decided while planning.
```

### TASK-057 — Fix Vercel build: declare `elm` as an npm dependency

**Source:** user request (preparing the app for Vercel deployment, 2026-06-18)
**Branch:** fix/task-057-vercel-elm-dependency
**Problem:** Vercel's `npm run build` fails with `spawn elm ENOENT`. `vite-plugin-elm`
→ `node-elm-compiler` spawns a bare `elm` binary from `PATH`; it's never declared
as a dependency, so a clean `npm install` doesn't provide it. It only worked
locally because the user has a global elm (`~/.yarn/bin/elm`). Reproduced locally
on a PATH with no global elm — identical `spawn elm ENOENT`.
**Acceptance criteria:**
- [ ] `elm` declared in `devDependencies` (pinned `0.19.1-6`, the `latest` tag wrapping the 0.19.1 compiler) so a clean install drops the binary in `node_modules/.bin/` (verify: `node_modules/.bin/elm --version` → `0.19.1`).
- [ ] `npm run build` succeeds on a PATH with **no** global elm (Vercel-equivalent) and emits `dist/` (verify: clean-PATH build → `dist/index.html` + hashed assets).
- [ ] Full local CI green from a clean `npm ci` with no global elm — type-check + build + all 8 smoke harnesses — proving the harnesses (which call `npx --no-install elm`) are now hermetic and no longer need a global elm.
- [ ] `reference/local-ci.md` Prerequisites corrected: elm is now an npm dep; `npm install`/`npm ci` provides it (the old "install Elm globally, npm won't provide it" note is now false).
**Notes:** Scope is the missing compiler dependency only. No `vercel.json` needed —
the router is hash-based (`Route.elm`: "works as a static bundle without
server-side rewrites"), so Vite's default `dist/` static output is enough.
Frontend↔backend wiring (set `VITE_BACKEND_URL`; on cadence add the Vercel origin
to CORS + set `FRONTEND_URL_TRAIL`) is deployment config, not a code change —
tracked separately. Observed but out of scope: Vercel ran the build on Node
v24.15.0 while `.nvmrc`/dev pin to v22 — consider an `engines.node` pin as a
follow-up (not required for the build to pass).

---

### (backlog context — no queued task)

The **coach-collaboration arc is complete** (2026-06-17): TASK-046–051, 053, 054,
055, 056 all shipped + verified. The active BACKLOG queue is exhausted. Pull the
next item only on a fresh steer from the user — the candidates are the **parking
lot** (light/dark toggle, multi-language, GAP descent slider, per-km gain/loss
for the slope factor) and roadmap §7's remaining calibration fits, none of which
is prioritized. **Calibration stays paused** (user, 2026-06-15). Do **not**
auto-promote a parking-lot item; surface options and let the user choose.

---

**Arc state (2026-06-17):** **coach-collaboration arc COMPLETE.** WI-1 (TASK-047),
WI-2 (048), aid-id (049), WI-3 engine (050), WI-4 feed (051), backfill (053),
WI-5 identity (054), home owner view (055), and WI-3·UI merge integration + review
modal (056) all shipped. ADRs 0009–0013. The whole flow — share a `.trail`,
annotate it, import it back, three-way-merge with a person-named review surface —
is live and user-verified in-browser.

**Recommended in-browser checks (standing, pre-arc):** TASK-040 IDB round-trip; TASK-042 print preview; TASK-045 section table/card with a linked actual.

---

## Standing reminders (not active tasks)

- **Calibration is paused (user, 2026-06-15).** The two core continuous rates
  shipped (TASK-043 vmh, TASK-044 flat pace); the harder roadmap §7 fits
  (descent / fatigue / Riegel / sustainable-HR / decoupling) stay queued —
  promote only on a fresh go-ahead.
- **Three manual checks recommended** (headless env can't do them): browser
  round-trip after the TASK-040 IDB migration; print-preview of the TASK-042
  table; section table/card with a **linked actual** for TASK-045 (clock Time,
  Actual − Time = Δ, monotonic Cum ending at total clock).
- **Coach-collab arc: COMPLETE** (2026-06-17). All work items shipped + verified
  (TASK-046–051, 053–056; ADRs 0009–0013). Nothing outstanding in the arc.
