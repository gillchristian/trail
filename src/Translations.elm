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


{-| `prevKm` is the already-formatted "X.X" km string.
-}
modeHelpFromPrevious : Language -> String -> String
modeHelpFromPrevious language prevKm =
    case language of
        English ->
            "Distance added on top of " ++ prevKm ++ " km (the previous stop, or start if there is none)."

        Spanish ->
            "Distancia que se suma a " ++ prevKm ++ " km (la parada anterior, o la salida si no hay)."


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
