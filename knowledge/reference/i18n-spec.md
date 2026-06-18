# i18n Spec — English + Spanish

**Status:** Accepted (with deltas) — being implemented as the **i18n epic** (TASK-058–069), 2026-06-18.
**Scope:** Add English/Spanish localization to `trail` without compromising local-first architecture or type-driven guarantees.
**Owner:** Christian
**Coding agent:** implement per work items below; branch → PR → squash-merge; commits under Christian's name only.

> ## Resolved decisions / reality corrections (2026-06-18) — read first
>
> Between the spec-as-written and the steer the user gave when greenlighting the
> work, several things changed. **Where this callout and the work-item bodies
> below disagree, this callout wins.** (Same convention as `coach-collab-spec.md`.)
>
> 1. **Units are descoped — language only.** This epic ships the `Language`
>    axis only. WI-2's `UnitSystem`, WI-5's metric/imperial *conversion*, and the
>    units half of `Settings`/`Context` are **not built here**. They become an
>    unpromoted backlog item — **TASK-070, "Unit selection (metric/imperial) in
>    Profile/Settings"** — reframed as a user preference, *not* a derived value
>    built now (user, 2026-06-18). Where a WI interleaves units, implement the
>    language axis only and **leave the seams**: `Settings`/`Context` are records
>    (one field now), decoded with `D.oneOf` per field, so `units` slots in later
>    with no signature churn.
> 2. **Decimal separator IS in scope** (it is *language*, not units): Spanish
>    `42,2 km`, English `42.2 km` (WI-5). Pace/clock/elapsed stay colon-neutral.
>    **Exports are never localized** — `.trail`, CSV, and GPX keep `.`-decimals
>    and their own formatters (data interchange, not display).
> 3. **No `myrho/elm-round` dependency.** trail already hand-rolls rounding
>    (`formatFloat`/`formatKm`); `Format` wraps that output and swaps the
>    separator. The spec's "Dependencies to add: `myrho/elm-round`" is **void**.
> 4. **No date/month machinery.** Dates are stored + rendered as ISO strings
>    (`2026-06-18`); there are **no rendered month names** anywhere in the app, so
>    WI-5's `monthName` and the Open-Question-2 date strategy are **not built**
>    (would be dead code).
> 5. **Persistence (Open Q3):** reuse the existing `settings` IDB store under a
>    new `deviceSettings` key; add one outbound `saveSettings` port; extend flags
>    with `browserLanguage : navigator.language`. To avoid a flash-of-English, the
>    JS boot **`await`s the settings read before `Elm.Main.init`** (the spec's
>    `init` already assumes `flags.settings` is present) rather than mirroring to
>    localStorage — honouring "stored in IDB" (user).
> 6. **`Context` is threaded even though it holds one field** (`language`) — the
>    forward-compat insurance from WI-3, so adding `units` later is a record +
>    `Format` change, not a mass re-signature.
> 7. **Toggle UX (user):** footer, right side, endonyms `English / Español`, **no
>    flag icons**, click to switch, persisted in IDB, **never in the URL or
>    `.trail`**. Also set `<html lang>` per language (a11y + suppress browser
>    auto-translate).
> 8. **Remaining open questions:** Q1 (units default) moot — descoped. Q2 (dates)
>    no-op — see #4. Q4 (gradient/% separator): slope% appears only in CSV export
>    (not localized) and is **not shown in the UI**; if surfaced later, `12,5 %`.
>    Q5 (travelm threshold) unchanged — future trigger. Q6 (authored-in-language
>    metadata): **no**.
>
> Architecture decision recorded in **ADR-0014**; Spanish term choices in
> **`i18n-glossary.md`** (single source of truth across the translation PRs).

---

## Context

`trail` is currently English-only. This spec adds Spanish as a second language and, in the same pass, introduces a unit-system preference (metric/imperial) because the formatter layer has to be built once and the two axes interact at the display boundary.

The approach is hand-rolled, type-driven localization with **no i18n library**. Translations are exhaustive functions over a `Language` custom type; the Elm compiler enforces completeness. No runtime fetching of translation files — everything is compiled into the bundle, consistent with local-first.

## Design axioms (must hold)

- **Impossible states unrepresentable.** A missing translation must not compile. Every formatter is total over both `Language` and `UnitSystem`.
- **No premature abstraction.** Hand-rolled translation modules; no library, no codegen. Revisit `travelm-agency` only when hand-maintenance becomes the bottleneck (see Alternatives).
- **Back-compat via `D.oneOf` defaults.** Settings records predating i18n must decode cleanly, using the same idiom already applied to `.trail` and IDB records.
- **Store canonical, format at the boundary.** All quantities persist in SI (meters, seconds-per-meter). Unit conversion and locale formatting are pure view concerns. Toggling units mutates no stored data.
- **Language is a device preference, not document data.** It is never written to `.trail`. A coach reading in Spanish and a runner reading in English see their own language on the same shared plan.

---

## WI-1 — `Language` type and codec

**Status:** Proposed

Self-contained module. Codec keyed on ISO codes (stable serialization), not constructor names (refactorable). Leaf decoder is strict and total; migration tolerance lives one level up (WI-2).

```elm
module Language exposing (Language(..), decoder, encode, fromCode, toCode)

import Json.Decode as D
import Json.Encode as E

type Language
    = English
    | Spanish

toCode : Language -> String
toCode lang =
    case lang of
        English -> "en"
        Spanish -> "es"

fromCode : String -> Maybe Language
fromCode code =
    case code of
        "en" -> Just English
        "es" -> Just Spanish
        _   -> Nothing

encode : Language -> E.Value
encode =
    toCode >> E.string

decoder : D.Decoder Language
decoder =
    D.string
        |> D.andThen
            (\code ->
                case fromCode code of
                    Just lang -> D.succeed lang
                    Nothing   -> D.fail ("Unknown language: " ++ code)
            )
```

**Acceptance criteria**
- `toCode`/`fromCode` round-trip for every constructor.
- `decoder` fails on unknown codes (strictness verified by a failing-decode test).
- Adding a third constructor produces compile errors in `toCode` and `fromCode` (exhaustiveness, no `_ ->` in `toCode`).

---

## WI-2 — Settings record and persistence round-trip

**Status:** Proposed

Device-level settings carry `language` and `units`. Persisted to IDB via a port; hydrated through flags at init. First-run default for language is derived from `navigator.language`; units default to `Metric`.

```elm
type UnitSystem
    = Metric
    | Imperial

type alias Settings =
    { language : Language
    , units : UnitSystem
    }

defaultSettings : Settings
defaultSettings =
    { language = English, units = Metric }

unitSystemDecoder : D.Decoder UnitSystem
unitSystemDecoder =
    D.string
        |> D.andThen
            (\s ->
                case s of
                    "metric"   -> D.succeed Metric
                    "imperial" -> D.succeed Imperial
                    _          -> D.fail ("Unknown unit system: " ++ s)
            )

encodeUnitSystem : UnitSystem -> E.Value
encodeUnitSystem u =
    E.string (case u of
        Metric -> "metric"
        Imperial -> "imperial")

-- Back-compat lives HERE: missing fields default, the record never fails.
settingsDecoder : D.Decoder Settings
settingsDecoder =
    D.map2 Settings
        (D.oneOf [ D.field "language" Language.decoder, D.succeed English ])
        (D.oneOf [ D.field "units" unitSystemDecoder, D.succeed Metric ])

encodeSettings : Settings -> E.Value
encodeSettings s =
    E.object
        [ ( "language", Language.encode s.language )
        , ( "units", encodeUnitSystem s.units )
        ]
```

**Flags + init** (first-run default from browser, matching subtag only):

```elm
type alias Flags =
    { settings : D.Value        -- raw IDB record, or null on first run
    , browserLanguage : String  -- navigator.language, e.g. "es-AR"
    }

init : Flags -> ( Model, Cmd Msg )
init flags =
    let
        settings =
            case D.decodeValue settingsDecoder flags.settings of
                Ok s ->
                    s

                Err _ ->
                    { defaultSettings
                        | language =
                            Language.fromCode (String.left 2 flags.browserLanguage)
                                |> Maybe.withDefault English
                    }
    in
    ( { model | settings = settings }, Cmd.none )
```

**Persistence port + update path:**

```elm
port saveSettings : E.Value -> Cmd msg

-- in update
ChangeLanguage lang ->
    let
        settings = model.settings
        next = { settings | language = lang }
    in
    ( { model | settings = next }, saveSettings (encodeSettings next) )

ChangeUnits units ->
    let
        settings = model.settings
        next = { settings | units = units }
    in
    ( { model | settings = next }, saveSettings (encodeSettings next) )
```

**JS side** (reuse existing IDB plumbing): the `saveSettings` subscription does an IDB `put`; on boot, read the same key and pass it plus `navigator.language` into `Elm.Main.init({ flags: { settings, browserLanguage: navigator.language } })`.

**Acceptance criteria**
- A v1 settings blob with no `language`/`units` fields decodes to `{ English, Metric }` without error.
- An `"es-AR"` browser language on first run (null IDB record) yields `Spanish`.
- Changing language or units emits exactly one `saveSettings` command and mutates no `.trail` data.
- Round-trip: `encodeSettings >> decodeValue settingsDecoder` is identity for all `Settings`.

---

## WI-3 — `Context` threading

**Status:** Proposed

Render-time locale is bundled into a small `Context` derived from the model and threaded as the first argument to any view that renders localized text or quantities. Leaf views never reach into `model.settings`.

```elm
type alias Context =
    { language : Language
    , units : UnitSystem
    }

toContext : Model -> Context
toContext model =
    { language = model.settings.language, units = model.settings.units }
```

```elm
viewSplit : Context -> Split -> Html Msg
viewSplit ctx split =
    Html.div []
        [ Html.text (Translations.distanceLabel ctx.language)
        , Html.text (Format.distance ctx split.distanceMeters)
        ]
```

**Acceptance criteria**
- No view module outside the top level references `model.settings` directly; localized views take `Context`.
- `Context` carries only what the view needs (language, units); not the whole model.

> Rejected alternative (record-of-applied-functions) recorded below; do not implement it.

---

## WI-4 — `Translations` module

**Status:** Proposed

Function-per-key, each pattern-matching on `Language`. This is where exhaustiveness pays off: a new language makes every `case` non-exhaustive, producing a complete punch-list at compile time. Interpolation is plain function arguments. Pluralization is a simple one/other helper (sufficient for en + es).

```elm
module Translations exposing (..)

import Language exposing (Language(..))

plural : Int -> { one : String, other : String } -> String
plural n { one, other } =
    if n == 1 then one else other

distanceLabel : Language -> String
distanceLabel lang =
    case lang of
        English -> "Distance"
        Spanish -> "Distancia"

mileAtPace : Language -> Int -> String -> String
mileAtPace lang mile pace =
    case lang of
        English -> "Mile " ++ String.fromInt mile ++ " at " ++ pace
        Spanish -> "Milla " ++ String.fromInt mile ++ " a " ++ pace

-- Combined count + per-language pluralization
aidStationCount : Language -> Int -> String
aidStationCount lang n =
    let
        noun =
            case lang of
                English -> plural n { one = "aid station", other = "aid stations" }
                Spanish -> plural n { one = "avituallamiento", other = "avituallamientos" }
    in
    String.fromInt n ++ " " ++ noun

-- Month names for date assembly (see WI-5 / Open Questions)
monthName : Language -> Time.Month -> String
monthName lang month =
    case ( lang, month ) of
        ( English, Time.Jun ) -> "June"
        ( Spanish, Time.Jun ) -> "junio"
        -- … remaining months
        _ -> "…"
```

**Rule of placement:** `Translations` owns anything where the *words or their order* change. Anything where only *units or punctuation* change belongs in `Format` (WI-5).

**Acceptance criteria**
- Every exported translation function is total over `Language` (no `_ ->` fallthrough that masks a missing translation).
- Adding a third `Language` constructor fails compilation in `Translations` until all strings are supplied.
- Interpolated strings take typed arguments (no string-template lookup that can fail at runtime).

---

## WI-5 — `Format` layer (units + locale)

**Status:** Proposed

All quantities stored in SI; `Format` converts and localizes at the display boundary, driven by `Context`. Number formatting uses `myrho/elm-round` for fixed-decimal strings, then swaps the decimal separator per language. **Only decimal quantities need the separator swap** — colon-formatted values (pace, clock time, elapsed) are locale-neutral and skip it.

```elm
module Format exposing (distance, elevation, pace, number)

import Round
import Language exposing (Language(..))

number : Language -> Int -> Float -> String
number lang decimals value =
    Round.round decimals value
        |> localizeDecimal lang

localizeDecimal : Language -> String -> String
localizeDecimal lang str =
    case lang of
        Spanish -> String.replace "." "," str
        English -> str

distance : Context -> Float -> String   -- input: meters
distance ctx meters =
    case ctx.units of
        Metric   -> number ctx.language 1 (meters / 1000) ++ " km"
        Imperial -> number ctx.language 1 (meters / 1609.344) ++ " mi"

elevation : Context -> Float -> String   -- input: meters
elevation ctx meters =
    case ctx.units of
        Metric   -> number ctx.language 0 meters ++ " m"
        Imperial -> number ctx.language 0 (meters * 3.28084) ++ " ft"

-- Pace is M:SS, colon-separated → locale-neutral, no separator swap.
pace : Context -> Float -> String   -- input: seconds per meter
pace ctx secondsPerMeter =
    let
        perUnit =
            case ctx.units of
                Metric   -> secondsPerMeter * 1000
                Imperial -> secondsPerMeter * 1609.344

        minutes = floor (perUnit / 60)
        seconds = round (perUnit - toFloat minutes * 60)

        suffix =
            case ctx.units of
                Metric -> "/km"
                Imperial -> "/mi"
    in
    String.fromInt minutes
        ++ ":"
        ++ String.padLeft 2 '0' (String.fromInt seconds)
        ++ " "
        ++ suffix
```

**Acceptance criteria**
- All persisted quantities are SI; toggling `UnitSystem` mutates no stored value.
- Spanish renders decimal quantities with `,`; pace and any colon-formatted value retain `:`.
- Each formatter is total over `UnitSystem` and `Language`.
- Gradient/percentage values are treated as decimal quantities (comma in Spanish) — confirm in Open Questions.

---

## Alternatives considered (paths not taken)

- **`elm-i18next` — rejected.** Loads JSON at runtime (against local-first) and yields `Result`-typed lookups that can fail at runtime (against type-driven guarantees). Buys nothing for two compiled languages.
- **`travelm-agency` (inline mode) — deferred, not rejected.** Type-safe codegen from JSON/Fluent at build time, bundled, stays local. Earns its build step only once hand-maintaining strings becomes the bottleneck or a non-programmer translator enters the loop. Migration trigger, not a day-one dependency.
- **Record-of-applied-functions (`T` bound per render) — rejected.** Reads marginally cleaner at call sites but duplicates the entire key surface (module function + record field kept in sync by hand). Explicit `Context` threading is the cleaner trade for a type-first project.
- **`Language` in `.trail` — rejected.** Language is a per-device viewer preference; a shared plan must not carry the viewer's locale. Each peer renders in their own language.
- **`Language` ≡ `UnitSystem` coupling — rejected.** Spanish does not imply metric. The two axes are orthogonal preferences; a Spanish speaker may want miles, an English speaker km.

---

## Open questions

1. **Units first-run default.** Always `Metric`, or derive a heuristic from region (e.g. `en-US` → Imperial)? Decoupling argues for a fixed default; UX argues for a heuristic. Decision needed.
2. **Date formatting strategy.** Hand-rolled month names + per-language assembly (consistent with the rest, zero deps), or a port to JS `Intl.DateTimeFormat` (correct locale formatting, small impurity)? Spec assumes the former; flagging the trade.
3. **IDB store layout.** New object store for settings, or another record in an existing store? Prefer reusing existing plumbing.
4. **Gradient/percentage separator.** Confirm Spanish renders `12,5 %` (comma) and the space-before-`%` convention.
5. **`travelm-agency` migration threshold.** Define the rough string-count or translator-onboarding signal that triggers the move, so it's a deliberate decision later rather than ad hoc.
6. **Authored-in-language metadata.** Any value in recording the language a plan was *authored* in as `.trail` metadata (distinct from viewer language)? Default assumption: no.

---

## Hand-off brief

**Suggested implementation order:** WI-1 → WI-2 → WI-3 → WI-4 → WI-5. WI-1 and WI-2 are foundational; WI-3 unblocks view work; WI-4 and WI-5 can proceed in parallel once `Context` exists.

**Module layout:**
```
src/
  Language.elm       -- WI-1
  Settings.elm       -- WI-2 (Settings, UnitSystem, codecs, defaults)
  Translations.elm   -- WI-4
  Format.elm         -- WI-5
  -- Context lives wherever shared view types live; toContext near Main
```

**Dependencies to add:** `myrho/elm-round`.

**Ports to add:** `saveSettings : E.Value -> Cmd msg` (+ JS IDB `put` handler and boot-time read). Flags extended with `settings : D.Value` and `browserLanguage : String`.

**Workflow:** one branch, PR, squash-merge. Commits under Christian's name only.

**Definition of done:** all WI acceptance criteria pass; a deliberate compile-error check (temporarily add a third `Language` constructor, confirm the compiler enumerates every untranslated site, then revert) is documented in the PR description.
