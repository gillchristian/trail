module Settings exposing
    ( Settings
    , decoder
    , defaultSettings
    , encode
    , fromFlags
    , languageFromBrowser
    )

{-| Device-level UI preferences (i18n epic, WI-2, ADR-0014).

For now this is just `language`; it is a **record** (not a bare `Language`) on
purpose, so the descoped unit-system preference (TASK-070) slots in later as an
additive field with no signature churn. Persisted as one JSON object under the
`deviceSettings` key of the existing `settings` IDB store, hydrated through flags
at boot. **Language is a device preference — never written to `.trail`.**

Back-compat lives **here**, not in `Language` (whose leaf decoder is strict): every
field defaults via `D.oneOf`, so a record predating i18n — or any partial blob —
decodes cleanly. First-run (no stored record) derives the language from the
browser locale; see `fromFlags`.

-}

import Json.Decode as D
import Json.Encode as E
import Language exposing (Language(..))


type alias Settings =
    { language : Language }


defaultSettings : Settings
defaultSettings =
    { language = English }


{-| Per-field `D.oneOf` defaulting: a missing/invalid `language` falls back to
`English` rather than failing the whole record. Adding `units` later (TASK-070)
is the same idiom — purely additive.
-}
decoder : D.Decoder Settings
decoder =
    D.map Settings
        (D.oneOf [ D.field "language" Language.decoder, D.succeed English ])


encode : Settings -> E.Value
encode s =
    E.object
        [ ( "language", Language.encode s.language ) ]


{-| Resolve settings at boot. A **stored object** (even a partial one) wins via
the field-defaulting `decoder`; a **null** raw value (first run — nothing in IDB
yet) routes to the browser-locale default. `D.nullable` is what distinguishes the
two: it short-circuits `null` to `Nothing` before the always-succeeding `decoder`
can turn it into defaults, so the first-run browser detection actually fires.
-}
fromFlags : D.Value -> String -> Settings
fromFlags raw browserLanguage =
    case D.decodeValue (D.nullable decoder) raw of
        Ok (Just stored) ->
            stored

        _ ->
            { defaultSettings | language = languageFromBrowser browserLanguage }


{-| First-run language from `navigator.language`, matched on the **primary
subtag** only (e.g. `"es-AR"` → Spanish, `"en-US"` → English); anything trail
doesn't ship falls back to English.
-}
languageFromBrowser : String -> Language
languageFromBrowser browserLanguage =
    String.left 2 browserLanguage
        |> String.toLower
        |> Language.fromCode
        |> Maybe.withDefault English
