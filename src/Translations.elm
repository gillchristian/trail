module Translations exposing
    ( documentTitle
    , footerPrivacy
    , headerSubtitle
    , plural
    , profileNav
    )

{-| Hand-rolled UI translations (i18n epic, WI-4, ADR-0014).

Function-per-key, each **total over `Language`** (no `_ ->` fallthrough that could
mask a missing translation) — so adding a third language makes every `case`
non-exhaustive, yielding a compile-time punch-list of what's left to translate.
Interpolation is plain typed arguments; pluralization is the one/other `plural`
helper (sufficient for en + es). Spanish term choices follow
`reference/i18n-glossary.md` — keep them in sync.

This slice (TASK-061) covers the **global chrome** — header, footer, document
title. Later surface tasks (TASK-062–068) append their strings here.

"Trail" is the product name and is kept verbatim in both languages.

-}

import Language exposing (Language(..))
import Route exposing (Route)


{-| English-style one/other pluralization — sufficient for English + Spanish.
-}
plural : Int -> { one : String, other : String } -> String
plural n words =
    if n == 1 then
        words.one

    else
        words.other


{-| Browser tab title, per route.
-}
documentTitle : Language -> Route -> String
documentTitle language route =
    case route of
        Route.Index ->
            "Trail"

        Route.RaceDetail _ ->
            case language of
                English ->
                    "Trail — race"

                Spanish ->
                    "Trail — carrera"

        Route.RaceMap _ ->
            case language of
                English ->
                    "Trail — map"

                Spanish ->
                    "Trail — mapa"

        Route.PlanTable _ ->
            "Trail — plan"

        Route.PlanKm _ _ ->
            case language of
                English ->
                    "Trail — plan km"

                Spanish ->
                    "Trail — plan km"

        Route.PlanSection _ _ ->
            case language of
                English ->
                    "Trail — plan section"

                Spanish ->
                    "Trail — plan tramo"

        Route.ProfileSettings ->
            case language of
                English ->
                    "Trail — profile"

                Spanish ->
                    "Trail — perfil"

        Route.NotFound ->
            case language of
                English ->
                    "Trail — not found"

                Spanish ->
                    "Trail — no encontrado"


{-| The header's route subtitle (the small text after the wordmark).
-}
headerSubtitle : Language -> Route -> String
headerSubtitle language route =
    case route of
        Route.Index ->
            case language of
                English ->
                    "Your races."

                Spanish ->
                    "Tus carreras."

        Route.RaceDetail _ ->
            case language of
                English ->
                    "Race detail."

                Spanish ->
                    "Detalle de la carrera."

        Route.RaceMap _ ->
            case language of
                English ->
                    "Map view."

                Spanish ->
                    "Mapa."

        Route.PlanTable _ ->
            case language of
                English ->
                    "Plan · table view."

                Spanish ->
                    "Plan · tabla."

        Route.PlanKm _ _ ->
            case language of
                English ->
                    "Plan · per km."

                Spanish ->
                    "Plan · por km."

        Route.PlanSection _ _ ->
            case language of
                English ->
                    "Plan · section."

                Spanish ->
                    "Plan · tramo."

        Route.ProfileSettings ->
            case language of
                English ->
                    "Profile · settings."

                Spanish ->
                    "Perfil · ajustes."

        Route.NotFound ->
            case language of
                English ->
                    "Lost?"

                Spanish ->
                    "¿Perdido?"


{-| The "Profile" nav link in the header.
-}
profileNav : Language -> String
profileNav language =
    case language of
        English ->
            "Profile"

        Spanish ->
            "Perfil"


{-| The footer privacy line (left side; the language toggle sits on the right).
-}
footerPrivacy : Language -> String
footerPrivacy language =
    case language of
        English ->
            "Local-first. Your GPX never leaves the browser."

        Spanish ->
            "Todo local. Tu GPX nunca sale del navegador."
