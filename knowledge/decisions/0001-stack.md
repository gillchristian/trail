# 0001 — Stack: Elm 0.19 + Tailwind v4 + Vite

**Date:** 2026-05-15
**Status:** accepted

## Context

The user explicitly offered the choice between **React + TypeScript** and **Elm**, with a stated preference for Elm if the language could carry the "if it compiles it works" philosophy across the whole app. A working Elm prototype already exists at `../crest` (Elm 0.19.1, Tailwind v4 via Vite, `vite-plugin-elm`, ~500-line `Main.elm`, custom SVG rendering, regex GPX parser, Haversine, iterative Douglas-Peucker, gain/loss with 2m noise threshold). The prototype is the exact "true 1:1 elevation profile" we need for feature #4.

## Decision

Use **Elm 0.19.1** as the application language, **Tailwind v4** for styling, **Vite 6** as the build tool, and **`vite-plugin-elm`** for the integration. Reuse `Gpx.elm` from `../crest` verbatim. Use plain JS ports for the few unavoidable side-effects: IndexedDB, service worker registration, file picker fallbacks if needed, and (later) the Leaflet map view.

## Alternatives considered

- **React + TypeScript.** Bigger ecosystem (react-leaflet, framer-motion, dozens of GPX parsers). But the user's "if it compiles it works" requirement is a much stronger guarantee in Elm than in TS — even strict TS lets `any`/`as`/runtime nulls slip through. Rejected on language ergonomics relative to the user's stated philosophy.
- **Elm Land / Lamdera / Other Elm frameworks.** User explicitly said no Elm Land. Rejected.
- **Pure TypeScript with a discriminated-union-heavy style.** Closer to Elm's ergonomics than React-with-classes, but still doesn't catch the same class of bugs (exhaustive pattern matching, no nulls, no runtime exceptions in pure code). Rejected.

## Consequences

**Easy now:**
- Reuse of `Gpx.elm` (parsing + DP + haversine + gain/loss) saves a significant chunk of work and is already proven on UTMB-sized inputs.
- Single-source-of-truth `Model` with custom types makes impossible-states-impossible enforceable by the compiler.
- Refactors are cheap — change a type, the compiler enumerates everywhere you need to update.
- No `package-lock.json` churn beyond the vite dev-deps; Elm packages versioned in `elm.json`.

**Hard later:**
- Maps. Elm has no first-class Leaflet wrapper. We'll need a small JS port (`mapboxgl-ports.js`-style) that holds the imperative map and accepts commands from Elm. This is why map view is the *last* feature.
- Animations beyond Tailwind's CSS animations require care. View transitions / per-element entry animations work fine via Tailwind classes + a few `Browser.Events.onAnimationFrame` ticks where strictly needed. We will not pull in any animation lib.
- IndexedDB has to go through ports (no Elm package matches IDB's full surface). The port is small and standard; not a concern.
- Onboarding cost for collaborators if any join later. Mitigated: the codebase will be small and readable.

## Folder layout (this commit and onward)

```
.
├── CLAUDE.md
├── README.md                    (added when the app's actually usable)
├── elm.json
├── package.json
├── vite.config.js
├── index.html
├── public/
│   └── (icons, manifest, sw.js when offline-first lands)
├── src/
│   ├── Main.elm                 (root component, router)
│   ├── Gpx.elm                  (lifted from crest; same module)
│   ├── Types.elm                (shared types: Race, Plan, Km, AidStation)
│   ├── Storage.elm              (IDB facade — talks to JS via ports)
│   ├── Pace.elm                 (GAP distribution — see ADR-0003)
│   ├── Pages/
│   │   ├── Index.elm            (race grid)
│   │   ├── Race.elm             (single-race dashboard)
│   │   ├── Profile.elm          (true-1:1 elevation view)
│   │   └── Plan.elm             (per-km card + table view)
│   ├── Ui/
│   │   ├── Button.elm
│   │   ├── Badge.elm            (aid-station badge)
│   │   └── Card.elm
│   ├── styles/
│   │   └── app.css              (Tailwind + a few custom utility layers)
│   └── ports.js                 (IDB, file APIs, SW registration)
├── tests/                        (elm-test, if/when added)
├── samples/                      (input fixtures — already exists)
└── knowledge/
```
