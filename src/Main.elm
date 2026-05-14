module Main exposing (main)

{-| TASK-004.

`Browser.application` shell with hash routing, IndexedDB-backed
persistence, race index, race-detail (now with the **true-scale**
elevation profile lifted from crest). Tracks are parsed lazily from
the raw GPX on RacesLoaded / RaceSaved and cached in the model so
navigating between races doesn't re-parse.

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
import Html exposing (Html, a, button, div, h1, h2, p, span, text)
import Html.Attributes as A exposing (class, classList)
import Html.Events as E exposing (onClick, preventDefaultOn)
import Html.Lazy
import Json.Decode as D
import Json.Encode as Encode
import Profile exposing (ScaleMode(..))
import Route exposing (Route)
import Storage
import Task
import Types exposing (Race, RaceId, encodeRace, raceIdFromString, raceIdToString)
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


type alias Model =
    { key : Nav.Key
    , route : Route
    , now : Int
    , viewportWidth : Float
    , races : RacesState
    , parsedTracks : Dict String Track -- keyed by raceIdToString
    , scaleMode : ScaleMode
    , upload : UploadState
    , dragOver : Bool
    , storageError : Maybe String
    , pendingDelete : Maybe RaceId
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
      -- delete
    | RequestDelete RaceId
    | ConfirmDelete
    | CancelDelete


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            ( { model | route = Route.fromUrl url, pendingDelete = Nothing }, Cmd.none )

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
                    in
                    ( { model
                        | races = LoadedRaces (sortRaces merged)
                        , parsedTracks = cacheTrack race model.parsedTracks
                        , upload = NotUploading
                      }
                    , Nav.pushUrl model.key (Route.toString (Route.RaceDetail race.id))
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


currentRaces : Model -> List Race
currentRaces model =
    case model.races of
        LoadedRaces rs ->
            rs

        LoadingRaces ->
            []


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
    }


readFile : File -> Cmd Msg
readFile file =
    Task.perform (GotContent (File.name file)) (File.toString file)



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
        ( label, sub, disabled ) =
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
        [ p [ class "text-slate-200 font-medium" ] [ text label ]
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
                    [ text
                        (case race.location of
                            "" ->
                                Maybe.withDefault "—" race.date

                            loc ->
                                case race.date of
                                    Just d ->
                                        loc ++ " · " ++ d

                                    Nothing ->
                                        loc
                        )
                    ]
                ]
            , div [ class "grid grid-cols-3 gap-2 text-center" ]
                [ miniStat (formatKm race.distance) "km"
                , miniStat (formatInt race.gain) "m+"
                , miniStat (formatInt race.loss) "m−"
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
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 space-y-8 px-6" ]
        [ a [ Route.href Route.Index, class "inline-flex items-center gap-2 text-sm text-slate-400 hover:text-slate-100" ]
            [ text "← Back to races" ]
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ div [ class "min-w-0" ]
                [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text race.name ]
                , p [ class "mt-2 text-sm text-slate-500" ]
                    [ text
                        (case ( race.date, race.location ) of
                            ( Just d, "" ) ->
                                d

                            ( Nothing, loc ) ->
                                if String.isEmpty loc then
                                    "Race detail"

                                else
                                    loc

                            ( Just d, loc ) ->
                                loc ++ " · " ++ d
                        )
                    ]
                ]
            , div [ class "grid grid-cols-3 gap-3 sm:gap-4" ]
                [ bigStat "Distance" (formatKm race.distance) "km"
                , bigStat "Gain" (formatInt race.gain) "m"
                , bigStat "Loss" (formatInt race.loss) "m"
                ]
            ]
        , case cachedTrack of
            Just track ->
                viewProfileSection model track containerWidth

            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text "Parsing GPX…" ]
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 text-sm text-slate-400" ]
            [ p [ class "font-medium text-slate-300 mb-2" ] [ text "Coming soon" ]
            , p [] [ text "Aid stations, per-km planning, table view, and Coros-ready GPX export are next in the queue." ]
            ]
        ]


viewProfileSection : Model -> Track -> Float -> Html Msg
viewProfileSection model track containerWidth =
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
        , Html.Lazy.lazy3 Profile.view track model.scaleMode containerWidth
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
