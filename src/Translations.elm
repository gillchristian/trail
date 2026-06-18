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

import AthleteProfile exposing (AidStyle(..), DescentSkill(..), Preset(..), TechSkill(..))
import Language exposing (Language(..))
import Route exposing (Route)
import Types exposing (Service(..))


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



-- SHARED (used across surfaces)


cancel : Language -> String
cancel language =
    case language of
        English ->
            "Cancel"

        Spanish ->
            "Cancelar"


parsingGpx : Language -> String
parsingGpx language =
    case language of
        English ->
            "Parsing GPX…"

        Spanish ->
            "Procesando GPX…"


{-| "N aid station(s)" — count + pluralized noun. Reused on the map summary and
the aid-stations section.
-}
aidStationCount : Language -> Int -> String
aidStationCount language count =
    String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    plural count { one = "aid station", other = "aid stations" }

                Spanish ->
                    plural count { one = "avituallamiento", other = "avituallamientos" }
           )



-- Stat labels (race detail + plan table)


statDistance : Language -> String
statDistance language =
    case language of
        English ->
            "Distance"

        Spanish ->
            "Distancia"


statGain : Language -> String
statGain language =
    case language of
        English ->
            "Gain"

        Spanish ->
            "Desnivel +"


statLoss : Language -> String
statLoss language =
    case language of
        English ->
            "Loss"

        Spanish ->
            "Desnivel −"


statDensity : Language -> String
statDensity language =
    case language of
        English ->
            "Density"

        Spanish ->
            "Densidad"


statFlatEq : Language -> String
statFlatEq language =
    case language of
        English ->
            "Flat eq."

        Spanish ->
            "Equiv. llano"



-- RACE DETAIL (TASK-063)


backToRaces : Language -> String
backToRaces language =
    case language of
        English ->
            "← Back to races"

        Spanish ->
            "← Volver a las carreras"


editDetails : Language -> String
editDetails language =
    case language of
        English ->
            "Edit details"

        Spanish ->
            "Editar detalles"


planThisRace : Language -> String
planThisRace language =
    case language of
        English ->
            "Plan this race"

        Spanish ->
            "Planifica esta carrera"


planThisRaceSub : Language -> String
planThisRaceSub language =
    case language of
        English ->
            "Set a target time. We'll distribute pace by km using the terrain. Override any km manually."

        Spanish ->
            "Fija un tiempo objetivo. Distribuimos el ritmo por km según el terreno. Ajusta cualquier km a mano."


openThePlan : Language -> String
openThePlan language =
    case language of
        English ->
            "Open the plan →"

        Spanish ->
            "Abrir el plan →"


mapTeaserTitle : Language -> String
mapTeaserTitle language =
    case language of
        English ->
            "Open on the map"

        Spanish ->
            "Ver en el mapa"


mapTeaserSub : Language -> String
mapTeaserSub language =
    case language of
        English ->
            "Real-world OSM tiles. Useful for spotting which forest you're about to enter."

        Spanish ->
            "Mapas reales de OSM. Útiles para ver en qué bosque te vas a meter."


viewOnMap : Language -> String
viewOnMap language =
    case language of
        English ->
            "View on map →"

        Spanish ->
            "Ver en el mapa →"



-- MAP VIEW (TASK-063)


breadcrumbRaces : Language -> String
breadcrumbRaces language =
    case language of
        English ->
            "Races"

        Spanish ->
            "Carreras"


breadcrumbMap : Language -> String
breadcrumbMap language =
    case language of
        English ->
            "Map"

        Spanish ->
            "Mapa"


mapTiles : Language -> String
mapTiles language =
    case language of
        English ->
            "Tiles from OpenStreetMap. Once you've panned over an area, those tiles are cached for offline use."

        Spanish ->
            "Mosaicos de OpenStreetMap. Una vez que recorres una zona, quedan en caché para usarlos sin conexión."


{-| Map marker name for the start point.
-}
startLabel : Language -> String
startLabel language =
    case language of
        English ->
            "Start"

        Spanish ->
            "Salida"


{-| Map marker name for the finish point (prefix; the distance follows).
-}
finishLabel : Language -> String
finishLabel language =
    case language of
        English ->
            "Finish"

        Spanish ->
            "Meta"



-- EXPORT PANEL (TASK-063)


exportTitle : Language -> String
exportTitle language =
    case language of
        English ->
            "Export"

        Spanish ->
            "Exportar"


exportSub : Language -> String
exportSub language =
    case language of
        English ->
            "everything lives on this device · take it with you"

        Spanish ->
            "todo vive en este dispositivo · llévatelo contigo"


exportGpxTitle : Language -> String
exportGpxTitle language =
    case language of
        English ->
            "GPX for Coros"

        Spanish ->
            "GPX para Coros"


{-| Coros UI terms ("Waypoint Alerts", "Pace Strategy") are kept verbatim — the
user has to find them in the COROS app.
-}
exportGpxDesc : Language -> Bool -> String
exportGpxDesc language hasAids =
    if hasAids then
        case language of
            English ->
                "Re-emit the original GPX with your aid stations as standard waypoints. Upload it to the COROS app, then enable Waypoint Alerts on the route — that's what surfaces aid stations in Pace Strategy."

            Spanish ->
                "Reexporta el GPX original con tus avituallamientos como waypoints estándar. Súbelo a la app de COROS y activa Waypoint Alerts en la ruta — eso es lo que muestra los avituallamientos en Pace Strategy."

    else
        case language of
            English ->
                "Add aid stations first — without them the export is identical to the source."

            Spanish ->
                "Agrega avituallamientos primero — sin ellos la exportación es idéntica al original."


exportGpxButton : Language -> String
exportGpxButton language =
    case language of
        English ->
            "Download .gpx"

        Spanish ->
            "Descargar .gpx"


exportTrailTitle : Language -> String
exportTrailTitle language =
    case language of
        English ->
            "Project file (.trail)"

        Spanish ->
            "Archivo de proyecto (.trail)"


exportTrailDesc : Language -> String
exportTrailDesc language =
    case language of
        English ->
            "Everything about this race in one file: GPX, aid stations, target time, per-km plan, notes. Import it back here later, or share it."

        Spanish ->
            "Todo sobre esta carrera en un archivo: GPX, avituallamientos, tiempo objetivo, plan por km, notas. Vuelve a importarlo aquí más tarde, o compártelo."


exportTrailButton : Language -> String
exportTrailButton language =
    case language of
        English ->
            "Download .trail"

        Spanish ->
            "Descargar .trail"



-- EDIT DIALOG (TASK-063)


editRaceDetails : Language -> String
editRaceDetails language =
    case language of
        English ->
            "Edit race details"

        Spanish ->
            "Editar detalles de la carrera"


fieldName : Language -> String
fieldName language =
    case language of
        English ->
            "Name"

        Spanish ->
            "Nombre"


fieldDate : Language -> String
fieldDate language =
    case language of
        English ->
            "Date (optional)"

        Spanish ->
            "Fecha (opcional)"


fieldLocation : Language -> String
fieldLocation language =
    case language of
        English ->
            "Location (optional)"

        Spanish ->
            "Ubicación (opcional)"


fieldUrl : Language -> String
fieldUrl language =
    case language of
        English ->
            "URL (optional)"

        Spanish ->
            "URL (opcional)"


fieldNotes : Language -> String
fieldNotes language =
    case language of
        English ->
            "Notes"

        Spanish ->
            "Notas"


notesPlaceholder : Language -> String
notesPlaceholder language =
    case language of
        English ->
            "Anything that should travel with this race — checklist, strategy, mental cues…"

        Spanish ->
            "Lo que deba viajar con esta carrera — lista, estrategia, recordatorios mentales…"


coverImage : Language -> String
coverImage language =
    case language of
        English ->
            "Cover image (optional)"

        Spanish ->
            "Imagen de portada (opcional)"


replace : Language -> String
replace language =
    case language of
        English ->
            "Replace"

        Spanish ->
            "Reemplazar"


remove : Language -> String
remove language =
    case language of
        English ->
            "Remove"

        Spanish ->
            "Quitar"


pickImage : Language -> String
pickImage language =
    case language of
        English ->
            "Pick an image"

        Spanish ->
            "Elegir una imagen"


saveChanges : Language -> String
saveChanges language =
    case language of
        English ->
            "Save changes"

        Spanish ->
            "Guardar cambios"


elevationProfile : Language -> String
elevationProfile language =
    case language of
        English ->
            "Elevation profile"

        Spanish ->
            "Perfil de elevación"


trueScaleNote : Language -> String
trueScaleNote language =
    case language of
        English ->
            "true 1:1 scale · no vertical exaggeration"

        Spanish ->
            "escala real 1:1 · sin exageración vertical"



-- STATUS VIEWS (loading / not found)


loadingRaces : Language -> String
loadingRaces language =
    case language of
        English ->
            "Loading races…"

        Spanish ->
            "Cargando carreras…"


notFoundTitle : Language -> String
notFoundTitle language =
    case language of
        English ->
            "404 — that page doesn't exist."

        Spanish ->
            "404 — esa página no existe."


raceNotFoundMsg : Language -> String
raceNotFoundMsg language =
    case language of
        English ->
            "This race isn't in your library anymore."

        Spanish ->
            "Esta carrera ya no está en tu biblioteca."


{-| Button label without the leading arrow (the breadcrumb variant `backToRaces`
keeps the "←").
-}
backToRacesPlain : Language -> String
backToRacesPlain language =
    case language of
        English ->
            "Back to races"

        Spanish ->
            "Volver a las carreras"



-- AID STATIONS (TASK-064)


{-| Localized **display** label for an aid-station service. The export/serialization
path keeps `Types.serviceToString` (canonical) and `Types.serviceLabel` (stable
English, used in the GPX `<desc>`) — only the on-screen chip/tooltip localizes.
-}
serviceLabel : Language -> Service -> String
serviceLabel language service =
    case language of
        English ->
            Types.serviceLabel service

        Spanish ->
            case service of
                Water ->
                    "Agua"

                Food ->
                    "Comida"

                WarmFood ->
                    "Comida caliente"

                Medical ->
                    "Asistencia médica"

                WC ->
                    "Baño"

                DropBag ->
                    "Bolsa de material"

                Crew ->
                    "Acceso para asistencia"


aidSectionTitle : Language -> String
aidSectionTitle language =
    case language of
        English ->
            "Aid stations"

        Spanish ->
            "Avituallamientos"


{-| Aid count beside the section title: "none yet" / "1 stop" / "N stops".
-}
aidStopCount : Language -> Int -> String
aidStopCount language count =
    if count == 0 then
        case language of
            English ->
                "none yet"

            Spanish ->
                "ninguna todavía"

    else
        String.fromInt count
            ++ " "
            ++ (case language of
                    English ->
                        plural count { one = "stop", other = "stops" }

                    Spanish ->
                        plural count { one = "parada", other = "paradas" }
               )


importCsv : Language -> String
importCsv language =
    case language of
        English ->
            "Import CSV"

        Spanish ->
            "Importar CSV"


exportCsv : Language -> String
exportCsv language =
    case language of
        English ->
            "Export CSV"

        Spanish ->
            "Exportar CSV"


addAid : Language -> String
addAid language =
    case language of
        English ->
            "+ Add"

        Spanish ->
            "+ Agregar"


reading : Language -> String -> String
reading language fileName =
    case language of
        English ->
            "Reading " ++ fileName ++ "…"

        Spanish ->
            "Leyendo " ++ fileName ++ "…"


aidEmptySub : Language -> String
aidEmptySub language =
    case language of
        English ->
            "Add them one at a time, or Import CSV from a race organiser's aid table."

        Spanish ->
            "Agrégalos uno a uno, o importa un CSV con la tabla de avituallamientos del organizador."


importPreviewTitle : Language -> String
importPreviewTitle language =
    case language of
        English ->
            "Import preview"

        Spanish ->
            "Vista previa de importación"


{-| "N station(s) ready".
-}
importReady : Language -> Int -> String
importReady language count =
    String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    plural count { one = "station ready", other = "stations ready" }

                Spanish ->
                    plural count { one = "parada lista", other = "paradas listas" }
           )


{-| "· N skipped".
-}
importSkipped : Language -> Int -> String
importSkipped language count =
    " · "
        ++ String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    "skipped"

                Spanish ->
                    plural count { one = "omitida", other = "omitidas" }
           )


{-| "· N warning(s)".
-}
importWarningsCount : Language -> Int -> String
importWarningsCount language count =
    " · "
        ++ String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    plural count { one = "warning", other = "warnings" }

                Spanish ->
                    plural count { one = "aviso", other = "avisos" }
           )


nothingParsed : Language -> String
nothingParsed language =
    case language of
        English ->
            "Nothing parsed — fix the file and try Import again."

        Spanish ->
            "No se pudo leer nada — corrige el archivo e Importa de nuevo."


issueSkipped : Language -> String
issueSkipped language =
    case language of
        English ->
            "Skipped rows"

        Spanish ->
            "Filas omitidas"


issueWarnings : Language -> String
issueWarnings language =
    case language of
        English ->
            "Warnings"

        Spanish ->
            "Avisos"


issueFile : Language -> String
issueFile language =
    case language of
        English ->
            "File"

        Spanish ->
            "Archivo"


issueRow : Language -> Int -> String
issueRow language row =
    (case language of
        English ->
            "Row "

        Spanish ->
            "Fila "
    )
        ++ String.fromInt row


{-| Footnote under the import preview: replaces existing stops, or adds new ones.
-}
importReplaceNote : Language -> Int -> String
importReplaceNote language existing =
    if existing > 0 then
        (case language of
            English ->
                "Replaces your current " ++ String.fromInt existing ++ plural existing { one = " stop.", other = " stops." }

            Spanish ->
                "Reemplaza tus " ++ String.fromInt existing ++ plural existing { one = " parada actual.", other = " paradas actuales." }
        )

    else
        case language of
            English ->
                "Adds these to the race."

            Spanish ->
                "Las agrega a la carrera."


{-| Import confirm button: nothing / replace-with-N / import-N.
-}
importConfirmLabel : Language -> Int -> Int -> String
importConfirmLabel language n existing =
    if n == 0 then
        case language of
            English ->
                "Nothing to import"

            Spanish ->
                "Nada que importar"

    else if existing > 0 then
        (case language of
            English ->
                "Replace with "

            Spanish ->
                "Reemplazar con "
        )
            ++ String.fromInt n

    else
        (case language of
            English ->
                "Import "

            Spanish ->
                "Importar "
        )
            ++ String.fromInt n


cutoffLabel : Language -> String
cutoffLabel language =
    case language of
        English ->
            "cutoff"

        Spanish ->
            "corte"


aidFromStart : Language -> String
aidFromStart language =
    case language of
        English ->
            "from start"

        Spanish ->
            "desde la salida"


aidFromPrevious : Language -> String
aidFromPrevious language =
    case language of
        English ->
            "from previous"

        Spanish ->
            "desde el anterior"


aidToFinish : Language -> String
aidToFinish language =
    case language of
        English ->
            "to finish"

        Spanish ->
            "hasta la meta"


edit : Language -> String
edit language =
    case language of
        English ->
            "Edit"

        Spanish ->
            "Editar"


aidFormTitle : Language -> Bool -> String
aidFormTitle language editing =
    if editing then
        case language of
            English ->
                "Edit aid station"

            Spanish ->
                "Editar avituallamiento"

    else
        case language of
            English ->
                "New aid station"

            Spanish ->
                "Nuevo avituallamiento"


fieldRestMinutes : Language -> String
fieldRestMinutes language =
    case language of
        English ->
            "Rest (minutes)"

        Spanish ->
            "Descanso (minutos)"


fieldCutoff : Language -> String
fieldCutoff language =
    case language of
        English ->
            "Cutoff (optional)"

        Spanish ->
            "Corte (opcional)"


cutoffPlaceholder : Language -> String
cutoffPlaceholder language =
    case language of
        English ->
            "h:mm from start, e.g. 6:30"

        Spanish ->
            "h:mm desde la salida, p. ej. 6:30"


modeFromPrevious : Language -> String
modeFromPrevious language =
    case language of
        English ->
            "From previous"

        Spanish ->
            "Desde el anterior"


modeFromStart : Language -> String
modeFromStart language =
    case language of
        English ->
            "From start"

        Spanish ->
            "Desde la salida"


modeHelpFromStart : Language -> String
modeHelpFromStart language =
    case language of
        English ->
            "Absolute distance from the start line."

        Spanish ->
            "Distancia absoluta desde la línea de salida."


{-| `prevKmStr` is the already-formatted "X.X" km string.
-}
modeHelpFromPrevious : Language -> String -> String
modeHelpFromPrevious language prevKmStr =
    case language of
        English ->
            "Distance added on top of " ++ prevKmStr ++ " km (the previous stop, or start if there is none)."

        Spanish ->
            "Distancia que se suma a " ++ prevKmStr ++ " km (la parada anterior, o la salida si no hay)."


servicesLabel : Language -> String
servicesLabel language =
    case language of
        English ->
            "Services"

        Spanish ->
            "Servicios"


fieldNotesOptional : Language -> String
fieldNotesOptional language =
    case language of
        English ->
            "Notes (optional)"

        Spanish ->
            "Notas (opcional)"


aidNotesPlaceholder : Language -> String
aidNotesPlaceholder language =
    case language of
        English ->
            "Crew access, drop-bag here, what to grab…"

        Spanish ->
            "Acceso de asistencia, bolsa de material aquí, qué agarrar…"


addAidStation : Language -> String
addAidStation language =
    case language of
        English ->
            "Add aid station"

        Spanish ->
            "Agregar avituallamiento"



-- PLAN VIEWS (TASK-065)
-- Actual-run strip


actualParseError : Language -> String
actualParseError language =
    case language of
        English ->
            "Couldn't parse actual run: "

        Spanish ->
            "No se pudo procesar la actividad: "


linkFromStrava : Language -> String
linkFromStrava language =
    case language of
        English ->
            "Link from Strava"

        Spanish ->
            "Vincular desde Strava"


linkActualRun : Language -> String
linkActualRun language =
    case language of
        English ->
            "Link actual run"

        Spanish ->
            "Vincular actividad real"


linkActualRunHelp : Language -> String
linkActualRunHelp language =
    case language of
        English ->
            "Upload the .gpx of your completed run to compare per-km splits against the plan."

        Spanish ->
            "Sube el .gpx de tu actividad terminada para comparar los parciales por km con el plan."


uploadGpx : Language -> String
uploadGpx language =
    case language of
        English ->
            "Upload .gpx"

        Spanish ->
            "Subir .gpx"


actualRunLinked : Language -> String
actualRunLinked language =
    case language of
        English ->
            "Actual run linked"

        Spanish ->
            "Actividad vinculada"


distanceRun : Language -> String
distanceRun language =
    case language of
        English ->
            "Distance run"

        Spanish ->
            "Distancia recorrida"


onTarget : Language -> String
onTarget language =
    case language of
        English ->
            "On target"

        Spanish ->
            "En objetivo"


vsTarget : Language -> String
vsTarget language =
    case language of
        English ->
            "vs Target"

        Spanish ->
            "vs objetivo"


{-| Suffix after a +/- time diff, e.g. "+1:30 vs target".
-}
vsTargetSuffix : Language -> String
vsTargetSuffix language =
    case language of
        English ->
            " vs target"

        Spanish ->
            " vs objetivo"


unlink : Language -> String
unlink language =
    case language of
        English ->
            "Unlink"

        Spanish ->
            "Desvincular"



-- Target panel


targetTime : Language -> String
targetTime language =
    case language of
        English ->
            "Target time"

        Spanish ->
            "Tiempo objetivo"


timeCommitHint : Language -> String
timeCommitHint language =
    case language of
        English ->
            "Tap Tab or click away to commit."

        Spanish ->
            "Pulsa Tab o haz clic fuera para confirmar."


planOver : Language -> String
planOver language =
    case language of
        English ->
            " over"

        Spanish ->
            " de más"


planUnder : Language -> String
planUnder language =
    case language of
        English ->
            " under"

        Spanish ->
            " de menos"


currentSumLabel : Language -> String
currentSumLabel language =
    case language of
        English ->
            "Current sum"

        Spanish ->
            "Suma actual"


{-| The bare word "rest" (e.g. "· rest 5:00") — distinct from `formatRest`,
which formats a duration.
-}
restWord : Language -> String
restWord language =
    case language of
        English ->
            "rest"

        Spanish ->
            "descanso"


aidRestLabel : Language -> String
aidRestLabel language =
    case language of
        English ->
            "Aid rest"

        Spanish ->
            "Descanso"


{-| "N stops" (always count form — for the aid-rest subtitle).
-}
stopsCount : Language -> Int -> String
stopsCount language count =
    String.fromInt count
        ++ " "
        ++ (case language of
                English ->
                    plural count { one = "stop", other = "stops" }

                Spanish ->
                    plural count { one = "parada", other = "paradas" }
           )


avgPace : Language -> String
avgPace language =
    case language of
        English ->
            "Avg pace"

        Spanish ->
            "Ritmo medio"


paceMovingSuffix : Language -> String
paceMovingSuffix language =
    case language of
        English ->
            "/ km · moving"

        Spanish ->
            "/ km · en movimiento"



-- Predictor strip


effortLabel : Language -> String
effortLabel language =
    case language of
        English ->
            "Effort"

        Spanish ->
            "Esfuerzo"


predictedFinish : Language -> String
predictedFinish language =
    case language of
        English ->
            "Predicted finish"

        Spanish ->
            "Llegada estimada"


effortConservative : Language -> String
effortConservative language =
    case language of
        English ->
            "Conservative"

        Spanish ->
            "Conservador"


effortGoal : Language -> String
effortGoal language =
    case language of
        English ->
            "Goal"

        Spanish ->
            "Objetivo"


effortPush : Language -> String
effortPush language =
    case language of
        English ->
            "Push"

        Spanish ->
            "Fuerte"


effortAllIn : Language -> String
effortAllIn language =
    case language of
        English ->
            "All-in"

        Spanish ->
            "Al máximo"


sliderHelp : Language -> String
sliderHelp language =
    case language of
        English ->
            "Drag the slider to dial effort up or down — the target time updates to match."

        Spanish ->
            "Arrastra el control para subir o bajar el esfuerzo — el tiempo objetivo se ajusta."


sliderHelpNoTarget : Language -> String
sliderHelpNoTarget language =
    case language of
        English ->
            "No target set yet. Drag the slider to lock one in, or type a target above."

        Spanish ->
            "Aún no hay objetivo. Arrastra el control para fijar uno, o escribe un objetivo arriba."



-- Tabs + table headers


byKm : Language -> String
byKm language =
    case language of
        English ->
            "By km"

        Spanish ->
            "Por km"


bySection : Language -> String
bySection language =
    case language of
        English ->
            "By section"

        Spanish ->
            "Por tramo"


downloadCsv : Language -> String
downloadCsv language =
    case language of
        English ->
            "Download CSV"

        Spanish ->
            "Descargar CSV"


print : Language -> String
print language =
    case language of
        English ->
            "Print"

        Spanish ->
            "Imprimir"


tapRowHint : Language -> String
tapRowHint language =
    case language of
        English ->
            "Tap a row to edit a km in detail."

        Spanish ->
            "Toca una fila para editar un km en detalle."


colKm : Language -> String
colKm _ =
    "Km"


colSpan : Language -> String
colSpan language =
    case language of
        English ->
            "Span"

        Spanish ->
            "Rango"


{-| Δ-elevation column header. Kept compact (symbol + "ele") in both languages.
-}
colDeltaEle : Language -> String
colDeltaEle _ =
    "Δ ele"


colGrade : Language -> String
colGrade language =
    case language of
        English ->
            "Grade"

        Spanish ->
            "Pendiente"


colPace : Language -> String
colPace language =
    case language of
        English ->
            "Pace"

        Spanish ->
            "Ritmo"


colTime : Language -> String
colTime language =
    case language of
        English ->
            "Time"

        Spanish ->
            "Tiempo"


colActual : Language -> String
colActual language =
    case language of
        English ->
            "Actual"

        Spanish ->
            "Real"


{-| Δ-vs-plan column header. "plan" is a cognate; kept compact in both.
-}
colDeltaVsPlan : Language -> String
colDeltaVsPlan _ =
    "Δ vs plan"


colAvgHr : Language -> String
colAvgHr language =
    case language of
        English ->
            "Avg HR"

        Spanish ->
            "FC media"


colCum : Language -> String
colCum language =
    case language of
        English ->
            "Cum"

        Spanish ->
            "Acum."


colNotesStops : Language -> String
colNotesStops language =
    case language of
        English ->
            "Notes / stops"

        Spanish ->
            "Notas / paradas"


colSection : Language -> String
colSection language =
    case language of
        English ->
            "Section"

        Spanish ->
            "Tramo"


colSectionTime : Language -> String
colSectionTime language =
    case language of
        English ->
            "Section time"

        Spanish ->
            "Tiempo de tramo"


sectionTimeNote : Language -> String
sectionTimeNote language =
    case language of
        English ->
            "Section time and Cum are clock time — moving plus the aid rest taken in that section. Pace is moving only."

        Spanish ->
            "El tiempo de tramo y Acum. son tiempo de reloj — en movimiento más el descanso en avituallamientos del tramo. El ritmo es solo en movimiento."



-- Per-section detail


prevSection : Language -> String
prevSection language =
    case language of
        English ->
            "← Prev section"

        Spanish ->
            "← Tramo anterior"


nextSection : Language -> String
nextSection language =
    case language of
        English ->
            "Next section →"

        Spanish ->
            "Tramo siguiente →"


sectionBreadcrumb : Language -> Int -> Int -> String
sectionBreadcrumb language index total =
    (case language of
        English ->
            "Section "

        Spanish ->
            "Tramo "
    )
        ++ String.fromInt index
        ++ (case language of
                English ->
                    " of "

                Spanish ->
                    " de "
           )
        ++ String.fromInt total


backToTable : Language -> String
backToTable language =
    case language of
        English ->
            "Back to table"

        Spanish ->
            "Volver a la tabla"


sectionNotExist : Language -> String
sectionNotExist language =
    case language of
        English ->
            "This section doesn't exist in this race."

        Spanish ->
            "Este tramo no existe en esta carrera."


sectionActualMissing : Language -> String
sectionActualMissing language =
    case language of
        English ->
            "Actual run is linked, but some km in this section is missing from its trace."

        Spanish ->
            "Hay una actividad vinculada, pero falta algún km de este tramo en su traza."


sectionPlan : Language -> String
sectionPlan language =
    case language of
        English ->
            "Section plan"

        Spanish ->
            "Plan del tramo"


kmsLabel : Language -> String
kmsLabel _ =
    "Kms"


{-| `rest` is the already-formatted rest string.
-}
sectionClockNote : Language -> String -> String
sectionClockNote language rest =
    case language of
        English ->
            "Time is clock time, including " ++ rest ++ " at aid stations in this section. Pace is moving only."

        Spanish ->
            "El tiempo es tiempo de reloj, incluye " ++ rest ++ " en avituallamientos de este tramo. El ritmo es solo en movimiento."


endsAt : Language -> String
endsAt language =
    case language of
        English ->
            "Ends at"

        Spanish ->
            "Termina en"


editAidStationLink : Language -> String
editAidStationLink language =
    case language of
        English ->
            "Edit aid station →"

        Spanish ->
            "Editar avituallamiento →"


sectionFinishes : Language -> String
sectionFinishes language =
    case language of
        English ->
            "🏁 This section finishes the race."

        Spanish ->
            "🏁 Este tramo termina la carrera."


kmsInSection : Language -> String
kmsInSection language =
    case language of
        English ->
            "Kilometers in this section"

        Spanish ->
            "Kilómetros de este tramo"


{-| Section-card header: "Section · <widthKm> km wide · scale <mPerPx> m/px".
The two numbers are already-formatted strings.
-}
sectionCardHeader : Language -> String -> String -> String
sectionCardHeader language widthKm mPerPx =
    case language of
        English ->
            "Section · " ++ widthKm ++ " km wide · scale " ++ mPerPx ++ " m/px"

        Spanish ->
            "Tramo · " ++ widthKm ++ " km de ancho · escala " ++ mPerPx ++ " m/px"



-- Per-km detail


prevKm : Language -> String
prevKm language =
    case language of
        English ->
            "← Prev km"

        Spanish ->
            "← Km anterior"


nextKm : Language -> String
nextKm language =
    case language of
        English ->
            "Next km →"

        Spanish ->
            "Km siguiente →"


kmBreadcrumb : Language -> Int -> Int -> String
kmBreadcrumb language index total =
    "Km "
        ++ String.fromInt index
        ++ (case language of
                English ->
                    " of "

                Spanish ->
                    " de "
           )
        ++ String.fromInt total


kmNotExist : Language -> String
kmNotExist language =
    case language of
        English ->
            "This km doesn't exist in this race."

        Spanish ->
            "Este km no existe en esta carrera."


{-| Km-card header: "Km <n> · 1:1 scale (1 px = <mPerPx> m)". `index` is the
1-based km number; `mPerPx` is already formatted.
-}
kmCardHeader : Language -> Int -> String -> String
kmCardHeader language index mPerPx =
    "Km "
        ++ String.fromInt index
        ++ (case language of
                English ->
                    " · 1:1 scale (1 px = "

                Spanish ->
                    " · escala 1:1 (1 px = "
           )
        ++ mPerPx
        ++ " m)"


modeManual : Language -> String
modeManual _ =
    "Manual"


modeAuto : Language -> String
modeAuto _ =
    "Auto"


planThisKm : Language -> String
planThisKm language =
    case language of
        English ->
            "Plan this km"

        Spanish ->
            "Planifica este km"


slopeLabel : Language -> String
slopeLabel language =
    case language of
        English ->
            "Slope"

        Spanish ->
            "Pendiente"


autoSuffix : Language -> String
autoSuffix _ =
    " (auto)"


{-| `rest` is the already-formatted rest string.
-}
kmClockNote : Language -> String -> String
kmClockNote language rest =
    case language of
        English ->
            "Target time is clock time, including " ++ rest ++ " at the aid station. Pace is moving only."

        Spanish ->
            "El tiempo objetivo es tiempo de reloj, incluye " ++ rest ++ " en el avituallamiento. El ritmo es solo en movimiento."


kmActualMissing : Language -> String
kmActualMissing language =
    case language of
        English ->
            "Actual run linked, but this km isn't in its trace."

        Spanish ->
            "Actividad vinculada, pero este km no está en su traza."


resetToAuto : Language -> String
resetToAuto language =
    case language of
        English ->
            "Reset to auto (GAP)"

        Spanish ->
            "Restablecer a auto (GAP)"


resetToAutoHelp : Language -> String
resetToAutoHelp language =
    case language of
        English ->
            "Auto-distributed from your target total time using the slope of this km."

        Spanish ->
            "Distribuido automáticamente desde tu tiempo objetivo total según la pendiente de este km."


kmNotesPlaceholder : Language -> String
kmNotesPlaceholder language =
    case language of
        English ->
            "Anything to remember about this km — surface, exposure, mental cues…"

        Spanish ->
            "Algo que recordar de este km — terreno, exposición, recordatorios mentales…"


aidStationsInKm : Language -> String
aidStationsInKm language =
    case language of
        English ->
            "Aid stations in this km"

        Spanish ->
            "Avituallamientos en este km"



-- PROFILE PAGE (TASK-066)


profileIntro : Language -> String
profileIntro language =
    case language of
        English ->
            "Population-tier defaults seed the predictor. Tweak any field; values stick on save."

        Spanish ->
            "Los valores por nivel poblacional alimentan el predictor. Ajusta cualquier campo; se guardan al guardar."


resetToPreset : Language -> String
resetToPreset language =
    case language of
        English ->
            "Reset to preset"

        Spanish ->
            "Restablecer a preset"


saveProfile : Language -> String
saveProfile language =
    case language of
        English ->
            "Save profile"

        Spanish ->
            "Guardar perfil"


savedConfirm : Language -> String
savedConfirm language =
    case language of
        English ->
            "Saved ✓"

        Spanish ->
            "Guardado ✓"


fieldVertRate : Language -> String
fieldVertRate language =
    case language of
        English ->
            "Vertical rate"

        Spanish ->
            "Ritmo vertical"


fieldVertRateHint : Language -> String
fieldVertRateHint language =
    case language of
        English ->
            "m / h on moderate climbs (~10-20% grade). Strong mid-pack ≈ 850."

        Spanish ->
            "m / h en subidas moderadas (~10-20% de pendiente). Intermedio avanzado ≈ 850."


fieldFlatPace : Language -> String
fieldFlatPace language =
    case language of
        English ->
            "Flat trail pace"

        Spanish ->
            "Ritmo en llano"


fieldFlatPaceHint : Language -> String
fieldFlatPaceHint language =
    case language of
        English ->
            "On moderate trail at sustainable effort. Add 30-60 s/km vs road pace."

        Spanish ->
            "En sendero moderado a esfuerzo sostenible. Suma 30-60 s/km respecto al ritmo en asfalto."


fieldFatigueThreshold : Language -> String
fieldFatigueThreshold language =
    case language of
        English ->
            "Fatigue threshold"

        Spanish ->
            "Umbral de fatiga"


fieldFatigueThresholdHint : Language -> String
fieldFatigueThresholdHint language =
    case language of
        English ->
            "Hours of effort before pace inflation starts."

        Spanish ->
            "Horas de esfuerzo antes de que el ritmo empiece a inflarse."


fieldFatigueSlope : Language -> String
fieldFatigueSlope language =
    case language of
        English ->
            "Fatigue slope"

        Spanish ->
            "Pendiente de fatiga"


fieldFatigueSlopeHint : Language -> String
fieldFatigueSlopeHint language =
    case language of
        English ->
            "Pace inflation per hour after the threshold."

        Spanish ->
            "Inflación del ritmo por hora tras el umbral."


fieldDescentSkill : Language -> String
fieldDescentSkill language =
    case language of
        English ->
            "Descent skill"

        Spanish ->
            "Habilidad en bajada"


fieldDescentSkillHint : Language -> String
fieldDescentSkillHint language =
    case language of
        English ->
            "Faster descenders run technical downhill closer to runnable pace."

        Spanish ->
            "Quienes bajan más rápido corren las bajadas técnicas a un ritmo más cercano al corrible."


fieldTechnicality : Language -> String
fieldTechnicality language =
    case language of
        English ->
            "Technicality"

        Spanish ->
            "Tecnicidad"


fieldTechnicalityHint : Language -> String
fieldTechnicalityHint language =
    case language of
        English ->
            "Slows flat pace on rooty / rocky terrain."

        Spanish ->
            "Ralentiza el ritmo en llano sobre terreno con raíces / rocas."


fieldAidStops : Language -> String
fieldAidStops language =
    case language of
        English ->
            "Aid stops"

        Spanish ->
            "Paradas en avituallamiento"


fieldAidStopsHint : Language -> String
fieldAidStopsHint language =
    case language of
        English ->
            "Default time per aid station. Override per race later."

        Spanish ->
            "Tiempo por defecto en cada avituallamiento. Ajústalo por carrera más tarde."


hrSectionIntro : Language -> String
hrSectionIntro language =
    case language of
        English ->
            "Optional — used by future HR-based calibration. Leave empty if you don't have the numbers."

        Spanish ->
            "Opcional — para una futura calibración por FC. Déjalo vacío si no tienes los datos."


fieldLthr : Language -> String
fieldLthr language =
    case language of
        English ->
            "Lactate threshold HR"

        Spanish ->
            "FC umbral de lactato"


fieldLthrHint : Language -> String
fieldLthrHint language =
    case language of
        English ->
            "Approx 95% of max HR for trained runners."

        Spanish ->
            "Aprox. 95% de la FC máxima en corredores entrenados."


fieldMaxHr : Language -> String
fieldMaxHr language =
    case language of
        English ->
            "Max HR"

        Spanish ->
            "FC máxima"


fieldMaxHrHint : Language -> String
fieldMaxHrHint language =
    case language of
        English ->
            "Highest sustained beat-rate you've actually hit."

        Spanish ->
            "La frecuencia más alta que realmente has sostenido."


unitHours : Language -> String
unitHours language =
    case language of
        English ->
            "hours"

        Spanish ->
            "horas"



-- CALIBRATION PANEL


calibrateTitle : Language -> String
calibrateTitle language =
    case language of
        English ->
            "Calibrate from your runs"

        Spanish ->
            "Calibra desde tus actividades"


calibrateEmpty : Language -> String
calibrateEmpty language =
    case language of
        English ->
            "Link an actual run to a race (via Strava or a GPX upload) to calibrate your climb rate and flat pace from real data."

        Spanish ->
            "Vincula una actividad real a una carrera (por Strava o subiendo un GPX) para calibrar tu ritmo de ascenso y tu ritmo en llano con datos reales."


calibClimbRate : Language -> String
calibClimbRate language =
    case language of
        English ->
            "Climb rate "

        Spanish ->
            "Ritmo de ascenso "


calibFlatPace : Language -> String
calibFlatPace language =
    case language of
        English ->
            "Flat pace "

        Spanish ->
            "Ritmo en llano "


{-| " — from N climb km · current " (the value + unit follow).
-}
calibClimbFrom : Language -> Int -> String
calibClimbFrom language n =
    case language of
        English ->
            " — from " ++ String.fromInt n ++ " climb km · current "

        Spanish ->
            " — de " ++ String.fromInt n ++ " km de subida · actual "


{-| " — from N runnable km · current " (the value + unit follow).
-}
calibFlatFrom : Language -> Int -> String
calibFlatFrom language n =
    case language of
        English ->
            " — from " ++ String.fromInt n ++ " runnable km · current "

        Spanish ->
            " — de " ++ String.fromInt n ++ " km corribles · actual "


calibContributors : Language -> String
calibContributors language =
    case language of
        English ->
            "From your linked runs: "

        Spanish ->
            "De tus actividades vinculadas: "


apply : Language -> String
apply language =
    case language of
        English ->
            "Apply"

        Spanish ->
            "Aplicar"



-- IDENTITY CARD


identityCardTitle : Language -> String
identityCardTitle language =
    case language of
        English ->
            "Your name (for sharing)"

        Spanish ->
            "Tu nombre (para compartir)"


identityCardHelp : Language -> String
identityCardHelp language =
    case language of
        English ->
            "How collaborators see your changes when you share a plan. Separate from the performance settings below — renaming relabels every plan you own."

        Spanish ->
            "Cómo ven tus cambios los colaboradores cuando compartes un plan. Es independiente de los ajustes de rendimiento de abajo — renombrar reetiqueta cada plan que posees."


{-| "You are <name>." — split so the name renders bold between the two parts.
-}
youArePrefix : Language -> String
youArePrefix language =
    case language of
        English ->
            "You are "

        Spanish ->
            "Eres "


newNamePlaceholder : Language -> String
newNamePlaceholder language =
    case language of
        English ->
            "New name"

        Spanish ->
            "Nombre nuevo"


rename : Language -> String
rename language =
    case language of
        English ->
            "Rename"

        Spanish ->
            "Renombrar"


{-| Pre-identity hint: split around the ".trail" span. Prefix + suffix.
-}
identityDeferredPrefix : Language -> String
identityDeferredPrefix language =
    case language of
        English ->
            "We'll ask for your name the first time you share a plan (export a "

        Spanish ->
            "Te pediremos tu nombre la primera vez que compartas un plan (al exportar un "


identityDeferredSuffix : Language -> String
identityDeferredSuffix language =
    case language of
        English ->
            " file)."

        Spanish ->
            ")."



-- STRAVA


stravaTitle : Language -> String
stravaTitle language =
    case language of
        English ->
            "Strava integration"

        Spanish ->
            "Integración con Strava"


stravaHelp : Language -> String
stravaHelp language =
    case language of
        English ->
            "Optional. Lets you link a completed race directly from Strava and (later) calibrate the profile from past activities. App works fully offline without it."

        Spanish ->
            "Opcional. Te permite vincular una carrera terminada directamente desde Strava y (más adelante) calibrar el perfil con actividades pasadas. La app funciona sin conexión sin ella."


connected : Language -> String
connected language =
    case language of
        English ->
            "Connected"

        Spanish ->
            "Conectado"


disconnect : Language -> String
disconnect language =
    case language of
        English ->
            "Disconnect"

        Spanish ->
            "Desconectar"


connectStrava : Language -> String
connectStrava language =
    case language of
        English ->
            "Connect Strava"

        Spanish ->
            "Conectar Strava"


backendPrefix : Language -> String
backendPrefix language =
    case language of
        English ->
            "Backend: "

        Spanish ->
            "Backend: "



-- STRAVA ACTIVITY PICKER (deferred from TASK-065)


stravaSearchHeading : Language -> String
stravaSearchHeading language =
    case language of
        English ->
            "Search Strava activities"

        Spanish ->
            "Buscar actividades de Strava"


stravaRecentHeading : Language -> String
stravaRecentHeading language =
    case language of
        English ->
            "Recent Strava activities (60 days)"

        Spanish ->
            "Actividades recientes de Strava (60 días)"


stravaSearching : Language -> String
stravaSearching language =
    case language of
        English ->
            "Searching…"

        Spanish ->
            "Buscando…"


stravaLoadingRecent : Language -> String
stravaLoadingRecent language =
    case language of
        English ->
            "Loading recent activities…"

        Spanish ->
            "Cargando actividades recientes…"


stravaFetchingStreams : Language -> Int -> String
stravaFetchingStreams language actId =
    case language of
        English ->
            "Fetching streams for activity " ++ String.fromInt actId ++ "…"

        Spanish ->
            "Obteniendo datos de la actividad " ++ String.fromInt actId ++ "…"


stravaError : Language -> String
stravaError language =
    case language of
        English ->
            "Strava error"

        Spanish ->
            "Error de Strava"


close : Language -> String
close language =
    case language of
        English ->
            "Close"

        Spanish ->
            "Cerrar"


stravaNoMatch : Language -> String
stravaNoMatch language =
    case language of
        English ->
            "No activities match this search."

        Spanish ->
            "Ninguna actividad coincide con esta búsqueda."


stravaNoneRecent : Language -> String
stravaNoneRecent language =
    case language of
        English ->
            "No activities found in the past 60 days. Try searching."

        Spanish ->
            "No se encontraron actividades en los últimos 60 días. Prueba a buscar."


stravaSearchPlaceholder : Language -> String
stravaSearchPlaceholder language =
    case language of
        English ->
            "Search activity names · full history"

        Spanish ->
            "Buscar por nombre de actividad · historial completo"



-- ELEVATION TOOLBAR (Profile.elm)


fitWidth : Language -> String
fitWidth language =
    case language of
        English ->
            "Fit width"

        Spanish ->
            "Ajustar al ancho"


trueScale : Language -> String
trueScale language =
    case language of
        English ->
            "True scale"

        Spanish ->
            "Escala real"


{-| Elevation legend: "1 px = <mpp> m (both axes · 1:1)". `mpp` is preformatted.
-}
elevationLegend : Language -> String -> String
elevationLegend language mpp =
    case language of
        English ->
            "1 px = " ++ mpp ++ " m (both axes · 1:1)"

        Spanish ->
            "1 px = " ++ mpp ++ " m (ambos ejes · 1:1)"



-- ATHLETE-PROFILE display labels (localized; the English `AthleteProfile.*Label`
-- stays the canonical value/selection key — see the profile <select> round-trip).


preset : Language -> Preset -> String
preset language p =
    case language of
        English ->
            AthleteProfile.presetLabel p

        Spanish ->
            case p of
                Beginner ->
                    "Principiante"

                MidPack ->
                    "Intermedio"

                StrongMidPack ->
                    "Intermedio avanzado"

                SubElite ->
                    "Subélite"


descentSkill : Language -> DescentSkill -> String
descentSkill language d =
    case language of
        English ->
            AthleteProfile.descentSkillLabel d

        Spanish ->
            case d of
                DescCautious ->
                    "Cauteloso"

                DescAverage ->
                    "Normal"

                DescConfident ->
                    "Seguro"

                DescExpert ->
                    "Experto"


techSkill : Language -> TechSkill -> String
techSkill language t =
    case language of
        English ->
            AthleteProfile.techSkillLabel t

        Spanish ->
            case t of
                TechNovice ->
                    "Principiante"

                TechAverage ->
                    "Normal"

                TechExperienced ->
                    "Con experiencia"

                TechExpert ->
                    "Experto"


aidStyle : Language -> AidStyle -> String
aidStyle language a =
    case language of
        English ->
            AthleteProfile.aidStyleLabel a

        Spanish ->
            case a of
                AidElite ->
                    "Élite (1 min)"

                AidLean ->
                    "Ágil (3 min)"

                AidStandard ->
                    "Estándar (7-8 min)"

                AidRelaxed ->
                    "Relajado (15 min)"



-- ACTIVITY FEED / CHANGELOG (TASK-067)


activityLabel : Language -> String
activityLabel language =
    case language of
        English ->
            "Activity"

        Spanish ->
            "Actividad"


activitySubtitle : Language -> String
activitySubtitle language =
    case language of
        English ->
            "Every change to this plan, newest first"

        Spanish ->
            "Cada cambio de este plan, lo más reciente primero"


noChangesYet : Language -> String
noChangesYet language =
    case language of
        English ->
            "No changes recorded yet."

        Spanish ->
            "Aún no hay cambios registrados."


{-| Person label for "your own" entries (also used by the merge review).
-}
you : Language -> String
you language =
    case language of
        English ->
            "You"

        Spanish ->
            "Tú"


someone : Language -> String
someone language =
    case language of
        English ->
            "Someone"

        Spanish ->
            "Alguien"


relativeJustNow : Language -> String
relativeJustNow language =
    case language of
        English ->
            "just now"

        Spanish ->
            "ahora mismo"


{-| Wrap a coarse magnitude ("5m"/"3h"/"2d") as a relative time. English suffixes
"ago"; Spanish prefixes "hace".
-}
relativeAgo : Language -> String -> String
relativeAgo language magnitude =
    case language of
        English ->
            magnitude ++ " ago"

        Spanish ->
            "hace " ++ magnitude



-- MODALS + TOASTS (TASK-068)


deleteRaceTitle : Language -> String
deleteRaceTitle language =
    case language of
        English ->
            "Delete race?"

        Spanish ->
            "¿Eliminar carrera?"


deleteRaceBody : Language -> String -> String
deleteRaceBody language raceName =
    case language of
        English ->
            "This will remove “" ++ raceName ++ "” and any planning data attached to it. This cannot be undone."

        Spanish ->
            "Esto eliminará “" ++ raceName ++ "” y todos los datos de planificación asociados. No se puede deshacer."


delete : Language -> String
delete language =
    case language of
        English ->
            "Delete"

        Spanish ->
            "Eliminar"


{-| Accessible label for the race-card delete button (aria-label + title).
-}
deleteRaceAction : Language -> String
deleteRaceAction language =
    case language of
        English ->
            "Delete race"

        Spanish ->
            "Eliminar carrera"


storageErrorTitle : Language -> String
storageErrorTitle language =
    case language of
        English ->
            "Storage error"

        Spanish ->
            "Error de almacenamiento"



-- Identity flows


whatsYourName : Language -> String
whatsYourName language =
    case language of
        English ->
            "What's your name?"

        Spanish ->
            "¿Cómo te llamas?"


nameSubtitleExport : Language -> String
nameSubtitleExport language =
    case language of
        English ->
            "Your plans and changes are labelled with this name when you share them. You can rename yourself any time on the Profile page."

        Spanish ->
            "Tus planes y cambios se etiquetan con este nombre al compartirlos. Puedes renombrarte cuando quieras en la página de Perfil."


nameSubtitleReviewer : Language -> String
nameSubtitleReviewer language =
    case language of
        English ->
            "So your suggestions on this plan are attributed to you."

        Spanish ->
            "Para que tus sugerencias en este plan se te atribuyan."


saveAndExport : Language -> String
saveAndExport language =
    case language of
        English ->
            "Save & export"

        Spanish ->
            "Guardar y exportar"


saveAndImport : Language -> String
saveAndImport language =
    case language of
        English ->
            "Save & import"

        Spanish ->
            "Guardar e importar"


namePlaceholder : Language -> String
namePlaceholder language =
    case language of
        English ->
            "e.g. Alex"

        Spanish ->
            "p. ej. Alex"


whosePlan : Language -> String
whosePlan language =
    case language of
        English ->
            "Whose plan is this?"

        Spanish ->
            "¿De quién es este plan?"


{-| Suffix after the quoted plan name: "” was shared by <owner>."
-}
ownershipSharedBy : Language -> String -> String
ownershipSharedBy language owner =
    case language of
        English ->
            "” was shared by " ++ owner ++ "."

        Spanish ->
            "” lo compartió " ++ owner ++ "."


imOwner : Language -> String -> String
imOwner language owner =
    case language of
        English ->
            "I'm " ++ owner

        Spanish ->
            "Soy " ++ owner


imOwnerDesc : Language -> String
imOwnerDesc language =
    case language of
        English ->
            "Claim it as yours — this device is recognized as the same person."

        Spanish ->
            "Reclámalo como tuyo — este dispositivo se reconoce como la misma persona."


someoneElsesPlan : Language -> String
someoneElsesPlan language =
    case language of
        English ->
            "Someone else's plan"

        Spanish ->
            "El plan de otra persona"


someoneElsesDesc : Language -> String -> String
someoneElsesDesc language owner =
    case language of
        English ->
            "Import it as " ++ owner ++ "'s — you're reviewing."

        Spanish ->
            "Impórtalo como de " ++ owner ++ " — estás revisando."


linkDeviceTitle : Language -> String
linkDeviceTitle language =
    case language of
        English ->
            "Link this device?"

        Spanish ->
            "¿Vincular este dispositivo?"


{-| "This device is already <myName>. Link it to " — the owner name (a span) and
the suffix follow.
-}
linkBodyPrefix : Language -> String -> String
linkBodyPrefix language myName =
    case language of
        English ->
            "This device is already " ++ myName ++ ". Link it to "

        Spanish ->
            "Este dispositivo ya es " ++ myName ++ ". Vincúlalo a "


linkBodySuffix : Language -> String
linkBodySuffix language =
    case language of
        English ->
            " so they're recognized as the same person?"

        Spanish ->
            " para que se reconozcan como la misma persona?"


linkExplain : Language -> String -> String
linkExplain language owner =
    case language of
        English ->
            "Your plans on this device move to " ++ owner ++ "'s identity. Use this when you've imported your own plan from another device."

        Spanish ->
            "Tus planes en este dispositivo pasan a la identidad de " ++ owner ++ ". Úsalo cuando hayas importado tu propio plan desde otro dispositivo."


notNow : Language -> String
notNow language =
    case language of
        English ->
            "Not now"

        Spanish ->
            "Ahora no"


link : Language -> String
link language =
    case language of
        English ->
            "Link"

        Spanish ->
            "Vincular"



-- Merge review


{-| Modal title: "<name>'s suggestions".
-}
suggestionsTitle : Language -> String -> String
suggestionsTitle language name =
    case language of
        English ->
            name ++ "’s suggestions"

        Spanish ->
            "Sugerencias de " ++ name


changesOverlap : Language -> Int -> String
changesOverlap language count =
    case language of
        English ->
            String.fromInt count
                ++ plural count { one = " change overlaps", other = " changes overlap" }
                ++ " with edits you made"

        Spanish ->
            String.fromInt count
                ++ plural count { one = " cambio coincide", other = " cambios coinciden" }
                ++ " con tus ediciones"


{-| "M other change(s) from <name> was/were added automatically." (compound plural).
-}
autoMerged : Language -> Int -> String -> String
autoMerged language count name =
    case language of
        English ->
            String.fromInt count
                ++ plural count { one = " other change from ", other = " other changes from " }
                ++ name
                ++ plural count { one = " was added automatically.", other = " were added automatically." }

        Spanish ->
            "Se "
                ++ plural count { one = "agregó", other = "agregaron" }
                ++ " automáticamente "
                ++ String.fromInt count
                ++ plural count { one = " cambio más de ", other = " cambios más de " }
                ++ name
                ++ "."


editToCombine : Language -> String
editToCombine language =
    case language of
        English ->
            "Edit to combine both notes."

        Spanish ->
            "Edita para combinar ambas notas."


discardConfirm : Language -> String
discardConfirm language =
    case language of
        English ->
            "Discard your choices and keep your own version?"

        Spanish ->
            "¿Descartar tus elecciones y conservar tu versión?"


keepEditing : Language -> String
keepEditing language =
    case language of
        English ->
            "Keep editing"

        Spanish ->
            "Seguir editando"


discard : Language -> String
discard language =
    case language of
        English ->
            "Discard"

        Spanish ->
            "Descartar"


chosenOfN : Language -> Int -> Int -> String
chosenOfN language chosen total =
    case language of
        English ->
            String.fromInt chosen ++ " of " ++ String.fromInt total ++ " chosen"

        Spanish ->
            String.fromInt chosen ++ " de " ++ String.fromInt total ++ " elegidas"


keepMyVersion : Language -> String
keepMyVersion language =
    case language of
        English ->
            "Keep my version"

        Spanish ->
            "Conservar mi versión"


applyChanges : Language -> String
applyChanges language =
    case language of
        English ->
            "Apply changes"

        Spanish ->
            "Aplicar cambios"
