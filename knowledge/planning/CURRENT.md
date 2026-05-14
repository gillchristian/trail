# Current task

## TASK-001 — Scaffold the Elm + Vite + Tailwind app

**Pulled from backlog:** 2026-05-15 00:15
**Why this now:** First task. Nothing else can land until the project compiles.

### Acceptance criteria
- [ ] `package.json`, `vite.config.js`, `elm.json`, `index.html`, `src/main.js`, `src/styles/app.css` exist.
- [ ] Dependencies installed; `npm run dev` starts a Vite server without errors.
- [ ] Tailwind v4 is active — a Tailwind utility class on a visible element produces the expected style.
- [ ] `src/Main.elm` compiles and renders a placeholder home page ("Trail — load a GPX") with the Tailwind-styled shell visible.
- [ ] `src/Gpx.elm` is lifted from `../crest/src/Gpx.elm` verbatim (same module, same API).
- [ ] User can click a "Load GPX" button, pick a file, and the app shows: track name, total distance, gain, loss — proving `Gpx.parseGPX` works end-to-end.
- [ ] `npm run build` succeeds.
- [ ] Branch `feat/task-001-scaffold` opened, PR opened with the template, PR squash-merged into `master`. Branch deleted.
- [ ] `planning/CURRENT.md` cleared, `DONE.md` updated, journal entry written.

### Plan
1. Branch off `master`.
2. Copy `vite.config.js`, `package.json`, `index.html`, `elm.json` from crest as starting points; rename / strip down.
3. Drop in `src/Main.elm` with Empty/Parsing/Failed/Loaded state — file picker only, no fancy rendering yet (we'll port crest's profile rendering in TASK-004).
4. Lift `src/Gpx.elm` verbatim.
5. Set up Tailwind v4 entry (`src/styles/app.css` with `@import "tailwindcss";` and the Vite plugin in `vite.config.js`).
6. Verify dev server, run end-to-end smoke test (load `samples/20k_oh_meu_deus.gpx`, see distance/gain/loss).
7. Verify `npm run build`.
8. Open PR; merge.

### Verification plan
- `npm run dev` boots; visit `http://localhost:5173`; click "Load GPX"; pick `samples/20k_oh_meu_deus.gpx`; observe stats. Quote the numbers in the journal.
- `npm run build` exits 0. Quote summary line.
- `elm make src/Main.elm --output=/dev/null` (or via vite-plugin-elm during build) → no errors.
- PR URL captured.

### Notes during execution
_(append as I go)_

### Done
_(filled when all gates pass)_
