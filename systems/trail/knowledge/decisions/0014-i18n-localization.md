# 0014 — i18n: hand-rolled, type-driven English/Spanish (units descoped)

**Date:** 2026-06-18
**Status:** accepted

## Context

trail is English-only. The user wants English + Spanish, defaulting to the
browser locale with a footer toggle, stored in IDB, language never written to a
shared `.trail`. A full spec exists (`reference/i18n-spec.md`, authored by the
user) proposing hand-rolled, type-driven localization with no i18n library, plus
a unit-system (metric/imperial) preference built in the same pass. On
greenlighting, the user **descoped units** ("that'd be a way larger task") to a
separate backlog item, and delegated the translations themselves (neutral
Spanish, reviewed per-PR).

## Decision

Implement **language localization only**, hand-rolled and exhaustive over a
`Language` custom type, no library, everything compiled into the bundle
(local-first). Specifically:

- **`Language = English | Spanish`** (`Language.elm`), codec keyed on ISO codes
  (`"en"`/`"es"`), strict leaf decoder; migration tolerance one level up. (WI-1)
- **`Settings { language }`** (`Settings.elm`), persisted as one JSON record
  under a new `deviceSettings` key in the **existing `settings` IDB store**.
  `settingsDecoder` uses `D.oneOf` per field (missing `language` → `English`), so
  a future `units` field is purely additive. First-run default derives from
  `navigator.language` (subtag match). New outbound port `saveSettings`; flags
  gain `settings : D.Value` + `browserLanguage : String`. The JS boot **awaits
  the settings read before `Elm.Main.init`** so there is no flash-of-English.
  (WI-2)
- **`Context { language }`** threaded as the first arg to any localized view
  (`toContext` near `Main`); leaf views never read `model.settings`. Threaded as
  a *record* even though it holds one field — so `units` later is a record edit,
  not a mass re-signature. (WI-3)
- **`Translations.elm`** — function-per-key, each `case`-matching on `Language`,
  total (no `_ ->` fallthrough). Interpolation is typed function arguments;
  pluralization is a one/other helper (sufficient for en + es). Adding a third
  language makes every `case` non-exhaustive → a compile-time punch-list. (WI-4)
- **`Format.elm`** localizes **decimal quantities only** (Spanish comma,
  English period) by wrapping trail's existing hand-rolled rounding output —
  **no `myrho/elm-round` dependency**. Pace/clock/elapsed are colon-formatted →
  locale-neutral, untouched. **No unit conversion** (descoped). (WI-5, language
  half)

**Descoped → backlog (TASK-070):** unit selection (metric/imperial) as a
Profile/Settings preference — store SI, convert at the display boundary, toggle
in the profile page; extends `Settings`/`Context`/`Format` along the seams left
here.

**Not built (would be dead code):** date/month-name localization — dates render
as ISO strings, no month names appear in the UI.

**Never localized:** `.trail`, CSV, GPX exports (data interchange). Language is
a device preference, never written to `.trail` (a Spanish coach and an English
runner see their own language on one shared plan).

## Alternatives considered

- **`elm-i18next` (runtime JSON + `Result` lookups)** — rejected by the spec:
  against local-first (runtime fetch) and against type-driven guarantees
  (lookups fail at runtime). Buys nothing for two compiled languages.
- **`travelm-agency` (build-time codegen)** — deferred, not rejected. Earns its
  build step only once hand-maintenance is the bottleneck or a non-programmer
  translator joins. Migration trigger, not a day-one dep.
- **Bundling units now (as the spec proposed)** — rejected by the user as too
  large; reframed as TASK-070. Seams left so it's additive.
- **`myrho/elm-round`** — rejected: trail's hand-rolled rounding already works;
  localizing its output avoids a new dep (project value: simple stack, no
  premature abstraction).
- **Language in localStorage (sync at boot, like `deviceId`)** — rejected: the
  user wants it in IDB per the spec. Reconciled by awaiting the IDB read before
  Elm boots (no flash) instead.
- **Threading `Language` directly instead of a `Context` record** — rejected:
  adding `units` later would re-signature every localized view. The record is
  cheap forward-compat (WI-3's stated rationale).
- **`Language` in `.trail`** — rejected (spec): it's a per-viewer device
  preference, not document data.

## Consequences

- **Easy:** a missing translation cannot compile; adding a language yields a
  complete compile-time punch-list; toggling language mutates no stored data;
  units later is additive (records + `D.oneOf` seams already in place).
- **Hard / to revisit:** the translation surface is large (~260 strings across
  `Main.elm`'s ~8.5k lines) — split across several PRs (TASK-061–068), so the
  `Translations` module and call-site migrations land incrementally. Term
  consistency is enforced by hand via `i18n-glossary.md`, not tooling — the
  travelm threshold (Q5) is the future escape hatch. The boot refactor
  (await-before-init) is the one change to the JS boot sequence; covered by
  the storage smoke + build gate.
