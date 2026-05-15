module Main exposing (main)

{-| TASK-006 + TASK-007.

`Browser.application` shell with hash routing, IndexedDB-backed
persistence, race index, race-detail with 1:1 elevation profile +
aid-station CRUD, plus the per-km planning experience: target
total time, GAP-distributed pace per km, table view (km / section
toggle), per-km card view with mini-profile + notes + manual time
override.

The whole UI still lives in this module. We'll split per-page when
a page passes ~250 lines on its own.

-}

import ActualGpx
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Csv
import Dict exposing (Dict)
import Download
import File exposing (File)
import File.Select as Select
import Gpx exposing (Track)
import GpxExport
import Html exposing (Html, a, button, div, h1, h2, h3, input, label, p, span, text, textarea)
import Html.Attributes as A exposing (class, classList)
import Html.Events as E exposing (onBlur, onClick, onInput, preventDefaultOn)
import Html.Lazy
import Json.Decode as D
import Json.Encode as Encode
import Planning exposing (Km, KmResult, KmSource(..))
import ProjectFile
import Profile exposing (Marker, ScaleMode(..))
import Route exposing (Route)
import Storage
import Svg
import Svg.Attributes as SA
import Task
import Time
import Types
    exposing
        ( AidStation
        , KmTime(..)
        , Plan
        , Race
        , RaceId
        , Service
        , allServices
        , defaultPlan
        , emptyKmPlan
        , encodeRace
        , kmPlanFor
        , raceIdFromString
        , raceIdToString
        , serviceIcon
        , serviceLabel
        , sortAidStations
        , withKmPlan
        , withTargetSeconds
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


type alias MetaForm =
    { name : String
    , date : String
    , location : String
    , url : String
    , notes : String
    , coverImage : Maybe String
    }


type MetaEditor
    = MetaClosed
    | MetaOpen MetaForm


type TableMode
    = ByKm
    | BySection


type alias Model =
    { key : Nav.Key
    , route : Route
    , now : Int
    , viewportWidth : Float
    , races : RacesState
    , parsedTracks : Dict String Track
    , kmsCache : Dict String (List Km)
    , scaleMode : ScaleMode
    , upload : UploadState
    , dragOver : Bool
    , storageError : Maybe String
    , pendingDelete : Maybe RaceId
    , aidEditor : AidEditor
    , metaEditor : MetaEditor
    , planTableMode : TableMode
    , targetTimeText : String
    , kmTimeText : String
    , kmNotesText : String
    , actualRunError : Maybe String
    }


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    ( { key = key
      , route = Route.fromUrl url
      , now = flags.now
      , viewportWidth = flags.width
      , races = LoadingRaces
      , parsedTracks = Dict.empty
      , kmsCache = Dict.empty
      , scaleMode = FitWidth
      , upload = NotUploading
      , dragOver = False
      , storageError = Nothing
      , pendingDelete = Nothing
      , aidEditor = AidClosed
      , metaEditor = MetaClosed
      , planTableMode = ByKm
      , targetTimeText = ""
      , kmTimeText = ""
      , kmNotesText = ""
      , actualRunError = Nothing
      }
    , Storage.loadAll
    )



-- ============================================================
-- MSG / UPDATE
-- ============================================================


type Msg
    = LinkClicked Browser.UrlRequest
    | UrlChanged Url
    | NavigateTo Route
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
      -- plan
    | SetPlanTableMode TableMode
    | SetTargetTimeText String
    | CommitTargetTime
    | SetKmTimeText String
    | CommitKmTimeForKm Int
    | SetKmNotesText String
    | CommitKmNotesForKm Int
    | ResetKmToAuto Int
      -- exports
    | ExportCsvKms
    | ExportCsvSections
    | ExportGpxForCoros
    | ExportProjectFile
      -- metadata edit
    | OpenMetaEdit
    | CloseMetaEdit
    | MetaSetName String
    | MetaSetDate String
    | MetaSetLocation String
    | MetaSetUrl String
    | MetaSetNotes String
    | MetaPickCover
    | MetaCoverPicked String
    | MetaClearCover
    | MetaSubmit
      -- actual run
    | OpenActualGpxPicker RaceId
    | PickedActualGpxFile RaceId File
    | GotActualGpxContent RaceId Int String
    | ClearActualRun RaceId
    | ActualGpxFailed String


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        LinkClicked (Browser.Internal url) ->
            ( model, Nav.pushUrl model.key (Url.toString url) )

        LinkClicked (Browser.External href) ->
            ( model, Nav.load href )

        UrlChanged url ->
            let
                newRoute =
                    Route.fromUrl url

                hydrated =
                    hydratePlanInputs
                        { model
                            | route = newRoute
                            , pendingDelete = Nothing
                            , aidEditor = AidClosed
                        }
            in
            ( hydrated, Cmd.none )

        NavigateTo route ->
            ( model, Nav.pushUrl model.key (Route.toString route) )

        WindowResized w _ ->
            ( { model | viewportWidth = toFloat w }, Cmd.none )

        SetScaleMode m ->
            ( { model | scaleMode = m }, Cmd.none )

        DragEnter ->
            ( { model | dragOver = True }, Cmd.none )

        DragLeave ->
            ( { model | dragOver = False }, Cmd.none )

        OpenPicker ->
            ( model
            , Select.file
                [ "application/gpx+xml", ".gpx", ".trail", "application/json" ]
                PickedFile
            )

        GotFiles file _ ->
            ( { model | dragOver = False, upload = Parsing (File.name file) }
            , readFile file
            )

        PickedFile file ->
            ( { model | upload = Parsing (File.name file) }
            , readFile file
            )

        GotContent fileName content ->
            if isProjectFile fileName then
                case ProjectFile.decode content of
                    Err err ->
                        ( { model | upload = UploadFailed fileName err }, Cmd.none )

                    Ok importedRace ->
                        let
                            -- Drop the imported id so JS assigns a fresh one
                            -- (lets users import the same .trail twice safely)
                            -- and stamp a new createdAt so it sorts to the top.
                            draft =
                                { importedRace
                                    | id = raceIdFromString ""
                                    , createdAt = model.now
                                }
                        in
                        ( { model | upload = Persisting fileName }
                        , Storage.saveRace (encodeRace draft)
                        )

            else
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

                        tracks =
                            buildTrackCache sorted Dict.empty

                        kms =
                            buildKmsCache sorted tracks Dict.empty

                        modelWithRaces =
                            { model
                                | races = LoadedRaces sorted
                                , parsedTracks = tracks
                                , kmsCache = kms
                            }
                    in
                    ( hydratePlanInputs modelWithRaces, Cmd.none )

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

                        nextRaces =
                            sortRaces merged

                        nextTracks =
                            cacheTrack race model.parsedTracks

                        nextKms =
                            cacheKms race nextTracks model.kmsCache

                        navCmd =
                            case model.route of
                                Route.RaceDetail rid ->
                                    if raceIdToString rid == raceIdToString race.id then
                                        Cmd.none

                                    else
                                        Cmd.none

                                Route.PlanTable _ ->
                                    Cmd.none

                                Route.PlanKm _ _ ->
                                    Cmd.none

                                _ ->
                                    Nav.pushUrl model.key (Route.toString (Route.RaceDetail race.id))
                    in
                    ( { model
                        | races = LoadedRaces nextRaces
                        , parsedTracks = nextTracks
                        , kmsCache = nextKms
                        , upload = NotUploading
                        , aidEditor = AidClosed
                        , metaEditor = MetaClosed
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
                , kmsCache = Dict.remove idStr model.kmsCache
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

        SetPlanTableMode m ->
            ( { model | planTableMode = m }, Cmd.none )

        SetTargetTimeText s ->
            ( { model | targetTimeText = s }, Cmd.none )

        CommitTargetTime ->
            case currentRace model of
                Just race ->
                    let
                        newTarget =
                            parseHhmm model.targetTimeText

                        formatted =
                            case newTarget of
                                Just s ->
                                    formatHhmm s

                                Nothing ->
                                    if String.isEmpty (String.trim model.targetTimeText) then
                                        ""

                                    else
                                        model.targetTimeText

                        updatedRace =
                            { race | plan = withTargetSeconds newTarget race.plan }
                    in
                    ( { model | targetTimeText = formatted }
                    , Storage.saveRace (encodeRace updatedRace)
                    )

                Nothing ->
                    ( model, Cmd.none )

        SetKmTimeText s ->
            ( { model | kmTimeText = s }, Cmd.none )

        CommitKmTimeForKm kmIndex ->
            case currentRace model of
                Just race ->
                    let
                        kp =
                            kmPlanFor kmIndex race.plan

                        trimmed =
                            String.trim model.kmTimeText

                        newTime =
                            if String.isEmpty trimmed then
                                Auto

                            else
                                case parseMmss trimmed of
                                    Just secs ->
                                        Manual secs

                                    Nothing ->
                                        kp.time

                        formatted =
                            case newTime of
                                Manual s ->
                                    formatMmss s

                                Auto ->
                                    ""

                        updatedKp =
                            { kp | time = newTime }

                        updatedRace =
                            { race | plan = withKmPlan kmIndex updatedKp race.plan }
                    in
                    ( { model | kmTimeText = formatted }
                    , Storage.saveRace (encodeRace updatedRace)
                    )

                Nothing ->
                    ( model, Cmd.none )

        SetKmNotesText s ->
            ( { model | kmNotesText = s }, Cmd.none )

        CommitKmNotesForKm kmIndex ->
            case currentRace model of
                Just race ->
                    let
                        kp =
                            kmPlanFor kmIndex race.plan

                        updatedKp =
                            { kp | notes = model.kmNotesText }

                        updatedRace =
                            { race | plan = withKmPlan kmIndex updatedKp race.plan }
                    in
                    ( model, Storage.saveRace (encodeRace updatedRace) )

                Nothing ->
                    ( model, Cmd.none )

        ResetKmToAuto kmIndex ->
            case currentRace model of
                Just race ->
                    let
                        kp =
                            kmPlanFor kmIndex race.plan

                        updatedKp =
                            { kp | time = Auto }

                        updatedRace =
                            { race | plan = withKmPlan kmIndex updatedKp race.plan }
                    in
                    ( { model | kmTimeText = "" }
                    , Storage.saveRace (encodeRace updatedRace)
                    )

                Nothing ->
                    ( model, Cmd.none )

        ExportCsvKms ->
            case currentRace model of
                Just race ->
                    let
                        kms =
                            Dict.get (raceIdToString race.id) model.kmsCache
                                |> Maybe.withDefault []

                        results =
                            Planning.distribute
                                { target = race.plan.targetSeconds
                                , kms = kms
                                , plan = race.plan
                                , aidRestSeconds = Planning.aidRestTotal race.aidStations
                                }

                        content =
                            Csv.kmsCsv { race = race, kms = kms, results = results }

                        filename =
                            csvFilename race "km"
                    in
                    ( model
                    , Download.file
                        { filename = filename
                        , content = content
                        , mime = "text/csv"
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ExportCsvSections ->
            case currentRace model of
                Just race ->
                    let
                        kms =
                            Dict.get (raceIdToString race.id) model.kmsCache
                                |> Maybe.withDefault []

                        results =
                            Planning.distribute
                                { target = race.plan.targetSeconds
                                , kms = kms
                                , plan = race.plan
                                , aidRestSeconds = Planning.aidRestTotal race.aidStations
                                }

                        content =
                            Csv.sectionsCsv { race = race, kms = kms, results = results }

                        filename =
                            csvFilename race "sections"
                    in
                    ( model
                    , Download.file
                        { filename = filename
                        , content = content
                        , mime = "text/csv"
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        ExportGpxForCoros ->
            case ( currentRace model, Dict.get (currentRaceIdString model) model.parsedTracks ) of
                ( Just race, Just track ) ->
                    ( model
                    , Download.file
                        { filename = GpxExport.filenameFor race
                        , content = GpxExport.exportWithAidStations race track
                        , mime = "application/gpx+xml"
                        }
                    )

                _ ->
                    ( model, Cmd.none )

        ExportProjectFile ->
            case currentRace model of
                Just race ->
                    ( model
                    , Download.file
                        { filename = ProjectFile.filenameFor race
                        , content = ProjectFile.encode race
                        , mime = "application/json"
                        }
                    )

                Nothing ->
                    ( model, Cmd.none )

        OpenMetaEdit ->
            case currentRace model of
                Just race ->
                    ( { model | metaEditor = MetaOpen (metaFormFromRace race) }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CloseMetaEdit ->
            ( { model | metaEditor = MetaClosed }, Cmd.none )

        MetaSetName s ->
            ( updateMetaForm (\f -> { f | name = s }) model, Cmd.none )

        MetaSetDate s ->
            ( updateMetaForm (\f -> { f | date = s }) model, Cmd.none )

        MetaSetLocation s ->
            ( updateMetaForm (\f -> { f | location = s }) model, Cmd.none )

        MetaSetUrl s ->
            ( updateMetaForm (\f -> { f | url = s }) model, Cmd.none )

        MetaSetNotes s ->
            ( updateMetaForm (\f -> { f | notes = s }) model, Cmd.none )

        MetaPickCover ->
            ( model, Download.pickImageFile )

        MetaCoverPicked dataUrl ->
            ( updateMetaForm (\f -> { f | coverImage = Just dataUrl }) model, Cmd.none )

        MetaClearCover ->
            ( updateMetaForm (\f -> { f | coverImage = Nothing }) model, Cmd.none )

        MetaSubmit ->
            case ( model.metaEditor, currentRace model ) of
                ( MetaOpen form, Just race ) ->
                    let
                        trimmedName =
                            String.trim form.name

                        finalName =
                            if String.isEmpty trimmedName then
                                race.name

                            else
                                trimmedName

                        date =
                            let
                                t =
                                    String.trim form.date
                            in
                            if String.isEmpty t then
                                Nothing

                            else
                                Just t

                        updatedRace =
                            { race
                                | name = finalName
                                , date = date
                                , location = String.trim form.location
                                , url = String.trim form.url
                                , notes = form.notes
                                , coverImage = form.coverImage
                            }
                    in
                    ( { model | metaEditor = MetaClosed }
                    , Storage.saveRace (encodeRace updatedRace)
                    )

                _ ->
                    ( model, Cmd.none )

        OpenActualGpxPicker rid ->
            ( { model | actualRunError = Nothing }
            , Select.file [ "application/gpx+xml", ".gpx" ] (PickedActualGpxFile rid)
            )

        PickedActualGpxFile rid file ->
            ( model
            , Task.perform identity
                (Task.map2 (GotActualGpxContent rid)
                    (Time.now |> Task.map Time.posixToMillis)
                    (File.toString file)
                )
            )

        GotActualGpxContent rid uploadedAtMs content ->
            case ActualGpx.parse content of
                Err e ->
                    ( { model | actualRunError = Just e }, Cmd.none )

                Ok track ->
                    case findRace rid (currentRaces model) of
                        Nothing ->
                            ( model, Cmd.none )

                        Just race ->
                            let
                                splits =
                                    ActualGpx.computeSplits track |> Dict.fromList

                                actual =
                                    { splits = splits
                                    , totalSeconds = track.totalElapsedS
                                    , totalDistance = track.totalDist
                                    , uploadedAt = uploadedAtMs
                                    }

                                updatedRace =
                                    { race | actualSplits = Just actual }
                            in
                            ( { model | actualRunError = Nothing }
                            , Storage.saveRace (encodeRace updatedRace)
                            )

        ClearActualRun rid ->
            case findRace rid (currentRaces model) of
                Nothing ->
                    ( model, Cmd.none )

                Just race ->
                    ( { model | actualRunError = Nothing }
                    , Storage.saveRace (encodeRace { race | actualSplits = Nothing })
                    )

        ActualGpxFailed err ->
            ( { model | actualRunError = Just err }, Cmd.none )


updateMetaForm : (MetaForm -> MetaForm) -> Model -> Model
updateMetaForm f model =
    case model.metaEditor of
        MetaOpen form ->
            { model | metaEditor = MetaOpen (f form) }

        MetaClosed ->
            model


metaFormFromRace : Race -> MetaForm
metaFormFromRace race =
    { name = race.name
    , date = Maybe.withDefault "" race.date
    , location = race.location
    , url = race.url
    , notes = race.notes
    , coverImage = race.coverImage
    }


isProjectFile : String -> Bool
isProjectFile fname =
    String.endsWith ".trail" (String.toLower fname)


currentRaceIdString : Model -> String
currentRaceIdString model =
    case currentRace model of
        Just race ->
            raceIdToString race.id

        Nothing ->
            ""


csvFilename : Race -> String -> String
csvFilename race tag =
    let
        base =
            ProjectFile.filenameFor race |> String.dropRight 6
    in
    base ++ "-" ++ tag ++ ".csv"


hydratePlanInputs : Model -> Model
hydratePlanInputs model =
    case currentRace model of
        Nothing ->
            { model | targetTimeText = "", kmTimeText = "", kmNotesText = "" }

        Just race ->
            let
                targetText =
                    case race.plan.targetSeconds of
                        Just s ->
                            formatHhmm s

                        Nothing ->
                            ""

                ( kmTime, kmNotes ) =
                    case model.route of
                        Route.PlanKm _ idx ->
                            let
                                kp =
                                    kmPlanFor idx race.plan
                            in
                            ( case kp.time of
                                Manual s ->
                                    formatMmss s

                                Auto ->
                                    ""
                            , kp.notes
                            )

                        _ ->
                            ( "", "" )
            in
            { model
                | targetTimeText = targetText
                , kmTimeText = kmTime
                , kmNotesText = kmNotes
            }


currentRaces : Model -> List Race
currentRaces model =
    case model.races of
        LoadedRaces rs ->
            rs

        LoadingRaces ->
            []


currentRace : Model -> Maybe Race
currentRace model =
    let
        lookup rid =
            currentRaces model
                |> List.filter (\r -> raceIdToString r.id == raceIdToString rid)
                |> List.head
    in
    case model.route of
        Route.RaceDetail rid ->
            lookup rid

        Route.RaceMap rid ->
            lookup rid

        Route.PlanTable rid ->
            lookup rid

        Route.PlanKm rid _ ->
            lookup rid

        Route.PlanSection rid _ ->
            lookup rid

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


cacheKms : Race -> Dict String Track -> Dict String (List Km) -> Dict String (List Km)
cacheKms race tracks cache =
    let
        key =
            raceIdToString race.id
    in
    case Dict.get key cache of
        Just _ ->
            cache

        Nothing ->
            case Dict.get key tracks of
                Just track ->
                    Dict.insert key (Planning.computeKms track) cache

                Nothing ->
                    cache


buildKmsCache : List Race -> Dict String Track -> Dict String (List Km) -> Dict String (List Km)
buildKmsCache races tracks existing =
    List.foldl (\r acc -> cacheKms r tracks acc) existing races


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
    , plan = defaultPlan
    , actualSplits = Nothing
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
        , Download.imagePicked MetaCoverPicked
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

        Route.RaceMap _ ->
            "Trail — map"

        Route.PlanTable _ ->
            "Trail — plan"

        Route.PlanKm _ _ ->
            "Trail — plan km"

        Route.PlanSection _ _ ->
            "Trail — plan section"

        Route.NotFound ->
            "Trail — not found"


viewHeader : Route -> Html Msg
viewHeader route =
    div [ class "px-6 py-4 border-b border-slate-800/60 bg-slate-950/95 backdrop-blur sticky top-0 z-30" ]
        [ div [ class "max-w-screen-2xl mx-auto flex items-center gap-4" ]
            [ a
                [ Route.href Route.Index
                , class "flex items-center gap-2.5 hover:opacity-90 transition-opacity"
                ]
                [ viewLogo
                , span [ class "text-2xl font-bold tracking-tight bg-gradient-to-r from-amber-300 via-rose-400 to-rose-600 bg-clip-text text-transparent" ]
                    [ text "Trail" ]
                ]
            , span [ class "text-slate-700" ] [ text "·" ]
            , p [ class "text-sm text-slate-400" ]
                [ text
                    (case route of
                        Route.Index ->
                            "Your races."

                        Route.RaceDetail _ ->
                            "Race detail."

                        Route.RaceMap _ ->
                            "Map view."

                        Route.PlanTable _ ->
                            "Plan · table view."

                        Route.PlanKm _ _ ->
                            "Plan · per km."

                        Route.PlanSection _ _ ->
                            "Plan · section."

                        Route.NotFound ->
                            "Lost?"
                    )
                ]
            ]
        ]


viewLogo : Html msg
viewLogo =
    Svg.svg
        [ SA.width "28"
        , SA.height "28"
        , SA.viewBox "0 0 64 64"
        ]
        [ Svg.defs []
            [ Svg.linearGradient
                [ SA.id "logo-peak", SA.x1 "0", SA.y1 "0", SA.x2 "0", SA.y2 "1" ]
                [ Svg.stop [ SA.offset "0%", SA.stopColor "#ff5f6a" ] []
                , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A" ] []
                ]
            ]
        , Svg.path
            [ SA.d "M6 50 L22 28 L30 38 L42 18 L58 50 Z"
            , SA.fill "url(#logo-peak)"
            , SA.opacity "0.85"
            ]
            []
        , Svg.path
            [ SA.d "M6 50 L22 28 L30 38 L42 18 L58 50"
            , SA.fill "none"
            , SA.stroke "#ff5f6a"
            , SA.strokeWidth "2"
            , SA.strokeLinejoin "round"
            , SA.strokeLinecap "round"
            ]
            []
        , Svg.circle
            [ SA.cx "42"
            , SA.cy "18"
            , SA.r "2.5"
            , SA.fill "#fbbf24"
            ]
            []
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

        ( Route.RaceMap rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewRaceMap model race

                Nothing ->
                    viewRaceNotFound

        ( Route.PlanTable rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewPlanTable model race

                Nothing ->
                    viewRaceNotFound

        ( Route.PlanKm rid kmIndex, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewPlanKm model race kmIndex

                Nothing ->
                    viewRaceNotFound

        ( Route.PlanSection rid secIndex, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewPlanSection model race secIndex

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
            viewRaceGrid model races
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
                    ( "Drop a .gpx or .trail file", "or click to choose one", False )

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


viewRaceGrid : Model -> List Race -> Html Msg
viewRaceGrid model races =
    div [ class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5" ]
        (List.map (\r -> viewRaceCard (Dict.get (raceIdToString r.id) model.parsedTracks) r) races)


viewRaceCard : Maybe Track -> Race -> Html Msg
viewRaceCard maybeTrack race =
    let
        ( catLetter, catColor, catLabel ) =
            distanceCategory race.distance
    in
    div
        [ class "trail-card-in group relative bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden hover:border-rose-500/60 hover:-translate-y-0.5 hover:shadow-lg hover:shadow-rose-500/10 transition-all duration-200 flex flex-col" ]
        [ case race.coverImage of
            Just dataUrl ->
                div
                    [ class "relative h-28 border-b border-slate-800"
                    , A.style "background-image" ("url(" ++ dataUrl ++ ")")
                    , A.style "background-size" "cover"
                    , A.style "background-position" "center"
                    ]
                    [ div [ class "absolute inset-0 bg-gradient-to-t from-slate-900 to-slate-900/10" ] []
                    , div [ class ("absolute top-0 left-0 right-0 h-1.5 " ++ catColor) ] []
                    ]

            Nothing ->
                viewCoverSparkline catColor maybeTrack
        , a
            [ Route.href (Route.RaceDetail race.id)
            , class "block p-5 space-y-4"
            ]
            [ div [ class "flex items-start gap-3" ]
                [ div
                    [ class
                        ("flex-shrink-0 w-12 h-12 rounded-lg flex items-center justify-center text-white font-bold text-lg shadow-lg "
                            ++ catColor
                        )
                    ]
                    [ text catLetter ]
                , div [ class "min-w-0 flex-1" ]
                    [ p [ class "text-base font-semibold text-slate-100 truncate" ] [ text race.name ]
                    , let
                        dens =
                            elevationDensity race.distance race.gain

                        ( densText, densTone ) =
                            densityLabel dens
                      in
                      p [ class "text-[10px] uppercase tracking-wider text-slate-500 truncate" ]
                        [ text catLabel
                        , span [ class ("ml-1.5 " ++ densTone) ]
                            [ text ("· " ++ densText ++ " · " ++ formatInt dens ++ " m/km") ]
                        ]
                    , p [ class "text-xs text-slate-500 truncate mt-0.5" ]
                        [ text (raceSubtitle race) ]
                    ]
                ]
            , div [ class "grid grid-cols-3 gap-2 text-center" ]
                [ miniStat (formatKm race.distance) "km"
                , miniStat (formatInt race.gain) "m+"
                , miniStat (formatInt race.loss) "m−"
                ]
            , if List.isEmpty race.aidStations then
                p [ class "text-xs text-slate-600" ]
                    [ text "No aid stations yet." ]

              else
                p [ class "text-xs text-amber-400/70" ]
                    [ text
                        ("★ "
                            ++ String.fromInt (List.length race.aidStations)
                            ++ (if List.length race.aidStations == 1 then
                                    " aid station planned"

                                else
                                    " aid stations planned"
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


distanceCategory : Float -> ( String, String, String )
distanceCategory meters =
    let
        km =
            meters / 1000
    in
    if km < 30 then
        ( "S", "bg-sky-500", "Short" )

    else if km < 70 then
        ( "M", "bg-amber-500", "Medium" )

    else if km < 120 then
        ( "L", "bg-orange-500", "Long" )

    else
        ( "XL", "bg-rose-600", "Ultra" )


{-| Elevation density in meters of gain per kilometer of distance.
See pace-prediction-roadmap.md §11.A.
-}
elevationDensity : Float -> Float -> Float
elevationDensity distanceMeters gainMeters =
    if distanceMeters <= 0 then
        0

    else
        gainMeters / (distanceMeters / 1000)


{-| Six buckets from `(label, tone-class)`. Tone intensifies with density
so the eye finds steep races on the index. Cutoffs match
pace-prediction-roadmap.md §11.A.
-}
densityLabel : Float -> ( String, String )
densityLabel mPerKm =
    if mPerKm < 5 then
        ( "Flat", "text-slate-400" )

    else if mPerKm < 20 then
        ( "Rolling", "text-sky-400" )

    else if mPerKm < 40 then
        ( "Hilly", "text-amber-400" )

    else if mPerKm < 55 then
        ( "Mountainous", "text-orange-400" )

    else if mPerKm < 70 then
        ( "Very mountainous", "text-rose-400" )

    else
        ( "Extreme", "text-rose-500" )


{-| Refined Naismith-Scarf flat-equivalent distance in km:
`D_km + ascent_m / 100 + descent_m / 1000`. The mental model:
"this race feels like running X km on the flat."
-}
equivalentFlatKm : Float -> Float -> Float -> Float
equivalentFlatKm distanceMeters gainMeters lossMeters =
    distanceMeters / 1000 + gainMeters / 100 + lossMeters / 1000


{-| Five grade buckets for per-km classification. `slope` is the
end-to-end Δele / Δdist ratio already stored on `Planning.Km`.
Cutoffs at ±0.04 and ±0.10 from spec §3.2. Tone intensifies at
the extremes; the runnable band stays neutral so the table doesn't
shout when nothing notable is happening.
-}
gradeClass : Float -> ( String, String )
gradeClass slope =
    if slope >= 0.1 then
        ( "Steep climb", "text-rose-300 bg-rose-500/15 ring-rose-500/30" )

    else if slope >= 0.04 then
        ( "Climb", "text-rose-400 bg-rose-500/10 ring-rose-500/20" )

    else if slope > -0.04 then
        ( "Runnable", "text-slate-400 bg-slate-500/10 ring-slate-500/20" )

    else if slope > -0.1 then
        ( "Descent", "text-emerald-400 bg-emerald-500/10 ring-emerald-500/20" )

    else
        ( "Steep descent", "text-emerald-300 bg-emerald-500/15 ring-emerald-500/30" )


{-| Race-card "cover" when there's no user image: a real silhouette
of the race's elevation profile drawn at the card width. Each race
becomes visually recognisable by its profile shape. If the parsed
track isn't available yet (shouldn't happen post-RacesLoaded), we
fall back to a generic stylised silhouette so the card stays the
same shape.
-}
viewCoverSparkline : String -> Maybe Track -> Html msg
viewCoverSparkline catColor maybeTrack =
    let
        bandHeight =
            112
    in
    div
        [ class "relative h-28 border-b border-slate-800 overflow-hidden bg-slate-950"
        ]
        [ div [ class ("absolute top-0 left-0 right-0 h-1.5 " ++ catColor) ] []
        , case maybeTrack of
            Just t ->
                raceSparkline t bandHeight

            Nothing ->
                Svg.svg
                    [ SA.viewBox "0 0 320 112"
                    , SA.preserveAspectRatio "xMidYMid slice"
                    , SA.class "absolute inset-0 w-full h-full opacity-30"
                    ]
                    [ Svg.path
                        [ SA.d "M0 90 L40 70 L70 80 L110 40 L150 70 L190 50 L230 75 L270 45 L320 75 L320 112 L0 112 Z"
                        , SA.fill "#ff5f6a"
                        , SA.fillOpacity "0.4"
                        ]
                        []
                    ]
        ]


raceSparkline : Track -> Int -> Html msg
raceSparkline track bandHeight =
    let
        width =
            320.0

        height =
            toFloat bandHeight

        pad =
            8.0

        chartW =
            width

        chartH =
            height - pad * 2

        eleRange =
            max 1 (track.maxEle - track.minEle)

        mPerPxX =
            track.totalDist / chartW

        -- The card's silhouette is read for shape, not strict 1:1.
        -- We scale the elevation to fill the band's height with
        -- some breathing room so flat routes don't render as a line.
        yScale =
            chartH / eleRange

        coords =
            List.map2 (\d p -> ( d / mPerPxX, pad + (track.maxEle - p.ele) * yScale ))
                track.cumDist
                track.points
                |> List.indexedMap Tuple.pair
                |> List.filter (\( i, _ ) -> modBy (max 1 (List.length track.points // 240)) i == 0)
                |> List.map Tuple.second

        pathD =
            buildAreaForSparkline coords (height - pad)

        strokeD =
            buildStrokeForSparkline coords
    in
    Svg.svg
        [ SA.viewBox ("0 0 " ++ String.fromFloat width ++ " " ++ String.fromFloat height)
        , SA.preserveAspectRatio "none"
        , SA.class "absolute inset-0 w-full h-full"
        ]
        [ Svg.defs []
            [ Svg.linearGradient
                [ SA.id "spark-fill", SA.x1 "0", SA.y1 "0", SA.x2 "0", SA.y2 "1" ]
                [ Svg.stop [ SA.offset "0%", SA.stopColor "#ff5f6a", SA.stopOpacity "0.55" ] []
                , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A", SA.stopOpacity "0.05" ] []
                ]
            ]
        , Svg.path
            [ SA.d pathD
            , SA.fill "url(#spark-fill)"
            ]
            []
        , Svg.path
            [ SA.d strokeD
            , SA.fill "none"
            , SA.stroke "#ff5f6a"
            , SA.strokeWidth "1.4"
            , SA.strokeLinejoin "round"
            , SA.strokeLinecap "round"
            ]
            []
        ]


buildAreaForSparkline : List ( Float, Float ) -> Float -> String
buildAreaForSparkline coords baseline =
    case coords of
        [] ->
            ""

        ( x0, y0 ) :: _ ->
            let
                middle =
                    coords
                        |> List.drop 1
                        |> List.map (\( x, y ) -> "L " ++ formatFloat 2 x ++ " " ++ formatFloat 2 y)
                        |> String.join " "

                xLast =
                    coords
                        |> List.reverse
                        |> List.head
                        |> Maybe.map Tuple.first
                        |> Maybe.withDefault x0
            in
            String.join " "
                [ "M " ++ formatFloat 2 x0 ++ " " ++ formatFloat 2 baseline
                , "L " ++ formatFloat 2 x0 ++ " " ++ formatFloat 2 y0
                , middle
                , "L " ++ formatFloat 2 xLast ++ " " ++ formatFloat 2 baseline
                , "Z"
                ]


buildStrokeForSparkline : List ( Float, Float ) -> String
buildStrokeForSparkline coords =
    case coords of
        [] ->
            ""

        ( x0, y0 ) :: rest ->
            ("M " ++ formatFloat 2 x0 ++ " " ++ formatFloat 2 y0)
                :: List.map (\( x, y ) -> "L " ++ formatFloat 2 x ++ " " ++ formatFloat 2 y) rest
                |> String.join " "


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
            sortAidStations race.aidStations
                |> List.indexedMap
                    (\i a ->
                        { distance = a.distance
                        , label = aidShortLabel a
                        , index = i + 1
                        }
                    )
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 space-y-8 px-6" ]
        [ a [ Route.href Route.Index, class "inline-flex items-center gap-2 text-sm text-slate-400 hover:text-slate-100" ]
            [ text "← Back to races" ]
        , viewRaceHero race
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ div [ class "min-w-0" ]
                [ div [ class "flex items-center gap-3 flex-wrap" ]
                    [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text race.name ]
                    , case model.metaEditor of
                        MetaClosed ->
                            button
                                [ onClick OpenMetaEdit
                                , class "px-3 py-1.5 text-xs border border-slate-700 rounded-md hover:bg-slate-800 text-slate-300"
                                ]
                                [ text "Edit details" ]

                        MetaOpen _ ->
                            text ""
                    ]
                , p [ class "mt-2 text-sm text-slate-500" ] [ text (raceSubtitle race) ]
                , case ( race.url, race.notes ) of
                    ( "", "" ) ->
                        text ""

                    ( "", _ ) ->
                        p [ class "mt-2 text-sm text-slate-400 max-w-prose whitespace-pre-line" ] [ text race.notes ]

                    ( url, "" ) ->
                        a
                            [ A.href url
                            , A.target "_blank"
                            , A.rel "noopener noreferrer"
                            , class "mt-2 inline-block text-sm text-rose-400 hover:text-rose-300 underline"
                            ]
                            [ text url ]

                    ( url, notes ) ->
                        div [ class "mt-2 space-y-2" ]
                            [ a
                                [ A.href url
                                , A.target "_blank"
                                , A.rel "noopener noreferrer"
                                , class "inline-block text-sm text-rose-400 hover:text-rose-300 underline"
                                ]
                                [ text url ]
                            , p [ class "text-sm text-slate-400 max-w-prose whitespace-pre-line" ] [ text notes ]
                            ]
                ]
            , let
                dens =
                    elevationDensity race.distance race.gain

                eqKm =
                    equivalentFlatKm race.distance race.gain race.loss
              in
              div [ class "grid grid-cols-3 lg:grid-cols-5 gap-3 sm:gap-4" ]
                [ bigStat "Distance" (formatKm race.distance) "km"
                , bigStat "Gain" (formatInt race.gain) "m"
                , bigStat "Loss" (formatInt race.loss) "m"
                , bigStat "Density" (formatInt dens) "m/km"
                , bigStat "Flat eq." (formatFloat 1 eqKm) "km"
                ]
            ]
        , case model.metaEditor of
            MetaOpen form ->
                viewMetaForm form

            MetaClosed ->
                text ""
        , case cachedTrack of
            Just track ->
                viewProfileSection model track containerWidth markers

            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text "Parsing GPX…" ]
        , viewAidStationsSection model race
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 flex items-center justify-between gap-4 flex-wrap" ]
            [ div []
                [ p [ class "font-medium text-slate-100" ] [ text "Plan this race" ]
                , p [ class "text-sm text-slate-400 mt-1" ] [ text "Set a target time. We'll distribute pace by km using the terrain. Override any km manually." ]
                ]
            , a
                [ Route.href (Route.PlanTable race.id)
                , class "px-4 py-2 bg-rose-600 text-white rounded-md hover:bg-rose-500 text-sm font-medium"
                ]
                [ text "Open the plan →" ]
            ]
        , viewMapTeaser model race
        , viewExportPanel race
        ]


viewMapTeaser : Model -> Race -> Html Msg
viewMapTeaser model race =
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 flex items-center justify-between gap-4 flex-wrap" ]
        [ div []
            [ p [ class "font-medium text-slate-100" ] [ text "Open on the map" ]
            , p [ class "text-sm text-slate-400 mt-1" ]
                [ text "Real-world OSM tiles. Useful for spotting which forest you're about to enter."
                ]
            ]
        , let
            _ =
                model
          in
          a
            [ Route.href (Route.RaceMap race.id)
            , class "px-4 py-2 border border-slate-700 rounded-md hover:bg-slate-800 text-sm font-medium text-slate-100"
            ]
            [ text "View on map →" ]
        ]


viewRaceMap : Model -> Race -> Html Msg
viewRaceMap model race =
    let
        track =
            Dict.get (raceIdToString race.id) model.parsedTracks

        coords =
            case track of
                Just t ->
                    t.points
                        |> List.map (\p -> [ p.lat, p.lon ])

                Nothing ->
                    []

        sortedAids =
            sortAidStations race.aidStations

        aidMarkers =
            case track of
                Just t ->
                    sortedAids
                        |> List.indexedMap
                            (\i a ->
                                case findCoordAt a.distance t of
                                    Just ( lat, lon ) ->
                                        Just
                                            (Encode.object
                                                [ ( "kind", Encode.string "aid" )
                                                , ( "lat", Encode.float lat )
                                                , ( "lon", Encode.float lon )
                                                , ( "label", Encode.string (String.fromInt (i + 1)) )
                                                , ( "name", Encode.string a.name )
                                                , ( "index", Encode.int (i + 1) )
                                                , ( "distanceKm", Encode.float (a.distance / 1000) )
                                                , ( "restSeconds", Encode.int a.restSeconds )
                                                , ( "services"
                                                  , Encode.list
                                                        (\s ->
                                                            Encode.string (Types.serviceToString s)
                                                        )
                                                        a.services
                                                  )
                                                ]
                                            )

                                    Nothing ->
                                        Nothing
                            )
                        |> List.filterMap identity

                Nothing ->
                    []

        startFinishMarkers =
            case track of
                Just t ->
                    let
                        first =
                            List.head t.points

                        last =
                            t.points |> List.reverse |> List.head
                    in
                    [ first
                        |> Maybe.map
                            (\p ->
                                Encode.object
                                    [ ( "kind", Encode.string "start" )
                                    , ( "lat", Encode.float p.lat )
                                    , ( "lon", Encode.float p.lon )
                                    , ( "label", Encode.string "S" )
                                    , ( "name", Encode.string "Start" )
                                    ]
                            )
                    , last
                        |> Maybe.map
                            (\p ->
                                Encode.object
                                    [ ( "kind", Encode.string "finish" )
                                    , ( "lat", Encode.float p.lat )
                                    , ( "lon", Encode.float p.lon )
                                    , ( "label", Encode.string "F" )
                                    , ( "name", Encode.string ("Finish · " ++ formatFloat 1 (race.distance / 1000) ++ " km") )
                                    ]
                            )
                    ]
                        |> List.filterMap identity

                Nothing ->
                    []

        markers =
            startFinishMarkers ++ aidMarkers

        trackJson =
            Encode.encode 0 (Encode.list (Encode.list Encode.float) coords)

        markersJson =
            Encode.encode 0 (Encode.list identity markers)
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 px-6 space-y-6" ]
        [ div [ class "text-sm text-slate-400 flex items-center gap-2" ]
            [ a [ Route.href Route.Index, class "hover:text-slate-100" ] [ text "Races" ]
            , span [ class "text-slate-700" ] [ text "/" ]
            , a [ Route.href (Route.RaceDetail race.id), class "hover:text-slate-100" ] [ text race.name ]
            , span [ class "text-slate-700" ] [ text "/" ]
            , span [ class "text-slate-200" ] [ text "Map" ]
            ]
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text race.name ]
            , p [ class "text-sm text-slate-500" ]
                [ text
                    (formatFloat 1 (race.distance / 1000)
                        ++ " km · "
                        ++ String.fromInt (List.length sortedAids)
                        ++ (if List.length sortedAids == 1 then
                                " aid station"

                            else
                                " aid stations"
                           )
                    )
                ]
            ]
        , case track of
            Just _ ->
                Html.node "trail-map"
                    [ A.attribute "track" trackJson
                    , A.attribute "markers" markersJson
                    , A.style "display" "block"
                    , A.style "width" "100%"
                    , A.style "height" "70vh"
                    , class "rounded-2xl border border-slate-800 overflow-hidden"
                    ]
                    []

            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text "Parsing GPX…" ]
        , p [ class "text-xs text-slate-500" ]
            [ text "Tiles from OpenStreetMap. Once you've panned over an area, those tiles are cached for offline use." ]
        ]


findCoordAt : Float -> Track -> Maybe ( Float, Float )
findCoordAt distance track =
    let
        pairs =
            List.map2 Tuple.pair track.cumDist track.points

        pick ( d, p ) best =
            case best of
                Nothing ->
                    Just ( abs (d - distance), p )

                Just ( bestDelta, _ ) ->
                    let
                        delta =
                            abs (d - distance)
                    in
                    if delta < bestDelta then
                        Just ( delta, p )

                    else
                        best
    in
    pairs
        |> List.foldl pick Nothing
        |> Maybe.map (\( _, p ) -> ( p.lat, p.lon ))


viewExportPanel : Race -> Html Msg
viewExportPanel race =
    let
        hasAids =
            not (List.isEmpty race.aidStations)
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
        [ div [ class "flex items-baseline gap-3" ]
            [ h2 [ class "text-xl font-semibold text-slate-100" ] [ text "Export" ]
            , span [ class "text-xs text-slate-500" ] [ text "everything lives on this device · take it with you" ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-2 gap-3" ]
            [ exportCard
                { titleText = "GPX for Coros"
                , description =
                    if hasAids then
                        "Re-emit the original GPX with your aid stations as standard waypoints. Upload it to the COROS app, then enable Waypoint Alerts on the route — that's what surfaces aid stations in Pace Strategy."

                    else
                        "Add aid stations first — without them the export is identical to the source."
                , buttonText = "Download .gpx"
                , msg = ExportGpxForCoros
                , disabled = not hasAids
                }
            , exportCard
                { titleText = "Project file (.trail)"
                , description = "Everything about this race in one file: GPX, aid stations, target time, per-km plan, notes. Import it back here later, or share it."
                , buttonText = "Download .trail"
                , msg = ExportProjectFile
                , disabled = False
                }
            ]
        ]


exportCard :
    { titleText : String
    , description : String
    , buttonText : String
    , msg : Msg
    , disabled : Bool
    }
    -> Html Msg
exportCard opts =
    div [ class "rounded-xl bg-slate-950 border border-slate-800 p-4 flex flex-col gap-3" ]
        [ p [ class "font-medium text-slate-100" ] [ text opts.titleText ]
        , p [ class "text-xs text-slate-400 flex-1" ] [ text opts.description ]
        , button
            [ onClick opts.msg
            , A.disabled opts.disabled
            , class "px-3 py-2 text-sm bg-rose-600 text-white rounded-md hover:bg-rose-500 disabled:opacity-40 disabled:cursor-not-allowed w-fit"
            ]
            [ text opts.buttonText ]
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


viewRaceHero : Race -> Html msg
viewRaceHero race =
    case race.coverImage of
        Just dataUrl ->
            div
                [ class "relative rounded-2xl overflow-hidden border border-slate-800 h-40 sm:h-56"
                , A.style "background-image" ("url(" ++ dataUrl ++ ")")
                , A.style "background-size" "cover"
                , A.style "background-position" "center"
                ]
                [ div [ class "absolute inset-0 bg-gradient-to-t from-slate-950/90 to-slate-950/10" ] [] ]

        Nothing ->
            text ""


viewMetaForm : MetaForm -> Html Msg
viewMetaForm form =
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4" ]
        [ div [ class "flex items-baseline justify-between" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text "Edit race details" ]
            , button
                [ onClick CloseMetaEdit, class "text-xs text-slate-500 hover:text-slate-200" ]
                [ text "Cancel" ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
            [ field "Name"
                [ input
                    [ A.type_ "text"
                    , A.value form.name
                    , onInput MetaSetName
                    , inputClass
                    ]
                    []
                ]
            , field "Date (optional)"
                [ input
                    [ A.type_ "date"
                    , A.value form.date
                    , onInput MetaSetDate
                    , inputClass
                    ]
                    []
                ]
            , field "Location (optional)"
                [ input
                    [ A.type_ "text"
                    , A.value form.location
                    , A.placeholder "Chamonix, FR"
                    , onInput MetaSetLocation
                    , inputClass
                    ]
                    []
                ]
            , field "URL (optional)"
                [ input
                    [ A.type_ "url"
                    , A.value form.url
                    , A.placeholder "https://utmbmontblanc.com/…"
                    , onInput MetaSetUrl
                    , inputClass
                    ]
                    []
                ]
            ]
        , field "Notes"
            [ textarea
                [ A.value form.notes
                , A.placeholder "Anything that should travel with this race — checklist, strategy, mental cues…"
                , A.rows 4
                , onInput MetaSetNotes
                , inputClass
                ]
                []
            ]
        , div [ class "space-y-2" ]
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text "Cover image (optional)" ]
            , case form.coverImage of
                Just dataUrl ->
                    div [ class "flex items-center gap-3" ]
                        [ div
                            [ class "w-24 h-16 rounded-lg border border-slate-800 bg-slate-950"
                            , A.style "background-image" ("url(" ++ dataUrl ++ ")")
                            , A.style "background-size" "cover"
                            , A.style "background-position" "center"
                            ]
                            []
                        , div [ class "flex gap-2" ]
                            [ button
                                [ onClick MetaPickCover
                                , class "px-3 py-1.5 text-xs border border-slate-700 rounded hover:bg-slate-800 text-slate-200"
                                ]
                                [ text "Replace" ]
                            , button
                                [ onClick MetaClearCover
                                , class "px-3 py-1.5 text-xs text-slate-500 hover:text-rose-400"
                                ]
                                [ text "Remove" ]
                            ]
                        ]

                Nothing ->
                    button
                        [ onClick MetaPickCover
                        , class "px-3 py-1.5 text-xs border border-dashed border-slate-700 rounded hover:bg-slate-800 text-slate-300"
                        ]
                        [ text "Pick an image" ]
            ]
        , div [ class "flex justify-end gap-2" ]
            [ button
                [ onClick CloseMetaEdit
                , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                ]
                [ text "Cancel" ]
            , button
                [ onClick MetaSubmit
                , class "px-4 py-2 text-sm bg-rose-600 text-white rounded-md hover:bg-rose-500 font-medium"
                ]
                [ text "Save changes" ]
            ]
        ]


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
-- PLAN VIEWS
-- ============================================================


viewPlanTable : Model -> Race -> Html Msg
viewPlanTable model race =
    let
        kms =
            Dict.get (raceIdToString race.id) model.kmsCache
                |> Maybe.withDefault []

        aidRest =
            Planning.aidRestTotal race.aidStations

        results =
            Planning.distribute
                { target = race.plan.targetSeconds
                , kms = kms
                , plan = race.plan
                , aidRestSeconds = aidRest
                }

        currentSum =
            Dict.foldl (\_ r acc -> acc + r.seconds) 0 results + aidRest
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 space-y-6 px-6" ]
        [ viewPlanCrumb race
        , viewPlanHeader race
        , viewPlanTargetPanel race aidRest currentSum model.targetTimeText
        , viewActualRunStrip model race
        , viewPlanTabs race model.planTableMode
        , case model.planTableMode of
            ByKm ->
                viewKmTable race kms results

            BySection ->
                viewSectionTable race kms results
        ]


viewActualRunStrip : Model -> Race -> Html Msg
viewActualRunStrip model race =
    let
        errorBanner =
            case model.actualRunError of
                Just msg ->
                    p [ class "mt-2 text-sm text-rose-400" ]
                        [ text ("Couldn't parse actual run: " ++ msg) ]

                Nothing ->
                    text ""
    in
    case race.actualSplits of
        Nothing ->
            div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-4 flex items-center justify-between gap-4 flex-wrap" ]
                [ div [ class "min-w-0" ]
                    [ p [ class "font-medium text-slate-100" ] [ text "Link actual run" ]
                    , p [ class "text-sm text-slate-400 mt-0.5" ]
                        [ text "Upload the .gpx of your completed run to compare per-km splits against the plan." ]
                    , errorBanner
                    ]
                , button
                    [ onClick (OpenActualGpxPicker race.id)
                    , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-100 whitespace-nowrap"
                    ]
                    [ text "Upload .gpx" ]
                ]

        Just actual ->
            div [ class "rounded-2xl bg-slate-900 border border-emerald-500/30 p-4 flex items-center justify-between gap-4 flex-wrap" ]
                [ div [ class "flex items-center gap-6 flex-wrap min-w-0" ]
                    [ div []
                        [ p [ class "text-[10px] uppercase tracking-wider text-emerald-400/80" ] [ text "Actual run linked" ]
                        , p [ class "text-2xl font-semibold text-slate-100 tabular-nums mt-0.5" ]
                            [ text (formatHhmm actual.totalSeconds) ]
                        ]
                    , div []
                        [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text "Distance run" ]
                        , p [ class "text-lg text-slate-200 tabular-nums mt-0.5" ]
                            [ text (formatFloat 2 (actual.totalDistance / 1000) ++ " km") ]
                        ]
                    , let
                        plannedSum =
                            Dict.foldl (\_ s acc -> acc + s) 0 actual.splits

                        targetForCompare =
                            race.plan.targetSeconds |> Maybe.withDefault 0
                      in
                      if targetForCompare > 0 then
                        let
                            diff =
                                actual.totalSeconds - targetForCompare

                            ( label, tone ) =
                                if diff > 0 then
                                    ( "+" ++ formatMmss diff ++ " vs target", "text-rose-400" )

                                else if diff < 0 then
                                    ( "−" ++ formatMmss (abs diff) ++ " vs target", "text-emerald-400" )

                                else
                                    ( "On target", "text-emerald-400" )
                        in
                        div []
                            [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text "vs Target" ]
                            , p [ class ("text-lg tabular-nums mt-0.5 " ++ tone) ] [ text label ]
                            ]

                      else
                        text ""
                    ]
                , div [ class "flex items-center gap-2" ]
                    [ button
                        [ onClick (OpenActualGpxPicker race.id)
                        , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                        ]
                        [ text "Replace" ]
                    , button
                        [ onClick (ClearActualRun race.id)
                        , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-400 hover:text-rose-400"
                        ]
                        [ text "Unlink" ]
                    , errorBanner
                    ]
                ]


viewPlanCrumb : Race -> Html Msg
viewPlanCrumb race =
    div [ class "text-sm text-slate-400 flex items-center gap-2" ]
        [ a [ Route.href Route.Index, class "hover:text-slate-100" ] [ text "Races" ]
        , span [ class "text-slate-700" ] [ text "/" ]
        , a [ Route.href (Route.RaceDetail race.id), class "hover:text-slate-100" ] [ text race.name ]
        , span [ class "text-slate-700" ] [ text "/" ]
        , span [ class "text-slate-200" ] [ text "Plan" ]
        ]


viewPlanHeader : Race -> Html Msg
viewPlanHeader race =
    div [ class "flex items-end justify-between gap-4 flex-wrap" ]
        [ div []
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text "Plan" ]
            , p [ class "mt-2 text-sm text-slate-500" ]
                [ text
                    (formatFloat 1 (race.distance / 1000)
                        ++ " km · "
                        ++ formatInt race.gain
                        ++ " m+ · "
                        ++ String.fromInt (List.length race.aidStations)
                        ++ (if List.length race.aidStations == 1 then
                                " aid station"

                            else
                                " aid stations"
                           )
                    )
                ]
            ]
        ]


viewPlanTargetPanel : Race -> Int -> Int -> String -> Html Msg
viewPlanTargetPanel race aidRest currentSum targetText =
    let
        target =
            race.plan.targetSeconds

        diff =
            case target of
                Just t ->
                    currentSum - t

                Nothing ->
                    0
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 grid grid-cols-1 sm:grid-cols-4 gap-4 items-center" ]
        [ div []
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider mb-2" ] [ text "Target time" ]
            , input
                [ A.type_ "text"
                , A.value targetText
                , A.placeholder "h:mm"
                , onInput SetTargetTimeText
                , onBlur CommitTargetTime
                , A.attribute "inputmode" "numeric"
                , class "w-full bg-slate-950 border border-slate-800 rounded-md px-3 py-2 text-2xl font-semibold text-slate-100 tabular-nums focus:outline-none focus:border-rose-500/60"
                ]
                []
            , p [ class "text-xs text-slate-500 mt-1" ] [ text "Tap Tab or click away to commit." ]
            ]
        , planStat "Current sum"
            (if currentSum == 0 then
                "—"

             else
                formatHhmm currentSum
            )
            (case target of
                Just _ ->
                    if diff == 0 then
                        Just ( "On target", "text-emerald-400" )

                    else if diff > 0 then
                        Just ( "+" ++ formatMmss diff ++ " over", "text-rose-400" )

                    else
                        Just ( formatMmss (abs diff) ++ " under", "text-amber-400" )

                Nothing ->
                    Nothing
            )
        , planStat "Aid rest"
            (formatHhmm aidRest)
            (Just
                ( String.fromInt (List.length race.aidStations)
                    ++ " stops"
                , "text-slate-500"
                )
            )
        , planStat "Avg pace"
            (case ( target, race.distance > 0 ) of
                ( Just t, True ) ->
                    paceMinPerKm (t - aidRest) race.distance

                _ ->
                    "—"
            )
            (Just ( "/ km · moving", "text-slate-500" ))
        ]


planStat : String -> String -> Maybe ( String, String ) -> Html msg
planStat label value note =
    div []
        [ p [ class "text-xs text-slate-500 uppercase tracking-wider mb-1" ] [ text label ]
        , p [ class "text-2xl font-semibold text-slate-100 tabular-nums" ] [ text value ]
        , case note of
            Just ( t, colorClass ) ->
                p [ class ("text-xs " ++ colorClass) ] [ text t ]

            Nothing ->
                text ""
        ]


viewPlanTabs : Race -> TableMode -> Html Msg
viewPlanTabs _ mode =
    div [ class "flex items-center justify-between gap-3 flex-wrap" ]
        [ div [ class "flex items-center gap-1 bg-slate-900 border border-slate-800 rounded-lg p-1" ]
            [ tabButton "By km" (mode == ByKm) (SetPlanTableMode ByKm)
            , tabButton "By section" (mode == BySection) (SetPlanTableMode BySection)
            ]
        , div [ class "flex items-center gap-2" ]
            [ button
                [ onClick
                    (if mode == ByKm then
                        ExportCsvKms

                     else
                        ExportCsvSections
                    )
                , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200 flex items-center gap-2"
                ]
                [ text "Download CSV" ]
            , p [ class "text-xs text-slate-500" ]
                [ text "Tap a row to edit a km in detail." ]
            ]
        ]


tabButton : String -> Bool -> Msg -> Html Msg
tabButton labelText active msg =
    button
        [ onClick msg
        , classList
            [ ( "px-3 py-1.5 text-sm rounded transition-colors", True )
            , ( "bg-rose-600 text-white font-medium shadow-sm", active )
            , ( "text-slate-400 hover:text-slate-100", not active )
            ]
        ]
        [ text labelText ]


viewKmTable : Race -> List Km -> Dict Int KmResult -> Html Msg
viewKmTable race kms results =
    let
        aidByKm =
            race.aidStations
                |> List.map (\a -> ( Planning.kmAtDistance a.distance, a ))
                |> List.foldl (\( idx, a ) acc -> Dict.update idx (Just << (\v -> a :: Maybe.withDefault [] v)) acc) Dict.empty

        cumulativeRows =
            kmsWithCumulative race aidByKm results kms

        hasActual =
            race.actualSplits /= Nothing

        actualHeaders =
            if hasActual then
                [ Html.th [ class "px-4 py-3 text-right" ] [ text "Actual" ]
                , Html.th [ class "px-4 py-3 text-right" ] [ text "Δ vs plan" ]
                ]

            else
                []
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 overflow-x-auto" ]
        [ Html.table [ class "w-full text-sm" ]
            [ Html.thead [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ Html.tr []
                    ([ Html.th [ class "px-4 py-3 text-left" ] [ text "Km" ]
                     , Html.th [ class "px-4 py-3 text-left" ] [ text "Span" ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text "Δ ele" ]
                     , Html.th [ class "px-4 py-3 text-left" ] [ text "Grade" ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text "Pace" ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text "Time" ]
                     ]
                        ++ actualHeaders
                        ++ [ Html.th [ class "px-4 py-3 text-right" ] [ text "Cum" ]
                           , Html.th [ class "px-4 py-3 text-left" ] [ text "Notes / stops" ]
                           ]
                    )
                ]
            , Html.tbody [] cumulativeRows
            ]
        ]


kmsWithCumulative :
    Race
    -> Dict Int (List AidStation)
    -> Dict Int KmResult
    -> List Km
    -> List (Html Msg)
kmsWithCumulative race aidByKm results kms =
    let
        go km ( running, acc ) =
            let
                result =
                    Dict.get km.index results
                        |> Maybe.withDefault { seconds = 0, source = AutoComputed }

                stops =
                    Dict.get km.index aidByKm |> Maybe.withDefault []

                stopRest =
                    List.foldl (\a sum -> sum + a.restSeconds) 0 stops

                newRunning =
                    running + result.seconds + stopRest

                notes =
                    (kmPlanFor km.index race.plan).notes
            in
            ( newRunning, viewKmRow race km result stops notes newRunning :: acc )

        ( _, rows ) =
            List.foldl go ( 0, [] ) kms
    in
    List.reverse rows


viewKmRow : Race -> Km -> KmResult -> List AidStation -> String -> Int -> Html Msg
viewKmRow race km result stops notes cumulative =
    let
        deltaEle =
            km.eleEnd - km.eleStart

        pace =
            paceMinPerKm result.seconds km.distance

        timeCell =
            div [ class "flex items-baseline justify-end gap-1 tabular-nums" ]
                [ span [ class "text-slate-100 font-medium" ] [ text (formatMmss result.seconds) ]
                , span
                    [ classList
                        [ ( "text-[10px] uppercase tracking-wider", True )
                        , ( "text-amber-300", result.source == UserManual )
                        , ( "text-slate-600", result.source == AutoComputed )
                        ]
                    ]
                    [ text
                        (if result.source == UserManual then
                            "M"

                         else
                            "A"
                        )
                    ]
                ]
    in
    let
        kmCell =
            Html.td [ class "px-4 py-3 align-top tabular-nums text-slate-300 font-medium" ]
                [ text (String.fromInt (km.index + 1)) ]

        spanCell =
            Html.td [ class "px-4 py-3 align-top text-slate-400 tabular-nums whitespace-nowrap" ]
                [ text
                    (formatFloat 2 (km.distStart / 1000)
                        ++ " → "
                        ++ formatFloat 2 (km.distEnd / 1000)
                        ++ " km"
                    )
                ]

        eleCell =
            Html.td [ class "px-4 py-3 align-top text-right tabular-nums" ]
                [ span
                    [ classList
                        [ ( "font-medium", True )
                        , ( "text-rose-300", deltaEle > 0 )
                        , ( "text-emerald-300", deltaEle < 0 )
                        , ( "text-slate-400", deltaEle == 0 )
                        ]
                    ]
                    [ text
                        ((if deltaEle > 0 then
                            "+"

                          else
                            ""
                         )
                            ++ formatInt deltaEle
                            ++ " m"
                        )
                    ]
                ]

        gradeCell =
            Html.td [ class "px-4 py-3 align-top" ]
                [ let
                    ( gLabel, gTone ) =
                        gradeClass km.slope
                  in
                  span
                    [ class
                        ("inline-flex items-center px-2 py-0.5 rounded text-[10px] uppercase tracking-wider whitespace-nowrap ring-1 ring-inset "
                            ++ gTone
                        )
                    ]
                    [ text gLabel ]
                ]

        paceCell =
            Html.td [ class "px-4 py-3 align-top text-right text-slate-300 tabular-nums" ] [ text pace ]

        plannedCell =
            Html.td [ class "px-4 py-3 align-top text-right" ] [ timeCell ]

        actualCells =
            case race.actualSplits of
                Just actual ->
                    let
                        maybeActualS =
                            Dict.get km.index actual.splits

                        actualCell =
                            Html.td [ class "px-4 py-3 align-top text-right text-slate-200 tabular-nums" ]
                                [ case maybeActualS of
                                    Just s ->
                                        text (formatMmss s)

                                    Nothing ->
                                        span [ class "text-slate-700" ] [ text "—" ]
                                ]

                        diffCell =
                            Html.td [ class "px-4 py-3 align-top text-right tabular-nums" ]
                                [ case maybeActualS of
                                    Just s ->
                                        let
                                            diff =
                                                s - result.seconds

                                            ( tone, prefix ) =
                                                if diff > 0 then
                                                    ( "text-rose-300", "+" )

                                                else if diff < 0 then
                                                    ( "text-emerald-300", "−" )

                                                else
                                                    ( "text-slate-400", "" )
                                        in
                                        span [ class tone ]
                                            [ text (prefix ++ formatMmss (abs diff)) ]

                                    Nothing ->
                                        span [ class "text-slate-700" ] [ text "—" ]
                                ]
                    in
                    [ actualCell, diffCell ]

                Nothing ->
                    []

        cumCell =
            Html.td [ class "px-4 py-3 align-top text-right text-slate-300 tabular-nums" ]
                [ text (formatHmsLong cumulative) ]

        notesCell =
            Html.td [ class "px-4 py-3 align-top text-slate-400 text-xs" ]
                [ if List.isEmpty stops && String.isEmpty notes then
                    span [ class "text-slate-700" ] [ text "—" ]

                  else
                    div [ class "space-y-1" ]
                        (List.map
                            (\a ->
                                div [ class "text-amber-300" ]
                                    [ text ("★ " ++ a.name ++ " · +" ++ formatRest a.restSeconds) ]
                            )
                            stops
                            ++ (if String.isEmpty notes then
                                    []

                                else
                                    [ p [ class "text-slate-400 line-clamp-2" ] [ text notes ] ]
                               )
                        )
                ]
    in
    Html.tr
        [ class "border-t border-slate-800 hover:bg-slate-950/60 transition-colors cursor-pointer"
        , onClick (NavigateTo (Route.PlanKm race.id km.index))
        , A.attribute "role" "link"
        , A.attribute "tabindex" "0"
        ]
        ([ kmCell, spanCell, eleCell, gradeCell, paceCell, plannedCell ]
            ++ actualCells
            ++ [ cumCell, notesCell ]
        )


viewSectionTable : Race -> List Km -> Dict Int KmResult -> Html Msg
viewSectionTable race kms results =
    let
        sections =
            Planning.sectionsForRace
                { totalDistance = race.distance
                , aidStations = race.aidStations
                , kms = kms
                }

        rows =
            sectionsWithCumulative race results sections
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 overflow-x-auto" ]
        [ Html.table [ class "w-full text-sm" ]
            [ Html.thead [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ Html.tr []
                    [ Html.th [ class "px-4 py-3 text-left" ] [ text "Section" ]
                    , Html.th [ class "px-4 py-3 text-right" ] [ text "Distance" ]
                    , Html.th [ class "px-4 py-3 text-right" ] [ text "Gain" ]
                    , Html.th [ class "px-4 py-3 text-right" ] [ text "Loss" ]
                    , Html.th [ class "px-4 py-3 text-right" ] [ text "Pace" ]
                    , Html.th [ class "px-4 py-3 text-right" ] [ text "Section time" ]
                    , Html.th [ class "px-4 py-3 text-right" ] [ text "Cum" ]
                    ]
                ]
            , Html.tbody [] rows
            ]
        ]


sectionsWithCumulative : Race -> Dict Int KmResult -> List Planning.Section -> List (Html Msg)
sectionsWithCumulative race results sections =
    let
        go section ( running, acc ) =
            let
                sectionSeconds =
                    section.kmIndices
                        |> List.filterMap (\idx -> Dict.get idx results)
                        |> List.foldl (\r sum -> sum + r.seconds) 0

                aidRest =
                    section.followedByAid
                        |> Maybe.map .restSeconds
                        |> Maybe.withDefault 0

                runningAfterSection =
                    running + sectionSeconds

                runningAfterRest =
                    runningAfterSection + aidRest

                pace =
                    paceMinPerKm sectionSeconds section.distance

                sectionRow =
                    Html.tr
                        [ class "border-t border-slate-800 hover:bg-slate-950/60 transition-colors cursor-pointer"
                        , onClick (NavigateTo (Route.PlanSection race.id section.index))
                        , A.attribute "role" "link"
                        , A.attribute "tabindex" "0"
                        ]
                        [ Html.td [ class "px-4 py-3 text-white font-medium" ] [ text section.label ]
                        , Html.td [ class "px-4 py-3 text-right text-slate-300 tabular-nums" ] [ text (formatFloat 2 (section.distance / 1000) ++ " km") ]
                        , Html.td [ class "px-4 py-3 text-right text-rose-300 tabular-nums" ] [ text (formatInt section.gain ++ " m+") ]
                        , Html.td [ class "px-4 py-3 text-right text-emerald-300 tabular-nums" ] [ text (formatInt section.loss ++ " m−") ]
                        , Html.td [ class "px-4 py-3 text-right text-slate-300 tabular-nums" ] [ text pace ]
                        , Html.td [ class "px-4 py-3 text-right text-white font-medium tabular-nums" ] [ text (formatHmsLong sectionSeconds) ]
                        , Html.td [ class "px-4 py-3 text-right text-slate-300 tabular-nums" ] [ text (formatHmsLong runningAfterSection) ]
                        ]

                aidRow =
                    case section.followedByAid of
                        Just aid ->
                            Html.tr [ class "border-t border-slate-800 bg-slate-950/40" ]
                                [ Html.td [ class "px-4 py-2 text-xs text-amber-300" ]
                                    [ text ("★ " ++ aid.name) ]
                                , Html.td [ class "px-4 py-2 text-right text-xs text-slate-500 tabular-nums" ] [ text "—" ]
                                , Html.td [ class "px-4 py-2 text-right text-xs text-slate-500 tabular-nums" ] [ text "—" ]
                                , Html.td [ class "px-4 py-2 text-right text-xs text-slate-500 tabular-nums" ] [ text "—" ]
                                , Html.td [ class "px-4 py-2 text-right text-xs text-slate-500 tabular-nums" ] [ text "—" ]
                                , Html.td [ class "px-4 py-2 text-right text-xs text-amber-300 tabular-nums" ] [ text ("+" ++ formatHmsLong aid.restSeconds) ]
                                , Html.td [ class "px-4 py-2 text-right text-xs text-slate-400 tabular-nums" ] [ text (formatHmsLong runningAfterRest) ]
                                ]

                        Nothing ->
                            text ""
            in
            ( runningAfterRest, aidRow :: sectionRow :: acc )

        ( _, rowsRev ) =
            List.foldl go ( 0, [] ) sections
    in
    List.reverse rowsRev



-- PER-SECTION CARD VIEW


viewPlanSection : Model -> Race -> Int -> Html Msg
viewPlanSection model race secIndex =
    let
        kms =
            Dict.get (raceIdToString race.id) model.kmsCache
                |> Maybe.withDefault []

        aidRest =
            Planning.aidRestTotal race.aidStations

        results =
            Planning.distribute
                { target = race.plan.targetSeconds
                , kms = kms
                , plan = race.plan
                , aidRestSeconds = aidRest
                }

        sections =
            Planning.sectionsForRace
                { totalDistance = race.distance
                , aidStations = race.aidStations
                , kms = kms
                }

        section =
            sections
                |> List.filter (\s -> s.index == secIndex)
                |> List.head

        prevIndex =
            if secIndex <= 0 then
                Nothing

            else
                Just (secIndex - 1)

        nextIndex =
            if secIndex + 1 >= List.length sections then
                Nothing

            else
                Just (secIndex + 1)
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 px-6 space-y-6" ]
        [ viewPlanCrumb race
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ h1 [ class "text-3xl font-bold tracking-tight text-white" ]
                [ text ("Section " ++ String.fromInt (secIndex + 1) ++ " of " ++ String.fromInt (List.length sections)) ]
            , a [ Route.href (Route.PlanTable race.id), class "text-sm text-slate-400 hover:text-slate-100" ]
                [ text "Back to table" ]
            ]
        , case section of
            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text "This section doesn't exist in this race." ]

            Just s ->
                viewSectionCardAndDetails model race kms results s prevIndex nextIndex
        ]


viewSectionCardAndDetails :
    Model
    -> Race
    -> List Km
    -> Dict Int KmResult
    -> Planning.Section
    -> Maybe Int
    -> Maybe Int
    -> Html Msg
viewSectionCardAndDetails _ race kms results section prevIndex nextIndex =
    let
        containedKms =
            kms |> List.filter (\km -> List.member km.index section.kmIndices)

        sectionSeconds =
            section.kmIndices
                |> List.filterMap (\idx -> Dict.get idx results)
                |> List.foldl (\r sum -> sum + r.seconds) 0

        sectionPace =
            paceMinPerKm sectionSeconds section.distance

        navLink labelText maybeIdx =
            case maybeIdx of
                Just idx ->
                    a
                        [ Route.href (Route.PlanSection race.id idx)
                        , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 hover:border-slate-600 text-slate-200 w-[210px] text-center"
                        ]
                        [ text labelText ]

                Nothing ->
                    span
                        [ class "px-4 py-2 text-sm border border-slate-800 rounded-md text-slate-600 cursor-not-allowed w-[210px] text-center" ]
                        [ text labelText ]
    in
    div [ class "grid grid-cols-1 lg:grid-cols-2 gap-6 items-start" ]
        [ div [ class "flex flex-col items-center gap-4 lg:sticky lg:top-24" ]
            [ viewSectionCard section containedKms
            , div [ class "flex gap-3 justify-between" ]
                [ navLink "← Prev section" prevIndex
                , navLink "Next section →" nextIndex
                ]
            ]
        , viewSectionDetails race section containedKms results sectionSeconds sectionPace
        ]


viewSectionCard : Planning.Section -> List Km -> Html msg
viewSectionCard section containedKms =
    let
        cardWidth =
            440.0

        chartPadH =
            16.0

        chartWidth =
            cardWidth - chartPadH * 2

        -- The whole section is meant to fit in one card, so we drop 1:1
        -- here and use a per-section mPerPx instead. A note on the card
        -- makes the change of scale explicit.
        mPerPx =
            if section.distance <= 0 then
                1

            else
                section.distance / chartWidth

        eleRange =
            containedKms
                |> List.foldl
                    (\km ( lo, hi ) -> ( min lo km.minEle, max hi km.maxEle ))
                    ( 1.0e9, -1.0e9 )

        ( minEle, maxEle ) =
            if List.isEmpty containedKms then
                ( 0, 0 )

            else
                eleRange

        eleSpan =
            max 1 (maxEle - minEle)

        chartHeight =
            max 90 (min 240 (eleSpan / mPerPx))

        chartTopPad =
            14

        chartBottomPad =
            22

        chartTotalHeight =
            chartTopPad + chartHeight + chartBottomPad

        elevBaseline =
            chartTopPad + chartHeight

        toX d =
            -- d is absolute distance from start; subtract section start.
            chartPadH + (d - section.distStart) / mPerPx

        toY ele =
            elevBaseline - (ele - minEle) * (chartHeight / eleSpan)

        coords =
            containedKms
                |> List.concatMap
                    (\km ->
                        List.map2 (\d p -> ( toX (km.distStart + d), toY p.ele )) km.cumDist km.points
                    )

        pathD =
            buildAreaPathLocal coords elevBaseline

        strokeD =
            buildStrokePathLocal coords

        sectionGain =
            section.gain

        sectionLoss =
            section.loss
    in
    div
        [ class "relative bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden flex flex-col"
        , A.style "width" (String.fromFloat cardWidth ++ "px")
        ]
        [ div [ class "px-5 pt-4 pb-3 border-b border-slate-800" ]
            [ p [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ text
                    ("Section · "
                        ++ formatFloat 1 (section.distance / 1000)
                        ++ " km wide · scale "
                        ++ formatFloat 1 mPerPx
                        ++ " m/px"
                    )
                ]
            , p [ class "mt-1 text-2xl font-semibold text-white" ] [ text section.label ]
            , div [ class "mt-2 flex items-baseline gap-3 text-sm tabular-nums" ]
                [ span [ class "text-rose-300" ] [ text ("+" ++ formatInt sectionGain ++ " m") ]
                , span [ class "text-emerald-300" ] [ text ("−" ++ formatInt sectionLoss ++ " m") ]
                ]
            ]
        , div [ class "flex-1" ]
            [ Svg.svg
                [ SA.width (String.fromFloat cardWidth)
                , SA.height (String.fromFloat chartTotalHeight)
                , SA.viewBox ("0 0 " ++ String.fromFloat cardWidth ++ " " ++ String.fromFloat chartTotalHeight)
                , A.style "display" "block"
                ]
                [ Svg.defs []
                    [ Svg.linearGradient
                        [ SA.id ("sec-fill-" ++ String.fromInt section.index)
                        , SA.x1 "0"
                        , SA.y1 "0"
                        , SA.x2 "0"
                        , SA.y2 "1"
                        ]
                        [ Svg.stop [ SA.offset "0%", SA.stopColor "#E52E3A", SA.stopOpacity "0.7" ] []
                        , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A", SA.stopOpacity "0.05" ] []
                        ]
                    ]
                , Svg.path
                    [ SA.d pathD
                    , SA.fill ("url(#sec-fill-" ++ String.fromInt section.index ++ ")")
                    , SA.stroke "none"
                    ]
                    []
                , Svg.path
                    [ SA.d strokeD
                    , SA.fill "none"
                    , SA.stroke "#ff5f6a"
                    , SA.strokeWidth "1.8"
                    , SA.strokeLinejoin "round"
                    , SA.strokeLinecap "round"
                    ]
                    []
                ]
            ]
        , div [ class "px-5 py-3 border-t border-slate-800 flex items-baseline justify-between text-xs text-slate-400 tabular-nums" ]
            [ span [] [ text (formatInt minEle ++ " m") ]
            , span [ class "text-amber-400" ] [ text ("⤒ " ++ formatInt maxEle ++ " m") ]
            , span [] [ text (formatInt maxEle ++ " m") ]
            ]
        ]


viewSectionDetails :
    Race
    -> Planning.Section
    -> List Km
    -> Dict Int KmResult
    -> Int
    -> String
    -> Html Msg
viewSectionDetails race section containedKms results sectionSeconds sectionPace =
    div [ class "space-y-4" ]
        [ div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4" ]
            [ h3 [ class "text-base font-semibold text-white" ] [ text "Section plan" ]
            , div [ class "grid grid-cols-2 sm:grid-cols-4 gap-3 tabular-nums" ]
                [ smallStat "Distance" (formatFloat 1 (section.distance / 1000)) "km"
                , smallStat "Time" (formatHmsLong sectionSeconds) ""
                , smallStat "Pace" sectionPace "/km"
                , smallStat "Kms"
                    (String.fromInt (List.length containedKms))
                    ""
                ]
            , case section.followedByAid of
                Just aid ->
                    div [ class "rounded-xl bg-amber-400/5 border border-amber-400/30 p-4 space-y-2" ]
                        [ p [ class "text-xs uppercase tracking-wider text-amber-300" ]
                            [ text "Ends at" ]
                        , div [ class "flex items-baseline justify-between gap-3 flex-wrap" ]
                            [ p [ class "text-lg font-semibold text-white" ] [ text aid.name ]
                            , p [ class "text-sm text-amber-200 tabular-nums" ]
                                [ text (formatFloat 1 (aid.distance / 1000) ++ " km · " ++ formatRest aid.restSeconds) ]
                            ]
                        , if List.isEmpty aid.services then
                            text ""

                          else
                            p [ class "flex gap-2 text-lg" ]
                                (List.map
                                    (\s ->
                                        span [ A.title (serviceLabel s) ]
                                            [ text (serviceIcon s) ]
                                    )
                                    aid.services
                                )
                        , a
                            [ Route.href (Route.RaceDetail race.id)
                            , class "inline-block text-xs text-amber-300 hover:text-amber-200 underline"
                            ]
                            [ text "Edit aid station →" ]
                        ]

                Nothing ->
                    div [ class "rounded-xl bg-slate-950 border border-slate-800 p-4 text-sm text-slate-400" ]
                        [ text "🏁 This section finishes the race." ]
            ]
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
            [ h3 [ class "text-base font-semibold text-white" ] [ text "Kilometers in this section" ]
            , div [ class "divide-y divide-slate-800" ]
                (List.map (viewSectionKmRow race results) containedKms)
            ]
        ]


viewSectionKmRow : Race -> Dict Int KmResult -> Km -> Html Msg
viewSectionKmRow race results km =
    let
        result =
            Dict.get km.index results
                |> Maybe.withDefault { seconds = 0, source = AutoComputed }

        deltaEle =
            km.eleEnd - km.eleStart

        pace =
            paceMinPerKm result.seconds km.distance
    in
    a
        [ Route.href (Route.PlanKm race.id km.index)
        , class "flex items-center gap-4 py-3 px-1 hover:bg-slate-950/40 -mx-1 transition-colors rounded-md cursor-pointer"
        ]
        [ div [ class "flex items-center justify-center w-9 h-9 rounded-full bg-rose-500/15 border border-rose-500/40 text-rose-300 text-xs font-semibold flex-shrink-0" ]
            [ text (String.fromInt (km.index + 1)) ]
        , div [ class "min-w-0 flex-1" ]
            [ p [ class "text-sm text-white font-medium tabular-nums" ]
                [ text
                    (formatFloat 2 (km.distStart / 1000)
                        ++ " → "
                        ++ formatFloat 2 (km.distEnd / 1000)
                        ++ " km"
                    )
                ]
            , p [ class "text-xs text-slate-500 tabular-nums" ]
                [ text
                    ((if deltaEle >= 0 then
                        "+"

                      else
                        ""
                     )
                        ++ formatInt deltaEle
                        ++ " m · "
                        ++ pace
                        ++ "/km"
                    )
                ]
            ]
        , div [ class "flex items-baseline gap-2 tabular-nums" ]
            [ span [ class "text-sm text-white font-medium" ] [ text (formatMmss result.seconds) ]
            , span
                [ classList
                    [ ( "text-[10px] uppercase tracking-wider", True )
                    , ( "text-amber-300", result.source == UserManual )
                    , ( "text-slate-600", result.source == AutoComputed )
                    ]
                ]
                [ text
                    (if result.source == UserManual then
                        "M"

                     else
                        "A"
                    )
                ]
            ]
        , span [ class "text-slate-500 text-sm" ] [ text "›" ]
        ]



-- PER-KM CARD VIEW


viewPlanKm : Model -> Race -> Int -> Html Msg
viewPlanKm model race kmIndex =
    let
        kms =
            Dict.get (raceIdToString race.id) model.kmsCache
                |> Maybe.withDefault []

        thisKm =
            kms
                |> List.filter (\k -> k.index == kmIndex)
                |> List.head

        aidRest =
            Planning.aidRestTotal race.aidStations

        results =
            Planning.distribute
                { target = race.plan.targetSeconds
                , kms = kms
                , plan = race.plan
                , aidRestSeconds = aidRest
                }

        prevIndex =
            if kmIndex <= 0 then
                Nothing

            else
                Just (kmIndex - 1)

        nextIndex =
            if kmIndex + 1 >= List.length kms then
                Nothing

            else
                Just (kmIndex + 1)
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 px-6 space-y-6" ]
        [ viewPlanCrumb race
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ]
                [ text ("Km " ++ String.fromInt (kmIndex + 1) ++ " of " ++ String.fromInt (List.length kms)) ]
            , a [ Route.href (Route.PlanTable race.id), class "text-sm text-slate-400 hover:text-slate-100" ]
                [ text "Back to table" ]
            ]
        , case thisKm of
            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text "This km doesn't exist in this race." ]

            Just km ->
                viewKmCardAndForm model race km kms results aidRest prevIndex nextIndex
        ]


viewKmCardAndForm : Model -> Race -> Km -> List Km -> Dict Int KmResult -> Int -> Maybe Int -> Maybe Int -> Html Msg
viewKmCardAndForm model race km allKms results _ prevIndex nextIndex =
    let
        result =
            Dict.get km.index results |> Maybe.withDefault { seconds = 0, source = AutoComputed }

        kp =
            kmPlanFor km.index race.plan

        stopsInKm =
            race.aidStations
                |> List.filter (\a -> a.distance >= km.distStart && a.distance <= km.distEnd)

        -- Uniform chart height across every km in this race, so the card
        -- shape doesn't change as we navigate and the prev/next buttons
        -- stay in a predictable spot. Computed from the steepest km's
        -- elevation range at the same m/px we draw at.
        raceMaxRange =
            allKms
                |> List.map (\k -> max 1 (k.maxEle - k.minEle))
                |> List.maximum
                |> Maybe.withDefault 100

        navLink labelText maybeIdx =
            case maybeIdx of
                Just idx ->
                    a
                        [ Route.href (Route.PlanKm race.id idx)
                        , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 hover:border-slate-600 text-slate-200 w-[170px] text-center"
                        ]
                        [ text labelText ]

                Nothing ->
                    span
                        [ class "px-4 py-2 text-sm border border-slate-800 rounded-md text-slate-600 cursor-not-allowed w-[170px] text-center" ]
                        [ text labelText ]
    in
    div [ class "grid grid-cols-1 lg:grid-cols-2 gap-6 items-start" ]
        [ div [ class "flex flex-col items-center gap-4 lg:sticky lg:top-24" ]
            [ viewKmCard km stopsInKm raceMaxRange
            , div [ class "flex gap-3 w-[360px] justify-between" ]
                [ navLink "← Prev km" prevIndex
                , navLink "Next km →" nextIndex
                ]
            ]
        , viewKmForm model race km result kp stopsInKm
        ]


viewKmCard : Km -> List AidStation -> Float -> Html Msg
viewKmCard km stopsInKm raceMaxRange =
    let
        cardWidth =
            360.0

        chartHorizontalPadding =
            16.0

        chartWidth =
            cardWidth - chartHorizontalPadding * 2

        -- True 1:1: 1 km horizontally = chartWidth px → m/px = 1000 / chartWidth.
        mPerPx =
            1000 / chartWidth

        -- The race-wide max range × m/px → uniform chart height for every
        -- km in this race. Flatter kms get headroom above the silhouette,
        -- which is the right visual story (a flat km feels flat in this
        -- frame; the climb km fills the frame).
        chartHeight =
            max 80 (raceMaxRange / mPerPx)

        chartTopPad =
            14

        chartBottomPad =
            22

        chartTotalHeight =
            chartTopPad + chartHeight + chartBottomPad

        elevBaseline =
            chartTopPad + chartHeight

        -- Y axis is anchored to maxEle (not raceMaxEle) so each km's
        -- silhouette sits on the bottom of its frame. Empty headroom
        -- above is the visual signal that this km is flatter than the
        -- race's steepest.
        toX d =
            chartHorizontalPadding + d / mPerPx

        toY ele =
            elevBaseline - (ele - km.minEle) / mPerPx

        coords =
            List.map2 (\d p -> ( toX d, toY p.ele )) km.cumDist km.points

        pathD =
            buildAreaPathLocal coords elevBaseline

        strokeD =
            buildStrokePathLocal coords

        stopMarkers =
            List.map (viewKmCardStop chartTopPad elevBaseline km.distStart toX) stopsInKm

        deltaEle =
            km.eleEnd - km.eleStart
    in
    div
        [ class "relative bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden flex flex-col"
        , A.style "width" (String.fromFloat cardWidth ++ "px")
        ]
        [ div [ class "px-5 pt-4 pb-3 border-b border-slate-800" ]
            [ p [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ text
                    ("Km "
                        ++ String.fromInt (km.index + 1)
                        ++ " · 1:1 scale (1 px = "
                        ++ formatFloat 1 mPerPx
                        ++ " m)"
                    )
                ]
            , div [ class "mt-1 flex items-baseline justify-between" ]
                [ p [ class "text-2xl font-semibold text-white tabular-nums" ]
                    [ text
                        (formatFloat 2 (km.distStart / 1000)
                            ++ " → "
                            ++ formatFloat 2 (km.distEnd / 1000)
                            ++ " km"
                        )
                    ]
                , p
                    [ classList
                        [ ( "text-sm tabular-nums font-medium", True )
                        , ( "text-rose-300", deltaEle > 1 )
                        , ( "text-emerald-300", deltaEle < -1 )
                        , ( "text-slate-400", deltaEle >= -1 && deltaEle <= 1 )
                        ]
                    ]
                    [ text
                        ((if deltaEle >= 0 then
                            "+"

                          else
                            ""
                         )
                            ++ formatInt deltaEle
                            ++ " m"
                        )
                    ]
                ]
            ]
        , div [ class "flex-1" ]
            [ Svg.svg
                [ SA.width (String.fromFloat cardWidth)
                , SA.height (String.fromFloat chartTotalHeight)
                , SA.viewBox ("0 0 " ++ String.fromFloat cardWidth ++ " " ++ String.fromFloat chartTotalHeight)
                , A.style "display" "block"
                ]
                [ Svg.defs []
                    [ Svg.linearGradient
                        [ SA.id ("km-fill-" ++ String.fromInt km.index)
                        , SA.x1 "0"
                        , SA.y1 "0"
                        , SA.x2 "0"
                        , SA.y2 "1"
                        ]
                        [ Svg.stop [ SA.offset "0%", SA.stopColor "#E52E3A", SA.stopOpacity "0.7" ] []
                        , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A", SA.stopOpacity "0.05" ] []
                        ]
                    ]
                , Svg.path
                    [ SA.d pathD
                    , SA.fill ("url(#km-fill-" ++ String.fromInt km.index ++ ")")
                    , SA.stroke "none"
                    ]
                    []
                , Svg.path
                    [ SA.d strokeD
                    , SA.fill "none"
                    , SA.stroke "#ff5f6a"
                    , SA.strokeWidth "1.8"
                    , SA.strokeLinejoin "round"
                    , SA.strokeLinecap "round"
                    ]
                    []
                , Svg.g [] stopMarkers
                ]
            ]
        , div [ class "px-5 py-3 border-t border-slate-800 flex items-baseline justify-between text-xs text-slate-400 tabular-nums" ]
            [ span [] [ text (formatInt km.eleStart ++ " m") ]
            , span [ class "text-amber-400" ] [ text ("⤒ " ++ formatInt km.maxEle ++ " m") ]
            , span [] [ text (formatInt km.eleEnd ++ " m") ]
            ]
        ]


viewKmCardStop : Float -> Float -> Float -> (Float -> Float) -> AidStation -> Svg.Svg Msg
viewKmCardStop yTop yBottom kmStart toX aid =
    let
        relative =
            aid.distance - kmStart

        x =
            toX relative
    in
    Svg.g []
        [ Svg.line
            [ SA.x1 (String.fromFloat x)
            , SA.x2 (String.fromFloat x)
            , SA.y1 (String.fromFloat yTop)
            , SA.y2 (String.fromFloat yBottom)
            , SA.stroke "#fbbf24"
            , SA.strokeWidth "1"
            , SA.strokeDasharray "2 2"
            ]
            []
        , Svg.circle
            [ SA.cx (String.fromFloat x)
            , SA.cy (String.fromFloat yTop)
            , SA.r "5"
            , SA.fill "#fbbf24"
            ]
            []
        ]


buildAreaPathLocal : List ( Float, Float ) -> Float -> String
buildAreaPathLocal coords baseline =
    case coords of
        [] ->
            ""

        ( x0, y0 ) :: _ ->
            let
                middle =
                    coords
                        |> List.drop 1
                        |> List.map (\( x, y ) -> "L " ++ fmtCoord x ++ " " ++ fmtCoord y)
                        |> String.join " "

                xLast =
                    coords
                        |> List.reverse
                        |> List.head
                        |> Maybe.map Tuple.first
                        |> Maybe.withDefault x0
            in
            String.join " "
                [ "M " ++ fmtCoord x0 ++ " " ++ fmtCoord baseline
                , "L " ++ fmtCoord x0 ++ " " ++ fmtCoord y0
                , middle
                , "L " ++ fmtCoord xLast ++ " " ++ fmtCoord baseline
                , "Z"
                ]


buildStrokePathLocal : List ( Float, Float ) -> String
buildStrokePathLocal coords =
    case coords of
        [] ->
            ""

        ( x0, y0 ) :: rest ->
            ("M " ++ fmtCoord x0 ++ " " ++ fmtCoord y0)
                :: List.map (\( x, y ) -> "L " ++ fmtCoord x ++ " " ++ fmtCoord y) rest
                |> String.join " "


fmtCoord : Float -> String
fmtCoord f =
    let
        rounded =
            toFloat (round (f * 100)) / 100
    in
    String.fromFloat rounded


viewKmForm :
    Model
    -> Race
    -> Km
    -> KmResult
    -> Types.KmPlan
    -> List AidStation
    -> Html Msg
viewKmForm model _ km result kp stopsInKm =
    let
        sourceBadge =
            case result.source of
                UserManual ->
                    span [ class "px-2 py-0.5 text-[10px] uppercase tracking-wider bg-amber-400/20 text-amber-300 rounded" ]
                        [ text "Manual" ]

                AutoComputed ->
                    span [ class "px-2 py-0.5 text-[10px] uppercase tracking-wider bg-slate-800 text-slate-400 rounded" ]
                        [ text "Auto" ]

        pace =
            paceMinPerKm result.seconds km.distance
    in
    div [ class "space-y-5 rounded-2xl bg-slate-900 border border-slate-800 p-5" ]
        [ div [ class "flex items-baseline justify-between gap-2" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text "Plan this km" ]
            , sourceBadge
            ]
        , div [ class "grid grid-cols-3 gap-3 tabular-nums" ]
            [ smallStat "Distance" (formatFloat 2 (km.distance / 1000)) "km"
            , smallStat "Δ ele" (formatInt (km.eleEnd - km.eleStart)) "m"
            , smallStat "Slope" (formatFloat 1 (km.slope * 100)) "%"
            ]
        , div [ class "grid grid-cols-2 gap-3" ]
            [ field "Target time"
                [ input
                    [ A.type_ "text"
                    , A.value model.kmTimeText
                    , A.placeholder
                        (if result.seconds > 0 then
                            formatMmss result.seconds ++ " (auto)"

                         else
                            "m:ss"
                        )
                    , onInput SetKmTimeText
                    , onBlur (CommitKmTimeForKm km.index)
                    , class "w-full bg-slate-950 border border-slate-800 rounded-md px-3 py-2 text-lg font-medium text-slate-100 tabular-nums focus:outline-none focus:border-rose-500/60"
                    ]
                    []
                ]
            , div [ class "space-y-1" ]
                [ span [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text "Pace" ]
                , div [ class "px-3 py-2 bg-slate-950 border border-slate-800 rounded-md text-lg font-medium text-slate-100 tabular-nums" ]
                    [ text (pace ++ "/km") ]
                ]
            ]
        , case kp.time of
            Manual _ ->
                button
                    [ onClick (ResetKmToAuto km.index)
                    , class "text-xs text-slate-400 hover:text-slate-100 underline"
                    ]
                    [ text "Reset to auto (GAP)" ]

            Auto ->
                p [ class "text-xs text-slate-500" ]
                    [ text "Auto-distributed from your target total time using the slope of this km." ]
        , field "Notes"
            [ textarea
                [ A.value model.kmNotesText
                , A.placeholder "Anything to remember about this km — surface, exposure, mental cues…"
                , A.rows 3
                , onInput SetKmNotesText
                , onBlur (CommitKmNotesForKm km.index)
                , class "w-full bg-slate-950 border border-slate-800 rounded-md px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-rose-500/60"
                ]
                []
            ]
        , if List.isEmpty stopsInKm then
            text ""

          else
            div [ class "space-y-2" ]
                [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text "Aid stations in this km" ]
                , div [ class "space-y-1" ]
                    (List.map
                        (\a ->
                            div [ class "text-sm text-amber-300" ]
                                [ text ("★ " ++ a.name ++ " · " ++ formatFloat 2 (a.distance / 1000) ++ " km · " ++ formatRest a.restSeconds) ]
                        )
                        stopsInKm
                    )
                ]
        ]


smallStat : String -> String -> String -> Html msg
smallStat labelText value unit =
    div [ class "rounded-lg bg-slate-950/60 px-3 py-2" ]
        [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text labelText ]
        , p [ class "flex items-baseline gap-1" ]
            [ span [ class "text-base font-semibold text-slate-100" ] [ text value ]
            , span [ class "text-[10px] text-slate-500" ] [ text unit ]
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



-- TIME PARSING / FORMATTING


{-| Parse "H:MM" or "HH:MM" (hours and minutes) into total seconds.
Also accepts "H:MM:SS". Empty / unparseable input → Nothing.
-}
parseHhmm : String -> Maybe Int
parseHhmm raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        Nothing

    else
        case String.split ":" trimmed |> List.map String.trim of
            [ h, m ] ->
                Maybe.map2 (\hh mm -> hh * 3600 + mm * 60) (String.toInt h) (String.toInt m)

            [ h, m, s ] ->
                Maybe.map3 (\hh mm ss -> hh * 3600 + mm * 60 + ss)
                    (String.toInt h)
                    (String.toInt m)
                    (String.toInt s)

            [ only ] ->
                -- bare number = minutes
                String.toInt only |> Maybe.map (\v -> v * 60)

            _ ->
                Nothing


{-| Format seconds as "H:MM" (or "HH:MM" if ≥ 10 h).
-}
formatHhmm : Int -> String
formatHhmm totalSeconds =
    let
        hours =
            totalSeconds // 3600

        minutes =
            modBy 60 (totalSeconds // 60)
    in
    String.fromInt hours
        ++ ":"
        ++ String.padLeft 2 '0' (String.fromInt minutes)


formatHmsLong : Int -> String
formatHmsLong totalSeconds =
    let
        hours =
            totalSeconds // 3600

        minutes =
            modBy 60 (totalSeconds // 60)

        seconds =
            modBy 60 totalSeconds
    in
    if hours == 0 then
        String.fromInt minutes ++ ":" ++ String.padLeft 2 '0' (String.fromInt seconds)

    else
        String.fromInt hours
            ++ ":"
            ++ String.padLeft 2 '0' (String.fromInt minutes)
            ++ ":"
            ++ String.padLeft 2 '0' (String.fromInt seconds)


{-| Parse "M:SS" → seconds. Also accepts bare "M" (minutes).
-}
parseMmss : String -> Maybe Int
parseMmss raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        Nothing

    else
        case String.split ":" trimmed |> List.map String.trim of
            [ m, s ] ->
                Maybe.map2 (\mm ss -> mm * 60 + ss) (String.toInt m) (String.toInt s)

            [ only ] ->
                String.toInt only |> Maybe.map (\v -> v * 60)

            _ ->
                Nothing


{-| Format seconds as "M:SS" (no hours).
-}
formatMmss : Int -> String
formatMmss totalSeconds =
    let
        m =
            totalSeconds // 60

        s =
            modBy 60 totalSeconds
    in
    String.fromInt m ++ ":" ++ String.padLeft 2 '0' (String.fromInt s)


paceMinPerKm : Int -> Float -> String
paceMinPerKm secs meters =
    if meters <= 0 || secs <= 0 then
        "—"

    else
        let
            secPerKm =
                toFloat secs * 1000 / meters

            m =
                floor (secPerKm / 60)

            s =
                round (secPerKm - toFloat (m * 60))
        in
        String.fromInt m ++ ":" ++ String.padLeft 2 '0' (String.fromInt s)
