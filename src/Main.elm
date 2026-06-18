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
import AidCsv
import AthleteProfile exposing (AidStyle(..), DescentSkill(..), Preset(..), Profile, TechSkill(..))
import Browser
import Browser.Events
import Browser.Navigation as Nav
import Calibration
import Changelog
import Context exposing (Context)
import Csv
import Dict exposing (Dict)
import Dom
import Download
import File exposing (File)
import File.Select as Select
import Format
import Gpx exposing (Track)
import GpxExport
import Html exposing (Html, a, button, div, h1, h2, h3, input, label, p, span, text, textarea)
import Html.Attributes as A exposing (class, classList)
import Html.Events as E exposing (onBlur, onClick, onInput, preventDefaultOn)
import Html.Lazy
import Identity
import Json.Decode as D
import Json.Encode as Encode
import Language exposing (Language(..))
import Merge
import Planning exposing (Km, KmResult, KmSource(..))
import Predictor
import Process
import ProjectFile
import Profile exposing (Marker, ScaleMode(..))
import Route exposing (Route)
import Http
import Settings exposing (Settings)
import Storage
import StravaApi
import StravaStreams
import Svg
import Svg.Attributes as SA
import Task
import Time
import TrailSync
import Translations
import Types
    exposing
        ( AidStation
        , ChangeDescriptor(..)
        , ChangeEntry
        , KmTime(..)
        , Plan
        , PlanningLayer
        , Race
        , RaceId
        , Service
        , allServices
        , defaultPlan
        , emptyKmPlan
        , encodeRace
        , encodeRaceMeta
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
    , incomingStravaToken : Maybe String
    , backendUrl : String
    , deviceId : String
    , newUserId : String

    -- i18n (WI-2): the raw IDB `deviceSettings` record (or null on first run),
    -- read by JS before init, plus navigator.language for the first-run default.
    , settings : D.Value
    , browserLanguage : String
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
    , cutoffText : String -- elapsed cutoff "h:mm" / "h:mm:ss"; "" = none
    , services : List Service
    , notesText : String
    , error : Maybe String
    }


type AidEditor
    = AidClosed
    | AidOpen AidForm


type AidImportState
    = AidImportClosed
    | AidImportReading String -- filename being read
    | AidImportPreview ImportPreview


type alias ImportPreview =
    { fileName : String
    , result : AidCsv.ParseResult
    }


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
    , aidImport : AidImportState
    , metaEditor : MetaEditor
    , planTableMode : TableMode
    , targetTimeText : String
    , kmTimeText : String
    , kmNotesText : String
    , actualRunError : Maybe String
    , profile : Profile
    , profileSaved : Bool
    , stravaToken : Maybe String
    , backendUrl : String
    , deviceId : String
    , me : Maybe Identity.Me
    , directory : Identity.Directory
    , freshUserId : String
    , identityFlow : IdentityFlow
    , nameDraft : String
    , renameDraft : String
    , mergeReview : Maybe MergeReview
    , stravaPicker : StravaPicker
    , stravaPickerSearch : String
    , sliderDraft : Maybe Float
    , sparklineCoords : Dict String (List ( Float, Float ))
    , historyOpen : Bool
    , settings : Settings
    }


{-| The render-time locale context (WI-3). Derived from the model here; threaded
into localized views so leaf views never read `model.settings` directly.
-}
toContext : Model -> Context
toContext model =
    { language = model.settings.language }


type StravaPicker
    = PickerClosed
    | PickerLoadingActivities RaceId
    | PickerShowing RaceId (List StravaApi.Activity)
    | PickerLoadingStreams RaceId Int
    | PickerError RaceId String


{-| The identity prompt/flow state machine (WI-5 / TASK-054, ADR-0012). An
export with no identity, or an import where the file's owner isn't me, *pauses*
here; the side effect (mint, stamp, save) happens only when the prompt is
answered, so cancelling leaves no state behind. Design note in
`planning/CURRENT.md` (slice 4).
-}
type IdentityFlow
    = FlowIdle
    | FlowName PendingAfterName
    | FlowOwnership PendingImport
    | FlowLink PendingImport


{-| What the "What's your name?" prompt resumes once a name is entered and a
`userId` is minted: finish the export that triggered it, or finish importing a
file as a reviewer (someone else's plan).
-}
type PendingAfterName
    = ThenExport Race
    | ThenImportReviewer PendingImport


{-| An import paused on an identity prompt: the decoded draft (local id cleared,
courseHash ensured), the source filename (for the persisting state), the file's
denormalized name directory (LWW-merged into the local one **only on
completion**), and the owner's resolved display name (for the prompt copy).
-}
type alias PendingImport =
    { draft : Race
    , fileName : String
    , filePeople : Identity.Directory
    , ownerName : String
    }


{-| The suggestion-review modal state (TASK-056 / ADR-0013). Open only when a
returned `.trail` *diverged* with true collisions the engine couldn't auto-merge;
fast-forwards and disjoint merges apply without it. `merged` is the engine's
result (every conflict defaulted to mine, so it always applies cleanly);
`choices` is the user's per-conflict resolution, keyed by the conflict's index in
`conflicts`. `autoMergedCount` is the disjoint changes already folded in (the
reassurance line). `touched` gates the confirm-on-dismiss (Q-U4).
-}
type alias MergeReview =
    { target : Race
    , incoming : Race
    , filePeople : Identity.Directory
    , merged : PlanningLayer
    , conflicts : List Merge.Conflict
    , choices : Dict Int MergeChoice
    , autoMergedCount : Int
    , touched : Bool
    , confirmingDiscard : Bool
    }


{-| A per-conflict resolution. `ChooseCustom` carries a hand-merged note string
(Q-U3) — used only for `KKmNote` conflicts, where `resolve`'s flip-to-theirs
isn't enough.
-}
type MergeChoice
    = ChooseMine
    | ChooseTheirs
    | ChooseCustom String


init : Flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init flags url key =
    let
        settings =
            Settings.fromFlags flags.settings flags.browserLanguage
    in
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
      , aidImport = AidImportClosed
      , metaEditor = MetaClosed
      , planTableMode = ByKm
      , targetTimeText = ""
      , kmTimeText = ""
      , kmNotesText = ""
      , actualRunError = Nothing
      , profile = AthleteProfile.midPack
      , profileSaved = False
      , stravaToken = flags.incomingStravaToken
      , backendUrl = flags.backendUrl
      , deviceId = flags.deviceId
      , me = Nothing
      , directory = Identity.emptyDirectory
      , freshUserId = flags.newUserId
      , identityFlow = FlowIdle
      , nameDraft = ""
      , renameDraft = ""
      , mergeReview = Nothing
      , stravaPicker = PickerClosed
      , stravaPickerSearch = ""
      , sliderDraft = Nothing
      , sparklineCoords = Dict.empty
      , historyOpen = False
      , settings = settings
      }
    , Cmd.batch
        [ Storage.loadAll
        , Storage.loadProfile
        , Storage.loadIdentity
        , Dom.setHtmlLang (Language.toCode settings.language)
        , case flags.incomingStravaToken of
            Just t ->
                Storage.saveStravaToken (Encode.string t)

            Nothing ->
                Storage.loadStravaToken
        ]
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
    | ChangeLanguage Language
      -- upload
    | DragEnter
    | DragLeave
    | OpenPicker
    | GotFiles File (List File)
    | PickedFile File
    | GotContent String String
    | StartParse String String
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
    | AidSetCutoff String
    | AidSetNotes String
    | AidToggleService Service
    | AidSubmit
    | AidDelete String
    | OpenAidImport
    | AidImportPicked File
    | AidImportContent String String
    | AidImportConfirm
    | AidImportCancel
    | ExportAidCsv
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
    | PrintPlan
      -- metadata edit
    | OpenMetaEdit
    | CloseMetaEdit
    | OpenHistory
    | CloseHistory
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
      -- identity (WI-5 / TASK-054)
    | IdentityLoaded Encode.Value
    | NameDraftInput String
    | NamePromptConfirm
    | NamePromptCancel
    | OwnershipChoose Identity.OwnershipAnswer
    | OwnershipCancel
    | LinkConfirm
    | LinkCancel
    | RenameDraftInput String
    | RenameMeCommit
      -- merge review (WI-3 part 2 / TASK-056)
    | MergePickMine Int
    | MergePickTheirs Int
    | MergeEditNote Int String
    | MergeApply
    | MergeKeepMine
    | MergeConfirmDiscard
    | MergeCancelDiscard
      -- profile
    | ProfileLoaded Encode.Value
    | ProfilePickPreset Preset
    | ProfileSetVmh String
    | ProfileSetPace String
    | ProfileSetFatigueThreshold String
    | ProfileSetFatigueSlope String
    | ProfileSetDescentSkill String
    | ProfileSetTechSkill String
    | ProfileSetAidStyle String
    | ProfileSetLthr String
    | ProfileSetMaxHr String
    | ProfileSave
    | CalibrateVmh
    | CalibrateFlatPace
      -- predictor slider
    | SliderInput String
    | SliderCommit String
      -- strava integration
    | StravaTokenLoaded Encode.Value
    | StravaDisconnect
    | OpenStravaPicker RaceId
    | StravaActivitiesLoaded RaceId (Result Http.Error (List StravaApi.Activity))
    | StravaPickerSelect RaceId Int
    | InternalStartStreamFetch RaceId Int Int String
    | StravaStreamsLoaded RaceId Int Int (Result Http.Error Encode.Value)
    | StravaPickerSetSearch RaceId String
    | StravaPickerClose
    | ModalNoOp


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

        ChangeLanguage lang ->
            let
                settings =
                    model.settings

                next =
                    { settings | language = lang }
            in
            -- Persist + sync <html lang>. Touches no race/`.trail` data: language
            -- is a device preference (ADR-0014).
            ( { model | settings = next }
            , Cmd.batch
                [ Storage.saveSettings (Settings.encode next)
                , Dom.setHtmlLang (Language.toCode lang)
                ]
            )

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
            -- File read finished. The actual parse (Gpx.parseGPX, possibly
            -- multi-second on UTMB-size files) is synchronous and would
            -- block the Elm runtime if we ran it here in the same update
            -- step — the `Parsing` state never reaches the renderer. Yield
            -- one event-loop tick first so the pulse animation can paint,
            -- then do the heavy lifting in StartParse.
            ( { model | upload = Parsing fileName }
            , Task.perform (\_ -> StartParse fileName content) (Process.sleep 1)
            )

        StartParse fileName content ->
            if isProjectFile fileName then
                case ProjectFile.decode content of
                    Err err ->
                        ( { model | upload = UploadFailed fileName err }, Cmd.none )

                    Ok ( importedRace, filePeople ) ->
                        case findShareMatch importedRace model of
                            Just localRace ->
                                -- A returned file for a race we already have →
                                -- merge, not import-as-new (TASK-056). A course
                                -- mismatch on a matching shareId hard-blocks (WI-1).
                                case TrailSync.classify importedRace localRace of
                                    TrailSync.DifferentCourse ->
                                        ( { model | upload = UploadFailed fileName (TrailSync.verdictMessage TrailSync.DifferentCourse) }
                                        , Cmd.none
                                        )

                                    _ ->
                                        routeMerge localRace importedRace filePeople model

                            Nothing ->
                                importAsNew importedRace filePeople fileName model

            else
                case Gpx.parseGPX content of
                    Err err ->
                        ( { model | upload = UploadFailed fileName err }, Cmd.none )

                    Ok track ->
                        let
                            draft =
                                buildDraftRace model.deviceId (myUserId model) model.now track content
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

                        sparklines =
                            buildSparklineCache tracks Dict.empty

                        modelWithRaces =
                            { model
                                | races = LoadedRaces sorted
                                , parsedTracks = tracks
                                , kmsCache = kms
                                , sparklineCoords = sparklines
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
                Ok decoded ->
                    let
                        existing =
                            currentRaces model

                        -- A light (meta) save echoes the race without gpxText
                        -- (it lives in its own IDB row now — TASK-040). Refill
                        -- it from the in-model race so the track/kms caches below
                        -- keep working. A full save (new race) carries gpxText
                        -- and isn't in `existing` yet, so it's used as-is.
                        race =
                            if String.isEmpty decoded.gpxText then
                                findRace decoded.id existing
                                    |> Maybe.map (\prev -> { decoded | gpxText = prev.gpxText })
                                    |> Maybe.withDefault decoded

                            else
                                decoded

                        merged =
                            race :: List.filter (\r -> r.id /= race.id) existing

                        nextRaces =
                            sortRaces merged

                        nextTracks =
                            cacheTrack race model.parsedTracks

                        nextKms =
                            cacheKms race nextTracks model.kmsCache

                        nextSparklines =
                            cacheSparkline (raceIdToString race.id) nextTracks model.sparklineCoords

                        navCmd =
                            -- Only a *full* save (a new race — it carries gpxText)
                            -- navigates. A light/meta echo has empty gpxText, so an
                            -- edit (or the WI-5 link-action's owner re-own, which
                            -- meta-saves several races) never hijacks navigation.
                            if String.isEmpty decoded.gpxText then
                                Cmd.none

                            else
                                -- Already on a race/plan page → don't yank focus.
                                -- Elsewhere (e.g. the index after an import) → open
                                -- the newly-saved race.
                                case model.route of
                                    Route.RaceDetail _ ->
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
                        , sparklineCoords = nextSparklines
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
                , sparklineCoords = Dict.remove idStr model.sparklineCoords
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
            ( { model | aidEditor = AidOpen (emptyAidForm Nothing) }
            , Dom.scrollIntoView aidFormDomId
            )

        OpenEditAid aid ->
            ( { model | aidEditor = AidOpen (aidFormFromExisting aid) }
            , Dom.scrollIntoView aidFormDomId
            )

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

        AidSetCutoff s ->
            ( updateAidForm (\f -> { f | cutoffText = s, error = Nothing }) model, Cmd.none )

        AidSetNotes s ->
            ( updateAidForm (\f -> { f | notesText = s, error = Nothing }) model, Cmd.none )

        AidToggleService s ->
            ( updateAidForm (\f -> { f | services = toggleService s f.services }) model, Cmd.none )

        AidSubmit ->
            case ( model.aidEditor, currentRace model ) of
                ( AidOpen form, Just race ) ->
                    case validateAidForm model.deviceId form race of
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
                            ( model, commitRaceEdit race updatedRace model )

                _ ->
                    ( model, Cmd.none )

        AidDelete aidId ->
            case currentRace model of
                Just race ->
                    let
                        updatedRace =
                            { race | aidStations = List.filter (\a -> a.id /= aidId) race.aidStations }
                    in
                    ( model, commitRaceEdit race updatedRace model )

                Nothing ->
                    ( model, Cmd.none )

        OpenAidImport ->
            ( { model | aidEditor = AidClosed }
            , Select.file [ "text/csv", "text/plain", ".csv" ] AidImportPicked
            )

        AidImportPicked file ->
            ( { model | aidImport = AidImportReading (File.name file) }
            , Task.perform (AidImportContent (File.name file)) (File.toString file)
            )

        AidImportContent fileName content ->
            case currentRace model of
                Just race ->
                    let
                        result =
                            AidCsv.parse
                                { totalDistance = race.distance
                                , defaultRestSeconds = AthleteProfile.aidStyleSecondsPerStation model.profile.aidStyle
                                }
                                content
                    in
                    ( { model | aidImport = AidImportPreview { fileName = fileName, result = result } }
                    , Cmd.none
                    )

                Nothing ->
                    ( { model | aidImport = AidImportClosed }, Cmd.none )

        AidImportConfirm ->
            case ( model.aidImport, currentRace model ) of
                ( AidImportPreview preview, Just race ) ->
                    let
                        ( stations, nextSeq ) =
                            assignAidIds model.deviceId race.aidStationSeq preview.result.stations

                        updatedRace =
                            { race
                                | aidStations = sortAidStations stations
                                , aidStationSeq = nextSeq
                            }
                    in
                    ( { model | aidImport = AidImportClosed }
                    , commitRaceEdit race updatedRace model
                    )

                _ ->
                    ( { model | aidImport = AidImportClosed }, Cmd.none )

        AidImportCancel ->
            ( { model | aidImport = AidImportClosed }, Cmd.none )

        ExportAidCsv ->
            case currentRace model of
                Just race ->
                    ( model
                    , Download.file
                        { filename = csvFilename race "aid-stations"
                        , content = AidCsv.toCsv race.aidStations
                        , mime = "text/csv"
                        }
                    )

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
                    , commitRaceEdit race updatedRace model
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

                        kmRest =
                            aidRestInKm race.aidStations kmIndex

                        trimmed =
                            String.trim model.kmTimeText

                        newTime =
                            if String.isEmpty trimmed then
                                Auto

                            else
                                case parseMmss trimmed of
                                    Just secs ->
                                        -- User typed clock time. Store
                                        -- moving = clock − in-km aid rest.
                                        -- Clamp at 0 if they typed less
                                        -- than the aid rest itself.
                                        Manual (max 0 (secs - kmRest))

                                    Nothing ->
                                        kp.time

                        formatted =
                            case newTime of
                                Manual s ->
                                    formatMmss (s + kmRest)

                                Auto ->
                                    ""

                        updatedKp =
                            { kp | time = newTime }

                        updatedRace =
                            { race | plan = withKmPlan kmIndex updatedKp race.plan }
                    in
                    ( { model | kmTimeText = formatted }
                    , commitRaceEdit race updatedRace model
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
                    ( model, commitRaceEdit race updatedRace model )

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
                    , commitRaceEdit race updatedRace model
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
                                { target = Just (effectiveTargetSeconds model.profile race kms)
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
                                { target = Just (effectiveTargetSeconds model.profile race kms)
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
                    case model.me of
                        Nothing ->
                            -- First share with no identity → mint #1: prompt for a
                            -- name, then export (WI-5 / TASK-054, AC1). The export
                            -- resumes in NamePromptConfirm.
                            ( { model | identityFlow = FlowName (ThenExport race), nameDraft = "" }
                            , Cmd.none
                            )

                        Just m ->
                            let
                                -- Owner backfill on share (AC3): an unowned race
                                -- adopts my id. Then stamp shareId + courseHash for
                                -- a race that predates WI-1 (TASK-053).
                                owned =
                                    if race.owner == "" then
                                        { race | owner = m.userId }

                                    else
                                        race

                                stamped =
                                    TrailSync.ensureIdentity owned

                                -- Record the shared state as the merge ancestor
                                -- (the share point), so a returned `.trail` merges
                                -- against what we sent (TASK-056 / ADR-0013).
                                shared =
                                    { stamped | mergeBase = Just (Merge.planningLayer stamped) }

                                downloadCmd =
                                    exportDownload model.directory shared
                            in
                            if shared == race then
                                ( model, downloadCmd )

                            else
                                -- owner / identity / mergeBase changed → persist (light).
                                ( model
                                , Cmd.batch [ downloadCmd, Storage.saveRaceMeta (encodeRaceMeta shared) ]
                                )

                Nothing ->
                    ( model, Cmd.none )

        PrintPlan ->
            ( model, Dom.print () )

        OpenMetaEdit ->
            case currentRace model of
                Just race ->
                    ( { model | metaEditor = MetaOpen (metaFormFromRace race) }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        CloseMetaEdit ->
            ( { model | metaEditor = MetaClosed }, Cmd.none )

        OpenHistory ->
            ( { model | historyOpen = True }, Cmd.none )

        CloseHistory ->
            ( { model | historyOpen = False }, Cmd.none )

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
                    , commitRaceEdit race updatedRace model
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
                                    , hrPerKm = ActualGpx.computeHrPerKm track
                                    }

                                updatedRace =
                                    { race | actualSplits = Just actual }
                            in
                            ( { model | actualRunError = Nothing }
                            , commitRaceEdit race updatedRace model
                            )

        ClearActualRun rid ->
            case findRace rid (currentRaces model) of
                Nothing ->
                    ( model, Cmd.none )

                Just race ->
                    ( { model | actualRunError = Nothing }
                    , Storage.saveRaceMeta (encodeRaceMeta { race | actualSplits = Nothing })
                    )

        ActualGpxFailed err ->
            ( { model | actualRunError = Just err }, Cmd.none )

        IdentityLoaded value ->
            -- The dedicated identity store is empty until the first mint, so a
            -- null row is the normal startup case → keep the Nothing/empty
            -- defaults. WI-5 / TASK-054.
            case D.decodeValue (D.nullable Identity.decodeStored) value of
                Ok (Just stored) ->
                    ( { model | me = stored.me, directory = stored.directory }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        NameDraftInput s ->
            ( { model | nameDraft = s }, Cmd.none )

        NamePromptConfirm ->
            case model.identityFlow of
                FlowName after ->
                    let
                        name =
                            String.trim model.nameDraft
                    in
                    if name == "" then
                        ( model, Cmd.none )

                    else
                        let
                            -- Mint (the one and only mint per device): the
                            -- per-boot candidate is consumed here, ≤ once because
                            -- both mint points gate on `me == Nothing` (AC1).
                            userId =
                                model.freshUserId

                            me_ =
                                { userId = userId, displayName = name }

                            dir =
                                Dict.insert userId
                                    { displayName = name, nameUpdatedAt = model.now }
                                    model.directory

                            baseModel =
                                { model
                                    | me = Just me_
                                    , directory = dir
                                    , identityFlow = FlowIdle
                                    , nameDraft = ""
                                }

                            saveId =
                                Storage.saveIdentity (Identity.encodeStored { me = Just me_, directory = dir })
                        in
                        case after of
                            ThenExport race ->
                                let
                                    stamped =
                                        TrailSync.ensureIdentity { race | owner = userId }

                                    -- The share point: record what we sent as the
                                    -- merge ancestor (TASK-056 / ADR-0013).
                                    shared =
                                        { stamped | mergeBase = Just (Merge.planningLayer stamped) }
                                in
                                ( baseModel
                                , Cmd.batch
                                    [ saveId
                                    , Storage.saveRaceMeta (encodeRaceMeta shared)
                                    , exportDownload dir shared
                                    ]
                                )

                            ThenImportReviewer pending ->
                                -- Identity established → import keeping the file's
                                -- owner (I'm the reviewer). completeImport persists
                                -- the bundle + saves the draft.
                                completeImport pending baseModel

                _ ->
                    ( model, Cmd.none )

        NamePromptCancel ->
            ( { model | identityFlow = FlowIdle, nameDraft = "", upload = NotUploading }, Cmd.none )

        OwnershipChoose answer ->
            case model.identityFlow of
                FlowOwnership pending ->
                    case Identity.resolveOwnership answer model.me pending.draft.owner of
                        Identity.Adopt ownerId ->
                            case model.me of
                                Nothing ->
                                    -- New device claims this person: adopt the
                                    -- file's owner id + denormalized name (the
                                    -- device-link — never mints, AC1/AC6).
                                    let
                                        name =
                                            Identity.resolveNameWith "Me"
                                                (Identity.mergeDirectory pending.filePeople model.directory)
                                                ownerId

                                        me_ =
                                            { userId = ownerId, displayName = name }
                                    in
                                    completeImport pending { model | me = Just me_ }

                                Just _ ->
                                    -- I already have a *different* identity → a
                                    -- dual-id. Don't silently overwrite it; surface
                                    -- the explicit link action (Q-I1 / AC8).
                                    ( { model | identityFlow = FlowLink pending }, Cmd.none )

                        Identity.ReviewAs _ ->
                            -- Reviewer: keep the file's owner, my identity unchanged.
                            completeImport pending model

                        Identity.MintThenReview ->
                            -- Reviewer with no identity → name prompt + mint #2.
                            ( { model | identityFlow = FlowName (ThenImportReviewer pending), nameDraft = "" }
                            , Cmd.none
                            )

                _ ->
                    ( model, Cmd.none )

        OwnershipCancel ->
            ( { model | identityFlow = FlowIdle, upload = NotUploading, nameDraft = "" }, Cmd.none )

        LinkConfirm ->
            case model.identityFlow of
                FlowLink pending ->
                    case model.me of
                        Just m ->
                            let
                                newId =
                                    pending.draft.owner

                                name =
                                    Identity.resolveNameWith m.displayName
                                        (Identity.mergeDirectory pending.filePeople model.directory)
                                        newId

                                me_ =
                                    { userId = newId, displayName = name }

                                oldId =
                                    m.userId

                                -- Re-own my local races from the old id to the
                                -- linked id so they keep reading as mine — the
                                -- dual-id reconciliation (Q-I1 / AC8). Bounded:
                                -- only the races this device minted under `oldId`.
                                -- One pass builds both the new list and the saves
                                -- so the predicate can't drift between them.
                                ( reowned, migrateCmds ) =
                                    currentRaces model
                                        |> List.foldr
                                            (\r ( rs, cs ) ->
                                                if r.owner == oldId then
                                                    let
                                                        moved =
                                                            { r | owner = newId }
                                                    in
                                                    ( moved :: rs, Storage.saveRaceMeta (encodeRaceMeta moved) :: cs )

                                                else
                                                    ( r :: rs, cs )
                                            )
                                            ( [], [] )

                                ( model_, importCmd ) =
                                    completeImport pending
                                        { model | me = Just me_, races = LoadedRaces reowned }
                            in
                            ( model_, Cmd.batch (importCmd :: migrateCmds) )

                        Nothing ->
                            ( { model | identityFlow = FlowIdle }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        LinkCancel ->
            -- Back out to the ownership choice (not the whole import) so the user
            -- can pick "someone else" instead of linking.
            case model.identityFlow of
                FlowLink pending ->
                    ( { model | identityFlow = FlowOwnership pending }, Cmd.none )

                _ ->
                    ( { model | identityFlow = FlowIdle }, Cmd.none )

        RenameDraftInput s ->
            ( { model | renameDraft = s }, Cmd.none )

        RenameMeCommit ->
            case model.me of
                Just m ->
                    let
                        name =
                            String.trim model.renameDraft
                    in
                    if name == "" then
                        ( model, Cmd.none )

                    else
                        let
                            me_ =
                                { m | displayName = name }

                            -- A strictly-monotonic timestamp: `model.now` is frozen
                            -- at boot (as the changelog uses it), so a same-session
                            -- rename would reuse it and lose the downstream LWW tie
                            -- (an importer ignores an equal `nameUpdatedAt`). Force
                            -- it past the prior value so every rename propagates.
                            prevUpdated =
                                Dict.get m.userId model.directory
                                    |> Maybe.map .nameUpdatedAt
                                    |> Maybe.withDefault 0

                            stamp =
                                Basics.max model.now (prevUpdated + 1)

                            -- Self-rename is authoritative: a direct insert rather
                            -- than the LWW `learn`. One row, and every owned race
                            -- relabels through it with no per-race write (AC4).
                            dir =
                                Dict.insert m.userId
                                    { displayName = name, nameUpdatedAt = stamp }
                                    model.directory
                        in
                        ( { model | me = Just me_, directory = dir, renameDraft = "" }
                        , Storage.saveIdentity (Identity.encodeStored { me = Just me_, directory = dir })
                        )

                Nothing ->
                    ( model, Cmd.none )

        MergePickMine i ->
            ( { model | mergeReview = Maybe.map (pickChoice i ChooseMine) model.mergeReview }, Cmd.none )

        MergePickTheirs i ->
            ( { model | mergeReview = Maybe.map (pickChoice i ChooseTheirs) model.mergeReview }, Cmd.none )

        MergeEditNote i noteText ->
            ( { model | mergeReview = Maybe.map (pickChoice i (ChooseCustom noteText)) model.mergeReview }, Cmd.none )

        MergeApply ->
            case model.mergeReview of
                Just review ->
                    if Dict.size review.choices < List.length review.conflicts then
                        -- Not every card resolved (Apply is disabled in the UI too).
                        ( model, Cmd.none )

                    else
                        let
                            theirsLayer =
                                Merge.planningLayer review.incoming

                            finalLayer =
                                review.conflicts
                                    |> List.indexedMap Tuple.pair
                                    |> List.foldl
                                        (\( i, c ) acc ->
                                            case Dict.get i review.choices of
                                                Just ChooseTheirs ->
                                                    Merge.resolve c.key theirsLayer acc

                                                Just (ChooseCustom noteText) ->
                                                    Merge.setNote c.key noteText acc

                                                _ ->
                                                    -- ChooseMine (or, defensively,
                                                    -- unresolved): `merged` already
                                                    -- carries mine.
                                                    acc
                                        )
                                        review.merged
                        in
                        applyMerge review.target review.incoming review.filePeople finalLayer model

                Nothing ->
                    ( model, Cmd.none )

        MergeKeepMine ->
            -- Reject the whole import (no state change). Confirm only when the
            -- user has actually made picks (Q-U4 / ADR-0013).
            case model.mergeReview of
                Just review ->
                    if review.touched then
                        ( { model | mergeReview = Just { review | confirmingDiscard = True } }, Cmd.none )

                    else
                        ( { model | mergeReview = Nothing }, Cmd.none )

                Nothing ->
                    ( model, Cmd.none )

        MergeConfirmDiscard ->
            ( { model | mergeReview = Nothing }, Cmd.none )

        MergeCancelDiscard ->
            ( { model | mergeReview = Maybe.map (\r -> { r | confirmingDiscard = False }) model.mergeReview }, Cmd.none )

        ProfileLoaded value ->
            case D.decodeValue (D.nullable AthleteProfile.decode) value of
                Ok (Just p) ->
                    ( { model | profile = p }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        ProfilePickPreset preset ->
            ( { model | profile = AthleteProfile.presetProfile preset, profileSaved = False }
            , Cmd.none
            )

        ProfileSetVmh s ->
            let
                next =
                    case String.toFloat s of
                        Just v ->
                            { profile_ | verticalRateVmh = max 50 (min 2000 v) }

                        Nothing ->
                            profile_

                profile_ =
                    model.profile
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetPace s ->
            let
                profile_ =
                    model.profile

                next =
                    case parseMmss s of
                        Just secs ->
                            { profile_ | flatTrailPaceSecPerKm = max 120 (min 1200 secs) }

                        Nothing ->
                            profile_
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetFatigueThreshold s ->
            let
                profile_ =
                    model.profile

                next =
                    case String.toFloat s of
                        Just v ->
                            { profile_ | fatigueThresholdH = max 0 (min 24 v) }

                        Nothing ->
                            profile_
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetFatigueSlope s ->
            let
                profile_ =
                    model.profile

                next =
                    case String.toFloat s of
                        Just v ->
                            { profile_ | fatigueSlopePerH = max 0 (min 0.5 (v / 100)) }

                        Nothing ->
                            profile_
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetDescentSkill key ->
            let
                profile_ =
                    model.profile

                next =
                    case key of
                        "cautious" ->
                            { profile_ | descentSkill = DescCautious }

                        "confident" ->
                            { profile_ | descentSkill = DescConfident }

                        "expert" ->
                            { profile_ | descentSkill = DescExpert }

                        _ ->
                            { profile_ | descentSkill = DescAverage }
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetTechSkill key ->
            let
                profile_ =
                    model.profile

                next =
                    case key of
                        "novice" ->
                            { profile_ | technicalitySkill = TechNovice }

                        "experienced" ->
                            { profile_ | technicalitySkill = TechExperienced }

                        "expert" ->
                            { profile_ | technicalitySkill = TechExpert }

                        _ ->
                            { profile_ | technicalitySkill = TechAverage }
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetAidStyle key ->
            let
                profile_ =
                    model.profile

                next =
                    case key of
                        "elite" ->
                            { profile_ | aidStyle = AidElite }

                        "standard" ->
                            { profile_ | aidStyle = AidStandard }

                        "relaxed" ->
                            { profile_ | aidStyle = AidRelaxed }

                        _ ->
                            { profile_ | aidStyle = AidLean }
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetLthr s ->
            let
                profile_ =
                    model.profile

                next =
                    if String.isEmpty (String.trim s) then
                        { profile_ | lthrBpm = Nothing }

                    else
                        case String.toInt s of
                            Just v ->
                                { profile_ | lthrBpm = Just (max 80 (min 220 v)) }

                            Nothing ->
                                profile_
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSetMaxHr s ->
            let
                profile_ =
                    model.profile

                next =
                    if String.isEmpty (String.trim s) then
                        { profile_ | maxHrBpm = Nothing }

                    else
                        case String.toInt s of
                            Just v ->
                                { profile_ | maxHrBpm = Just (max 80 (min 240 v)) }

                            Nothing ->
                                profile_
            in
            ( { model | profile = next, profileSaved = False }, Cmd.none )

        ProfileSave ->
            ( { model | profileSaved = True }
            , Storage.saveProfile (AthleteProfile.encode model.profile)
            )

        CalibrateVmh ->
            case Calibration.fitVmh (linkedRuns model) of
                Just fit ->
                    let
                        prof =
                            model.profile

                        next =
                            { prof | verticalRateVmh = toFloat (round fit.vmh) }
                    in
                    ( { model | profile = next, profileSaved = True }
                    , Storage.saveProfile (AthleteProfile.encode next)
                    )

                Nothing ->
                    ( model, Cmd.none )

        CalibrateFlatPace ->
            case Calibration.fitFlatPace (linkedRuns model) of
                Just fit ->
                    let
                        prof =
                            model.profile

                        next =
                            { prof | flatTrailPaceSecPerKm = fit.paceSecPerKm }
                    in
                    ( { model | profile = next, profileSaved = True }
                    , Storage.saveProfile (AthleteProfile.encode next)
                    )

                Nothing ->
                    ( model, Cmd.none )

        StravaTokenLoaded value ->
            case D.decodeValue (D.nullable D.string) value of
                Ok (Just t) ->
                    ( { model | stravaToken = Just t }, Cmd.none )

                _ ->
                    ( { model | stravaToken = Nothing }, Cmd.none )

        StravaDisconnect ->
            ( { model | stravaToken = Nothing, stravaPicker = PickerClosed }
            , Storage.saveStravaToken Encode.null
            )

        OpenStravaPicker rid ->
            case model.stravaToken of
                Just token ->
                    ( { model
                        | stravaPicker = PickerLoadingActivities rid
                        , stravaPickerSearch = ""
                      }
                    , StravaApi.fetchActivities model.backendUrl token 60 (StravaActivitiesLoaded rid)
                    )

                Nothing ->
                    ( model, Cmd.none )

        StravaActivitiesLoaded rid result ->
            case result of
                Ok acts ->
                    ( { model | stravaPicker = PickerShowing rid acts }, Cmd.none )

                Err err ->
                    ( { model | stravaPicker = PickerError rid (httpErrorString err) }, Cmd.none )

        StravaPickerSelect rid actId ->
            case model.stravaToken of
                Just token ->
                    ( { model | stravaPicker = PickerLoadingStreams rid actId }
                    , Task.perform identity
                        (Time.now
                            |> Task.map Time.posixToMillis
                            |> Task.map
                                (\ms ->
                                    -- We need to pass the timestamp to StravaStreamsLoaded but Http
                                    -- doesn't compose with Task in the same chain. Trigger the fetch
                                    -- separately by emitting a Msg that does the fetch.
                                    InternalStartStreamFetch rid actId ms token
                                )
                        )
                    )

                Nothing ->
                    ( model, Cmd.none )

        InternalStartStreamFetch rid actId ms token ->
            ( model
            , StravaApi.fetchStreams model.backendUrl token actId (StravaStreamsLoaded rid actId ms)
            )

        StravaStreamsLoaded rid actId uploadedAtMs result ->
            case result of
                Err err ->
                    ( { model | stravaPicker = PickerError rid (httpErrorString err) }, Cmd.none )

                Ok value ->
                    case StravaStreams.parse value of
                        Err parseErr ->
                            ( { model | stravaPicker = PickerError rid parseErr }, Cmd.none )

                        Ok track ->
                            case findRace rid (currentRaces model) of
                                Nothing ->
                                    ( { model | stravaPicker = PickerClosed }, Cmd.none )

                                Just race ->
                                    let
                                        splits =
                                            ActualGpx.computeSplits track |> Dict.fromList

                                        actual =
                                            { splits = splits
                                            , totalSeconds = track.totalElapsedS
                                            , totalDistance = track.totalDist
                                            , uploadedAt = uploadedAtMs
                                            , hrPerKm = ActualGpx.computeHrPerKm track
                                            }

                                        updatedRace =
                                            { race | actualSplits = Just actual }
                                    in
                                    ( { model | stravaPicker = PickerClosed, actualRunError = Nothing }
                                    , commitRaceEdit race updatedRace model
                                    )

        StravaPickerSetSearch rid query ->
            let
                trimmed =
                    String.trim query
            in
            case model.stravaToken of
                Just token ->
                    let
                        nextCmd =
                            if String.isEmpty trimmed then
                                StravaApi.fetchActivities model.backendUrl token 60 (StravaActivitiesLoaded rid)

                            else
                                StravaApi.searchActivities model.backendUrl token trimmed (StravaActivitiesLoaded rid)
                    in
                    ( { model
                        | stravaPicker = PickerLoadingActivities rid
                        , stravaPickerSearch = query
                      }
                    , nextCmd
                    )

                Nothing ->
                    ( model, Cmd.none )

        StravaPickerClose ->
            ( { model | stravaPicker = PickerClosed, stravaPickerSearch = "" }, Cmd.none )

        ModalNoOp ->
            ( model, Cmd.none )

        SliderInput str ->
            -- Live update only — no IDB write. UTMB-sized races
            -- carry a ~3 MB gpxText field; serialising it on every
            -- input event makes the drag laggy. The actual save
            -- happens on SliderCommit (the 'change' event).
            --
            -- We also update targetTimeText so the Target Time input
            -- visibly tracks the drag — otherwise that input keeps
            -- the old persisted value and a focus/blur on it would
            -- re-commit the stale number.
            case ( String.toFloat str, currentRace model ) of
                ( Just i, Just race ) ->
                    let
                        kms =
                            Dict.get (raceIdToString race.id) model.kmsCache
                                |> Maybe.withDefault []
                    in
                    if List.isEmpty kms then
                        ( { model | sliderDraft = Just i }, Cmd.none )

                    else
                        let
                            prediction =
                                Predictor.predict model.profile race kms i
                        in
                        ( { model
                            | sliderDraft = Just i
                            , targetTimeText = formatHhmm prediction.totalS
                          }
                        , Cmd.none
                        )

                ( Just i, Nothing ) ->
                    ( { model | sliderDraft = Just i }, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        SliderCommit str ->
            case ( String.toFloat str, currentRace model ) of
                ( Just i, Just race ) ->
                    let
                        kms =
                            Dict.get (raceIdToString race.id) model.kmsCache
                                |> Maybe.withDefault []
                    in
                    if List.isEmpty kms then
                        ( { model | sliderDraft = Nothing }, Cmd.none )

                    else
                        let
                            prediction =
                                Predictor.predict model.profile race kms i

                            newPlan =
                                Types.withTargetSeconds (Just prediction.totalS) race.plan

                            newRace =
                                { race | plan = newPlan }
                        in
                        ( { model
                            | sliderDraft = Nothing
                            , targetTimeText = formatHhmm prediction.totalS
                          }
                        , Storage.saveRaceMeta (encodeRaceMeta newRace)
                        )

                _ ->
                    ( { model | sliderDraft = Nothing }, Cmd.none )


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

                                kmRest =
                                    aidRestInKm race.aidStations idx
                            in
                            ( case kp.time of
                                Manual s ->
                                    formatMmss (s + kmRest)

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


buildSparklineCache : Dict String Track -> Dict String (List ( Float, Float )) -> Dict String (List ( Float, Float ))
buildSparklineCache tracks existing =
    Dict.foldl
        (\key track acc ->
            if Dict.member key acc then
                acc

            else
                Dict.insert key (sparklineCoordsForTrack track) acc
        )
        existing
        tracks


cacheSparkline : String -> Dict String Track -> Dict String (List ( Float, Float )) -> Dict String (List ( Float, Float ))
cacheSparkline key tracks cache =
    case Dict.get key tracks of
        Just track ->
            Dict.insert key (sparklineCoordsForTrack track) cache

        Nothing ->
            cache


{-| Downsample a track to ~240 (x, y) coordinates sized for the
race-card cover sparkline (320 × 112 px). Computed once when the
track is parsed; the result is referentially cached so every
index render is a constant-time Dict lookup.

Without this, every navigation to the index walked the full
~26 k UTMB points through four list passes — ~100 ms per render
on slow machines.

-}
sparklineCoordsForTrack : Track -> List ( Float, Float )
sparklineCoordsForTrack track =
    let
        width =
            320.0

        height =
            112.0

        pad =
            8.0

        chartH =
            height - pad * 2

        n =
            List.length track.points

        stride =
            max 1 (n // 240)

        eleRange =
            max 1 (track.maxEle - track.minEle)

        mPerPxX =
            max 0.01 (track.totalDist / width)

        yScale =
            chartH / eleRange

        maxEle =
            track.maxEle

        zipped =
            List.map2 Tuple.pair track.cumDist track.points

        go ( d, p ) ( acc, idx ) =
            let
                kept =
                    if modBy stride idx == 0 then
                        ( d / mPerPxX, pad + (maxEle - p.ele) * yScale ) :: acc

                    else
                        acc
            in
            ( kept, idx + 1 )

        ( revCoords, _ ) =
            List.foldl go ( [], 0 ) zipped
    in
    List.reverse revCoords


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


buildDraftRace : String -> String -> Int -> Track -> String -> Race
buildDraftRace deviceId authorId now track gpxText =
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

    -- shareId left blank → JS mints it on save (like `id`). courseHash is the
    -- fingerprint of this course, set once here from the parsed track.
    , shareId = ""
    , courseHash = TrailSync.courseHash track

    -- owner left blank → stamped once a device identity exists (WI-5 flows,
    -- TASK-054 / ADR-0012); a userId, never the deviceId.
    , owner = ""

    -- Seed the change history with the course-upload event (TASK-051).
    -- authorId is the person (`me.userId`), "" before a first share — the feed
    -- then labels via the deviceId fallback (WI-5 / TASK-054).
    , history = [ Changelog.courseUploaded deviceId authorId now 0 ]

    -- No merge ancestor / version yet — set at the first share, bumped on edits
    -- (TASK-056 / ADR-0013). Inert until the merge entry point lands (slice 2).
    , mergeBase = Nothing
    , version = Dict.empty
    }


{-| Persist a plan/aid/metadata edit, logging a change-history entry (TASK-051).
Diffs the mergeable planning layer before→after via `Changelog.diff`; a
non-planning change (target time, the slider, linking actual splits, …) yields
an empty diff and so appends no entry — the save still happens. Used in place of
a bare `Storage.saveRaceMeta` at the edit sites; `before` is the race as it was,
`after` the edited race.

Also backfills `owner` on first touch: an unowned race adopts my `userId` once an
identity exists (WI-5 / TASK-054, AC3). No-op when already owned or no identity
yet (the deferred-mint case — owner is then stamped at the first export instead).
`owner` isn't part of the planning layer, so this never affects the diff.
-}
commitRaceEdit : Race -> Race -> Model -> Cmd Msg
commitRaceEdit before after0 model =
    let
        authorId =
            myUserId model

        afterOwned =
            case model.me of
                Just m ->
                    if after0.owner == "" then
                        { after0 | owner = m.userId }

                    else
                        after0

                Nothing ->
                    after0

        -- Bump my version counter when the mergeable layer actually changed (a
        -- plan/aid/metadata edit) — not on actual-run links or other no-op saves
        -- (owner backfill isn't in the layer, so it doesn't count). This is what
        -- lets a returned `.trail` classify as fast-forward vs divergent
        -- (TASK-056 / ADR-0013). Inert until the merge entry point lands.
        after =
            if Merge.planningLayer before /= Merge.planningLayer afterOwned then
                { afterOwned | version = Merge.bumpVersion model.deviceId afterOwned.version }

            else
                afterOwned

        changes =
            Changelog.diff (Merge.planningLayer before) (Merge.planningLayer after)

        withHistory =
            case Changelog.entryFromChanges model.deviceId authorId model.now (List.length after.history) "local" changes of
                Just entry ->
                    { after | history = after.history ++ [ entry ] }

                Nothing ->
                    after
    in
    Storage.saveRaceMeta (encodeRaceMeta withHistory)


{-| My person-level `userId`, or `""` if no identity has been minted yet. Used
to attribute changelog entries and to stamp `owner` (WI-5 / TASK-054).
-}
myUserId : Model -> String
myUserId model =
    model.me |> Maybe.map .userId |> Maybe.withDefault ""


{-| Finish importing a paused `.trail` (WI-5 / TASK-054): LWW-merge the file's
denormalized names into the local directory, persist the identity bundle, and
full-save the draft as a new race. The draft's `owner` is already set by the
calling branch (kept as the file owner for a reviewer, or my id when claimed).
The directory is touched **only here**, so cancelling a prompt leaves no trace.
-}
completeImport : PendingImport -> Model -> ( Model, Cmd Msg )
completeImport pending model =
    let
        merged =
            Identity.mergeDirectory pending.filePeople model.directory

        -- Guarantee my own identity has a directory row, so owner display / feed
        -- labels never fall back to "Someone" for me. Normally the merge above
        -- already carries it (an export denormalizes the owner), but a file that
        -- under-denormalizes — or a claimed/adopted id the file didn't name —
        -- would otherwise leave it absent. The mint and rename paths insert
        -- authoritatively; this is the import-side equivalent (WI-5 / TASK-054).
        dir =
            case model.me of
                Just m ->
                    if Dict.member m.userId merged then
                        merged

                    else
                        Dict.insert m.userId
                            { displayName = m.displayName, nameUpdatedAt = model.now }
                            merged

                Nothing ->
                    merged

        -- Persist identity when there's something to keep: a learned name, or an
        -- existing/just-set identity. Avoids writing an empty {me:null} row on a
        -- plain v1 import with no identity yet.
        saveIdCmd =
            if dir /= model.directory || model.me /= Nothing then
                Storage.saveIdentity (Identity.encodeStored { me = model.me, directory = dir })

            else
                Cmd.none
    in
    ( { model
        | directory = dir
        , identityFlow = FlowIdle
        , upload = Persisting pending.fileName
        , nameDraft = ""
      }
    , Cmd.batch [ saveIdCmd, Storage.saveRace (encodeRace pending.draft) ]
    )


{-| The `.trail` download command, denormalizing names from `directory` into the
file's `people` (WI-5 / TASK-054).
-}
exportDownload : Identity.Directory -> Race -> Cmd Msg
exportDownload directory race =
    Download.file
        { filename = ProjectFile.filenameFor race
        , content = ProjectFile.encode directory race
        , mime = "application/json"
        }



-- MERGE (WI-3 part 2 / TASK-056) — route a returned .trail into the engine


{-| A local race this incoming `.trail` is a returned copy of — matched by the
stable `shareId` (TASK-047). Empty shareId (v1 / unstamped) never matches, so
those still import as new.
-}
findShareMatch : Race -> Model -> Maybe Race
findShareMatch incoming model =
    if incoming.shareId == "" then
        Nothing

    else
        currentRaces model
            |> List.filter (\r -> r.shareId == incoming.shareId)
            |> List.head


{-| Route a returned `.trail` against the local race it belongs to: classify the
version vectors (Q4), then fast-forward / auto-merge / open the review modal /
no-op accordingly (TASK-056 / ADR-0013).
-}
routeMerge : Race -> Race -> Identity.Directory -> Model -> ( Model, Cmd Msg )
routeMerge local incoming filePeople model =
    case Merge.classifyVersions local.version incoming.version of
        Merge.Same ->
            landOnRace local model

        Merge.Behind ->
            landOnRace local model

        Merge.FastForward ->
            -- Theirs strictly dominates → adopt their plan directly, no UI.
            applyMerge local incoming filePeople (Merge.planningLayer incoming) model

        Merge.Diverged ->
            let
                -- The common ancestor is what we last shared (`local.mergeBase`).
                -- If it's missing (a race shared on a pre-merge-state build, then
                -- re-imported), fall back to a *neutral empty* layer — NOT the
                -- local layer: base == mine would make `field3` resolve every
                -- field to theirs with zero conflicts, silently discarding my
                -- edits. An empty base instead surfaces every genuine difference
                -- as a conflict to review (a field I left at default + they
                -- changed → theirs disjointly; both changed from default →
                -- conflict). Safe over silent.
                base =
                    local.mergeBase |> Maybe.withDefault emptyPlanningLayer

                result =
                    Merge.mergePlanningLayer base (Merge.planningLayer local) (Merge.planningLayer incoming)
            in
            if List.isEmpty result.conflicts then
                -- Both edited, but disjoint → auto-merge, no UI.
                applyMerge local incoming filePeople result.merged model

            else
                ( { model | mergeReview = Just (openReview local incoming filePeople result), upload = NotUploading }
                , Cmd.none
                )


landOnRace : Race -> Model -> ( Model, Cmd Msg )
landOnRace race model =
    ( { model | upload = NotUploading }
    , Nav.pushUrl model.key (Route.toString (Route.RaceDetail race.id))
    )


{-| A neutral, all-default planning layer — the safe ancestor when none was
recorded (see `routeMerge`). -}
emptyPlanningLayer : PlanningLayer
emptyPlanningLayer =
    { name = ""
    , date = Nothing
    , location = ""
    , url = ""
    , notes = ""
    , aidStations = []
    , aidStationSeq = 0
    , plan = defaultPlan
    }


{-| Build the review state for a divergence with true conflicts: pre-fill each
same-km-note conflict's textarea with both versions combined (Q-U3); binary
conflicts start unresolved. `autoMergedCount` = the disjoint changes the engine
already folded into `merged` (the reassurance line).
-}
openReview : Race -> Race -> Identity.Directory -> Merge.MergeResult -> MergeReview
openReview local incoming filePeople result =
    let
        noteChoices =
            result.conflicts
                |> List.indexedMap
                    (\i c ->
                        if isProseConflict c.key then
                            Just ( i, ChooseCustom (combineNotes c.mine c.theirs) )

                        else
                            Nothing
                    )
                |> List.filterMap identity
                |> Dict.fromList
    in
    { target = local
    , incoming = incoming
    , filePeople = filePeople
    , merged = result.merged
    , conflicts = result.conflicts
    , choices = noteChoices
    , autoMergedCount = List.length (Changelog.diff (Merge.planningLayer local) result.merged)

    -- Pre-filled note resolutions count as "something to lose", so dismissing
    -- confirms even before the user touches a binary card (Q-U4). A
    -- binary-only review starts untouched → closing it discards silently.
    , touched = not (Dict.isEmpty noteChoices)
    , confirmingDiscard = False
    }


{-| The person whose changes are being merged in — the most recent author in the
incoming history who isn't me (e.g. the coach who reviewed *my* race, so the
file's `owner` is still me, not them). Person-named via the directory (WI-5);
falls back to the file owner, then a neutral label.
-}
suggesterName : Maybe Identity.Me -> Identity.Directory -> Race -> String
suggesterName me dir incoming =
    let
        myId =
            me |> Maybe.map .userId |> Maybe.withDefault ""

        lastOtherAuthor =
            incoming.history
                |> List.filter (\e -> e.authorId /= "" && e.authorId /= myId)
                |> List.reverse
                |> List.head
                |> Maybe.map .authorId
    in
    case lastOtherAuthor of
        Just uid ->
            Identity.resolveName dir uid

        Nothing ->
            -- No distinct author in the history (e.g. they edited without an
            -- identity). The file owner is usually *me* (they reviewed my race),
            -- so don't label theirs with my own name — stay neutral.
            if incoming.owner == "" || incoming.owner == myId then
                "the other person"

            else
                Identity.resolveName dir incoming.owner


combineNotes : String -> String -> String
combineNotes mine theirs =
    if mine == "" then
        theirs

    else if theirs == "" then
        mine

    else
        mine ++ "\n" ++ theirs


{-| Apply a merged planning layer onto the local race: rebuild from the layer
(course frozen, WI-2), advance the version vector (seen both sides) + the merge
ancestor, **union the incoming change history** (so the other person's granular
edits join the feed — WI-4), and — when the plan actually changed — log a
person-named `Merged` marker entry. Always persists + lands on the race; even a
content-identical fast-forward advances the version so it isn't re-offered.
-}
applyMerge : Race -> Race -> Identity.Directory -> PlanningLayer -> Model -> ( Model, Cmd Msg )
applyMerge local incoming filePeople finalLayer model =
    let
        dir =
            Identity.mergeDirectory filePeople model.directory

        planChanged =
            finalLayer /= Merge.planningLayer local

        -- The taxonomy diff under-counts non-taxonomy fields (target/location/
        -- url/notes), so floor at 1 when the plan changed — never "Merged 0".
        count =
            Basics.max
                (List.length (Changelog.diff (Merge.planningLayer local) finalLayer))
                (if planChanged then
                    1

                 else
                    0
                )

        -- Union the other side's history first (conflict-free by entryId, WI-4),
        -- then append the merge marker when there was a real change.
        unioned =
            Changelog.union local.history incoming.history

        history =
            if planChanged then
                case Changelog.entryFromChanges model.deviceId (myUserId model) model.now (List.length local.history) "merge" [ Merged { fromAuthor = suggesterName model.me dir incoming, count = count } ] of
                    Just e ->
                        unioned ++ [ e ]

                    Nothing ->
                        unioned

            else
                unioned

        applied =
            -- withPlanningLayer keeps the frozen course + identity verbatim (WI-2).
            let
                rebuilt =
                    Merge.withPlanningLayer finalLayer local
            in
            { rebuilt
                | version = Merge.mergeVersions local.version incoming.version
                , mergeBase = Just finalLayer
                , history = history
            }

        nextRaces =
            applied :: List.filter (\r -> r.id /= local.id) (currentRaces model)
    in
    ( { model
        | races = LoadedRaces (sortRaces nextRaces)
        , directory = dir
        , mergeReview = Nothing
        , upload = NotUploading
      }
    , Cmd.batch
        [ Storage.saveIdentity (Identity.encodeStored { me = model.me, directory = dir })
        , Storage.saveRaceMeta (encodeRaceMeta applied)

        -- Defer the navigation a tick. Applying a merge tears down the
        -- full-screen review modal AND reorders the race list in the same
        -- update; navigating synchronously on top of that races the virtual-DOM
        -- patch ahead of the teardown and corrupts it (a `childNodes of
        -- undefined` crash that survives until reload). Letting the teardown
        -- render commit first makes the nav a clean Index→detail transition.
        -- Mirrors the `GotContent` → `StartParse` sleep.
        , Task.perform (\_ -> NavigateTo (Route.RaceDetail local.id)) (Process.sleep 50)
        ]
    )


{-| Record a per-card resolution in the review state (and mark it touched, so
dismiss confirms — Q-U4). -}
pickChoice : Int -> MergeChoice -> MergeReview -> MergeReview
pickChoice i choice review =
    { review | choices = Dict.insert i choice review.choices, touched = True }


{-| Import a `.trail` as a *new* race — no local race shares its `shareId`. The
WI-5 identity branching (TASK-054): silent for a file I own, prompt
yourself/someone-else otherwise, claim-on-touch for an owner-less file. (The
merge path — a returned file for a race I already have — is handled before this,
in `StartParse` via `findShareMatch`/`routeMerge`.)
-}
importAsNew : Race -> Identity.Directory -> String -> Model -> ( Model, Cmd Msg )
importAsNew importedRace filePeople fileName model =
    let
        -- Drop the imported id so JS assigns a fresh one (lets users import the
        -- same .trail twice safely) and stamp a new createdAt so it sorts to the
        -- top. shareId is *kept* (the round-trip identity); only the local IDB key
        -- is regenerated. A v1 file has no courseHash — compute it from the
        -- embedded GPX so the race is fully stamped (TASK-047).
        draft =
            { importedRace
                | id = raceIdFromString ""
                , createdAt = model.now
                , courseHash =
                    if importedRace.courseHash == "" then
                        TrailSync.courseHashFromGpxText importedRace.gpxText

                    else
                        importedRace.courseHash
            }

        -- Owner display name for the prompt copy: the file's denormalized names
        -- over what we already know. The model directory is touched only on
        -- completion.
        ownerName =
            Identity.resolveNameWith "this athlete"
                (Identity.mergeDirectory filePeople model.directory)
                draft.owner

        pending =
            { draft = draft
            , fileName = fileName
            , filePeople = filePeople
            , ownerName = ownerName
            }
    in
    if draft.owner == "" then
        -- Pre-identity / v1 file: no owner to attribute. It becomes mine on touch
        -- if I have an identity (AC3), else stays unowned until a first export
        -- stamps it. No prompt (there's no person to disambiguate).
        let
            claimed =
                case model.me of
                    Just m ->
                        { pending | draft = { draft | owner = m.userId } }

                    Nothing ->
                        pending
        in
        completeImport claimed model

    else
        case Identity.decideImport model.me draft.owner of
            Identity.ImportAsOwner ->
                -- A file I already own → import silently (AC6).
                completeImport pending model

            Identity.AskOwnership ->
                -- Owner ≠ me (or I have no identity) → ask.
                ( { model | identityFlow = FlowOwnership pending, upload = NotUploading }
                , Cmd.none
                )


readFile : File -> Cmd Msg
readFile file =
    Task.perform (GotContent (File.name file)) (File.toString file)



-- AID FORM HELPERS


aidFormDomId : String
aidFormDomId =
    "aid-station-form"


emptyAidForm : Maybe String -> AidForm
emptyAidForm editingId =
    { editing = editingId
    , name = ""
    , mode = FromPrevious
    , distanceKm = ""
    , restMinutes = "2"
    , cutoffText = ""
    , services = [ Types.Water ]
    , notesText = ""
    , error = Nothing
    }


aidFormFromExisting : AidStation -> AidForm
aidFormFromExisting aid =
    { editing = Just aid.id
    , name = aid.name
    , mode = FromStart
    , distanceKm = formatFloat 2 (aid.distance / 1000)
    , restMinutes = String.fromInt (aid.restSeconds // 60)
    , cutoffText = aid.cutoff |> Maybe.map AidCsv.formatClock |> Maybe.withDefault ""
    , services = aid.services
    , notesText = aid.notes
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


validateAidForm : String -> AidForm -> Race -> Result String AidStation
validateAidForm deviceId form race =
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
                                    case parseCutoffInput form.cutoffText of
                                        Err cutoffErr ->
                                            Err cutoffErr

                                        Ok cutoff ->
                                            let
                                                id =
                                                    Maybe.withDefault
                                                        (Merge.mintAidId deviceId race.aidStationSeq)
                                                        form.editing
                                            in
                                            Ok
                                                { id = id
                                                , name = trimmedName
                                                , distance = absolute
                                                , restSeconds = restMin * 60
                                                , services = form.services
                                                , notes = String.trim form.notesText
                                                , cutoff = cutoff
                                                }


parseCutoffInput : String -> Result String (Maybe Int)
parseCutoffInput raw =
    let
        trimmed =
            String.trim raw
    in
    if String.isEmpty trimmed then
        Ok Nothing

    else
        case AidCsv.parseClock trimmed of
            Just secs ->
                Ok (Just secs)

            Nothing ->
                Err "Cutoff must be a time like 6:30 or 6:30:00 (elapsed from start)."


previousAidDistance : Maybe String -> Race -> Float
previousAidDistance editing race =
    race.aidStations
        |> List.filter (\a -> Just a.id /= editing)
        |> List.sortBy .distance
        |> List.reverse
        |> List.head
        |> Maybe.map .distance
        |> Maybe.withDefault 0


{-| Issue stable ids to imported stations, continuing the race's existing
sequence so a later manual add can't collide. Returns the stations with
ids plus the next free sequence number.
-}
assignAidIds : String -> Int -> List AidStation -> ( List AidStation, Int )
assignAidIds deviceId startSeq stations =
    let
        ( reversed, nextSeq ) =
            List.foldl
                (\station ( acc, seq ) ->
                    ( { station | id = Merge.mintAidId deviceId seq } :: acc, seq + 1 )
                )
                ( [], startSeq )
                stations
    in
    ( List.reverse reversed, nextSeq )



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
        , Storage.gotProfile ProfileLoaded
        , Storage.gotIdentity IdentityLoaded
        , Storage.gotStravaToken StravaTokenLoaded
        , Download.imagePicked MetaCoverPicked
        , Browser.Events.onResize WindowResized
        ]



-- ============================================================
-- VIEW
-- ============================================================


view : Model -> Browser.Document Msg
view model =
    { title = Translations.documentTitle model.settings.language model.route
    , body =
        [ div [ class "min-h-screen flex flex-col" ]
            [ viewHeader model.settings.language model.route
            , div [ class "flex-1 pb-10" ] [ viewContent model ]
            , viewFooter model.settings.language
            , viewDeleteModal model
            , viewHistoryDrawer model
            , viewIdentityModals model
            , viewMergeReview model
            , viewErrorToast model
            ]
        ]
    }


viewHeader : Language -> Route -> Html Msg
viewHeader language route =
    div [ class "px-6 py-4 border-b border-slate-800/60 bg-slate-950/95 backdrop-blur sticky top-0 z-30 print:hidden" ]
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
                [ text (Translations.headerSubtitle language route) ]
            , div [ class "flex-1" ] []
            , a
                [ Route.href Route.ProfileSettings
                , classList
                    [ ( "text-sm text-slate-400 hover:text-slate-100", True )
                    , ( "text-slate-100", route == Route.ProfileSettings )
                    ]
                ]
                [ text (Translations.profileNav language) ]
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
                [ Svg.stop [ SA.offset "0%", SA.stopColor "#ff5f6a", SA.stopOpacity "0.55" ] []
                , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A", SA.stopOpacity "0.05" ] []
                ]
            ]
        , Svg.path
            [ SA.d "M6 50 L22 28 L30 38 L42 18 L58 50 Z"
            , SA.fill "url(#logo-peak)"
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
            [ SA.cx "15"
            , SA.cy "37.6"
            , SA.r "2.5"
            , SA.fill "#fbbf24"
            ]
            []
        , Svg.circle
            [ SA.cx "42"
            , SA.cy "18"
            , SA.r "2.5"
            , SA.fill "#fbbf24"
            ]
            []
        , Svg.circle
            [ SA.cx "56.8"
            , SA.cy "48.8"
            , SA.r "2.5"
            , SA.fill "#10b981"
            ]
            []
        ]


viewFooter : Language -> Html Msg
viewFooter language =
    div [ class "px-6 py-4 text-xs text-slate-500 border-t border-slate-800/60 bg-slate-950 print:hidden" ]
        [ div [ class "max-w-screen-2xl mx-auto flex flex-wrap items-center justify-between gap-3" ]
            -- The toggle labels are endonyms (English / Español), so they read the
            -- same in either language and need no translation.
            [ span [] [ text (Translations.footerPrivacy language) ]
            , viewLanguageToggle language
            ]
        ]


viewLanguageToggle : Language -> Html Msg
viewLanguageToggle current =
    let
        option lang lbl =
            let
                active =
                    lang == current
            in
            button
                [ class "px-1.5 py-0.5 rounded transition-colors"
                , classList
                    [ ( "text-emerald-400 font-semibold", active )
                    , ( "text-slate-400 hover:text-slate-200", not active )
                    ]
                , onClick (ChangeLanguage lang)
                , A.attribute "aria-pressed"
                    (if active then
                        "true"

                     else
                        "false"
                    )
                ]
                [ text lbl ]
    in
    div
        [ class "flex items-center gap-1"
        , A.attribute "role" "group"
        , A.attribute "aria-label" "Language / Idioma"
        ]
        [ option English "English"
        , span [ class "text-slate-700", A.attribute "aria-hidden" "true" ] [ text "/" ]
        , option Spanish "Español"
        ]


viewContent : Model -> Html Msg
viewContent model =
    case ( model.route, model.races ) of
        ( Route.ProfileSettings, _ ) ->
            viewProfileSettings model

        ( _, LoadingRaces ) ->
            viewLoading model.settings.language

        ( Route.Index, LoadedRaces races ) ->
            div [ class "px-6" ] [ viewIndex model races ]

        ( Route.RaceDetail rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewRaceDetail model race

                Nothing ->
                    viewRaceNotFound model.settings.language

        ( Route.RaceMap rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewRaceMap model race

                Nothing ->
                    viewRaceNotFound model.settings.language

        ( Route.PlanTable rid, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewPlanTable model race

                Nothing ->
                    viewRaceNotFound model.settings.language

        ( Route.PlanKm rid kmIndex, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewPlanKm model race kmIndex

                Nothing ->
                    viewRaceNotFound model.settings.language

        ( Route.PlanSection rid secIndex, LoadedRaces races ) ->
            case findRace rid races of
                Just race ->
                    viewPlanSection model race secIndex

                Nothing ->
                    viewRaceNotFound model.settings.language

        ( Route.NotFound, LoadedRaces _ ) ->
            viewNotFound model.settings.language


findRace : RaceId -> List Race -> Maybe Race
findRace rid =
    List.filter (\r -> raceIdToString r.id == raceIdToString rid) >> List.head


viewLoading : Language -> Html msg
viewLoading language =
    div [ class "max-w-screen-md mx-auto mt-20 text-center text-slate-500" ]
        [ text (Translations.loadingRaces language) ]


viewNotFound : Language -> Html msg
viewNotFound language =
    div [ class "max-w-screen-md mx-auto mt-20 text-center space-y-4 px-6" ]
        [ p [ class "text-rose-400 text-lg" ] [ text (Translations.notFoundTitle language) ]
        , a [ Route.href Route.Index, class "inline-block px-4 py-2 border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200" ]
            [ text (Translations.backToRacesPlain language) ]
        ]


viewRaceNotFound : Language -> Html msg
viewRaceNotFound language =
    div [ class "max-w-screen-md mx-auto mt-20 text-center space-y-4 px-6" ]
        [ p [ class "text-rose-400 text-lg" ] [ text (Translations.raceNotFoundMsg language) ]
        , a [ Route.href Route.Index, class "inline-block px-4 py-2 border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200" ]
            [ text (Translations.backToRacesPlain language) ]
        ]



-- ============================================================
-- PROFILE SETTINGS
-- ============================================================


{-| The races with a linked actual run, paired with the per-km course windows
(from the cache) + actual per-km times — the input to `Calibration.fitVmh`.
-}
linkedRunsWithRace : Model -> List ( Race, Calibration.Run )
linkedRunsWithRace model =
    currentRaces model
        |> List.filterMap
            (\race ->
                case race.actualSplits of
                    Just actual ->
                        Just
                            ( race
                            , { kms =
                                    Dict.get (raceIdToString race.id) model.kmsCache
                                        |> Maybe.withDefault []
                              , splits = actual.splits
                              }
                            )

                    Nothing ->
                        Nothing
            )


linkedRuns : Model -> List Calibration.Run
linkedRuns model =
    List.map Tuple.second (linkedRunsWithRace model)


{-| Names of the linked runs that feed either calibration fit — a single-run
fit is `Just` iff that run has qualifying terrain. Shown for transparency.
-}
calibrationContributors : Model -> List String
calibrationContributors model =
    linkedRunsWithRace model
        |> List.filterMap
            (\( race, runData ) ->
                if Calibration.fitVmh [ runData ] /= Nothing || Calibration.fitFlatPace [ runData ] /= Nothing then
                    Just race.name

                else
                    Nothing
            )


{-| One fit's row: a description (built by the caller) and an Apply button. -}
calibRow : Language -> List (Html Msg) -> Msg -> Html Msg
calibRow language descr applyMsg =
    div [ class "flex items-start justify-between gap-3" ]
        [ p [ class "text-sm text-slate-400" ] descr
        , button
            [ onClick applyMsg
            , class "shrink-0 px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
            ]
            [ text (Translations.apply language) ]
        ]


viewCalibrationPanel : Model -> Html Msg
viewCalibrationPanel model =
    let
        language =
            model.settings.language

        runs =
            linkedRuns model

        vmhRow =
            case Calibration.fitVmh runs of
                Just fit ->
                    [ calibRow language
                        [ text (Translations.calibClimbRate language)
                        , span [ class "text-slate-100 font-semibold tabular-nums" ]
                            [ text (formatInt fit.vmh ++ " m/h") ]
                        , text
                            (Translations.calibClimbFrom language fit.climbKmCount
                                ++ formatInt model.profile.verticalRateVmh
                                ++ " m/h"
                            )
                        ]
                        CalibrateVmh
                    ]

                Nothing ->
                    []

        flatRow =
            case Calibration.fitFlatPace runs of
                Just fit ->
                    [ calibRow language
                        [ text (Translations.calibFlatPace language)
                        , span [ class "text-slate-100 font-semibold tabular-nums" ]
                            [ text (formatMmss fit.paceSecPerKm ++ " /km") ]
                        , text
                            (Translations.calibFlatFrom language fit.runnableKmCount
                                ++ formatMmss model.profile.flatTrailPaceSecPerKm
                                ++ " /km"
                            )
                        ]
                        CalibrateFlatPace
                    ]

                Nothing ->
                    []

        rows =
            vmhRow ++ flatRow

        contributorsLine =
            case calibrationContributors model of
                [] ->
                    []

                names ->
                    [ p [ class "text-xs text-slate-500" ]
                        [ text (Translations.calibContributors language ++ String.join ", " names) ]
                    ]
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
        (p [ class "text-sm font-medium text-slate-100" ] [ text (Translations.calibrateTitle language) ]
            :: (if List.isEmpty rows then
                    [ p [ class "text-sm text-slate-500" ]
                        [ text (Translations.calibrateEmpty language) ]
                    ]

                else
                    rows ++ contributorsLine
               )
        )


viewProfileSettings : Model -> Html Msg
viewProfileSettings model =
    let
        language =
            model.settings.language

        prof =
            model.profile

        -- Input `value`s stay `.`-decimal (formatFloat, not Format): they round-trip
        -- through String.toFloat on edit, so a localized comma would break parsing.
        paceText =
            formatMmss prof.flatTrailPaceSecPerKm

        fatigueSlopePctText =
            formatFloat 1 (prof.fatigueSlopePerH * 100)

        thresholdText =
            formatFloat 1 prof.fatigueThresholdH
    in
    div [ class "max-w-screen-md mx-auto mt-8 space-y-6 px-6 pb-12" ]
        [ a [ Route.href Route.Index, class "inline-flex items-center gap-2 text-sm text-slate-400 hover:text-slate-100" ]
            [ text (Translations.backToRaces language) ]
        , div []
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text (Translations.profileNav language) ]
            , p2 (Translations.profileIntro language)
            ]
        , viewIdentityCard model
        , profilePresetsRow language
        , viewCalibrationPanel model
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-5" ]
            [ profileFieldRow (Translations.fieldVertRate language)
                (Translations.fieldVertRateHint language)
                (input
                    [ A.type_ "number"
                    , A.value (formatInt prof.verticalRateVmh)
                    , A.attribute "inputmode" "numeric"
                    , onInput ProfileSetVmh
                    , inputClass
                    ]
                    []
                )
                "vm/h"
            , profileFieldRow (Translations.fieldFlatPace language)
                (Translations.fieldFlatPaceHint language)
                (input
                    [ A.type_ "text"
                    , A.value paceText
                    , A.placeholder "6:00"
                    , onInput ProfileSetPace
                    , inputClass
                    ]
                    []
                )
                "/km"
            , profileFieldRow (Translations.fieldFatigueThreshold language)
                (Translations.fieldFatigueThresholdHint language)
                (input
                    [ A.type_ "number"
                    , A.attribute "step" "0.1"
                    , A.value thresholdText
                    , onInput ProfileSetFatigueThreshold
                    , inputClass
                    ]
                    []
                )
                (Translations.unitHours language)
            , profileFieldRow (Translations.fieldFatigueSlope language)
                (Translations.fieldFatigueSlopeHint language)
                (input
                    [ A.type_ "number"
                    , A.attribute "step" "0.1"
                    , A.value fatigueSlopePctText
                    , onInput ProfileSetFatigueSlope
                    , inputClass
                    ]
                    []
                )
                "% / h"
            , profileFieldRow (Translations.fieldDescentSkill language)
                (Translations.fieldDescentSkillHint language)
                (profileSelect ProfileSetDescentSkill
                    (List.map (\d -> ( AthleteProfile.descentSkillLabel d, Translations.descentSkill language d, AthleteProfile.descentSkillLabel d == AthleteProfile.descentSkillLabel prof.descentSkill )) AthleteProfile.allDescentSkills)
                )
                ""
            , profileFieldRow (Translations.fieldTechnicality language)
                (Translations.fieldTechnicalityHint language)
                (profileSelect ProfileSetTechSkill
                    (List.map (\t -> ( AthleteProfile.techSkillLabel t, Translations.techSkill language t, AthleteProfile.techSkillLabel t == AthleteProfile.techSkillLabel prof.technicalitySkill )) AthleteProfile.allTechSkills)
                )
                ""
            , profileFieldRow (Translations.fieldAidStops language)
                (Translations.fieldAidStopsHint language)
                (profileSelect ProfileSetAidStyle
                    (List.map (\a -> ( AthleteProfile.aidStyleLabel a, Translations.aidStyle language a, AthleteProfile.aidStyleLabel a == AthleteProfile.aidStyleLabel prof.aidStyle )) AthleteProfile.allAidStyles)
                )
                ""
            , div [ class "border-t border-slate-800 pt-5 space-y-5" ]
                [ p2 (Translations.hrSectionIntro language)
                , profileFieldRow (Translations.fieldLthr language)
                    (Translations.fieldLthrHint language)
                    (input
                        [ A.type_ "number"
                        , A.value (Maybe.map String.fromInt prof.lthrBpm |> Maybe.withDefault "")
                        , A.placeholder "—"
                        , onInput ProfileSetLthr
                        , inputClass
                        ]
                        []
                    )
                    "bpm"
                , profileFieldRow (Translations.fieldMaxHr language)
                    (Translations.fieldMaxHrHint language)
                    (input
                        [ A.type_ "number"
                        , A.value (Maybe.map String.fromInt prof.maxHrBpm |> Maybe.withDefault "")
                        , A.placeholder "—"
                        , onInput ProfileSetMaxHr
                        , inputClass
                        ]
                        []
                    )
                    "bpm"
                ]
            ]
        , div [ class "flex items-center justify-end gap-3" ]
            [ if model.profileSaved then
                p [ class "text-sm text-emerald-400" ] [ text (Translations.savedConfirm language) ]

              else
                text ""
            , button
                [ onClick ProfileSave
                , class "px-4 py-2 bg-rose-600 text-white rounded-md hover:bg-rose-500 text-sm font-medium"
                ]
                [ text (Translations.saveProfile language) ]
            ]
        , viewStravaSection model
        ]


{-| The WI-5 identity card (TASK-054): your collaboration name, distinct from
the performance settings on the rest of this page (ADR-0012). Shows a rename
control once an identity exists; before the first share there's nothing to name
yet (deferred mint), so it just explains when the name is asked for.
-}
viewIdentityCard : Model -> Html Msg
viewIdentityCard model =
    let
        language =
            model.settings.language
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
        [ div []
            [ p [ class "text-sm font-medium text-slate-100" ] [ text (Translations.identityCardTitle language) ]
            , p [ class "text-xs text-slate-500 mt-0.5" ]
                [ text (Translations.identityCardHelp language) ]
            ]
        , case model.me of
            Just m ->
                div [ class "space-y-3" ]
                    [ p [ class "text-sm text-slate-300" ]
                        [ text (Translations.youArePrefix language)
                        , span [ class "font-semibold text-slate-100" ] [ text m.displayName ]
                        , text "."
                        ]
                    , div [ class "flex items-center gap-2 flex-wrap" ]
                        [ input
                            [ A.type_ "text"
                            , A.value model.renameDraft
                            , A.placeholder (Translations.newNamePlaceholder language)
                            , onInput RenameDraftInput
                            , class "flex-1 min-w-40 bg-slate-950 border border-slate-700 rounded-md px-3 py-2 text-sm text-slate-100 placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-rose-500/50"
                            ]
                            []
                        , identityPrimaryButton RenameMeCommit (Translations.rename language) (String.trim model.renameDraft == "")
                        ]
                    ]

            Nothing ->
                p [ class "text-sm text-slate-400" ]
                    [ text (Translations.identityDeferredPrefix language)
                    , span [ class "text-slate-300" ] [ text ".trail" ]
                    , text (Translations.identityDeferredSuffix language)
                    ]
        ]


viewStravaSection : Model -> Html Msg
viewStravaSection model =
    let
        language =
            model.settings.language
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
        [ div [ class "flex items-center justify-between gap-4 flex-wrap" ]
            [ div []
                [ p [ class "text-sm font-medium text-slate-100" ] [ text (Translations.stravaTitle language) ]
                , p [ class "text-xs text-slate-500 mt-0.5" ]
                    [ text (Translations.stravaHelp language) ]
                ]
            , case model.stravaToken of
                Just _ ->
                    div [ class "flex items-center gap-2" ]
                        [ span [ class "px-2 py-1 text-xs rounded bg-emerald-500/15 text-emerald-300 ring-1 ring-inset ring-emerald-500/30" ]
                            [ text (Translations.connected language) ]
                        , button
                            [ onClick StravaDisconnect
                            , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-400 hover:text-rose-400"
                            ]
                            [ text (Translations.disconnect language) ]
                        ]

                Nothing ->
                    a
                        [ A.href (model.backendUrl ++ "/auth/strava?origin=trail")
                        , class "px-4 py-2 bg-orange-500 text-white rounded-md hover:bg-orange-400 text-sm font-medium"
                        ]
                        [ text (Translations.connectStrava language) ]
            ]
        , p [ class "text-xs text-slate-600" ]
            [ text (Translations.backendPrefix language ++ model.backendUrl) ]
        ]


profilePresetsRow : Language -> Html Msg
profilePresetsRow language =
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-4 flex items-center gap-3 flex-wrap" ]
        [ p [ class "text-xs text-slate-500 uppercase tracking-wider mr-2" ] [ text (Translations.resetToPreset language) ]
        , div [ class "flex items-center gap-2 flex-wrap" ]
            (List.map (presetButton language) AthleteProfile.allPresets)
        ]


presetButton : Language -> Preset -> Html Msg
presetButton language preset =
    button
        [ onClick (ProfilePickPreset preset)
        , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
        ]
        [ text (Translations.preset language preset) ]


profileFieldRow : String -> String -> Html Msg -> String -> Html Msg
profileFieldRow lbl hint control suffix =
    div [ class "grid grid-cols-1 sm:grid-cols-2 gap-4 items-center" ]
        [ div []
            [ p [ class "text-sm font-medium text-slate-100" ] [ text lbl ]
            , p [ class "text-xs text-slate-500 mt-0.5" ] [ text hint ]
            ]
        , div [ class "flex items-center gap-2" ]
            [ control
            , if String.isEmpty suffix then
                text ""

              else
                span [ class "text-xs text-slate-500 whitespace-nowrap" ] [ text suffix ]
            ]
        ]


{-| Each option is `(valueKey, displayLabel, selected)`. The option **value** is
derived from `valueKey` — the canonical English label — so the `onInput` round-trip
to the update handler is language-independent; only `displayLabel` localizes.
-}
profileSelect : (String -> Msg) -> List ( String, String, Bool ) -> Html Msg
profileSelect toMsg options =
    Html.select
        [ onInput toMsg
        , class "w-full bg-slate-950 border border-slate-800 rounded-md px-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-rose-500/60"
        ]
        (List.map
            (\( valueKey, displayLabel, selected ) ->
                Html.option
                    [ A.value (String.toLower (String.split " " valueKey |> List.head |> Maybe.withDefault valueKey))
                    , A.selected selected
                    ]
                    [ text displayLabel ]
            )
            options
        )


p2 : String -> Html msg
p2 s =
    p [ class "text-sm text-slate-400 mt-1" ] [ text s ]



-- ============================================================
-- INDEX PAGE
-- ============================================================


viewIndex : Model -> List Race -> Html Msg
viewIndex model races =
    div [ class "max-w-screen-2xl mx-auto mt-10 space-y-10" ]
        [ viewIndexHero model.settings.language (List.length races)
        , viewUploadBanner model
        , if List.isEmpty races then
            viewEmptyState model.settings.language

          else
            viewRaceSections model races
        ]


viewIndexHero : Language -> Int -> Html msg
viewIndexHero language count =
    div [ class "flex items-end justify-between flex-wrap gap-4" ]
        [ div []
            [ h1 [ class "text-4xl font-bold tracking-tight text-slate-100" ]
                [ text (Translations.homeTitle language) ]
            , p [ class "mt-2 text-slate-400" ]
                [ text (Translations.homeSubtitle language) ]
            ]
        , p [ class "text-sm text-slate-500" ]
            [ text (Translations.heroRaceCount language count) ]
        ]


viewUploadBanner : Model -> Html Msg
viewUploadBanner model =
    let
        language =
            model.settings.language

        ( labelText, sub, disabled ) =
            case model.upload of
                NotUploading ->
                    ( Translations.uploadDropTitle language, Translations.uploadDropSub language, False )

                Parsing fname ->
                    ( Translations.uploadProcessing language fname, Translations.uploadProcessingSub language, True )

                Persisting fname ->
                    ( Translations.uploadSaving language fname, Translations.uploadSavingSub language, True )

                UploadFailed fname err ->
                    -- `err` is a dynamic parse/decode message, not app chrome — left as-is.
                    ( Translations.uploadFailed language fname, err, False )

        inner =
            if disabled then
                viewUploadSkeleton labelText sub

            else
                viewUploadIdle language labelText sub
    in
    div
        [ classList
            [ ( "rounded-2xl border-2 border-dashed p-6 text-center transition-colors", True )
            , ( "border-slate-700 bg-slate-900/40 hover:bg-slate-900/70", not model.dragOver && not disabled )
            , ( "border-rose-500 bg-rose-500/5", model.dragOver )
            , ( "border-slate-700 bg-slate-900/30 cursor-wait animate-pulse", disabled )
            ]
        , preventDefaultOn "dragenter" (D.succeed ( DragEnter, True ))
        , preventDefaultOn "dragover" (D.succeed ( DragEnter, True ))
        , preventDefaultOn "dragleave" (D.succeed ( DragLeave, True ))
        , preventDefaultOn "drop" dropDecoder
        ]
        inner


viewUploadIdle : Language -> String -> String -> List (Html Msg)
viewUploadIdle language labelText sub =
    [ p [ class "text-slate-200 font-medium" ] [ text labelText ]
    , p [ class "text-sm text-slate-500 mt-1" ] [ text sub ]
    , button
        [ onClick OpenPicker
        , class "mt-4 px-4 py-2 bg-rose-600 text-white rounded-md hover:bg-rose-500 text-sm font-medium"
        ]
        [ text (Translations.chooseFile language) ]
    ]


viewUploadSkeleton : String -> String -> List (Html Msg)
viewUploadSkeleton labelText sub =
    [ p [ class "text-slate-200 font-medium" ] [ text labelText ]
    , p [ class "text-xs text-slate-500 mt-1" ] [ text sub ]
    , div [ class "mt-5 flex flex-col items-center gap-2" ]
        [ div [ class "h-3 w-56 rounded bg-slate-700/70" ] []
        , div [ class "h-3 w-72 rounded bg-slate-700/60" ] []
        , div [ class "h-3 w-40 rounded bg-slate-700/50" ] []
        ]
    ]


dropDecoder : D.Decoder ( Msg, Bool )
dropDecoder =
    D.at [ "dataTransfer", "files" ] (D.oneOrMore GotFiles File.decoder)
        |> D.map (\m -> ( m, True ))


viewEmptyState : Language -> Html msg
viewEmptyState language =
    div [ class "border border-dashed border-slate-800 rounded-2xl py-20 text-center text-slate-500" ]
        [ p [ class "text-lg" ] [ text (Translations.emptyTitle language) ]
        , p [ class "text-sm mt-2" ] [ text (Translations.emptySub language) ]
        ]


{-| Is this race the local user's own? **Owner-based, never last-editor**
(TASK-055, spec §1.5): my `userId`, or unstamped (`owner == ""`), or no identity
yet — all read as personal. A race someone else owns (`owner` set and ≠ me) is the
only "someone else's" case, so a race you own that a coach edited still reads as
yours.
-}
isMyRace : Maybe Identity.Me -> Race -> Bool
isMyRace me race =
    case me of
        Just m ->
            race.owner == "" || race.owner == m.userId

        Nothing ->
            True


{-| The home grid. Solo / common case (no one else's races): exactly the
Plans/Executions layout (TASK-028), unchanged. When you also hold races owned by
other people (the coach case — every athlete plan reads as theirs), group by
**person**: "Your races" first, then one group per other owner, named from the
directory. The Plans/Executions split lives inside each group. TASK-055, spec §1.5.
-}
viewRaceSections : Model -> List Race -> Html Msg
viewRaceSections model races =
    let
        ( mine, others ) =
            List.partition (isMyRace model.me) races
    in
    if List.isEmpty others then
        viewPlansExecutions model races

    else
        div [ class "space-y-12" ]
            ((if List.isEmpty mine then
                []

              else
                [ viewOwnerGroup model (Translations.homeTitle model.settings.language) mine ]
             )
                ++ viewOtherOwnerGroups model others
            )


{-| The Plans/Executions split (TASK-028) for a set of races — formerly the body
of `viewRaceSections`, now reused inside each owner group (TASK-055). The cut is
by `actualSplits` presence, not dates: a plan whose date passed but was never
linked stays in Plans; a logged training loop with an actual shows in Executions.
-}
viewPlansExecutions : Model -> List Race -> Html Msg
viewPlansExecutions model races =
    let
        ( executions, plans ) =
            List.partition (\r -> r.actualSplits /= Nothing) races

        sortedPlans =
            List.sortWith comparePlans plans

        sortedExecutions =
            List.sortWith compareExecutions executions

        language =
            model.settings.language
    in
    div [ class "space-y-10" ]
        [ if List.isEmpty sortedPlans then
            text ""

          else
            viewRaceSection model (Translations.sectionPlans language) (Translations.sectionPlansSub language) sortedPlans
        , if List.isEmpty sortedExecutions then
            text ""

          else
            viewRaceSection model (Translations.sectionExecutions language) (Translations.sectionExecutionsSub language) sortedExecutions
        ]


{-| One person's race group: a name header + their Plans/Executions split. -}
viewOwnerGroup : Model -> String -> List Race -> Html Msg
viewOwnerGroup model heading races =
    let
        n =
            List.length races
    in
    div [ class "space-y-4" ]
        [ div [ class "flex items-baseline gap-3 border-b border-slate-800 pb-2" ]
            [ h2 [ class "text-xl font-bold tracking-tight text-slate-100" ] [ text heading ]
            , span [ class "text-sm text-slate-500 tabular-nums" ]
                [ text (Translations.raceCount model.settings.language n) ]
            ]
        , viewPlansExecutions model races
        ]


{-| Others' races grouped by owner, each group named from the directory and
sorted by that name (TASK-055). -}
viewOtherOwnerGroups : Model -> List Race -> List (Html Msg)
viewOtherOwnerGroups model others =
    others
        |> List.foldr
            (\r acc -> Dict.update r.owner (\ex -> Just (r :: Maybe.withDefault [] ex)) acc)
            Dict.empty
        |> Dict.toList
        |> List.map (\( ownerId, rs ) -> ( Identity.resolveName model.directory ownerId, rs ))
        |> List.sortBy Tuple.first
        |> List.map (\( name, rs ) -> viewOwnerGroup model (Translations.othersRacesHeading model.settings.language name) rs)


viewRaceSection : Model -> String -> String -> List Race -> Html Msg
viewRaceSection model heading sub races =
    div [ class "space-y-4" ]
        [ div [ class "flex items-baseline gap-3 flex-wrap" ]
            [ h2 [ class "text-lg font-semibold text-slate-200" ] [ text heading ]
            , span [ class "text-sm text-slate-500 tabular-nums" ]
                [ text (String.fromInt (List.length races)) ]
            , span [ class "text-xs text-slate-600" ] [ text sub ]
            ]
        , viewRaceGrid model races
        ]


comparePlans : Race -> Race -> Order
comparePlans a b =
    -- Next race first (race.date ascending). Undated entries sort
    -- after dated ones, ordered by createdAt desc among themselves.
    case ( a.date, b.date ) of
        ( Just da, Just db ) ->
            case compare da db of
                EQ ->
                    compare b.createdAt a.createdAt

                ord ->
                    ord

        ( Just _, Nothing ) ->
            LT

        ( Nothing, Just _ ) ->
            GT

        ( Nothing, Nothing ) ->
            compare b.createdAt a.createdAt


compareExecutions : Race -> Race -> Order
compareExecutions a b =
    -- Newest race first (race.date descending). Undated executions
    -- sort after dated ones; among themselves, order by the time
    -- the actual was uploaded (the closest proxy for "when did I
    -- run this" when no race date was set).
    case ( a.date, b.date ) of
        ( Just da, Just db ) ->
            case compare db da of
                EQ ->
                    compareUploadedAtDesc a b

                ord ->
                    ord

        ( Just _, Nothing ) ->
            LT

        ( Nothing, Just _ ) ->
            GT

        ( Nothing, Nothing ) ->
            compareUploadedAtDesc a b


compareUploadedAtDesc : Race -> Race -> Order
compareUploadedAtDesc a b =
    let
        ts r =
            r.actualSplits
                |> Maybe.map .uploadedAt
                |> Maybe.withDefault 0
    in
    compare (ts b) (ts a)


viewRaceGrid : Model -> List Race -> Html Msg
viewRaceGrid model races =
    let
        ctx =
            toContext model
    in
    div [ class "grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-5" ]
        (List.map (\r -> viewRaceCard ctx (Dict.get (raceIdToString r.id) model.sparklineCoords) r) races)


viewRaceCard : Context -> Maybe (List ( Float, Float )) -> Race -> Html Msg
viewRaceCard ctx maybeCoords race =
    let
        ( catLetter, catColor, catLabel ) =
            distanceCategory ctx.language race.distance
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
                viewCoverSparkline catColor maybeCoords
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
                            densityLabel ctx.language dens
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
                [ miniStat (Format.number ctx.language 1 (race.distance / 1000)) "km"
                , miniStat (formatInt race.gain) "m+"
                , miniStat (formatInt race.loss) "m−"
                ]
            , if List.isEmpty race.aidStations then
                p [ class "text-xs text-slate-600" ]
                    [ text (Translations.cardNoAid ctx.language) ]

              else
                p [ class "text-xs text-amber-400/70" ]
                    [ text (Translations.cardAidCount ctx.language (List.length race.aidStations)) ]
            ]
        , button
            [ onClick (RequestDelete race.id)
            , class "absolute top-3 right-3 w-8 h-8 rounded-full bg-slate-950/70 text-slate-500 hover:text-rose-400 hover:bg-slate-950 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center text-sm"
            , A.attribute "aria-label" "Delete race"
            , A.title "Delete race"
            ]
            [ text "✕" ]
        ]


distanceCategory : Language -> Float -> ( String, String, String )
distanceCategory language meters =
    let
        km =
            meters / 1000

        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es
    in
    if km < 30 then
        ( "S", "bg-sky-500", tr "Short" "Corta" )

    else if km < 70 then
        ( "M", "bg-amber-500", tr "Medium" "Media" )

    else if km < 120 then
        ( "L", "bg-orange-500", tr "Long" "Larga" )

    else
        ( "XL", "bg-rose-600", tr "Ultra" "Ultra" )


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
densityLabel : Language -> Float -> ( String, String )
densityLabel language mPerKm =
    let
        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es
    in
    if mPerKm < 5 then
        ( tr "Flat" "Llano", "text-slate-400" )

    else if mPerKm < 20 then
        ( tr "Rolling" "Ondulado", "text-sky-400" )

    else if mPerKm < 40 then
        ( tr "Hilly" "Accidentado", "text-amber-400" )

    else if mPerKm < 55 then
        ( tr "Mountainous" "Montañoso", "text-orange-400" )

    else if mPerKm < 70 then
        ( tr "Very mountainous" "Muy montañoso", "text-rose-400" )

    else
        ( tr "Extreme" "Extremo", "text-rose-500" )


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
gradeClass : Language -> Float -> ( String, String )
gradeClass language slope =
    let
        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es
    in
    if slope >= 0.1 then
        ( tr "Steep climb" "Subida pronunciada", "text-rose-300 bg-rose-500/15 ring-rose-500/30" )

    else if slope >= 0.04 then
        ( tr "Climb" "Subida", "text-rose-400 bg-rose-500/10 ring-rose-500/20" )

    else if slope > -0.04 then
        ( tr "Runnable" "Corrible", "text-slate-400 bg-slate-500/10 ring-slate-500/20" )

    else if slope > -0.1 then
        ( tr "Descent" "Bajada", "text-emerald-400 bg-emerald-500/10 ring-emerald-500/20" )

    else
        ( tr "Steep descent" "Bajada pronunciada", "text-emerald-300 bg-emerald-500/15 ring-emerald-500/30" )


{-| Race-card "cover" when there's no user image: a real silhouette
of the race's elevation profile drawn at the card width. Each race
becomes visually recognisable by its profile shape. If the parsed
track isn't available yet (shouldn't happen post-RacesLoaded), we
fall back to a generic stylised silhouette so the card stays the
same shape.
-}
viewCoverSparkline : String -> Maybe (List ( Float, Float )) -> Html msg
viewCoverSparkline catColor maybeCoords =
    let
        bandHeight =
            112
    in
    div
        [ class "relative h-28 border-b border-slate-800 overflow-hidden bg-slate-950"
        ]
        [ div [ class ("absolute top-0 left-0 right-0 h-1.5 " ++ catColor) ] []
        , case maybeCoords of
            Just coords ->
                raceSparkline coords bandHeight

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


raceSparkline : List ( Float, Float ) -> Int -> Html msg
raceSparkline coords bandHeight =
    let
        width =
            320.0

        height =
            toFloat bandHeight

        pad =
            8.0

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


{-| "Plan by <name>" on the race detail — resolves `race.owner` (a userId)
through the directory (WI-5 / TASK-054). Demonstrates that a self-rename
relabels every owned race with no per-race write (one directory row drives them
all). Hidden until the race has an owner (stamped at first edit/share).
-}
viewOwnerLine : Model -> Race -> Html Msg
viewOwnerLine model race =
    if race.owner == "" then
        text ""

    else
        p [ class "mt-1 text-xs text-slate-500" ]
            [ text "Plan by "
            , span [ class "text-slate-400" ] [ text (Identity.resolveName model.directory race.owner) ]
            ]


viewRaceDetail : Model -> Race -> Html Msg
viewRaceDetail model race =
    let
        ctx =
            toContext model

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
        [ div [ class "flex items-center justify-between gap-3" ]
            [ a [ Route.href Route.Index, class "inline-flex items-center gap-2 text-sm text-slate-400 hover:text-slate-100" ]
                [ text (Translations.backToRaces ctx.language) ]
            , viewHistoryButton ctx.language race
            ]
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
                                [ text (Translations.editDetails ctx.language) ]

                        MetaOpen _ ->
                            text ""
                    ]
                , p [ class "mt-2 text-sm text-slate-500" ] [ text (raceSubtitle race) ]
                , viewOwnerLine model race
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
                [ bigStat (Translations.statDistance ctx.language) (Format.number ctx.language 1 (race.distance / 1000)) "km"
                , bigStat (Translations.statGain ctx.language) (formatInt race.gain) "m"
                , bigStat (Translations.statLoss ctx.language) (formatInt race.loss) "m"
                , bigStat (Translations.statDensity ctx.language) (formatInt dens) "m/km"
                , bigStat (Translations.statFlatEq ctx.language) (Format.number ctx.language 1 eqKm) "km"
                ]
            ]
        , case model.metaEditor of
            MetaOpen form ->
                viewMetaForm ctx.language form

            MetaClosed ->
                text ""
        , case cachedTrack of
            Just track ->
                viewProfileSection model track containerWidth markers

            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text (Translations.parsingGpx ctx.language) ]
        , viewAidStationsSection model race
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 flex items-center justify-between gap-4 flex-wrap" ]
            [ div []
                [ p [ class "font-medium text-slate-100" ] [ text (Translations.planThisRace ctx.language) ]
                , p [ class "text-sm text-slate-400 mt-1" ] [ text (Translations.planThisRaceSub ctx.language) ]
                ]
            , a
                [ Route.href (Route.PlanTable race.id)
                , class "px-4 py-2 bg-rose-600 text-white rounded-md hover:bg-rose-500 text-sm font-medium"
                ]
                [ text (Translations.openThePlan ctx.language) ]
            ]
        , viewMapTeaser model race
        , viewExportPanel ctx.language race
        ]


viewMapTeaser : Model -> Race -> Html Msg
viewMapTeaser model race =
    let
        language =
            model.settings.language
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 flex items-center justify-between gap-4 flex-wrap" ]
        [ div []
            [ p [ class "font-medium text-slate-100" ] [ text (Translations.mapTeaserTitle language) ]
            , p [ class "text-sm text-slate-400 mt-1" ]
                [ text (Translations.mapTeaserSub language) ]
            ]
        , a
            [ Route.href (Route.RaceMap race.id)
            , class "px-4 py-2 border border-slate-700 rounded-md hover:bg-slate-800 text-sm font-medium text-slate-100"
            ]
            [ text (Translations.viewOnMap language) ]
        ]


viewRaceMap : Model -> Race -> Html Msg
viewRaceMap model race =
    let
        language =
            model.settings.language

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
                                    , ( "name", Encode.string (Translations.startLabel language) )
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
                                    , ( "name", Encode.string (Translations.finishLabel language ++ " · " ++ Format.number language 1 (race.distance / 1000) ++ " km") )
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
            [ a [ Route.href Route.Index, class "hover:text-slate-100" ] [ text (Translations.breadcrumbRaces language) ]
            , span [ class "text-slate-700" ] [ text "/" ]
            , a [ Route.href (Route.RaceDetail race.id), class "hover:text-slate-100" ] [ text race.name ]
            , span [ class "text-slate-700" ] [ text "/" ]
            , span [ class "text-slate-200" ] [ text (Translations.breadcrumbMap language) ]
            ]
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text race.name ]
            , p [ class "text-sm text-slate-500" ]
                [ text
                    (Format.number language 1 (race.distance / 1000)
                        ++ " km · "
                        ++ Translations.aidStationCount language (List.length sortedAids)
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
                    [ text (Translations.parsingGpx language) ]
        , p [ class "text-xs text-slate-500" ]
            [ text (Translations.mapTiles language) ]
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


viewExportPanel : Language -> Race -> Html Msg
viewExportPanel language race =
    let
        hasAids =
            not (List.isEmpty race.aidStations)
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
        [ div [ class "flex items-baseline gap-3" ]
            [ h2 [ class "text-xl font-semibold text-slate-100" ] [ text (Translations.exportTitle language) ]
            , span [ class "text-xs text-slate-500" ] [ text (Translations.exportSub language) ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-2 gap-3" ]
            [ exportCard
                { titleText = Translations.exportGpxTitle language
                , description = Translations.exportGpxDesc language hasAids
                , buttonText = Translations.exportGpxButton language
                , msg = ExportGpxForCoros
                , disabled = not hasAids
                }
            , exportCard
                { titleText = Translations.exportTrailTitle language
                , description = Translations.exportTrailDesc language
                , buttonText = Translations.exportTrailButton language
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


viewMetaForm : Language -> MetaForm -> Html Msg
viewMetaForm language form =
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4" ]
        [ div [ class "flex items-baseline justify-between" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text (Translations.editRaceDetails language) ]
            , button
                [ onClick CloseMetaEdit, class "text-xs text-slate-500 hover:text-slate-200" ]
                [ text (Translations.cancel language) ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
            [ field (Translations.fieldName language)
                [ input
                    [ A.type_ "text"
                    , A.value form.name
                    , onInput MetaSetName
                    , inputClass
                    ]
                    []
                ]
            , field (Translations.fieldDate language)
                [ input
                    [ A.type_ "date"
                    , A.value form.date
                    , onInput MetaSetDate
                    , inputClass
                    ]
                    []
                ]
            , field (Translations.fieldLocation language)
                [ input
                    [ A.type_ "text"
                    , A.value form.location
                    , A.placeholder "Chamonix, FR"
                    , onInput MetaSetLocation
                    , inputClass
                    ]
                    []
                ]
            , field (Translations.fieldUrl language)
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
        , field (Translations.fieldNotes language)
            [ textarea
                [ A.value form.notes
                , A.placeholder (Translations.notesPlaceholder language)
                , A.rows 4
                , onInput MetaSetNotes
                , inputClass
                ]
                []
            ]
        , div [ class "space-y-2" ]
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.coverImage language) ]
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
                                [ text (Translations.replace language) ]
                            , button
                                [ onClick MetaClearCover
                                , class "px-3 py-1.5 text-xs text-slate-500 hover:text-rose-400"
                                ]
                                [ text (Translations.remove language) ]
                            ]
                        ]

                Nothing ->
                    button
                        [ onClick MetaPickCover
                        , class "px-3 py-1.5 text-xs border border-dashed border-slate-700 rounded hover:bg-slate-800 text-slate-300"
                        ]
                        [ text (Translations.pickImage language) ]
            ]
        , div [ class "flex justify-end gap-2" ]
            [ button
                [ onClick CloseMetaEdit
                , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                ]
                [ text (Translations.cancel language) ]
            , button
                [ onClick MetaSubmit
                , class "px-4 py-2 text-sm bg-rose-600 text-white rounded-md hover:bg-rose-500 font-medium"
                ]
                [ text (Translations.saveChanges language) ]
            ]
        ]


viewProfileSection : Model -> Track -> Float -> List Marker -> Html Msg
viewProfileSection model track containerWidth markers =
    div [ class "space-y-3" ]
        [ div [ class "flex items-baseline gap-3" ]
            [ h2 [ class "text-xl font-semibold text-slate-100" ] [ text (Translations.elevationProfile model.settings.language) ]
            , span [ class "text-xs text-slate-500" ] [ text (Translations.trueScaleNote model.settings.language) ]
            ]
        , Profile.viewToolbar
            { mode = model.scaleMode
            , track = track
            , containerWidth = containerWidth
            , onSetMode = SetScaleMode
            , language = model.settings.language
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
        language =
            model.settings.language

        sorted =
            sortAidStations race.aidStations

        idle =
            model.aidEditor == AidClosed && model.aidImport == AidImportClosed
    in
    div [ class "space-y-3" ]
        [ div [ class "flex items-baseline justify-between gap-3" ]
            [ div [ class "flex items-baseline gap-3" ]
                [ h2 [ class "text-xl font-semibold text-slate-100" ] [ text (Translations.aidSectionTitle language) ]
                , span [ class "text-xs text-slate-500" ]
                    [ text (Translations.aidStopCount language (List.length sorted)) ]
                ]
            , if idle then
                div [ class "flex items-center gap-2" ]
                    [ button [ onClick OpenAidImport, secondaryBtnClass ] [ text (Translations.importCsv language) ]
                    , if List.isEmpty sorted then
                        text ""

                      else
                        button [ onClick ExportAidCsv, secondaryBtnClass ] [ text (Translations.exportCsv language) ]
                    , button
                        [ onClick OpenAddAid
                        , class "px-3 py-1.5 text-sm rounded-md bg-rose-600 text-white hover:bg-rose-500"
                        ]
                        [ text (Translations.addAid language) ]
                    ]

              else
                text ""
            ]
        , case model.aidImport of
            AidImportClosed ->
                text ""

            AidImportReading fileName ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 text-sm text-slate-400" ]
                    [ text (Translations.reading language fileName) ]

            AidImportPreview preview ->
                viewAidImportPreview language preview race
        , case model.aidEditor of
            AidOpen form ->
                viewAidForm language form race

            AidClosed ->
                text ""
        , if List.isEmpty sorted then
            div [ class "rounded-2xl border border-dashed border-slate-800 p-8 text-center text-slate-500 text-sm" ]
                [ p [] [ text (Translations.cardNoAid language) ]
                , p [ class "mt-1 text-xs text-slate-600" ] [ text (Translations.aidEmptySub language) ]
                ]

          else
            div [ class "rounded-2xl bg-slate-900 border border-slate-800 overflow-hidden" ]
                (List.indexedMap (viewAidRow language sorted race.distance) sorted)
        ]


secondaryBtnClass : Html.Attribute msg
secondaryBtnClass =
    class "px-3 py-1.5 text-sm rounded-md border border-slate-700 text-slate-200 hover:bg-slate-800"


viewAidImportPreview : Language -> ImportPreview -> Race -> Html Msg
viewAidImportPreview language preview race =
    let
        r =
            preview.result

        n =
            List.length r.stations

        existing =
            List.length race.aidStations
    in
    div [ class "rounded-2xl bg-slate-900 border border-rose-500/30 p-5 space-y-4" ]
        [ div [ class "flex items-baseline justify-between gap-3" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text (Translations.importPreviewTitle language) ]
            , span [ class "text-xs text-slate-500 truncate max-w-[12rem]" ] [ text preview.fileName ]
            ]
        , p [ class "text-sm text-slate-300" ]
            [ text (Translations.importReady language n)
            , if List.isEmpty r.errors then
                text ""

              else
                span [ class "text-rose-400" ] [ text (Translations.importSkipped language (List.length r.errors)) ]
            , if List.isEmpty r.warnings then
                text ""

              else
                span [ class "text-amber-400" ] [ text (Translations.importWarningsCount language (List.length r.warnings)) ]
            ]
        , if n == 0 then
            p [ class "text-sm text-slate-500" ] [ text (Translations.nothingParsed language) ]

          else
            div [ class "rounded-xl bg-slate-950 border border-slate-800 overflow-hidden max-h-72 overflow-y-auto" ]
                (List.indexedMap (viewPreviewRow language) r.stations)
        , viewIssueBlock language (Translations.issueSkipped language) "text-rose-300/80" r.errors
        , viewIssueBlock language (Translations.issueWarnings language) "text-amber-300/80" r.warnings
        , div [ class "flex items-center justify-between gap-3 pt-1" ]
            [ p [ class "text-xs text-slate-500" ]
                [ text (Translations.importReplaceNote language existing) ]
            , div [ class "flex gap-2" ]
                [ button
                    [ onClick AidImportCancel
                    , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                    ]
                    [ text (Translations.cancel language) ]
                , button
                    [ onClick AidImportConfirm
                    , A.disabled (n == 0)
                    , classList
                        [ ( "px-4 py-2 text-sm rounded-md font-medium", True )
                        , ( "bg-rose-600 text-white hover:bg-rose-500", n > 0 )
                        , ( "bg-slate-800 text-slate-500 cursor-not-allowed", n == 0 )
                        ]
                    ]
                    [ text (Translations.importConfirmLabel language n existing) ]
                ]
            ]
        ]


viewPreviewRow : Language -> Int -> AidStation -> Html Msg
viewPreviewRow language index aid =
    div
        [ classList
            [ ( "flex items-center gap-3 px-4 py-2.5", True )
            , ( "border-t border-slate-800", index > 0 )
            ]
        ]
        [ div [ class "flex items-center justify-center w-7 h-7 rounded-full bg-amber-400/20 border border-amber-400/50 text-amber-300 text-[11px] font-semibold flex-shrink-0" ]
            [ text (String.fromInt (index + 1)) ]
        , div [ class "min-w-0 flex-1" ]
            [ p [ class "text-sm text-slate-100 truncate" ] [ text aid.name ]
            , p [ class "text-xs text-slate-500" ]
                [ text
                    (Format.number language 1 (aid.distance / 1000)
                        ++ " km · "
                        ++ formatRest language aid.restSeconds
                        ++ (case aid.cutoff of
                                Just secs ->
                                    " · " ++ Translations.cutoffLabel language ++ " " ++ AidCsv.formatClock secs

                                Nothing ->
                                    ""
                           )
                    )
                ]
            , if String.isEmpty aid.notes then
                text ""

              else
                p [ class "text-xs text-slate-400 truncate" ] [ text aid.notes ]
            ]
        , if List.isEmpty aid.services then
            text ""

          else
            span [ class "flex gap-1 text-sm flex-shrink-0" ]
                (List.map (\s -> span [ A.title (Translations.serviceLabel language s) ] [ text (serviceIcon s) ]) aid.services)
        ]


viewIssueBlock : Language -> String -> String -> List AidCsv.RowIssue -> Html Msg
viewIssueBlock language heading toneClass issues =
    if List.isEmpty issues then
        text ""

    else
        div [ class "space-y-1" ]
            [ p [ class "text-xs uppercase tracking-wider text-slate-500" ] [ text heading ]
            , div [ class "space-y-0.5" ]
                (List.map
                    (\issue ->
                        p [ class ("text-xs " ++ toneClass) ]
                            [ text
                                ((if issue.row == 0 then
                                    Translations.issueFile language

                                  else
                                    Translations.issueRow language issue.row
                                 )
                                    ++ ": "
                                    ++ issue.message
                                )
                            ]
                    )
                    issues
                )
            ]


plural : Int -> String -> String -> String
plural n singular pluralForm =
    if n == 1 then
        singular

    else
        pluralForm


viewAidRow : Language -> List AidStation -> Float -> Int -> AidStation -> Html Msg
viewAidRow language allAids totalDistance index aid =
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
                    (Format.number language 1 (aid.distance / 1000)
                        ++ " km "
                        ++ Translations.aidFromStart language
                        ++ " · +"
                        ++ Format.number language 1 fromPrevKm
                        ++ " km "
                        ++ Translations.aidFromPrevious language
                        ++ " · "
                        ++ Format.number language 1 toFinishKm
                        ++ " km "
                        ++ Translations.aidToFinish language
                    )
                ]
            , case aid.cutoff of
                Just secs ->
                    p [ class "text-xs text-amber-400/80" ]
                        [ text ("⏱ " ++ Translations.cutoffLabel language ++ " " ++ AidCsv.formatClock secs) ]

                Nothing ->
                    text ""
            , if String.isEmpty aid.notes then
                text ""

              else
                p [ class "mt-1 text-xs text-slate-400 whitespace-pre-line" ] [ text aid.notes ]
            , if List.isEmpty aid.services then
                text ""

              else
                p [ class "mt-1 flex gap-1.5 text-base" ]
                    (List.map (\s -> span [ A.title (Translations.serviceLabel language s) ] [ text (serviceIcon s) ]) aid.services)
            ]
        , div [ class "flex items-center gap-2 flex-shrink-0" ]
            [ span [ class "text-xs text-slate-500" ]
                [ text (formatRest language aid.restSeconds) ]
            , button
                [ onClick (OpenEditAid aid)
                , class "px-2 py-1 text-xs border border-slate-700 rounded hover:bg-slate-800 text-slate-200 opacity-0 group-hover:opacity-100 transition-opacity"
                ]
                [ text (Translations.edit language) ]
            , button
                [ onClick (AidDelete aid.id)
                , class "px-2 py-1 text-xs text-slate-500 hover:text-rose-400 opacity-0 group-hover:opacity-100 transition-opacity"
                ]
                [ text "✕" ]
            ]
        ]


viewAidForm : Language -> AidForm -> Race -> Html Msg
viewAidForm language form race =
    let
        editing =
            form.editing /= Nothing

        prevHint =
            previousAidDistance form.editing race / 1000
    in
    div [ A.id aidFormDomId, class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4 scroll-mt-4" ]
        [ div [ class "flex items-baseline justify-between" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text (Translations.aidFormTitle language editing) ]
            , button
                [ onClick CloseAid
                , class "text-xs text-slate-500 hover:text-slate-200"
                ]
                [ text (Translations.cancel language) ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-2 gap-4" ]
            [ field (Translations.fieldName language)
                [ input
                    [ A.type_ "text"
                    , A.value form.name
                    , A.placeholder "Las Truchas, Cafetería, Finish…"
                    , onInput AidSetName
                    , inputClass
                    ]
                    []
                ]
            , field (Translations.fieldRestMinutes language)
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
            , field (Translations.fieldCutoff language)
                [ input
                    [ A.type_ "text"
                    , A.value form.cutoffText
                    , A.placeholder (Translations.cutoffPlaceholder language)
                    , onInput AidSetCutoff
                    , inputClass
                    ]
                    []
                ]
            ]
        , div [ class "space-y-2" ]
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.statDistance language) ]
            , div [ class "flex gap-1 bg-slate-950 border border-slate-800 rounded-lg p-1 w-fit" ]
                [ modeChip (Translations.modeFromPrevious language) (form.mode == FromPrevious) (AidSetMode FromPrevious)
                , modeChip (Translations.modeFromStart language) (form.mode == FromStart) (AidSetMode FromStart)
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
                            Translations.modeHelpFromStart language

                        FromPrevious ->
                            Translations.modeHelpFromPrevious language (Format.number language 1 prevHint)
                    )
                ]
            ]
        , div [ class "space-y-2" ]
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.servicesLabel language) ]
            , div [ class "flex flex-wrap gap-2" ]
                (List.map (serviceChip language form.services) allServices)
            ]
        , field (Translations.fieldNotesOptional language)
            [ textarea
                [ A.value form.notesText
                , A.placeholder (Translations.aidNotesPlaceholder language)
                , A.rows 2
                , onInput AidSetNotes
                , inputClass
                ]
                []
            ]
        , case form.error of
            Just err ->
                -- `err` is a dynamic validation message from validateAidForm
                -- (English for now); see TASK-069.
                p [ class "text-sm text-rose-400" ] [ text err ]

            Nothing ->
                text ""
        , div [ class "flex justify-end gap-2" ]
            [ button
                [ onClick CloseAid
                , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                ]
                [ text (Translations.cancel language) ]
            , button
                [ onClick AidSubmit
                , class "px-4 py-2 text-sm bg-rose-600 text-white rounded-md hover:bg-rose-500 font-medium"
                ]
                [ text
                    (if editing then
                        Translations.saveChanges language

                     else
                        Translations.addAidStation language
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


serviceChip : Language -> List Service -> Service -> Html Msg
serviceChip language current s =
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
        , span [] [ text (Translations.serviceLabel language s) ]
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
                { target = Just (effectiveTargetSeconds model.profile race kms)
                , kms = kms
                , plan = race.plan
                , aidRestSeconds = aidRest
                }

        currentSum =
            Dict.foldl (\_ r acc -> acc + r.seconds) 0 results + aidRest

        language =
            model.settings.language
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 space-y-6 px-6 plan-print" ]
        [ viewPlanCrumb language race
        , viewPlanHeader language race
        , div [ class "space-y-6 print:hidden" ]
            [ viewPlanTargetPanel language race aidRest currentSum model.targetTimeText
            , viewPredictorStrip model race kms
            , viewActualRunStrip model race
            ]
        , viewPlanTabs language model.planTableMode
        , case model.planTableMode of
            ByKm ->
                viewKmTable language race kms results

            BySection ->
                viewSectionTable language race kms results
        ]


viewStravaPickerModal : Model -> RaceId -> Html Msg
viewStravaPickerModal model raceId =
    let
        language =
            model.settings.language

        sameRace pickerRid =
            raceIdToString pickerRid == raceIdToString raceId

        isSearching =
            not (String.isEmpty (String.trim model.stravaPickerSearch))

        heading =
            if isSearching then
                Translations.stravaSearchHeading language

            else
                Translations.stravaRecentHeading language
    in
    case model.stravaPicker of
        PickerClosed ->
            text ""

        PickerLoadingActivities pickerRid ->
            if sameRace pickerRid then
                modalShell heading
                    (div [ class "space-y-3" ]
                        [ viewStravaPickerSearch language pickerRid model.stravaPickerSearch
                        , p [ class "text-sm text-slate-500 py-6 text-center" ]
                            [ text
                                (if isSearching then
                                    Translations.stravaSearching language

                                 else
                                    Translations.stravaLoadingRecent language
                                )
                            ]
                        ]
                    )

            else
                text ""

        PickerLoadingStreams pickerRid actId ->
            if sameRace pickerRid then
                modalShell (Translations.stravaFetchingStreams language actId) (text "")

            else
                text ""

        PickerError pickerRid err ->
            if sameRace pickerRid then
                modalShell (Translations.stravaError language)
                    (div [ class "space-y-3" ]
                        [ p [ class "text-sm text-rose-400" ] [ text err ]
                        , button
                            [ onClick StravaPickerClose
                            , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-100"
                            ]
                            [ text (Translations.close language) ]
                        ]
                    )

            else
                text ""

        PickerShowing pickerRid acts ->
            if sameRace pickerRid then
                modalShell heading
                    (div [ class "space-y-3" ]
                        [ viewStravaPickerSearch language pickerRid model.stravaPickerSearch
                        , div [ class "space-y-2 max-h-[60vh] overflow-y-auto" ]
                            (if List.isEmpty acts then
                                [ p [ class "text-sm text-slate-400 py-6 text-center" ]
                                    [ text
                                        (if isSearching then
                                            Translations.stravaNoMatch language

                                         else
                                            Translations.stravaNoneRecent language
                                        )
                                    ]
                                ]

                             else
                                List.map (viewStravaActivityRow language pickerRid) acts
                            )
                        ]
                    )

            else
                text ""


viewStravaPickerSearch : Language -> RaceId -> String -> Html Msg
viewStravaPickerSearch language rid current =
    div [ class "relative" ]
        [ input
            [ A.type_ "text"
            , A.value current
            , A.placeholder (Translations.stravaSearchPlaceholder language)
            , onInput (StravaPickerSetSearch rid)
            , class "w-full bg-slate-950 border border-slate-800 rounded-md pl-9 pr-3 py-2 text-sm text-slate-100 focus:outline-none focus:border-rose-500/60"
            ]
            []
        , span [ class "absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 text-sm" ]
            [ text "⌕" ]
        ]


modalShell : String -> Html Msg -> Html Msg
modalShell heading body =
    div
        [ class "fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/70 backdrop-blur-sm"
        , onClick StravaPickerClose
        ]
        [ div
            [ class "max-w-xl w-full bg-slate-900 border border-slate-800 rounded-2xl p-5 space-y-4 shadow-2xl"
            , stopPropagation
            ]
            [ div [ class "flex items-center justify-between gap-3" ]
                [ h2 [ class "text-lg font-semibold text-slate-100" ] [ text heading ]
                , button
                    [ onClick StravaPickerClose
                    , class "w-8 h-8 rounded-full bg-slate-950 text-slate-500 hover:text-rose-400 hover:bg-slate-950 flex items-center justify-center text-sm"
                    ]
                    [ text "✕" ]
                ]
            , body
            ]
        ]


stopPropagation : Html.Attribute Msg
stopPropagation =
    E.stopPropagationOn "click" (D.succeed ( ModalNoOp, True ))


viewStravaActivityRow : Language -> RaceId -> StravaApi.Activity -> Html Msg
viewStravaActivityRow language rid act =
    button
        [ onClick (StravaPickerSelect rid act.id)
        , class "w-full text-left px-4 py-3 rounded-lg bg-slate-950 hover:bg-slate-800 border border-slate-800 hover:border-rose-500/60 transition-colors"
        ]
        [ div [ class "flex items-baseline justify-between gap-3" ]
            [ p [ class "font-medium text-slate-100 truncate" ] [ text act.name ]
            , p [ class "text-xs text-slate-500 whitespace-nowrap tabular-nums" ]
                [ text (String.left 10 act.startDateLocal) ]
            ]
        , p [ class "text-xs text-slate-500 mt-1 tabular-nums" ]
            [ text
                (Format.number language 2 (act.distance / 1000)
                    ++ " km · "
                    ++ formatHhmm act.movingTime
                    ++ " · "
                    ++ act.sportType
                )
            ]
        ]


httpErrorString : Http.Error -> String
httpErrorString err =
    case err of
        Http.BadUrl u ->
            "Bad URL: " ++ u

        Http.Timeout ->
            "Request timed out."

        Http.NetworkError ->
            "Network error — is cadence running and reachable?"

        Http.BadStatus s ->
            if s == 401 then
                "Unauthorized — reconnect Strava in settings."

            else
                "Server returned status " ++ String.fromInt s ++ "."

        Http.BadBody msg ->
            "Couldn't parse the response: " ++ msg


viewPredictorStrip : Model -> Race -> List Km -> Html Msg
viewPredictorStrip model race kms =
    let
        i =
            case model.sliderDraft of
                Just draft ->
                    draft

                Nothing ->
                    currentIntensity model race kms

        prediction =
            Predictor.predict model.profile race kms i

        language =
            model.settings.language

        ( bandLabel, bandTone ) =
            intensityBand language i
    in
    if List.isEmpty kms then
        text ""

    else
        let
            ( confLabel, confTone, confMargin ) =
                confidenceFromProfile model race
        in
        div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4" ]
            [ div [ class "flex items-baseline justify-between gap-4 flex-wrap" ]
                [ div []
                    [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.effortLabel language) ]
                    , p [ class ("text-2xl font-semibold tabular-nums " ++ bandTone) ]
                        [ text bandLabel ]
                    , p [ class "text-xs text-slate-500 mt-0.5" ]
                        [ text (Translations.profileNav language ++ ": " ++ profileBriefLabel model.profile) ]
                    ]
                , div [ class "text-right" ]
                    [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.predictedFinish language) ]
                    , p [ class "text-2xl font-semibold text-slate-100 tabular-nums" ]
                        [ text (formatHhmm prediction.totalS) ]
                    , p [ class "text-xs text-slate-500 mt-0.5 tabular-nums" ]
                        [ text ("± " ++ formatHhmm (round (toFloat prediction.totalS * confMargin)))
                        , span [ class ("ml-2 " ++ confTone) ] [ text ("· " ++ confLabel) ]
                        ]
                    , p [ class "text-[10px] text-slate-600 mt-0.5" ]
                        [ text (predictionBreakdown language prediction) ]
                    ]
                ]
            , div [ class "space-y-2" ]
                [ input
                    [ A.type_ "range"
                    , A.min "0.80"
                    , A.max "1.25"
                    , A.attribute "step" "0.01"
                    , A.value (formatFloat 2 i)
                    , onInput SliderInput
                    , E.on "change" (D.map SliderCommit E.targetValue)
                    , class "w-full accent-rose-500"
                    ]
                    []
                , div [ class "flex items-center justify-between text-[10px] uppercase tracking-wider text-slate-500" ]
                    [ span [] [ text (Translations.effortConservative language) ]
                    , span [] [ text (Translations.effortGoal language) ]
                    , span [] [ text (Translations.effortPush language) ]
                    , span [] [ text (Translations.effortAllIn language) ]
                    ]
                ]
            , div [ class "text-xs text-slate-500" ]
                [ text
                    (case race.plan.targetSeconds of
                        Just _ ->
                            Translations.sliderHelp language

                        Nothing ->
                            Translations.sliderHelpNoTarget language
                    )
                ]
            ]


currentIntensity : Model -> Race -> List Km -> Float
currentIntensity model race kms =
    case race.plan.targetSeconds of
        Just t ->
            Predictor.solveForIntensity model.profile race kms t

        Nothing ->
            1.0


intensityBand : Language -> Float -> ( String, String )
intensityBand language i =
    let
        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es
    in
    if i < 0.83 then
        ( tr "Below conservative" "Por debajo de conservador", "text-slate-300" )

    else if i < 0.97 then
        ( tr "Conservative" "Conservador", "text-sky-400" )

    else if i < 1.03 then
        ( tr "Goal" "Objetivo", "text-emerald-400" )

    else if i < 1.12 then
        ( tr "Push" "Fuerte", "text-amber-400" )

    else if i <= 1.22 then
        ( tr "All-in" "Al máximo", "text-rose-400" )

    else
        ( tr "Beyond all-in" "Más allá del máximo", "text-rose-500" )


profileBriefLabel : Profile -> String
profileBriefLabel profile =
    formatInt profile.verticalRateVmh
        ++ " vm/h · "
        ++ formatMmss profile.flatTrailPaceSecPerKm
        ++ "/km"


{-| Confidence band for the predictor output. Until calibration
ships (TASK-022) the profile is always "hand-tuned" with no past-data
backing, so every race shows "Low (no past data) ± 20 %". When the
user starts linking actuals (TASK-016) we can tighten:

  - actuals on 1+ races for this distance band → Medium ± 10 %
  - actuals on 2+ races across a 2× distance range → Medium-High ± 7 %

The race itself carries the actualSplits we've already linked; the
"how many other races have actuals?" question would need the full
race list (not just `race`), so for now we go solely by "does this
race have actuals." Future TASK-022 will refine.

-}
confidenceFromProfile : Model -> Race -> ( String, String, Float )
confidenceFromProfile model race =
    let
        tr en es =
            case model.settings.language of
                English ->
                    en

                Spanish ->
                    es
    in
    case race.actualSplits of
        Just _ ->
            -- We've seen actuals on this exact race — narrow the band
            -- slightly since the planned vs actual data was used to
            -- calibrate against. Pending real TASK-022 calibration
            -- this is mostly aspirational.
            ( tr "Medium-low · 1 actual linked" "Media-baja · 1 actividad vinculada", "text-sky-400", 0.15 )

        Nothing ->
            ( tr "Low · profile from presets" "Baja · perfil desde valores predefinidos", "text-slate-400", 0.20 )


predictionBreakdown : Language -> Predictor.Prediction -> String
predictionBreakdown language p =
    let
        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es

        pieces =
            [ ( tr "climb" "subida", p.climbS )
            , ( tr "descent" "bajada", p.descentS )
            , ( tr "runnable" "corrible", p.runnableS )
            , ( tr "aid" "avit.", p.aidS )
            ]
                |> List.filter (\( _, s ) -> s > 0)
                |> List.map (\( name, s ) -> formatHhmm s ++ " " ++ name)
                |> String.join " · "
    in
    if String.isEmpty pieces then
        "—"

    else
        pieces


viewActualRunStrip : Model -> Race -> Html Msg
viewActualRunStrip model race =
    let
        language =
            model.settings.language

        errorBanner =
            case model.actualRunError of
                Just msg ->
                    -- `msg` is a dynamic parse error (English; see TASK-069).
                    p [ class "mt-2 text-sm text-rose-400" ]
                        [ text (Translations.actualParseError language ++ msg) ]

                Nothing ->
                    text ""

        stravaButton =
            case model.stravaToken of
                Just _ ->
                    button
                        [ onClick (OpenStravaPicker race.id)
                        , class "px-4 py-2 text-sm bg-orange-500 text-white rounded-md hover:bg-orange-400 font-medium whitespace-nowrap"
                        ]
                        [ text (Translations.linkFromStrava language) ]

                Nothing ->
                    text ""
    in
    case race.actualSplits of
        Nothing ->
            div []
                [ div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-4 flex items-center justify-between gap-4 flex-wrap" ]
                    [ div [ class "min-w-0" ]
                        [ p [ class "font-medium text-slate-100" ] [ text (Translations.linkActualRun language) ]
                        , p [ class "text-sm text-slate-400 mt-0.5" ]
                            [ text (Translations.linkActualRunHelp language) ]
                        , errorBanner
                        ]
                    , div [ class "flex items-center gap-2" ]
                        [ stravaButton
                        , button
                            [ onClick (OpenActualGpxPicker race.id)
                            , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-100 whitespace-nowrap"
                            ]
                            [ text (Translations.uploadGpx language) ]
                        ]
                    ]
                , viewStravaPickerModal model race.id
                ]

        Just actual ->
            div [ class "rounded-2xl bg-slate-900 border border-emerald-500/30 p-4 flex items-center justify-between gap-4 flex-wrap" ]
                [ div [ class "flex items-center gap-6 flex-wrap min-w-0" ]
                    [ div []
                        [ p [ class "text-[10px] uppercase tracking-wider text-emerald-400/80" ] [ text (Translations.actualRunLinked language) ]
                        , p [ class "text-2xl font-semibold text-slate-100 tabular-nums mt-0.5" ]
                            [ text (formatHhmm actual.totalSeconds) ]
                        ]
                    , div []
                        [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text (Translations.distanceRun language) ]
                        , p [ class "text-lg text-slate-200 tabular-nums mt-0.5" ]
                            [ text (Format.number language 2 (actual.totalDistance / 1000) ++ " km") ]
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
                                    ( "+" ++ formatMmss diff ++ Translations.vsTargetSuffix language, "text-rose-400" )

                                else if diff < 0 then
                                    ( "−" ++ formatMmss (abs diff) ++ Translations.vsTargetSuffix language, "text-emerald-400" )

                                else
                                    ( Translations.onTarget language, "text-emerald-400" )
                        in
                        div []
                            [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ] [ text (Translations.vsTarget language) ]
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
                        [ text (Translations.replace language) ]
                    , button
                        [ onClick (ClearActualRun race.id)
                        , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-400 hover:text-rose-400"
                        ]
                        [ text (Translations.unlink language) ]
                    , errorBanner
                    ]
                ]


viewPlanCrumb : Language -> Race -> Html Msg
viewPlanCrumb language race =
    div [ class "text-sm text-slate-400 flex items-center gap-2 print:hidden" ]
        [ a [ Route.href Route.Index, class "hover:text-slate-100" ] [ text (Translations.breadcrumbRaces language) ]
        , span [ class "text-slate-700" ] [ text "/" ]
        , a [ Route.href (Route.RaceDetail race.id), class "hover:text-slate-100" ] [ text race.name ]
        , span [ class "text-slate-700" ] [ text "/" ]
        , span [ class "text-slate-200" ] [ text "Plan" ]
        ]


viewPlanHeader : Language -> Race -> Html Msg
viewPlanHeader language race =
    div [ class "flex items-end justify-between gap-4 flex-wrap" ]
        [ div []
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ] [ text "Plan" ]
            , p [ class "mt-2 text-sm text-slate-500" ]
                [ text
                    (Format.number language 1 (race.distance / 1000)
                        ++ " km · "
                        ++ formatInt race.gain
                        ++ " m+ · "
                        ++ Translations.aidStationCount language (List.length race.aidStations)
                    )
                ]
            ]
        ]


viewPlanTargetPanel : Language -> Race -> Int -> Int -> String -> Html Msg
viewPlanTargetPanel language race aidRest currentSum targetText =
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
            [ p [ class "text-xs text-slate-500 uppercase tracking-wider mb-2" ] [ text (Translations.targetTime language) ]
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
            , p [ class "text-xs text-slate-500 mt-1" ] [ text (Translations.timeCommitHint language) ]
            ]
        , planStat (Translations.currentSumLabel language)
            (if currentSum == 0 then
                "—"

             else
                formatHhmm currentSum
            )
            (case target of
                Just _ ->
                    if diff == 0 then
                        Just ( Translations.onTarget language, "text-emerald-400" )

                    else if diff > 0 then
                        Just ( "+" ++ formatMmss diff ++ Translations.planOver language, "text-rose-400" )

                    else
                        Just ( formatMmss (abs diff) ++ Translations.planUnder language, "text-amber-400" )

                Nothing ->
                    Nothing
            )
        , planStat (Translations.aidRestLabel language)
            (formatHhmm aidRest)
            (Just
                ( Translations.stopsCount language (List.length race.aidStations)
                , "text-slate-500"
                )
            )
        , planStat (Translations.avgPace language)
            (case ( target, race.distance > 0 ) of
                ( Just t, True ) ->
                    paceMinPerKm (t - aidRest) race.distance

                _ ->
                    "—"
            )
            (Just ( Translations.paceMovingSuffix language, "text-slate-500" ))
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


viewPlanTabs : Language -> TableMode -> Html Msg
viewPlanTabs language mode =
    div [ class "flex items-center justify-between gap-3 flex-wrap print:hidden" ]
        [ div [ class "flex items-center gap-1 bg-slate-900 border border-slate-800 rounded-lg p-1" ]
            [ tabButton (Translations.byKm language) (mode == ByKm) (SetPlanTableMode ByKm)
            , tabButton (Translations.bySection language) (mode == BySection) (SetPlanTableMode BySection)
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
                [ text (Translations.downloadCsv language) ]
            , button
                [ onClick PrintPlan
                , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200 flex items-center gap-2"
                ]
                [ text (Translations.print language) ]
            , p [ class "text-xs text-slate-500" ]
                [ text (Translations.tapRowHint language) ]
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


viewKmTable : Language -> Race -> List Km -> Dict Int KmResult -> Html Msg
viewKmTable language race kms results =
    let
        aidByKm =
            race.aidStations
                |> List.map (\a -> ( Planning.kmAtDistance a.distance, a ))
                |> List.foldl (\( idx, a ) acc -> Dict.update idx (Just << (\v -> a :: Maybe.withDefault [] v)) acc) Dict.empty

        cumulativeRows =
            kmsWithCumulative language race aidByKm results kms

        hasActual =
            race.actualSplits /= Nothing

        hasHr =
            race.actualSplits |> Maybe.andThen .hrPerKm |> (/=) Nothing

        actualHeaders =
            if hasActual then
                [ Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colActual language) ]
                , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colDeltaVsPlan language) ]
                ]

            else
                []

        hrHeader =
            if hasHr then
                [ Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colAvgHr language) ] ]

            else
                []
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 overflow-x-auto" ]
        [ Html.table [ class "w-full text-sm" ]
            [ Html.thead [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ Html.tr []
                    ([ Html.th [ class "px-4 py-3 text-left" ] [ text (Translations.colKm language) ]
                     , Html.th [ class "px-4 py-3 text-left" ] [ text (Translations.colSpan language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colDeltaEle language) ]
                     , Html.th [ class "px-4 py-3 text-left" ] [ text (Translations.colGrade language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colPace language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colTime language) ]
                     ]
                        ++ actualHeaders
                        ++ hrHeader
                        ++ [ Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colCum language) ]
                           , Html.th [ class "px-4 py-3 text-left" ] [ text (Translations.colNotesStops language) ]
                           ]
                    )
                ]
            , Html.tbody [] cumulativeRows
            ]
        ]


kmsWithCumulative :
    Language
    -> Race
    -> Dict Int (List AidStation)
    -> Dict Int KmResult
    -> List Km
    -> List (Html Msg)
kmsWithCumulative language race aidByKm results kms =
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
            ( newRunning, viewKmRow language race km result stops notes newRunning :: acc )

        ( _, rows ) =
            List.foldl go ( 0, [] ) kms
    in
    List.reverse rows


viewKmRow : Language -> Race -> Km -> KmResult -> List AidStation -> String -> Int -> Html Msg
viewKmRow language race km result stops notes cumulative =
    let
        deltaEle =
            km.eleEnd - km.eleStart

        stopRest =
            List.foldl (\a acc -> acc + a.restSeconds) 0 stops

        kmClockTime =
            result.seconds + stopRest

        pace =
            paceMinPerKm result.seconds km.distance

        timeCell =
            div [ class "flex items-baseline justify-end gap-1 tabular-nums" ]
                [ span [ class "text-slate-100 font-medium" ] [ text (formatMmss kmClockTime) ]
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
                    (Format.number language 2 (km.distStart / 1000)
                        ++ " → "
                        ++ Format.number language 2 (km.distEnd / 1000)
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
                        gradeClass language km.slope
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
                                                s - kmClockTime

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

                        hrCells =
                            case actual.hrPerKm of
                                Just hrs ->
                                    [ Html.td [ class "px-4 py-3 align-top text-right tabular-nums" ]
                                        [ case Dict.get km.index hrs of
                                            Just bpm ->
                                                span [ class "text-rose-300" ] [ text (String.fromInt bpm) ]

                                            Nothing ->
                                                span [ class "text-slate-700" ] [ text "—" ]
                                        ]
                                    ]

                                Nothing ->
                                    []
                    in
                    [ actualCell, diffCell ] ++ hrCells

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
                                div []
                                    [ div [ class "text-amber-300" ]
                                        [ text ("★ " ++ a.name ++ " · " ++ formatRest language a.restSeconds) ]
                                    , if String.isEmpty a.notes then
                                        text ""

                                      else
                                        div [ class "text-slate-400 whitespace-pre-line" ] [ text a.notes ]
                                    ]
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


viewSectionTable : Language -> Race -> List Km -> Dict Int KmResult -> Html Msg
viewSectionTable language race kms results =
    let
        sections =
            Planning.sectionsForRace
                { totalDistance = race.distance
                , aidStations = race.aidStations
                , kms = kms
                }

        rows =
            sectionsWithCumulative language race results sections

        hasActual =
            race.actualSplits /= Nothing

        actualHeaders =
            if hasActual then
                [ Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colActual language) ]
                , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colDeltaVsPlan language) ]
                ]

            else
                []

        hasAidRest =
            Planning.aidRestTotal race.aidStations > 0
    in
    div [ class "rounded-2xl bg-slate-900 border border-slate-800 overflow-x-auto" ]
        [ Html.table [ class "w-full text-sm" ]
            [ Html.thead [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ Html.tr []
                    ([ Html.th [ class "px-4 py-3 text-left" ] [ text (Translations.colSection language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.statDistance language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.statGain language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.statLoss language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colPace language) ]
                     , Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colSectionTime language) ]
                     ]
                        ++ actualHeaders
                        ++ [ Html.th [ class "px-4 py-3 text-right" ] [ text (Translations.colCum language) ] ]
                    )
                ]
            , Html.tbody [] rows
            ]
        , if hasAidRest then
            p [ class "px-4 py-3 text-xs text-slate-500 border-t border-slate-800" ]
                [ text (Translations.sectionTimeNote language) ]

          else
            text ""
        ]


sectionsWithCumulative : Language -> Race -> Dict Int KmResult -> List Planning.Section -> List (Html Msg)
sectionsWithCumulative language race results sections =
    let
        hasActual =
            race.actualSplits /= Nothing

        emptyCell =
            Html.td [ class "px-4 py-2 text-right text-xs text-slate-500 tabular-nums" ] [ text "—" ]

        go section ( running, acc ) =
            let
                sectionMoving =
                    section.kmIndices
                        |> List.filterMap (\idx -> Dict.get idx results)
                        |> List.foldl (\r sum -> sum + r.seconds) 0

                sectionRest =
                    Planning.sectionAidRest race.aidStations section

                sectionClock =
                    sectionMoving + sectionRest

                newRunning =
                    running + sectionClock

                pace =
                    paceMinPerKm sectionMoving section.distance

                actualMaybe =
                    sectionActualSeconds race section.kmIndices

                actualCells =
                    if hasActual then
                        case actualMaybe of
                            Just s ->
                                [ Html.td [ class "px-4 py-3 text-right text-slate-200 tabular-nums" ]
                                    [ text (formatHmsLong s) ]
                                , Html.td [ class "px-4 py-3 text-right" ]
                                    [ viewSignedDeltaCell (s - sectionClock) ]
                                ]

                            Nothing ->
                                [ Html.td [ class "px-4 py-3 text-right text-slate-700 tabular-nums" ] [ text "—" ]
                                , Html.td [ class "px-4 py-3 text-right text-slate-700 tabular-nums" ] [ text "—" ]
                                ]

                    else
                        []

                sectionRow =
                    Html.tr
                        [ class "border-t border-slate-800 hover:bg-slate-950/60 transition-colors cursor-pointer"
                        , onClick (NavigateTo (Route.PlanSection race.id section.index))
                        , A.attribute "role" "link"
                        , A.attribute "tabindex" "0"
                        ]
                        ([ Html.td [ class "px-4 py-3 text-white font-medium" ] [ text section.label ]
                         , Html.td [ class "px-4 py-3 text-right text-slate-300 tabular-nums" ] [ text (Format.number language 2 (section.distance / 1000) ++ " km") ]
                         , Html.td [ class "px-4 py-3 text-right text-rose-300 tabular-nums" ] [ text (formatInt section.gain ++ " m+") ]
                         , Html.td [ class "px-4 py-3 text-right text-emerald-300 tabular-nums" ] [ text (formatInt section.loss ++ " m−") ]
                         , Html.td [ class "px-4 py-3 text-right text-slate-300 tabular-nums" ] [ text pace ]
                         , Html.td [ class "px-4 py-3 text-right text-white font-medium tabular-nums" ] [ text (formatHmsLong sectionClock) ]
                         ]
                            ++ actualCells
                            ++ [ Html.td [ class "px-4 py-3 text-right text-slate-300 tabular-nums" ] [ text (formatHmsLong newRunning) ] ]
                        )

                aidRow =
                    case section.followedByAid of
                        Just aid ->
                            -- A divider between sections, not a time row: this aid's
                            -- rest is already folded into the clock Time of whichever
                            -- section owns its km (Planning.sectionAidRest), so it is
                            -- shown here only as context and adds nothing to Cum.
                            Html.tr [ class "border-t border-slate-800 bg-slate-950/40" ]
                                ([ Html.td [ class "px-4 py-2 text-xs align-top" ]
                                    [ div [ class "text-amber-300" ]
                                        [ text ("★ " ++ aid.name)
                                        , if aid.restSeconds > 0 then
                                            span [ class "text-amber-300/60 font-normal" ]
                                                [ text ("  ·  " ++ Translations.restWord language ++ " " ++ formatHmsLong aid.restSeconds) ]

                                          else
                                            text ""
                                        ]
                                    , if String.isEmpty aid.notes then
                                        text ""

                                      else
                                        div [ class "text-slate-400 whitespace-pre-line mt-0.5" ] [ text aid.notes ]
                                    ]
                                 , emptyCell
                                 , emptyCell
                                 , emptyCell
                                 , emptyCell
                                 , emptyCell
                                 ]
                                    ++ (if hasActual then
                                            [ emptyCell, emptyCell ]

                                        else
                                            []
                                       )
                                    ++ [ emptyCell ]
                                )

                        Nothing ->
                            text ""
            in
            ( newRunning, aidRow :: sectionRow :: acc )

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
                { target = Just (effectiveTargetSeconds model.profile race kms)
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

        language =
            model.settings.language
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 px-6 space-y-6" ]
        [ viewPlanCrumb language race
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ h1 [ class "text-3xl font-bold tracking-tight text-white" ]
                [ text (Translations.sectionBreadcrumb language (secIndex + 1) (List.length sections)) ]
            , a [ Route.href (Route.PlanTable race.id), class "text-sm text-slate-400 hover:text-slate-100" ]
                [ text (Translations.backToTable language) ]
            ]
        , case section of
            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text (Translations.sectionNotExist language) ]

            Just s ->
                viewSectionCardAndDetails language race kms results s prevIndex nextIndex
        ]


viewSectionCardAndDetails :
    Language
    -> Race
    -> List Km
    -> Dict Int KmResult
    -> Planning.Section
    -> Maybe Int
    -> Maybe Int
    -> Html Msg
viewSectionCardAndDetails language race kms results section prevIndex nextIndex =
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
            [ viewSectionCard language section containedKms
            , div [ class "flex gap-3 justify-between" ]
                [ navLink (Translations.prevSection language) prevIndex
                , navLink (Translations.nextSection language) nextIndex
                ]
            ]
        , viewSectionDetails language race section containedKms results sectionSeconds sectionPace
        ]


viewSectionCard : Language -> Planning.Section -> List Km -> Html msg
viewSectionCard language section containedKms =
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
            case section.followedByAid of
                Just _ ->
                    34

                Nothing ->
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

        terminalAidMarker =
            case section.followedByAid of
                Just aid ->
                    [ viewSectionCardEndAid chartTopPad elevBaseline cardWidth (toX section.distEnd) aid ]

                Nothing ->
                    []

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
                    (Translations.sectionCardHeader language
                        (Format.number language 1 (section.distance / 1000))
                        (Format.number language 1 mPerPx)
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
                , Svg.g [] terminalAidMarker
                ]
            ]
        , div [ class "px-5 py-3 border-t border-slate-800 flex items-baseline justify-between text-xs text-slate-400 tabular-nums" ]
            [ span [] [ text (formatInt minEle ++ " m") ]
            , span [ class "text-amber-400" ] [ text ("⤒ " ++ formatInt maxEle ++ " m") ]
            , span [] [ text (formatInt maxEle ++ " m") ]
            ]
        ]


viewSectionCardEndAid : Float -> Float -> Float -> Float -> AidStation -> Svg.Svg msg
viewSectionCardEndAid yTop yBottom cardWidth x aid =
    let
        rawPillW =
            max 48 (toFloat (String.length aid.name) * 6 + 14)

        pillW =
            min (cardWidth - 8) rawPillW

        -- Aid sits at the right edge; pull the pill inward so it stays
        -- inside the card.
        pillX =
            (x - pillW / 2)
                |> max 4
                |> min (cardWidth - pillW - 4)

        pillTop =
            yTop - 22

        pillH =
            16
    in
    Svg.g []
        [ Svg.line
            [ SA.x1 (String.fromFloat x)
            , SA.x2 (String.fromFloat x)
            , SA.y1 (String.fromFloat (pillTop + pillH))
            , SA.y2 (String.fromFloat yBottom)
            , SA.stroke "#fbbf24"
            , SA.strokeWidth "1"
            , SA.strokeDasharray "2 2"
            , SA.opacity "0.7"
            ]
            []
        , Svg.rect
            [ SA.x (String.fromFloat pillX)
            , SA.y (String.fromFloat pillTop)
            , SA.width (String.fromFloat pillW)
            , SA.height (String.fromInt pillH)
            , SA.rx "8"
            , SA.fill "#fbbf24"
            , SA.opacity "0.95"
            ]
            []
        , Svg.text_
            [ SA.x (String.fromFloat (pillX + pillW / 2))
            , SA.y (String.fromFloat (pillTop + 11))
            , SA.textAnchor "middle"
            , SA.fontSize "10"
            , SA.fontWeight "600"
            , SA.fill "#0b0b21"
            , SA.fontFamily "system-ui, -apple-system, sans-serif"
            ]
            [ Svg.text aid.name ]
        , Svg.circle
            [ SA.cx (String.fromFloat x)
            , SA.cy (String.fromFloat yBottom)
            , SA.r "4"
            , SA.fill "#fbbf24"
            ]
            []
        ]


viewSectionDetails :
    Language
    -> Race
    -> Planning.Section
    -> List Km
    -> Dict Int KmResult
    -> Int
    -> String
    -> Html Msg
viewSectionDetails language race section containedKms results sectionSeconds sectionPace =
    let
        sectionRest =
            Planning.sectionAidRest race.aidStations section

        sectionClock =
            sectionSeconds + sectionRest

        actualRow =
            case sectionActualSeconds race section.kmIndices of
                Just actualS ->
                    div [ class "grid grid-cols-2 gap-3 tabular-nums" ]
                        [ smallStat (Translations.colActual language) (formatHmsLong actualS) ""
                        , div [ class "rounded-lg bg-slate-950/60 px-3 py-2" ]
                            [ p [ class "text-[10px] uppercase tracking-wider text-slate-500" ]
                                [ text (Translations.colDeltaVsPlan language) ]
                            , p [ class "flex items-baseline gap-1" ]
                                [ span [ class "text-base font-semibold" ]
                                    [ viewSignedDeltaCell (actualS - sectionClock) ]
                                ]
                            ]
                        ]

                Nothing ->
                    case race.actualSplits of
                        Just _ ->
                            p [ class "text-xs text-slate-500 italic" ]
                                [ text (Translations.sectionActualMissing language) ]

                        Nothing ->
                            text ""
    in
    div [ class "space-y-4" ]
        [ div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-4" ]
            [ h3 [ class "text-base font-semibold text-white" ] [ text (Translations.sectionPlan language) ]
            , div [ class "grid grid-cols-2 sm:grid-cols-4 gap-3 tabular-nums" ]
                [ smallStat (Translations.statDistance language) (Format.number language 1 (section.distance / 1000)) "km"
                , smallStat (Translations.colTime language) (formatHmsLong sectionClock) ""
                , smallStat (Translations.colPace language) sectionPace "/km"
                , smallStat (Translations.kmsLabel language)
                    (String.fromInt (List.length containedKms))
                    ""
                ]
            , if sectionRest > 0 then
                p [ class "text-xs text-amber-300/80" ]
                    [ text (Translations.sectionClockNote language (formatRest language sectionRest)) ]

              else
                text ""
            , actualRow
            , case section.followedByAid of
                Just aid ->
                    div [ class "rounded-xl bg-amber-400/5 border border-amber-400/30 p-4 space-y-2" ]
                        [ p [ class "text-xs uppercase tracking-wider text-amber-300" ]
                            [ text (Translations.endsAt language) ]
                        , div [ class "flex items-baseline justify-between gap-3 flex-wrap" ]
                            [ p [ class "text-lg font-semibold text-white" ] [ text aid.name ]
                            , p [ class "text-sm text-amber-200 tabular-nums" ]
                                [ text (Format.number language 1 (aid.distance / 1000) ++ " km · " ++ formatRest language aid.restSeconds) ]
                            ]
                        , if List.isEmpty aid.services then
                            text ""

                          else
                            p [ class "flex gap-2 text-lg" ]
                                (List.map
                                    (\s ->
                                        span [ A.title (Translations.serviceLabel language s) ]
                                            [ text (serviceIcon s) ]
                                    )
                                    aid.services
                                )
                        , if String.isEmpty aid.notes then
                            text ""

                          else
                            p [ class "text-sm text-slate-300 whitespace-pre-line" ] [ text aid.notes ]
                        , a
                            [ Route.href (Route.RaceDetail race.id)
                            , class "inline-block text-xs text-amber-300 hover:text-amber-200 underline"
                            ]
                            [ text (Translations.editAidStationLink language) ]
                        ]

                Nothing ->
                    div [ class "rounded-xl bg-slate-950 border border-slate-800 p-4 text-sm text-slate-400" ]
                        [ text (Translations.sectionFinishes language) ]
            ]
        , div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-5 space-y-3" ]
            [ h3 [ class "text-base font-semibold text-white" ] [ text (Translations.kmsInSection language) ]
            , div [ class "divide-y divide-slate-800" ]
                (List.map (viewSectionKmRow language race results) containedKms)
            ]
        ]


viewSectionKmRow : Language -> Race -> Dict Int KmResult -> Km -> Html Msg
viewSectionKmRow language race results km =
    let
        result =
            Dict.get km.index results
                |> Maybe.withDefault { seconds = 0, source = AutoComputed }

        deltaEle =
            km.eleEnd - km.eleStart

        stopRest =
            aidRestInKm race.aidStations km.index

        kmClockTime =
            result.seconds + stopRest

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
                    (Format.number language 2 (km.distStart / 1000)
                        ++ " → "
                        ++ Format.number language 2 (km.distEnd / 1000)
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
            [ span [ class "text-sm text-white font-medium" ] [ text (formatMmss kmClockTime) ]
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
                { target = Just (effectiveTargetSeconds model.profile race kms)
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

        language =
            model.settings.language
    in
    div [ class "max-w-screen-2xl mx-auto mt-8 px-6 space-y-6" ]
        [ viewPlanCrumb language race
        , div [ class "flex items-end justify-between gap-4 flex-wrap" ]
            [ h1 [ class "text-3xl font-bold tracking-tight text-slate-100" ]
                [ text (Translations.kmBreadcrumb language (kmIndex + 1) (List.length kms)) ]
            , a [ Route.href (Route.PlanTable race.id), class "text-sm text-slate-400 hover:text-slate-100" ]
                [ text (Translations.backToTable language) ]
            ]
        , case thisKm of
            Nothing ->
                div [ class "rounded-2xl bg-slate-900 border border-slate-800 p-10 text-center text-slate-500" ]
                    [ text (Translations.kmNotExist language) ]

            Just km ->
                viewKmCardAndForm model race km kms results aidRest prevIndex nextIndex
        ]


viewKmCardAndForm : Model -> Race -> Km -> List Km -> Dict Int KmResult -> Int -> Maybe Int -> Maybe Int -> Html Msg
viewKmCardAndForm model race km allKms results _ prevIndex nextIndex =
    let
        language =
            model.settings.language

        result =
            Dict.get km.index results |> Maybe.withDefault { seconds = 0, source = AutoComputed }

        kp =
            kmPlanFor km.index race.plan

        stopsInKm =
            race.aidStations
                |> List.filter (\a -> Planning.kmAtDistance a.distance == km.index)

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
            [ viewKmCard language km stopsInKm raceMaxRange
            , div [ class "flex gap-3 w-[360px] justify-between" ]
                [ navLink (Translations.prevKm language) prevIndex
                , navLink (Translations.nextKm language) nextIndex
                ]
            ]
        , viewKmForm model race km result kp stopsInKm
        ]


viewKmCard : Language -> Km -> List AidStation -> Float -> Html Msg
viewKmCard language km stopsInKm raceMaxRange =
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
            if List.isEmpty stopsInKm then
                14

            else
                34

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
            List.map (viewKmCardStop chartTopPad elevBaseline km.distStart cardWidth toX) stopsInKm

        deltaEle =
            km.eleEnd - km.eleStart
    in
    div
        [ class "relative bg-slate-900 border border-slate-800 rounded-2xl overflow-hidden flex flex-col"
        , A.style "width" (String.fromFloat cardWidth ++ "px")
        ]
        [ div [ class "px-5 pt-4 pb-3 border-b border-slate-800" ]
            [ p [ class "text-xs uppercase tracking-wider text-slate-500" ]
                [ text (Translations.kmCardHeader language (km.index + 1) (Format.number language 1 mPerPx)) ]
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


viewKmCardStop : Float -> Float -> Float -> Float -> (Float -> Float) -> AidStation -> Svg.Svg Msg
viewKmCardStop yTop yBottom kmStart cardWidth toX aid =
    let
        relative =
            aid.distance - kmStart

        x =
            toX relative

        -- Pill width grows with the label so short names get tight
        -- pills and longer ones don't truncate.
        rawPillW =
            max 48 (toFloat (String.length aid.name) * 6 + 14)

        -- Keep the pill inside the card bounds when the aid lands
        -- near the left or right edge.
        pillW =
            min (cardWidth - 8) rawPillW

        pillX =
            (x - pillW / 2)
                |> max 4
                |> min (cardWidth - pillW - 4)

        pillTop =
            yTop - 22

        pillH =
            16
    in
    Svg.g []
        [ Svg.line
            [ SA.x1 (String.fromFloat x)
            , SA.x2 (String.fromFloat x)
            , SA.y1 (String.fromFloat (pillTop + pillH))
            , SA.y2 (String.fromFloat yBottom)
            , SA.stroke "#fbbf24"
            , SA.strokeWidth "1"
            , SA.strokeDasharray "2 2"
            , SA.opacity "0.7"
            ]
            []
        , Svg.rect
            [ SA.x (String.fromFloat pillX)
            , SA.y (String.fromFloat pillTop)
            , SA.width (String.fromFloat pillW)
            , SA.height (String.fromInt pillH)
            , SA.rx "8"
            , SA.fill "#fbbf24"
            , SA.opacity "0.95"
            ]
            []
        , Svg.text_
            [ SA.x (String.fromFloat (pillX + pillW / 2))
            , SA.y (String.fromFloat (pillTop + 11))
            , SA.textAnchor "middle"
            , SA.fontSize "10"
            , SA.fontWeight "600"
            , SA.fill "#0b0b21"
            , SA.fontFamily "system-ui, -apple-system, sans-serif"
            ]
            [ Svg.text aid.name ]
        , Svg.circle
            [ SA.cx (String.fromFloat x)
            , SA.cy (String.fromFloat yBottom)
            , SA.r "4"
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
viewKmForm model race km result kp stopsInKm =
    let
        language =
            model.settings.language

        sourceBadge =
            case result.source of
                UserManual ->
                    span [ class "px-2 py-0.5 text-[10px] uppercase tracking-wider bg-amber-400/20 text-amber-300 rounded" ]
                        [ text (Translations.modeManual language) ]

                AutoComputed ->
                    span [ class "px-2 py-0.5 text-[10px] uppercase tracking-wider bg-slate-800 text-slate-400 rounded" ]
                        [ text (Translations.modeAuto language) ]

        stopRestInKm =
            List.foldl (\a acc -> acc + a.restSeconds) 0 stopsInKm

        kmClockTime =
            result.seconds + stopRestInKm

        pace =
            paceMinPerKm result.seconds km.distance

        kmActualSeconds =
            race.actualSplits
                |> Maybe.andThen (\a -> Dict.get km.index a.splits)

        kmAvgHr =
            race.actualSplits
                |> Maybe.andThen .hrPerKm
                |> Maybe.andThen (Dict.get km.index)
    in
    div [ class "space-y-5 rounded-2xl bg-slate-900 border border-slate-800 p-5" ]
        [ div [ class "flex items-baseline justify-between gap-2" ]
            [ h3 [ class "text-base font-semibold text-slate-100" ] [ text (Translations.planThisKm language) ]
            , sourceBadge
            ]
        , div [ class "grid grid-cols-3 gap-3 tabular-nums" ]
            [ smallStat (Translations.statDistance language) (Format.number language 2 (km.distance / 1000)) "km"
            , smallStat (Translations.colDeltaEle language) (formatInt (km.eleEnd - km.eleStart)) "m"
            , smallStat (Translations.slopeLabel language) (Format.number language 1 (km.slope * 100)) "%"
            ]
        , div [ class "grid grid-cols-2 gap-3" ]
            [ field (Translations.targetTime language)
                [ input
                    [ A.type_ "text"
                    , A.value model.kmTimeText
                    , A.placeholder
                        (if result.seconds > 0 then
                            formatMmss kmClockTime ++ Translations.autoSuffix language

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
                [ span [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.colPace language) ]
                , div [ class "px-3 py-2 bg-slate-950 border border-slate-800 rounded-md text-lg font-medium text-slate-100 tabular-nums" ]
                    [ text (pace ++ "/km") ]
                ]
            ]
        , if stopRestInKm > 0 then
            p [ class "text-xs text-amber-300/80 -mt-3" ]
                [ text (Translations.kmClockNote language (formatRest language stopRestInKm)) ]

          else
            text ""
        , case ( race.actualSplits, kmActualSeconds ) of
            ( Just actualSplits, Just actualS ) ->
                let
                    hasHrData =
                        actualSplits.hrPerKm /= Nothing

                    hrCell =
                        if hasHrData then
                            [ div [ class "space-y-1" ]
                                [ span [ class "text-xs text-rose-400/80 uppercase tracking-wider" ] [ text (Translations.colAvgHr language) ]
                                , div [ class "px-3 py-2 bg-slate-950 border border-rose-500/30 rounded-md text-lg font-medium text-slate-100 tabular-nums" ]
                                    (case kmAvgHr of
                                        Just bpm ->
                                            [ span [] [ text (String.fromInt bpm) ]
                                            , span [ class "text-xs text-slate-500 ml-1" ] [ text "bpm" ]
                                            ]

                                        Nothing ->
                                            [ span [ class "text-slate-700" ] [ text "—" ] ]
                                    )
                                ]
                            ]

                        else
                            []

                    gridClass =
                        if hasHrData then
                            "grid grid-cols-3 gap-3"

                        else
                            "grid grid-cols-2 gap-3"
                in
                div [ class gridClass ]
                    ([ div [ class "space-y-1" ]
                        [ span [ class "text-xs text-emerald-400/80 uppercase tracking-wider" ] [ text (Translations.colActual language) ]
                        , div [ class "px-3 py-2 bg-slate-950 border border-emerald-500/30 rounded-md text-lg font-medium text-slate-100 tabular-nums" ]
                            [ text (formatMmss actualS) ]
                        ]
                     , div [ class "space-y-1" ]
                        [ span [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.colDeltaVsPlan language) ]
                        , div [ class "px-3 py-2 bg-slate-950 border border-slate-800 rounded-md text-lg font-medium" ]
                            [ viewSignedDeltaCell (actualS - kmClockTime) ]
                        ]
                     ]
                        ++ hrCell
                    )

            ( Just _, Nothing ) ->
                p [ class "text-xs text-slate-500 italic" ]
                    [ text (Translations.kmActualMissing language) ]

            ( Nothing, _ ) ->
                text ""
        , case kp.time of
            Manual _ ->
                button
                    [ onClick (ResetKmToAuto km.index)
                    , class "text-xs text-slate-400 hover:text-slate-100 underline"
                    ]
                    [ text (Translations.resetToAuto language) ]

            Auto ->
                p [ class "text-xs text-slate-500" ]
                    [ text (Translations.resetToAutoHelp language) ]
        , field (Translations.fieldNotes language)
            [ textarea
                [ A.value model.kmNotesText
                , A.placeholder (Translations.kmNotesPlaceholder language)
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
                [ p [ class "text-xs text-slate-500 uppercase tracking-wider" ] [ text (Translations.aidStationsInKm language) ]
                , div [ class "space-y-1" ]
                    (List.map
                        (\a ->
                            div [ class "text-sm" ]
                                [ div [ class "text-amber-300" ]
                                    [ text ("★ " ++ a.name ++ " · " ++ Format.number language 2 (a.distance / 1000) ++ " km · " ++ formatRest language a.restSeconds) ]
                                , if String.isEmpty a.notes then
                                    text ""

                                  else
                                    div [ class "text-slate-400 whitespace-pre-line" ] [ text a.notes ]
                                ]
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


-- ============================================================
-- CHANGE-HISTORY FEED / DRAWER (WI-4 / TASK-051)
-- ============================================================


{-| Right-aligned "Activity" button on the race-page header row, mirroring the
"← Back to races" link styling, with a count once there are entries.
-}
viewHistoryButton : Language -> Race -> Html Msg
viewHistoryButton language race =
    let
        count =
            List.length race.history
    in
    button
        [ onClick OpenHistory
        , class "inline-flex items-center gap-2 text-sm text-slate-400 hover:text-slate-100"
        ]
        [ span [ class "text-base leading-none" ] [ text "📍" ]
        , text (Translations.activityLabel language)
        , if count > 0 then
            span
                [ class "inline-flex items-center justify-center min-w-[1.25rem] h-5 px-1.5 rounded-full bg-rose-500/20 text-rose-300 text-xs font-semibold" ]
                [ text (String.fromInt count) ]

          else
            text ""
        ]


{-| Right slide-over drawer holding the activity feed for the current race.
-}
viewHistoryDrawer : Model -> Html Msg
viewHistoryDrawer model =
    if not model.historyOpen then
        text ""

    else
        case currentRace model of
            Nothing ->
                text ""

            Just race ->
                div [ class "fixed inset-0 z-50 flex justify-end" ]
                    [ div
                        [ class "absolute inset-0 bg-slate-950/70 backdrop-blur-sm"
                        , onClick CloseHistory
                        ]
                        []
                    , div [ class "relative w-full max-w-md bg-slate-900 border-l border-slate-800 shadow-2xl flex flex-col trail-drawer-in" ]
                        [ div [ class "flex items-start justify-between px-6 py-4 border-b border-slate-800" ]
                            [ div []
                                [ h2 [ class "text-lg font-semibold text-slate-100" ] [ text (Translations.activityLabel model.settings.language) ]
                                , p [ class "text-xs text-slate-500 mt-0.5" ] [ text (Translations.activitySubtitle model.settings.language) ]
                                ]
                            , button
                                [ onClick CloseHistory
                                , class "text-slate-500 hover:text-slate-100 text-2xl leading-none -mt-1"
                                ]
                                [ text "×" ]
                            ]
                        , div [ class "flex-1 overflow-y-auto px-6 py-5" ]
                            [ viewHistoryFeed model.settings.language model.now model.deviceId model.me model.directory race.history ]
                        ]
                    ]


viewHistoryFeed : Language -> Int -> String -> Maybe Identity.Me -> Identity.Directory -> List ChangeEntry -> Html Msg
viewHistoryFeed language now deviceId me directory history =
    if List.isEmpty history then
        div [ class "text-center py-12" ]
            [ p [ class "text-4xl mb-3 opacity-60" ] [ text "🗺" ]
            , p [ class "text-sm text-slate-500" ] [ text (Translations.noChangesYet language) ]
            ]

    else
        let
            entries =
                List.reverse history

            total =
                List.length entries
        in
        div [] (List.indexedMap (viewHistoryEntry language now deviceId me directory total) entries)


viewHistoryEntry : Language -> Int -> String -> Maybe Identity.Me -> Identity.Directory -> Int -> Int -> ChangeEntry -> Html Msg
viewHistoryEntry language now deviceId me directory total i entry =
    let
        isLast =
            i == total - 1

        ( badgeIcon, badgeTone ) =
            entryBadge entry
    in
    div [ class "relative flex gap-4 pb-6" ]
        [ if isLast then
            text ""

          else
            div [ class "absolute left-4 top-9 -bottom-1 w-px bg-slate-800" ] []
        , div
            [ class ("relative z-10 flex size-8 shrink-0 items-center justify-center rounded-full ring-4 ring-slate-900 " ++ badgeTone) ]
            [ span [ class "text-sm leading-none" ] [ text badgeIcon ] ]
        , div [ class "min-w-0 flex-1" ]
            [ div [ class "flex items-baseline justify-between gap-2" ]
                [ span [ class "text-sm font-medium text-slate-200" ] [ text (authorLabel language deviceId me directory entry) ]
                , span [ class "text-xs text-slate-500 whitespace-nowrap" ] [ text (relativeTime language now entry.timestampMs) ]
                ]
            , div [ class "mt-1.5 space-y-1" ] (List.map (viewChangeRow language) entry.changes)
            ]
        ]


viewChangeRow : Language -> ChangeDescriptor -> Html Msg
viewChangeRow language d =
    let
        info =
            describeChange language d
    in
    div [ class "flex items-start gap-2 text-sm text-slate-400" ]
        [ span [ class ("shrink-0 leading-5 " ++ info.tone) ] [ text info.icon ]
        , span [ class "leading-5" ] [ text info.phrase ]
        ]


{-| The badge icon + tint for an entry, by its nature (a course upload, a merge,
or an ordinary local edit).
-}
entryBadge : ChangeEntry -> ( String, String )
entryBadge entry =
    if List.any isCourseUploaded entry.changes then
        ( "🗺", "bg-emerald-500/20" )

    else if entry.source == "merge" then
        ( "🔀", "bg-sky-500/20" )

    else
        ( "✏️", "bg-rose-500/20" )


isCourseUploaded : ChangeDescriptor -> Bool
isCourseUploaded d =
    case d of
        CourseUploaded ->
            True

        _ ->
            False


{-| Per-type icon, phrasing and tint for one change — the feed's per-type visual
treatment (spec §5).
-}
describeChange : Language -> ChangeDescriptor -> { icon : String, phrase : String, tone : String }
describeChange language d =
    let
        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es

        -- "km N" (km is language-neutral).
        km1 km =
            "km " ++ String.fromInt (km + 1)
    in
    case d of
        AidAdded r ->
            { icon = "⛑", phrase = tr ("Added aid “" ++ r.name ++ "”") ("Avituallamiento agregado: “" ++ r.name ++ "”"), tone = "text-emerald-300" }

        AidRemoved r ->
            { icon = "✕", phrase = tr ("Removed aid “" ++ r.name ++ "”") ("Avituallamiento quitado: “" ++ r.name ++ "”"), tone = "text-rose-300" }

        AidMoved r ->
            { icon = "📍", phrase = tr ("Moved “" ++ r.name ++ "” to " ++ km1 r.toKm) ("“" ++ r.name ++ "” movido a " ++ km1 r.toKm), tone = "text-amber-300" }

        AidRenamed r ->
            { icon = "🏷", phrase = tr ("Renamed aid to “" ++ r.to ++ "”") ("Avituallamiento renombrado a “" ++ r.to ++ "”"), tone = "text-slate-300" }

        AidRetimed r ->
            { icon = "⏱", phrase = "“" ++ r.name ++ "” " ++ tr "rest → " "descanso → " ++ formatRestShort r.toRest, tone = "text-sky-300" }

        KmNoteAdded r ->
            { icon = "📝", phrase = tr ("Note added on " ++ km1 r.km) ("Nota agregada en " ++ km1 r.km), tone = "text-emerald-300" }

        KmNoteEdited r ->
            { icon = "📝", phrase = tr ("Note edited on " ++ km1 r.km) ("Nota editada en " ++ km1 r.km), tone = "text-slate-300" }

        KmNoteCleared r ->
            { icon = "📝", phrase = tr ("Note cleared on " ++ km1 r.km) ("Nota borrada en " ++ km1 r.km), tone = "text-rose-300" }

        KmPaceSet r ->
            { icon = "⏱", phrase = tr ("Pace set on " ++ km1 r.km) ("Ritmo fijado en " ++ km1 r.km), tone = "text-sky-300" }

        KmPaceChanged r ->
            { icon = "⏱", phrase = tr ("Pace changed on " ++ km1 r.km) ("Ritmo cambiado en " ++ km1 r.km), tone = "text-amber-300" }

        KmPaceCleared r ->
            { icon = "⏱", phrase = tr ("Pace cleared on " ++ km1 r.km) ("Ritmo borrado en " ++ km1 r.km), tone = "text-rose-300" }

        RaceRenamed r ->
            { icon = "🏷", phrase = tr ("Renamed race to “" ++ r.to ++ "”") ("Carrera renombrada a “" ++ r.to ++ "”"), tone = "text-slate-300" }

        RaceDateChanged r ->
            { icon = "📅", phrase = tr "Race date " "Fecha de carrera " ++ (r.to |> Maybe.map (\t -> "→ " ++ t) |> Maybe.withDefault (tr "cleared" "borrada")), tone = "text-slate-300" }

        CourseUploaded ->
            { icon = "🗺", phrase = tr "Course uploaded" "Recorrido subido", tone = "text-emerald-300" }

        Merged r ->
            { icon = "🔀"
            , phrase =
                String.fromInt r.count
                    ++ (case language of
                            English ->
                                Translations.plural r.count { one = " change merged from ", other = " changes merged from " }

                            Spanish ->
                                Translations.plural r.count { one = " cambio combinado de ", other = " cambios combinados de " }
                       )
                    ++ r.fromAuthor
            , tone = "text-sky-300"
            }


formatRestShort : Int -> String
formatRestShort secs =
    if secs == 0 then
        "0"

    else if modBy 60 secs == 0 then
        String.fromInt (secs // 60) ++ "m"

    else
        String.fromInt secs ++ "s"


{-| The feed's *person* label for an entry's author (WI-5 / TASK-054). Prefers
the person-level `authorId` resolved through the directory — "You" when it's my
id, otherwise the person's name. Falls back to the device comparison for
pre-WI-5 entries (no `authorId`), which are almost always this device's own.
This is what retires the old hardcoded seat-relative "Coach" label.
-}
authorLabel : Language -> String -> Maybe Identity.Me -> Identity.Directory -> ChangeEntry -> String
authorLabel language deviceId me directory entry =
    if entry.authorId /= "" then
        case me of
            Just m ->
                if entry.authorId == m.userId then
                    Translations.you language

                else
                    Identity.resolveName directory entry.authorId

            Nothing ->
                Identity.resolveName directory entry.authorId

    else if entry.author == deviceId then
        Translations.you language

    else
        -- A pre-WI-5 entry from another device: `author` is a deviceId, which the
        -- userId-keyed directory can't resolve, and there's no person id to go on.
        Translations.someone language


{-| A coarse "Nd/Nh/Nm ago" from two epoch-ms timestamps.
-}
relativeTime : Language -> Int -> Int -> String
relativeTime language now ms =
    let
        secs =
            (now - ms) // 1000
    in
    if secs < 60 then
        Translations.relativeJustNow language

    else if secs < 3600 then
        Translations.relativeAgo language (String.fromInt (secs // 60) ++ "m")

    else if secs < 86400 then
        Translations.relativeAgo language (String.fromInt (secs // 3600) ++ "h")

    else
        Translations.relativeAgo language (String.fromInt (secs // 86400) ++ "d")


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


{-| The WI-5 identity prompts (TASK-054): the name prompt (mint), the
yourself/someone-else ownership choice on import, and the Q-I1 link action. One
at a time — driven by `model.identityFlow`.
-}
viewIdentityModals : Model -> Html Msg
viewIdentityModals model =
    case model.identityFlow of
        FlowIdle ->
            text ""

        FlowName after ->
            let
                ( subtitle, confirmLabel ) =
                    case after of
                        ThenExport _ ->
                            ( "Your plans and changes are labelled with this name when you share them. You can rename yourself any time on the Profile page."
                            , "Save & export"
                            )

                        ThenImportReviewer _ ->
                            ( "So your suggestions on this plan are attributed to you."
                            , "Save & import"
                            )

                disabled =
                    String.trim model.nameDraft == ""
            in
            identityModalShell "What's your name?"
                [ p [ class "text-sm text-slate-400" ] [ text subtitle ]
                , input
                    [ A.type_ "text"
                    , A.value model.nameDraft
                    , A.placeholder "e.g. Alex"
                    , A.autofocus True
                    , onInput NameDraftInput
                    , class "w-full bg-slate-950 border border-slate-700 rounded-md px-3 py-2 text-slate-100 placeholder:text-slate-600 focus:outline-none focus:ring-2 focus:ring-rose-500/50"
                    ]
                    []
                , div [ class "flex justify-end gap-2" ]
                    [ identitySecondaryButton NamePromptCancel "Cancel"
                    , identityPrimaryButton NamePromptConfirm confirmLabel disabled
                    ]
                ]

        FlowOwnership pending ->
            identityModalShell "Whose plan is this?"
                [ p [ class "text-sm text-slate-400" ]
                    [ text "“"
                    , span [ class "text-slate-200" ] [ text pending.draft.name ]
                    , text ("” was shared by " ++ pending.ownerName ++ ".")
                    ]
                , button
                    [ onClick (OwnershipChoose Identity.Myself)
                    , class "w-full text-left px-4 py-3 rounded-lg bg-slate-950 hover:bg-slate-800 border border-slate-800 hover:border-rose-500/60 transition-colors"
                    ]
                    [ p [ class "font-medium text-slate-100" ] [ text ("I'm " ++ pending.ownerName) ]
                    , p [ class "text-xs text-slate-500 mt-0.5" ] [ text "Claim it as yours — this device is recognized as the same person." ]
                    ]
                , button
                    [ onClick (OwnershipChoose Identity.SomeoneElse)
                    , class "w-full text-left px-4 py-3 rounded-lg bg-slate-950 hover:bg-slate-800 border border-slate-800 hover:border-rose-500/60 transition-colors"
                    ]
                    [ p [ class "font-medium text-slate-100" ] [ text "Someone else's plan" ]
                    , p [ class "text-xs text-slate-500 mt-0.5" ] [ text ("Import it as " ++ pending.ownerName ++ "'s — you're reviewing.") ]
                    ]
                , div [ class "flex justify-end" ]
                    [ identitySecondaryButton OwnershipCancel "Cancel" ]
                ]

        FlowLink pending ->
            let
                myName =
                    model.me |> Maybe.map .displayName |> Maybe.withDefault "someone"
            in
            identityModalShell "Link this device?"
                [ p [ class "text-sm text-slate-400" ]
                    [ text ("This device is already " ++ myName ++ ". Link it to ")
                    , span [ class "text-slate-200" ] [ text pending.ownerName ]
                    , text " so they're recognized as the same person?"
                    ]
                , p [ class "text-xs text-slate-500" ]
                    [ text ("Your plans on this device move to " ++ pending.ownerName ++ "'s identity. Use this when you've imported your own plan from another device.") ]
                , div [ class "flex justify-end gap-2" ]
                    [ identitySecondaryButton LinkCancel "Not now"
                    , identityPrimaryButton LinkConfirm "Link" False
                    ]
                ]


identityModalShell : String -> List (Html Msg) -> Html Msg
identityModalShell heading body =
    div [ class "fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center px-4" ]
        [ div [ class "max-w-sm w-full bg-slate-900 border border-slate-800 rounded-2xl p-6 space-y-4" ]
            (h2 [ class "text-lg font-semibold text-slate-100" ] [ text heading ] :: body)
        ]


identityPrimaryButton : Msg -> String -> Bool -> Html Msg
identityPrimaryButton msg label isDisabled =
    button
        [ onClick msg
        , A.disabled isDisabled
        , class
            ("px-4 py-2 text-sm rounded-md text-white "
                ++ (if isDisabled then
                        "bg-slate-700 cursor-not-allowed opacity-60"

                    else
                        "bg-rose-600 hover:bg-rose-500"
                   )
            )
        ]
        [ text label ]


identitySecondaryButton : Msg -> String -> Html Msg
identitySecondaryButton msg label =
    button
        [ onClick msg
        , class "px-4 py-2 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
        ]
        [ text label ]



-- MERGE REVIEW MODAL (WI-3 part 2 / TASK-056 / ADR-0013)


{-| The suggestion-review modal: only the true-collision residue, person-named,
no red/green; two equal options per card (or a hand-merge textarea for a
same-km-note overlap), forced choice, Apply enabled only once all are resolved.
"Keep my version" / close reject the whole import (confirm only if picks exist).
-}
viewMergeReview : Model -> Html Msg
viewMergeReview model =
    case model.mergeReview of
        Nothing ->
            text ""

        Just review ->
            let
                name =
                    suggesterName model.me
                        (Identity.mergeDirectory review.filePeople model.directory)
                        review.incoming

                n =
                    List.length review.conflicts

                chosen =
                    Dict.size review.choices
            in
            div [ class "fixed inset-0 z-50 bg-slate-950/80 backdrop-blur-sm flex items-center justify-center px-4 py-8" ]
                [ div [ class "max-w-lg w-full max-h-full bg-slate-900 border border-slate-800 rounded-2xl shadow-2xl flex flex-col" ]
                    [ div [ class "flex items-start justify-between gap-3 px-6 py-4 border-b border-slate-800" ]
                        [ div [ class "min-w-0" ]
                            [ h2 [ class "text-lg font-semibold text-slate-100" ] [ text (name ++ "’s suggestions") ]
                            , p [ class "text-xs text-slate-500 mt-0.5" ]
                                [ text
                                    (String.fromInt n
                                        ++ (if n == 1 then
                                                " change overlaps"

                                            else
                                                " changes overlap"
                                           )
                                        ++ " with edits you made"
                                    )
                                ]
                            ]
                        , button
                            [ onClick MergeKeepMine
                            , class "shrink-0 text-slate-500 hover:text-slate-100 text-2xl leading-none -mt-1"
                            ]
                            [ text "×" ]
                        ]
                    , if review.autoMergedCount > 0 then
                        div [ class "px-6 pt-3" ]
                            [ p [ class "flex items-start gap-2 text-xs text-emerald-300/90 bg-emerald-500/10 rounded-lg px-3 py-2" ]
                                [ span [ class "shrink-0" ] [ text "✓" ]
                                , text
                                    (String.fromInt review.autoMergedCount
                                        ++ (if review.autoMergedCount == 1 then
                                                " other change from "

                                            else
                                                " other changes from "
                                           )
                                        ++ name
                                        ++ (if review.autoMergedCount == 1 then
                                                " was added automatically."

                                            else
                                                " were added automatically."
                                           )
                                    )
                                ]
                            ]

                      else
                        text ""
                    , div [ class "flex-1 overflow-y-auto px-6 py-4 space-y-3" ]
                        (List.indexedMap (viewConflictCard name review) review.conflicts)
                    , viewMergeFooter review chosen n
                    ]
                ]


viewConflictCard : String -> MergeReview -> Int -> Merge.Conflict -> Html Msg
viewConflictCard name review i conflict =
    let
        choice =
            Dict.get i review.choices
    in
    div [ class "rounded-xl border border-slate-800 bg-slate-950/50 p-3 space-y-2" ]
        [ p [ class "text-xs font-medium text-slate-400" ] [ text conflict.label ]
        , if isProseConflict conflict.key then
            viewNoteMerge name i conflict choice

          else
            div [ class "grid grid-cols-1 sm:grid-cols-2 gap-2" ]
                [ mergeOption (MergePickMine i) "You" "text-sky-300" conflict.mine (choice == Just ChooseMine)
                , mergeOption (MergePickTheirs i) name "text-amber-300" conflict.theirs (choice == Just ChooseTheirs)
                ]
        ]


{-| Prose fields get the hand-merge textarea (Q-U3) rather than a binary pick:
race notes, a per-km note, or an aid station's notes. -}
isProseConflict : Merge.ConflictKey -> Bool
isProseConflict key =
    case key of
        Merge.KNotes ->
            True

        Merge.KKmNote _ ->
            True

        Merge.KAid _ Merge.AidNotes ->
            True

        _ ->
            False


{-| One tappable option on a binary card — identity-tinted (no red/green),
selected by a ring + check (TASK-056 / ADR-0013). -}
mergeOption : Msg -> String -> String -> String -> Bool -> Html Msg
mergeOption msg who tone val selected =
    button
        [ onClick msg
        , class
            ("text-left rounded-lg border px-3 py-2 transition-colors "
                ++ (if selected then
                        "border-rose-500 ring-2 ring-rose-500/50 bg-slate-900"

                    else
                        "border-slate-800 bg-slate-900/40 hover:border-slate-600"
                   )
            )
        ]
        [ div [ class "flex items-center justify-between gap-2" ]
            [ span [ class ("text-xs font-semibold " ++ tone) ] [ text who ]
            , if selected then
                span [ class "text-rose-400 text-xs" ] [ text "✓" ]

              else
                text ""
            ]
        , p [ class "text-sm text-slate-200 mt-1 break-words" ] [ text (mergeValueOrDash val) ]
        ]


{-| A same-km-note overlap (Q-U3): both versions shown for reference, plus an
editable textarea pre-filled with the two combined to splice. -}
viewNoteMerge : String -> Int -> Merge.Conflict -> Maybe MergeChoice -> Html Msg
viewNoteMerge name i conflict choice =
    let
        current =
            case choice of
                Just (ChooseCustom t) ->
                    t

                _ ->
                    combineNotes conflict.mine conflict.theirs
    in
    div [ class "space-y-2" ]
        [ div [ class "grid grid-cols-2 gap-2" ]
            [ div []
                [ p [ class "text-xs font-semibold text-sky-300" ] [ text "You" ]
                , p [ class "text-xs text-slate-500 break-words" ] [ text (mergeValueOrDash conflict.mine) ]
                ]
            , div []
                [ p [ class "text-xs font-semibold text-amber-300" ] [ text name ]
                , p [ class "text-xs text-slate-500 break-words" ] [ text (mergeValueOrDash conflict.theirs) ]
                ]
            ]
        , textarea
            [ A.value current
            , A.rows 3
            , onInput (MergeEditNote i)
            , class "w-full bg-slate-950 border border-slate-700 rounded-md px-3 py-2 text-sm text-slate-100 focus:outline-none focus:ring-2 focus:ring-rose-500/50"
            ]
            []
        , p [ class "text-[11px] text-slate-500" ] [ text "Edit to combine both notes." ]
        ]


mergeValueOrDash : String -> String
mergeValueOrDash v =
    if v == "" then
        "—"

    else
        v


viewMergeFooter : MergeReview -> Int -> Int -> Html Msg
viewMergeFooter review chosen n =
    div [ class "px-6 py-4 border-t border-slate-800" ]
        (if review.confirmingDiscard then
            [ p [ class "text-sm text-slate-300 mb-3" ] [ text "Discard your choices and keep your own version?" ]
            , div [ class "flex justify-end gap-2" ]
                [ identitySecondaryButton MergeCancelDiscard "Keep editing"
                , identityPrimaryButton MergeConfirmDiscard "Discard" False
                ]
            ]

         else
            [ div [ class "flex items-center justify-between gap-3" ]
                [ p [ class "text-xs text-slate-500 tabular-nums" ]
                    [ text (String.fromInt chosen ++ " of " ++ String.fromInt n ++ " chosen") ]
                , div [ class "flex gap-2" ]
                    [ identitySecondaryButton MergeKeepMine "Keep my version"
                    , identityPrimaryButton MergeApply "Apply changes" (chosen < n)
                    ]
                ]
            ]
        )


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


{-| Sum the actual seconds for the kms in a section. Returns
`Nothing` when the race has no linked actuals OR when at least one
contained km has no split — both surfaced as "—" in the UI so
partial coverage doesn't quietly produce a wrong sum.
-}
sectionActualSeconds : Race -> List Int -> Maybe Int
sectionActualSeconds race kmIndices =
    case race.actualSplits of
        Nothing ->
            Nothing

        Just actual ->
            let
                pairs =
                    List.map (\idx -> Dict.get idx actual.splits) kmIndices
            in
            if List.any ((==) Nothing) pairs then
                Nothing

            else
                Just (List.sum (List.filterMap identity pairs))


{-| Render a signed +mm:ss / −mm:ss / on-target label with the
matching rose/emerald/slate tone. Used in both km and section
contexts.
-}
viewSignedDeltaCell : Int -> Html msg
viewSignedDeltaCell diff =
    let
        ( tone, prefix, mag ) =
            if diff > 0 then
                ( "text-rose-300", "+", diff )

            else if diff < 0 then
                ( "text-emerald-300", "−", -diff )

            else
                ( "text-slate-400", "", 0 )
    in
    span [ class ("tabular-nums " ++ tone) ]
        [ text (prefix ++ formatMmss mag) ]


formatRest : Language -> Int -> String
formatRest language seconds =
    let
        tr en es =
            case language of
                English ->
                    en

                Spanish ->
                    es
    in
    if seconds <= 0 then
        tr "no rest" "sin descanso"

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
            String.fromInt minutes ++ tr " min rest" " min descanso"

        else
            String.fromInt minutes ++ ":" ++ String.padLeft 2 '0' (String.fromInt remainder) ++ tr " rest" " descanso"



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


{-| The target finish time we hand to `Planning.distribute`. Falls
back to `Predictor.predict` at intensity = 1.0 when the user hasn't
committed a target yet, so the per-km Pace / Time columns populate
from a sane default rather than showing blank until the slider is
moved. Display-only — `race.plan.targetSeconds` stays `Nothing`
until the user explicitly commits via the slider or input field.
-}
effectiveTargetSeconds : Profile -> Race -> List Km -> Int
effectiveTargetSeconds profile race kms =
    case race.plan.targetSeconds of
        Just s ->
            s

        Nothing ->
            if List.isEmpty kms then
                0

            else
                .totalS (Predictor.predict profile race kms 1.0)


{-| Total aid-station rest scheduled inside a given km index.
Used to convert between *moving* time (what `Planning.distribute`
allocates) and *clock* time (what shows up in km splits on the
watch). A km that contains an aid carries its rest in clock time
but not in moving time.
-}
aidRestInKm : List AidStation -> Int -> Int
aidRestInKm aids kmIndex =
    aids
        |> List.filter (\a -> Planning.kmAtDistance a.distance == kmIndex)
        |> List.foldl (\a acc -> acc + a.restSeconds) 0


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
