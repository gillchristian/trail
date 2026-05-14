module Main exposing (main)

{-| TASK-005.

`Browser.application` shell with hash routing, IndexedDB-backed
persistence, race index, race-detail with 1:1 elevation profile +
aid-station CRUD (add by distance-from-start or distance-from-
previous, edit, delete). Markers render on the profile chart.

The whole UI still lives in this module. We'll split per-page when
a page passes ~250 lines on its own.

-}

import Browser
import Browser.Events
import Browser.Navigation as Nav
import Dict exposing (Dict)
import File exposing (File)
import File.Select as Select
import Gpx exposing (Track)
import Html exposing (Html, a, button, div, h1, h2, h3, input, label, p, span, text, textarea)
import Html.Attributes as A exposing (class, classList)
import Html.Events as E exposing (onClick, onInput, preventDefaultOn)
import Html.Lazy
import Json.Decode as D
import Json.Encode as Encode
import Profile exposing (Marker, ScaleMode(..))
import Route exposing (Route)
import Storage
import Task
import Types
    exposing
        ( AidStation
        , Race
        , RaceId
        , Service
        , allServices
        , encodeRace
        , raceIdFromString
        , raceIdToString
        , serviceIcon
        , serviceLabel
        , sortAidStations
        )
import Url exposing (Url)



-- ============================================================
-- MAIN
-- ============================================================


main : Program Flags Model Msg
main =
    Browser.application
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        , onUrlChange = UrlChanged
        , onUrlRequest = LinkClicked
        }


type alias Flags =
    { width : Float
    , now : Int
    }



-- ============================================================
-- MODEL
-- ============================================================


type RacesState
    = LoadingRaces
    | LoadedRaces (List Race)


type UploadState
    = NotUploading
    | Parsing String
    | UploadFailed String String
    | Persisting String


type AidFormMode
    = FromStart
    | FromPrevious


type alias AidForm =
    { editing : Maybe String -- aid id if editing; Nothing if adding
    , name : String
    , mode : AidFormMode
    , distanceKm : String
    , restMinutes : String
    , services : List Service
    , error : Maybe String
    }


type AidEditor
    = AidClosed
    | AidOpen AidForm


type alias Model =
    { key : Nav.Key
    , route : Route
    , now : Int
    , viewportWidth : Float
    , races : RacesState
    , parsedTracks : Dict String Track
    , scaleMode : ScaleMode
    , upload : UploadState
    , dragOver : Bool
    , storageError : Maybe String
    , pendingDelete : Maybe RaceId
    , aidEditor : AidEditor
    }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { key = key
      , route = Route.fromUrl url
      , now = flags.now
      , viewportWidth = flags.width
      , races = LoadingRaces
      , parsedTracks = Dict.empty
      , scaleMode = FitWidth
      , upload = NotUploading
      , dragOver = False
      , storageError = Nothing
      , pendingDelete = Nothing
      , aidEditor = AidClosed
      }
    , Storage.loadAll
    )



-- ============================================================
-- MSG / UPDATE
-- ============================================================


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | WindowResized Int Int
    | SetScaleMode ScaleMode
      -- upload
    | DragEnter
    | DragLeave
    | OpenPicker
    | GotFiles File (List File)
    | PickedFile File
    | GotContent String String
      -- storage
    | RacesLoaded Encode.Value
    | RaceSaved Encode.Value
    | RaceDeleted String
    | StorageError String
      -- delete race
    | RequestDelete RaceId
    | ConfirmDelete
    | CancelDelete
      -- aid stations
    | OpenAddAid
    | OpenEditAid AidStation
    | CloseAid
    | AidSetName String
    | AidSetMode AidFormMode
    | AidSetDistanceKm String
    | AidSetRestMinutes String
    | AidToggleService Service
    | AidSubmit
    | AidDelete String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            ( { model | route = Route.fromUrl url, pendingDelete = Nothing, aidEditor = AidClosed }, Cmd.none )

        WindowResized w _ ->
            ( { model | viewportWidth = toFloat w }, Cmd.none )

        SetScaleMode m ->
            ( { model | scaleMode = m }, Cmd.none )

        DragEnter ->
            ( { model | dragOver = True }, Cmd.none )

        DragLeave ->
            ( { model | dragOver = False }, Cmd.none )

        OpenPicker ->
            ( model, Select.file [ "application/gpx+xml", ".gpx" ] PickedFile )

        GotFiles file _ ->
            ( { model | dragOver = False, upload = Parsing (File.name file) }
            , readFile file
            )

        PickedFile file ->
            ( { model | upload = Parsing (File.name file) }
            , readFile file
            )

        GotContent fileName content ->
            case Gpx.parseGPX content of
                Err err ->
                    ( { model | upload = UploadFailed fileName err }, Cmd.none )

                Ok track ->
                    let
                        draft =
                            buildDraftRace model.now track content
                    in
                    ( { model | upload = Persisting fileName }
                    , Storage.saveRace (encodeRace draft)
                    )

        RacesLoaded value ->
            case D.decodeValue Types.decodeRaces value of
                Ok races ->
                    let
                        sorted =
                            sortRaces races
                    in
                    ( { model
                        | races = LoadedRaces sorted
                        , parsedTracks = buildTrackCache sorted Dict.empty
                      }
                    , Cmd.none
                    )

                Err err ->
                    ( { model
                        | races = LoadedRaces []
                        , storageError = Just ("decode races: " ++ D.errorToString err)
                      }
                    , Cmd.none
                    )

        RaceSaved value ->
            case D.decodeValue Types.decodeRace value of
                Ok race ->
                    let
                        existing =
                            currentRaces model

                        merged =
                            race :: List.filter (\r -> r.id /= race.id) existing

                        navCmd =
                            case model.route of
                                Route.RaceDetail rid ->
                                    if raceIdToString rid == raceIdToString race.id then
                                        -- already on detail page, no nav needed
                                        Cmd.none

                                    else
                                        Cmd.none

                                _ ->
                                    -- coming from upload — navigate to the new race
                                    Nav.pushUrl model.key (Route.toString (Route.RaceDetail race.id))
                    in
                    ( { model
                        | races = LoadedRaces (sortRaces merged)
                        , parsedTracks = cacheTrack race model.parsedTracks
                        , upload = NotUploading
                        , aidEditor = AidClosed
                      }
                    , navCmd
                    )

                Err err ->
                    ( { model
                        | upload = NotUploading
                        , storageError = Just ("decode saved race: " ++ D.errorToString err)
                      }
                    , Cmd.none
                    )

        RaceDeleted idStr ->
            let
                rid =
                    raceIdFromString idStr

                kept =
                    List.filter (\r -> r.id /= rid) (currentRaces model)
            in
            ( { model
                | races = LoadedRaces kept
                , parsedTracks = Dict.remove idStr model.parsedTracks
                , pendingDelete = Nothing
              }
            , if currentRouteIs (Route.RaceDetail rid) model.route then
                Nav.pushUrl model.key (Route.toString Route.Index)

              else
                Cmd.none
            )

        StorageError err ->
            ( { model | storageError = Just err, upload = NotUploading }, Cmd.none )

        RequestDelete rid ->
            ( { model | pendingDelete = Just rid }, Cmd.none )

        ConfirmDelete ->
            case model.pendingDelete of
                Just rid ->
                    ( model, Storage.deleteRace (raceIdToString rid) )

                Nothing ->
                    ( model, Cmd.none )

        CancelDelete ->
            ( { model | pendingDelete = Nothing }, Cmd.none )

        OpenAddAid ->
            ( { model | aidEditor = AidOpen (emptyAidForm Nothing) }, Cmd.none )

        OpenEditAid aid ->
            ( { model | aidEditor = AidOpen (aidFormFromExisting aid) }, Cmd.none )

        CloseAid ->
            ( { model | aidEditor = AidClosed }, Cmd.none )

        AidSetName s ->
            ( updateAidForm (\f -> { f | name = s, error = Nothing }) model, Cmd.none )

        AidSetMode m ->
            ( updateAidForm (\f -> { f | mode = m, error = Nothing }) model, Cmd.none )

        AidSetDistanceKm s ->
            ( updateAidForm (\f -> { f | distanceKm = s, error = Nothing }) model, Cmd.none )

        AidSetRestMinutes s ->
            ( updateAidForm (\f -> { f | restMinutes = s, error = Nothing }) model, Cmd.none )

        AidToggleService s ->
            ( updateAidForm (\f -> { f | services = toggleService s f.services }) model, Cmd.none )

        AidSubmit ->
            case ( model.aidEditor, currentRace model ) of
                ( AidOpen form, Just race ) ->
                    case validateAidForm form race of
                        Err err ->
                            ( updateAidForm (\f -> { f | error = Just err }) model, Cmd.none )

                        Ok aid ->
                            let
                                updatedRace =
                                    case form.editing of
                                        Just existingId ->
                                            { race
                                                | aidStations =
                                                    sortAidStations
                                                        (List.map
                                                            (\a ->
                                                                if a.id == existingId then
                                                                    aid

                                                                else
                                                                    a
                                                            )
                                                            race.aidStations
                                                        )
                                            }

                                        Nothing ->
                                            { race
                                                | aidStations = sortAidStations (aid :: race.aidStations)
                                                , aidStationSeq = race.aidStationSeq + 1
                                            }
                            in
                            ( model, Storage.saveRace (encodeRace updatedRace) )

                _ ->
                    ( model, Cmd.none )

        AidDelete aidId ->
            case currentRace model of
                Just race ->
                    let
                        updatedRace =
                            { race | aidStations = List.filter (\a -> a.id /= aidId) race.aidStations }
                    in
                    ( model, Storage.saveRace (encodeRace updatedRace) )

                Nothing ->
                    ( model, Cmd.none )


currentRaces : Model -> List Race
currentRaces model =
    case model.races of
        LoadedRaces rs ->
            rs

        LoadingRaces ->
            []


currentRace : Model -> Maybe Race
currentRace model =
    case model.route of
        Route.RaceDetail rid ->
            currentRaces model
                |> List.filter (\r -> raceIdToString r.id == raceIdToString rid)
                |> List.head

        _ ->
            Nothing


currentRouteIs : Route -> Route -> Bool
currentRouteIs target current =
    case ( target, current ) of
        ( Route.RaceDetail a, Route.RaceDetail b ) ->
            raceIdToString a == raceIdToString b

        _ ->
            False


sortRaces : List Race -> List Race
sortRaces =
    List.sortBy (\r -> -r.createdAt)


buildTrackCache : List Race -> Dict String Track -> Dict String Track
buildTrackCache races existing =
    List.foldl cacheTrack existing races


cacheTrack : Race -> Dict String Track -> Dict String Track
cacheTrack race cache =
    let
        key =
            raceIdToString race.id
    in
    case Dict.get key cache of
        Just _ ->
            cache

        Nothing ->
            case Gpx.parseGPX race.gpxText of
                Ok track ->
                    Dict.insert key track cache

                Err _ ->
                    cache


buildDraftRace : Int -> Track -> String -> Race
buildDraftRace now track gpxText =
    { id = raceIdFromString ""
    , name = track.name
    , date = Nothing
    , location = ""
    , url = ""
    , notes = ""
    , coverImage = Nothing
    , distance = track.totalDist
    , gain = track.gain
    , loss = track.loss
    , gpxText = gpxText
    , createdAt = now
    , aidStations = []
    , aidStationSeq = 0
    }


readFile : File -> Cmd Msg
readFile file =
    Task.perform (GotContent (File.name file)) (File.toString file)



-- AID FORM HELPERS


emptyAidForm : Maybe String -> AidForm
emptyAidForm editingId =
    { editing = editingId
    , name = ""
    , mode = FromPrevious
    , distanceKm = ""
    , restMinutes = "2"
    , services = [ Types.Water ]
    , error = Nothing
    }


aidFormFromExisting : AidStation -> AidForm
aidFormFromExisting aid =
    { editing = Just aid.id
    , name = aid.name
    , mode = FromStart
    , distanceKm = formatFloat 2 (aid.distance / 1000)
    , restMinutes = String.fromInt (aid.restSeconds // 60)
    , services = aid.services
    , error = Nothing
    }


updateAidForm : (AidForm -> AidForm) -> Model -> Model
updateAidForm f model =
    case model.aidEditor of
        AidOpen form ->
            { model | aidEditor = AidOpen (f form) }

        AidClosed ->
            model


toggleService : Service -> List Service -> List Service
toggleService s services =
    if List.member s services then
        List.filter (\x -> x /= s) services

    else
        s :: services


validateAidForm : AidForm -> Race -> Result String AidStation
validateAidForm form race =
    let
        trimmedName =
            String.trim form.name

        kmRaw =
            String.trim (String.replace "," "." form.distanceKm)

        restRaw =
            String.trim form.restMinutes

        maybeKm =
            String.toFloat kmRaw

        maybeRest =
            String.toInt restRaw
    in
    if String.isEmpty trimmedName then
        Err "Give the aid station a name."

    else
        case maybeKm of
            Nothing ->
                Err "Distance must be a number (in km)."

            Just kmValue ->
                if kmValue < 0 then
                    Err "Distance can't be negative."

                else
                    let
                        meters =
                            kmValue * 1000

                        absolute =
                            case form.mode of
                                FromStart ->
                                    meters

                                FromPrevious ->
                                    previousAidDistance form.editing race + meters
                    in
                    if absolute > race.distance + 5 then
                        Err
                            ("Distance is beyond the end of the route ("
                                ++ formatFloat 1 (race.distance / 1000)
                                ++ " km total)."
                            )

                    else
                        case maybeRest of
                            Nothing ->
                                Err "Rest minutes must be a whole number."

                            Just restMin ->
                                if restMin < 0 then
                                    Err "Rest can't be negative."

                                else
                                    let
                                        id =
                                            Maybe.withDefault
                                                ("a" ++ String.fromInt race.aidStationSeq)
                                                form.editing
                                    in
                                    Ok
                                        { id = id
                                        , name = trimmedName
                                        , distance = absolute
                                        , restSeconds = restMin * 60
                                        , services = form.services
                                        , notes = ""
                                        }


previousAidDistance : Maybe String -> Race -> Float
previousAidDistance editing race =
    race.aidStations
        |> List.filter (\a -> Just a.id /= editing)
        |> List.sortBy .distance
        |> List.reverse
        |> List.head
        |> Maybe.map .distance
        |> Maybe.withDefault 0



-- ============================================================
-- SUBSCRIPTIONS
-- ============================================================


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ Storage.gotRaces RacesLoaded
        , Storage.gotRace RaceSaved
        , Storage.gotRaceDeleted RaceDeleted
        , Storage.gotError StorageError
        , Browser.Events.onResize WindowResized
        ]



-- ============================================================
-- VIEW
-- ============================================================


view : Model -> Browser.Document Msg
view model =
    { title = title model.route
    , body =
        [ div [ class "min-h-screen flex flex-col" ]
            [ viewHeader model.route
            , div [ class "flex-1 pb-10" ] [ viewContent model ]
            , viewFooter
            , viewDeleteModal model
            , viewErrorToast model
            ]
        ]
    }


title : Route -> String
title route =
    case route of
        Route.Index ->
            "Trail"

        Route.RaceDetail _ ->
            "Trail — race"

        Route.NotFound ->
            "Trail — not found"


viewHeader : Route -> Html Msg
viewHeader route =
    div [ class "px-6 py-5 border-b border-slate-800/60 bg-slate-950/95 backdrop-blur" ]
        [ div [ class "max-w-screen-2xl mx-auto flex items-baseline gap-4" ]
            [ a
                [ Route.href Route.Index
                , class "text-2xl font-semibold tracking-tight text-rose-500 hover:text-rose-400 transition-colors"
                ]
                [ text "Trail" ]
            , p [ class "text-sm text-slate-400" ]
                [ text
                    (case route of
                        Route.Index ->
                            "Your races."

                        Route.RaceDetail _ ->
                            "Race detail."

                        Route.NotFound ->
                            "Lost?"
                    )
                ]
            ]
        ]


viewFooter : Html msg
viewFooter =
    div [ class "px-6 py-4 text-xs text-slate-500 border-t border-slate-800/60 bg-slate-950" ]
        [ div [ class "max-w-screen-2xl mx-auto" ]
            [ text "Local-first. Your GPX never leaves the browser." ]
        ]


viewContent : Model -> Html Msg
viewContent model =
    case ( model.route, model.races ) of
        ( _, LoadingRaces ) ->
            viewLoading

        ( Route.Index, LoadedRaces races ) ->
            div [ class "px-6" ] [ viewIndex model races ]

        ( Route.RaceDetail rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewRaceDetail model race

                Nothing ->
                    viewRaceNotFound

        ( Route.NotFound, LoadedRaces _ ) ->
            viewNotFound


findRace : RaceId -> List Race -> Maybe Race
findRace rid =
    List.filter (\r -> raceIdToString r.id == raceIdToString rid) >> List.head


viewLoading : Html msg
viewLoading =
    div [ class "max-w-screen-md mx-auto mt-20 text-center text-slate-500" ]
        [ text "Loading races…" ]


viewNotFound : Html msg
viewNotFound =
    div [ class "max-w-screen-md mx-auto mt-20 text-center space-y-4 px-6" ]
        [ p [ class "text-rose-400 text-lg" ] [ text "404 — that page doesn't exist." ]
        , a [ Route.href Route.Index, class "inline-block px-4 py-2 border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200" ]
            [ text "Back to races" ]
        ]


viewRaceNotFound : Html msg
viewRaceNotFound =
    div [ class "max-w-screen-md mx-auto mt-20 text-center space-y-4 px-6" ]
        [ p [ class "text-rose-400 text-lg" ] [ text "This race isn't in your library anymore." ]
        , a [ Route.href Route.Index, class "inline-block px-4 py-2 border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200" ]
            [ text "Back to races" ]
        ]



-- ============================================================
-- INDEX PAGE
-- ============================================================


viewIndex : Model -> List Race -> Html Msg
viewIndex model races =
    div [ class "max-w-screen-2xl mx-auto mt-10 space-y-10" ]
        [ viewIndexHero (List.length races)
        , viewUploadBanner model
        , if List.isEmpty races then
            viewEmptyState

          else
            viewRaceGrid races
        ]


viewIndexHero : Int -> Html msg
viewIndexHero count =
    div [ class "flex items-end justify-between flex-wrap gap-4" ]
        [ div []
            [ h1 [ class "text-4xl font-bold tracking-tight text-slate-100" ]
                [ text "Your races" ]
            , p [ class "mt-2 text-slate-400" ]
                [ text "Upload a GPX, plan the day, export Coros-ready files." ]
            ]
        , p [ class "text-sm text-slate-500" ]
            [ text
                (if count == 0 then
                    "no races yet"

                 else if count == 1 then
                    "1 race"

                 else
                    String.fromInt count ++ " races"
                )
            ]
        ]


viewUploadBanner : Model -> Html Msg
viewUploadBanner model =
    let
        ( labelText, sub, disabled ) =
            case model.upload of
                NotUploading ->
                    ( "Drop a .gpx file", "or click to choose one", False )

                Parsing fname ->
                    ( "Parsing " ++ fname ++ "…", "this should take a moment", True )

                Persisting fname ->
                    ( "Saving " ++ fname ++ "…", "writing to local storage", True )

                UploadFailed fname err ->
                    ( "Couldn't read " ++ fname, err, False )
    in
    div
        [ classList
            [ ( "rounded-2xl border-2 border-dashed p-6 text-center transition-colors", True )
            , ( "border-slate-700 bg-slate-900/40 hover:bg-slate-900/70", not model.dragOver && not disabled )
            , ( "border-rose-500 bg-rose-500/5", model.dragOver )
            , ( "border-slate-800 bg-slate-900/30 cursor-wait", disabled )
            ]
        , preventDefaultOn "dragenter" (D.succeed ( DragEnter, True ))
        , preventDefaultOn "dragover" (D.succeed ( DragEnter, True ))
        , preventDefaultOn "dragleave" (D.succeed ( DragLeave, True ))
        , preventDefaultOn "drop" dropDecoder
        ]
        [ p [ class "text-slate-200 font-medium" ] [ text labelText ]
        , p [ class "text-sm text-slate-500 mt-1" ] [ text sub ]
        , button
            [ onClick OpenPicker
            , A.disabled disabled
            , class "mt-4 px-4 py-2 bg-rose-600 text-white rounded-md hover:bg-rose-500 disabled:opacity-50 disabled:cursor-not-allowed text-sm font-medium"
            ]
            [ text "Choose a file" ]
        ]


dropDecoder : D.Decoder ( Msg, Bool )
dropDecoder =
    D.at [ "dataTransfer", "files" ] (D.oneOrMore GotFiles File.decoder)
        |> D.map (\m -> ( m, True ))


viewEmptyState : Html msg
viewEmptyState =
    div [ class "border border-dashed border-slate-800 rounded-2xl py-20 text-center text-slate-500" ]
        [ p [ class "text-lg" ] [ text "No races yet." ]
        , p [ class "text-sm mt-2" ] [ text "Drop in a GPX above to get started." ]
        ]


viewRaceGrid : List Race -> Html Msg
viewRaceGrid races =
    div [ class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5" ]
        (List.map viewRaceCard races)


viewRaceCard : Race -> Html Msg
viewRaceCard race =
    div
        [ class "group relative bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden hover:border-rose-500/60 transition-colors" ]
        [ a
            [ Route.href (Route.RaceDetail race.id)
            , class "block p-5 space-y-4"
            ]
            [ div []
                [ p [ class "text-lg font-semibold text-slate-100 truncate" ] [ text race.name ]
                , p [ class "text-xs text-slate-500 truncate" ]
                    [ text (raceSubtitle race) ]
                ]
            , div [ class "grid grid-cols-3 gap-2 text-center" ]
                [ miniStat (formatKm race.distance) "km"
                , miniStat (formatInt race.gain) "m+"
                , miniStat (formatInt race.loss) "m−"
                ]
            , if List.isEmpty race.aidStations then
                text ""

              else
                p [ class "text-xs text-slate-500" ]
                    [ text
                        (String.fromInt (List.length race.aidStations)
                            ++ (if List.length race.aidStations == 1 then
                                    " aid station"

                                else
                                    " aid stations"
                               )
                        )
                    ]
            ]
        , button
            [ onClick (RequestDelete race.id)
            , class "absolute top-3 right-3 w-8 h-8 rounded-full bg-slate-950/70 text-slate-500 hover:text-rose-400 hover:bg-slate-950 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-sm"
            , A.attribute "aria-label" "Delete race"
            , A.title "Delete race"
            ]
            [ text "✕" ]
        ]


raceSubtitle : Race -> String
raceSubtitle race =
    case ( race.date, race.location ) of
        ( Just d, "" ) ->
            d

        ( Nothing, loc ) ->
            if String.isEmpty loc then
                "—"

            else
                loc

        ( Just d, loc ) ->
            loc ++ " · " ++ d


miniStat : String -> String -> Html msg
miniStat value unit =
    div [ class "py-2 rounded-lg bg-slate-950/60" ]
        [ p [ class "text-base font-semibold text-slate-100" ] [ text value ]
        , p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text unit ]
        ]



-- ============================================================
-- RACE DETAIL
-- ============================================================


viewRaceDetail : Model -> Race -> Html Msg
viewRaceDetail model race =
    let
        containerWidth =
            min (max 320 (model.viewportWidth - 48)) (1536 - 48)

        cachedTrack =
            Dict.get (raceIdToString race.id) model.parsedTracks

        markers =
            List.map (\a -> { distance = a.distance, label = aidShortLabel a }) (sortAidStations race.aidStations)
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 space-y-8 px-6" ]
        [ a [ Route.href Route.Index, class "inline-flex items-center gap-2 text-sm text-slate-400 hover:text-slate-100" ]
            [ text "← Back to races" ]
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ div [ class "min-w-0" ]
                [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text race.name ]
                , p [ class "mt-2 text-sm text-slate-500" ] [ text (raceSubtitle race) ]
                ]
            , div [ class "grid grid-cols-3 gap-3 sm:gap-4" ]
                [ bigStat "Distance" (formatKm race.distance) "km"
                , bigStat "Gain" (formatInt race.gain) "m"
                , bigStat "Loss" (formatInt race.loss) "m"
                ]
            ]
        , case cachedTrack of
            Just track ->
                viewProfileSection model track containerWidth markers

            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text "Parsing GPX…" ]
        , viewAidStationsSection model race
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 text-sm text-slate-400" ]
            [ p [ class "font-medium text-slate-300 mb-2" ] [ text "Coming soon" ]
            , p [] [ text "Per-km planning, table view, and Coros-ready GPX export are next in the queue." ]
            ]
        ]


aidShortLabel : AidStation -> String
aidShortLabel a =
    let
        nameTrim =
            String.left 12 a.name
    in
    if String.length a.name > 12 then
        nameTrim ++ "…"

    else
        nameTrim


viewProfileSection : Model -> Track -> Float -> List Marker -> Html Msg
viewProfileSection model track containerWidth markers =
    div [ class "space-y-3" ]
        [ div [ class "flex items-baseline gap-3" ]
            [ h2 [ class "text-xl font-semibold text-slate-100" ] [ text "Elevation profile" ]
            , span [ class "text-xs text-slate-500" ] [ text "true 1:1 scale · no vertical exaggeration" ]
            ]
        , Profile.viewToolbar
            { mode = model.scaleMode
            , track = track
            , containerWidth = containerWidth
            , onSetMode = SetScaleMode
            }
        , Html.Lazy.lazy4 Profile.view track model.scaleMode containerWidth markers
        ]


bigStat : String -> String -> String -> Html msg
bigStat label value unit =
    div [ class "rounded-xl bg-slate-900 border border-slate-800 px-4 py-3 text-center min-w-[6rem]" ]
        [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text label ]
        , p [ class "mt-0.5 flex items-baseline justify-center gap-1" ]
            [ span [ class "text-2xl font-semibold text-slate-100" ] [ text value ]
            , span [ class "text-xs text-slate-500" ] [ text unit ]
            ]
        ]



-- ============================================================
-- AID STATIONS SECTION
-- ============================================================


viewAidStationsSection : Model -> Race -> Html Msg
viewAidStationsSection model race =
    let
        sorted =
            sortAidStations race.aidStations
    in
    div [ class "space-y-3" ]
        [ div [ class "flex items-baseline justify-between gap-3" ]
            [ div [ class "flex items-baseline gap-3" ]
                [ h2 [ class "text-xl font-semibold text-slate-100" ] [ text "Aid stations" ]
                , span [ class "text-xs text-slate-500" ]
                    [ text
                        (if List.isEmpty sorted then
                            "none yet"

                         else if List.length sorted == 1 then
                            "1 stop"

                         else
                            String.fromInt (List.length sorted) ++ " stops"
                        )
                    ]
                ]
            , case model.aidEditor of
                AidClosed ->
                    button
                        [ onClick OpenAddAid
                        , class "px-3 py-1.5 text-sm rounded-md bg-rose-600 text-white hover:bg-rose-500"
                        ]
                        [ text "+ Add" ]

                AidOpen _ ->
                    text ""
            ]
        , case model.aidEditor of
            AidOpen form ->
                viewAidForm form race

            AidClosed ->
                text ""
        , if List.isEmpty sorted then
            div [ class "rounded-2xl border border-dashed border-slate-800 p-8 text-center text-slate-500 text-sm" ]
                [ p [] [ text "No aid stations yet." ]
                , p [ class "mt-1 text-xs text-slate-600" ] [ text "Add them by distance from start or from the previous stop." ]
                ]

          else
            div [ class "rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden" ]
                (List.indexedMap (viewAidRow sorted race.distance) sorted)
        ]


viewAidRow : List AidStation -> Float -> Int -> AidStation -> Html Msg
viewAidRow allAids totalDistance index aid =
    let
        prev =
            allAids
                |> List.take index
                |> List.reverse
                |> List.head

        fromPrevKm =
            case prev of
                Just p ->
                    (aid.distance - p.distance) / 1000

                Nothing ->
                    aid.distance / 1000

        toFinishKm =
            (totalDistance - aid.distance) / 1000
    in
    div
        [ classList
            [ ( "group flex items-center gap-4 px-5 py-4 hover:bg-slate-950/40 transition-colors", True )
            , ( "border-t border-slate-800", index > 0 )
            ]
        ]
        [ div [ class "flex items-center justify-center w-9 h-9 rounded-full bg-amber-400/20 border border-amber-400/60 text-amber-300 text-xs font-semibold flex-shrink-0" ]
            [ text (String.fromInt (index + 1)) ]
        , div [ class "min-w-0 flex-1" ]
            [ p [ class "text-sm font-medium text-slate-100 truncate" ] [ text aid.name ]
            , p [ class "text-xs text-slate-500" ]
                [ text
                    (formatFloat 1 (aid.distance / 1000)
                        ++ " km from start · +"
                        ++ formatFloat 1 fromPrevKm
                        ++ " km from previous · "
                        ++ formatFloat 1 toFinishKm
                        ++ " km to finish"
                    )
                ]
            , if List.isEmpty aid.services then
                text ""

              else
                p [ class "mt-1 flex gap-1.5 text-base" ]
                    (List.map (\s -> span [ A.title (serviceLabel s) ] [ text (serviceIcon s) ]) aid.services)
            ]
        , div [ class "flex items-center gap-2 flex-shrink-0" ]
            [ span [ class "text-xs text-slate-500" ]
                [ text (formatRest aid.restSeconds) ]
            , button
                [ onClick (OpenEditAid aid)
                , class "px-2 py-1 text-xs border border-slate-700 rounded hover:bg-slate-800 text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                ]
                [ text "Edit" ]
            , button
                [ onClick (AidDelete aid.id)
                , class "px-2 py-1 text-xs text-slate-500 hover:text-rose-400 opacity-0 group-hover:opacity-100 transition-opacity"
                ]
                [ text "✕" ]
            ]
        ]


viewAidForm : AidForm -> Race -> Html Msg
viewAidForm form race =
    let
        editing =
            form.editing /= Nothing

        prevHint =
            previousAidDistance form.editing race / 1000

        title_ =
            if editing then
                "Edit aid station"

            else
                "New aid station"
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4" ]
        [ div [ class "flex items-baseline justify-between" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text title_ ]
            , button
                [ onClick CloseAid
                , class "text-xs text-slate-500 hover:text-slate-200"
                ]
                [ text "Cancel" ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
            [ field "Name"
                [ input
                    [ A.type_ "text"
                    , A.value form.name
                    , A.placeholder "Las Truchas, Cafetería, Finish…"
                    , onInput AidSetName
                    , inputClass
                    ]
                    []
                ]
            , field "Rest (minutes)"
                [ input
                    [ A.type_ "number"
                    , A.min "0"
                    , A.step "1"
                    , A.value form.restMinutes
                    , onInput AidSetRestMinutes
                    , inputClass
                    ]
                    []
                ]
            ]
        , div [ class "space-y-2" ]
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text "Distance" ]
            , div [ class "flex gap-1 bg-slate-950 border border-slate-800 rounded-lg p-1 w-fit" ]
                [ modeChip "From previous" (form.mode == FromPrevious) (AidSetMode FromPrevious)
                , modeChip "From start" (form.mode == FromStart) (AidSetMode FromStart)
                ]
            , div [ class "flex items-baseline gap-2" ]
                [ input
                    [ A.type_ "number"
                    , A.step "0.1"
                    , A.min "0"
                    , A.value form.distanceKm
                    , A.placeholder
                        (case form.mode of
                            FromStart ->
                                "e.g. 6.0"

                            FromPrevious ->
                                "e.g. 4.5"
                        )
                    , onInput AidSetDistanceKm
                    , inputClass
                    ]
                    []
                , span [ class "text-sm text-slate-500" ] [ text "km" ]
                ]
            , p [ class "text-xs text-slate-500" ]
                [ text
                    (case form.mode of
                        FromStart ->
                            "Absolute distance from the start line."

                        FromPrevious ->
                            "Distance added on top of "
                                ++ formatFloat 1 prevHint
                                ++ " km (the previous stop, or start if there is none)."
                    )
                ]
            ]
        , div [ class "space-y-2" ]
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text "Services" ]
            , div [ class "flex flex-wrap gap-2" ]
                (List.map (serviceChip form.services) allServices)
            ]
        , case form.error of
            Just err ->
                p [ class "text-sm text-rose-400" ] [ text err ]

            Nothing ->
                text ""
        , div [ class "flex justify-end gap-2" ]
            [ button
                [ onClick CloseAid
                , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                ]
                [ text "Cancel" ]
            , button
                [ onClick AidSubmit
                , class "px-4 py-2 text-sm bg-rose-600 text-white rounded-md hover:bg-rose-500 font-medium"
                ]
                [ text
                    (if editing then
                        "Save changes"

                     else
                        "Add aid station"
                    )
                ]
            ]
        ]


inputClass : Html.Attribute msg
inputClass =
    class "w-full bg-slate-950 border border-slate-800 rounded-md px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-rose-500/60"


field : String -> List (Html msg) -> Html msg
field labelText children =
    label [ class "block space-y-1" ]
        [ span [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text labelText ]
        , div [] children
        ]


modeChip : String -> Bool -> Msg -> Html Msg
modeChip labelText active msg =
    button
        [ onClick msg
        , classList
            [ ( "px-3 py-1.5 text-xs rounded transition-colors", True )
            , ( "bg-rose-600 text-white font-medium", active )
            , ( "text-slate-400 hover:text-slate-100", not active )
            ]
        ]
        [ text labelText ]


serviceChip : List Service -> Service -> Html Msg
serviceChip current s =
    let
        active =
            List.member s current
    in
    button
        [ onClick (AidToggleService s)
        , classList
            [ ( "px-3 py-1.5 text-sm rounded-full border transition-colors flex items-center gap-1.5", True )
            , ( "bg-rose-600/15 border-rose-500/60 text-rose-200", active )
            , ( "bg-slate-950 border-slate-800 text-slate-400 hover:text-slate-200 hover:border-slate-700", not active )
            ]
        ]
        [ span [] [ text (serviceIcon s) ]
        , span [] [ text (serviceLabel s) ]
        ]



-- ============================================================
-- DELETE CONFIRM + ERROR TOAST
-- ============================================================


viewDeleteModal : Model -> Html Msg
viewDeleteModal model =
    case ( model.pendingDelete, model.races ) of
        ( Just rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewModal
                        { title = "Delete race?"
                        , body = "This will remove “" ++ race.name ++ "” and any planning data attached to it. This cannot be undone."
                        , confirmLabel = "Delete"
                        , cancelLabel = "Cancel"
                        }

                Nothing ->
                    text ""

        _ ->
            text ""


viewModal :
    { title : String, body : String, confirmLabel : String, cancelLabel : String }
    -> Html Msg
viewModal cfg =
    div [ class "fixed inset-0 z-40 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center px-4" ]
        [ div [ class "max-w-sm w-full bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-5" ]
            [ h2 [ class "text-lg font-semibold text-slate-100" ] [ text cfg.title ]
            , p [ class "text-sm text-slate-400" ] [ text cfg.body ]
            , div [ class "flex justify-end gap-2" ]
                [ button
                    [ onClick CancelDelete
                    , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                    ]
                    [ text cfg.cancelLabel ]
                , button
                    [ onClick ConfirmDelete
                    , class "px-4 py-2 text-sm bg-rose-600 text-white rounded-md hover:bg-rose-500"
                    ]
                    [ text cfg.confirmLabel ]
                ]
            ]
        ]


viewErrorToast : Model -> Html msg
viewErrorToast model =
    case model.storageError of
        Just err ->
            div [ class "fixed bottom-6 right-6 z-50 max-w-sm bg-rose-600/20 border border-rose-500/60 text-rose-100 rounded-lg p-4 text-sm shadow-lg" ]
                [ p [ class "font-medium" ] [ text "Storage error" ]
                , p [ class "mt-1 text-xs opacity-80" ] [ text err ]
                ]

        Nothing ->
            text ""



-- ============================================================
-- FORMATTING
-- ============================================================


formatKm : Float -> String
formatKm meters =
    let
        km =
            meters / 1000

        rounded =
            toFloat (round (km * 10)) / 10
    in
    String.fromFloat rounded


formatInt : Float -> String
formatInt v =
    String.fromInt (round v)


formatFloat : Int -> Float -> String
formatFloat decimals f =
    let
        mult =
            10 ^ decimals |> toFloat

        rounded =
            toFloat (round (f * mult)) / mult
    in
    String.fromFloat rounded


formatRest : Int -> String
formatRest seconds =
    if seconds <= 0 then
        "no rest"

    else if seconds < 60 then
        String.fromInt seconds ++ "s"

    else
        let
            minutes =
                seconds // 60

            remainder =
                modBy 60 seconds
        in
        if remainder == 0 then
            String.fromInt minutes ++ " min rest"

        else
            String.fromInt minutes ++ ":" ++ String.padLeft 2 '0' (String.fromInt remainder) ++ " rest"
