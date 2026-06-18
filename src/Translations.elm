module Translations exposing (..)

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



-- HOME / INDEX (TASK-062)


homeTitle : Language -> String
homeTitle language =
    case language of
        English ->
            "Your races"

        Spanish ->
            "Tus carreras"


homeSubtitle : Language -> String
homeSubtitle language =
    case language of
        English ->
            "Upload a GPX, plan the day, export Coros-ready files."

        Spanish ->
            "Sube un GPX, planifica el día y exporta archivos listos para Coros."


{-| Hero race count: "no races yet" / "1 race" / "N races".
-}
heroRaceCount : Language -> Int -> String
heroRaceCount language count =
    if count == 0 then
        case language of
            English ->
                "no races yet"

            Spanish ->
                "ninguna carrera todavía"

    else
        raceCount language count


{-| "N race(s)" — the count plus the pluralized noun.
-}
raceCount : Language -> Int -> String
raceCount language count =
    String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    plural count { one = "race", other = "races" }

                Spanish ->
                    plural count { one = "carrera", other = "carreras" }
           )


uploadDropTitle : Language -> String
uploadDropTitle language =
    case language of
        English ->
            "Drop a .gpx or .trail file"

        Spanish ->
            "Suelta un archivo .gpx o .trail"


uploadDropSub : Language -> String
uploadDropSub language =
    case language of
        English ->
            "or click to choose one"

        Spanish ->
            "o haz clic para elegir uno"


uploadProcessing : Language -> String -> String
uploadProcessing language fileName =
    case language of
        English ->
            "Processing " ++ fileName ++ "…"

        Spanish ->
            "Procesando " ++ fileName ++ "…"


uploadProcessingSub : Language -> String
uploadProcessingSub language =
    case language of
        English ->
            "Crunching the track — this can take a moment on a long course."

        Spanish ->
            "Procesando la traza — puede tardar un momento en un recorrido largo."


uploadSaving : Language -> String -> String
uploadSaving language fileName =
    case language of
        English ->
            "Saving " ++ fileName ++ "…"

        Spanish ->
            "Guardando " ++ fileName ++ "…"


uploadSavingSub : Language -> String
uploadSavingSub language =
    case language of
        English ->
            "Writing to local storage."

        Spanish ->
            "Guardando en el almacenamiento local."


uploadFailed : Language -> String -> String
uploadFailed language fileName =
    case language of
        English ->
            "Couldn't read " ++ fileName

        Spanish ->
            "No se pudo leer " ++ fileName


chooseFile : Language -> String
chooseFile language =
    case language of
        English ->
            "Choose a file"

        Spanish ->
            "Elegir un archivo"


emptyTitle : Language -> String
emptyTitle language =
    case language of
        English ->
            "No races yet."

        Spanish ->
            "Aún no hay carreras."


emptySub : Language -> String
emptySub language =
    case language of
        English ->
            "Drop in a GPX above to get started."

        Spanish ->
            "Suelta un GPX arriba para empezar."


sectionPlans : Language -> String
sectionPlans language =
    case language of
        English ->
            "Plans"

        Spanish ->
            "Planes"


sectionPlansSub : Language -> String
sectionPlansSub language =
    case language of
        English ->
            "Courses you've prepared but haven't run yet."

        Spanish ->
            "Recorridos que has preparado pero aún no has corrido."


sectionExecutions : Language -> String
sectionExecutions language =
    case language of
        English ->
            "Executions"

        Spanish ->
            "Completadas"


sectionExecutionsSub : Language -> String
sectionExecutionsSub language =
    case language of
        English ->
            "Runs you came back from — linked to an actual activity."

        Spanish ->
            "Carreras que ya corriste — vinculadas a una actividad real."


{-| Owner group heading on the home page: "<name>'s races" / "carreras de <name>".
-}
othersRacesHeading : Language -> String -> String
othersRacesHeading language name =
    case language of
        English ->
            name ++ "’s races"

        Spanish ->
            "carreras de " ++ name


cardNoAid : Language -> String
cardNoAid language =
    case language of
        English ->
            "No aid stations yet."

        Spanish ->
            "Sin avituallamientos todavía."


{-| Race-card aid count: "★ N aid station(s) planned".
-}
cardAidCount : Language -> Int -> String
cardAidCount language count =
    "★ "
        ++ String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    plural count { one = "aid station planned", other = "aid stations planned" }

                Spanish ->
                    plural count { one = "avituallamiento planificado", other = "avituallamientos planificados" }
           )
