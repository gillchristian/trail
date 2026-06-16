module Types exposing
    ( ActualSplits
    , AidStation
    , ChangeDescriptor(..)
    , ChangeEntry
    , KmPlan
    , KmTime(..)
    , Plan
    , Race
    , RaceId
    , Service(..)
    , allServices
    , changeEntryDecoder
    , decodeRace
    , decodeRaces
    , defaultPlan
    , emptyKmPlan
    , encodeChangeEntry
    , encodeRace
    , encodeRaceMeta
    , kmPlanFor
    , planFromValue
    , planToValue
    , raceIdFromString
    , raceIdToString
    , serviceIcon
    , serviceLabel
    , serviceToString
    , sortAidStations
    , withKmPlan
    , withTargetSeconds
    )

{-| Types module — primary records carried across the app.

The data types and JSON codecs live here. The math (slope factors,
GAP distribution, km windowing) lives in `Planning.elm` and imports
from here.

`RaceId` is wrapped so the compiler stops us from passing a name or
a URL where a race id is expected. `AidStation` is embedded on
`Race`; ids are issued by a per-race sequence counter — stable
across re-imports, no uuid library needed.

-}

import Dict exposing (Dict)
import Json.Decode as D exposing (Decoder)
import Json.Encode as E exposing (Value)



-- RACE ID


type RaceId
    = RaceId String


raceIdFromString : String -> RaceId
raceIdFromString =
    RaceId


raceIdToString : RaceId -> String
raceIdToString (RaceId s) =
    s



-- SERVICE


type Service
    = Water
    | Food
    | WarmFood
    | Medical
    | WC
    | DropBag
    | Crew


allServices : List Service
allServices =
    [ Water, Food, WarmFood, Medical, WC, DropBag, Crew ]


serviceToString : Service -> String
serviceToString s =
    case s of
        Water ->
            "water"

        Food ->
            "food"

        WarmFood ->
            "warm_food"

        Medical ->
            "medical"

        WC ->
            "wc"

        DropBag ->
            "drop_bag"

        Crew ->
            "crew"


serviceFromString : String -> Maybe Service
serviceFromString s =
    case s of
        "water" ->
            Just Water

        "food" ->
            Just Food

        "warm_food" ->
            Just WarmFood

        "medical" ->
            Just Medical

        "wc" ->
            Just WC

        "drop_bag" ->
            Just DropBag

        "crew" ->
            Just Crew

        _ ->
            Nothing


serviceLabel : Service -> String
serviceLabel s =
    case s of
        Water ->
            "Water"

        Food ->
            "Food"

        WarmFood ->
            "Warm food"

        Medical ->
            "Medical"

        WC ->
            "WC"

        DropBag ->
            "Drop bag"

        Crew ->
            "Crew access"


serviceIcon : Service -> String
serviceIcon s =
    case s of
        Water ->
            "💧"

        Food ->
            "🍌"

        WarmFood ->
            "🍲"

        Medical ->
            "⛑"

        WC ->
            "🚻"

        DropBag ->
            "🎒"

        Crew ->
            "🤝"



-- AID STATION


type alias AidStation =
    { id : String
    , name : String
    , distance : Float -- meters from start
    , restSeconds : Int -- planned rest at the station
    , services : List Service
    , notes : String
    , cutoff : Maybe Int -- cutoff as elapsed seconds from start; Nothing = no cutoff
    }


sortAidStations : List AidStation -> List AidStation
sortAidStations =
    List.sortBy .distance



-- RACE


{-| `shareId` and `courseHash` are the `.trail`-sharing identity (TASK-047 /
ADR-0010, the coach-collaboration arc).

`shareId` is a *stable* lineage id, distinct from `id`: `id` is the local IDB
key and is regenerated on every import (so the same file can be imported twice
as two rows), whereas `shareId` is minted once and **preserved across the
export/import round-trip** — it's what lets a coach's returned file be matched
back to the race it came from. `courseHash` fingerprints the course the plan was
built on (see `TrailSync.courseHash`), so an imported plan can be refused when it
was built on a different course.

Both default to `""` for v1 `.trail` files and pre-existing IDB races; the import
path mints/computes them on the way in (`shareId` JS-side like `id`, `courseHash`
from the GPX). They ride in `raceMetaFields`, so they round-trip through both the
full and the light (meta) save paths.

`owner` (WI-5 / ADR-0012) is the race's person-level `userId` — distinct from the
device-level `deviceId` and from the document-level `shareId`. It follows the same
pattern: defaults to `""` for pre-identity races / v1 files, rides in
`raceMetaFields`, and is stamped once a device identity exists (the flows slice of
TASK-054; cf. how `shareId`/`courseHash` were backfilled in TASK-053).

-}
type alias Race =
    { id : RaceId
    , name : String
    , date : Maybe String
    , location : String
    , url : String
    , notes : String
    , coverImage : Maybe String
    , distance : Float
    , gain : Float
    , loss : Float
    , gpxText : String
    , createdAt : Int
    , aidStations : List AidStation
    , aidStationSeq : Int
    , plan : Plan
    , actualSplits : Maybe ActualSplits
    , shareId : String
    , courseHash : String
    , owner : String
    , history : List ChangeEntry
    }


{-| Per-km actual times after the user uploads a completed run's GPX.
`splits` keys match `Planning.Km.index` (0-based); values are seconds.
`totalDistance` is the actual track distance (may differ from
`Race.distance` if the user ran off-route or DNF'd). `uploadedAt` is
ms since epoch.
-}
type alias ActualSplits =
    { splits : Dict Int Int
    , totalSeconds : Int
    , totalDistance : Float
    , uploadedAt : Int
    , hrPerKm : Maybe (Dict Int Int)
    }



-- PLAN


type alias Plan =
    { targetSeconds : Maybe Int
    , kmPlans : Dict Int KmPlan
    }


type alias KmPlan =
    { time : KmTime
    , notes : String
    }


type KmTime
    = Auto
    | Manual Int -- seconds


defaultPlan : Plan
defaultPlan =
    { targetSeconds = Nothing, kmPlans = Dict.empty }


emptyKmPlan : KmPlan
emptyKmPlan =
    { time = Auto, notes = "" }


kmPlanFor : Int -> Plan -> KmPlan
kmPlanFor index plan =
    Dict.get index plan.kmPlans |> Maybe.withDefault emptyKmPlan


withKmPlan : Int -> KmPlan -> Plan -> Plan
withKmPlan index kp plan =
    if kp.time == Auto && String.isEmpty kp.notes then
        { plan | kmPlans = Dict.remove index plan.kmPlans }

    else
        { plan | kmPlans = Dict.insert index kp plan.kmPlans }


withTargetSeconds : Maybe Int -> Plan -> Plan
withTargetSeconds t plan =
    { plan | targetSeconds = t }



-- CHANGE HISTORY (WI-4 / TASK-051)
--
-- The typed change-history data lives here (with the rest of the Race codecs)
-- so `Race` can carry it without an import cycle; the diff/union *logic* is in
-- `Changelog`, which imports these. Derived + cosmetic (ADR-0009): never
-- replayed to reconstruct state.


type ChangeDescriptor
    = AidAdded { id : String, name : String }
    | AidRemoved { id : String, name : String }
    | AidMoved { id : String, name : String, fromKm : Int, toKm : Int }
    | AidRenamed { id : String, from : String, to : String }
    | AidRetimed { id : String, name : String, fromRest : Int, toRest : Int }
    | KmNoteAdded { km : Int }
    | KmNoteEdited { km : Int }
    | KmNoteCleared { km : Int }
    | KmPaceSet { km : Int, seconds : Int }
    | KmPaceChanged { km : Int, from : Int, to : Int }
    | KmPaceCleared { km : Int }
    | RaceRenamed { from : String, to : String }
    | RaceDateChanged { from : Maybe String, to : Maybe String }
    | CourseUploaded
    | Merged { fromAuthor : String, count : Int }


{-| One logical change-set (a local edit or a merge). `source` is
"local" | "merge" | "import". Immutable; keyed by `entryId` for conflict-free union.
-}
type alias ChangeEntry =
    { entryId : String
    , author : String
    , timestampMs : Int
    , source : String
    , changes : List ChangeDescriptor
    }


encodeChangeEntry : ChangeEntry -> Value
encodeChangeEntry e =
    E.object
        [ ( "entryId", E.string e.entryId )
        , ( "author", E.string e.author )
        , ( "timestampMs", E.int e.timestampMs )
        , ( "source", E.string e.source )
        , ( "changes", E.list encodeDescriptor e.changes )
        ]


changeEntryDecoder : Decoder ChangeEntry
changeEntryDecoder =
    D.map5 ChangeEntry
        (D.field "entryId" D.string)
        (D.field "author" D.string)
        (D.field "timestampMs" D.int)
        (D.oneOf [ D.field "source" D.string, D.succeed "local" ])
        (D.field "changes" (D.list descriptorDecoder))


encodeDescriptor : ChangeDescriptor -> Value
encodeDescriptor d =
    let
        tagged kind fields =
            E.object (( "kind", E.string kind ) :: fields)

        maybeStr m =
            Maybe.map E.string m |> Maybe.withDefault E.null
    in
    case d of
        AidAdded r ->
            tagged "aidAdded" [ ( "id", E.string r.id ), ( "name", E.string r.name ) ]

        AidRemoved r ->
            tagged "aidRemoved" [ ( "id", E.string r.id ), ( "name", E.string r.name ) ]

        AidMoved r ->
            tagged "aidMoved" [ ( "id", E.string r.id ), ( "name", E.string r.name ), ( "fromKm", E.int r.fromKm ), ( "toKm", E.int r.toKm ) ]

        AidRenamed r ->
            tagged "aidRenamed" [ ( "id", E.string r.id ), ( "from", E.string r.from ), ( "to", E.string r.to ) ]

        AidRetimed r ->
            tagged "aidRetimed" [ ( "id", E.string r.id ), ( "name", E.string r.name ), ( "fromRest", E.int r.fromRest ), ( "toRest", E.int r.toRest ) ]

        KmNoteAdded r ->
            tagged "kmNoteAdded" [ ( "km", E.int r.km ) ]

        KmNoteEdited r ->
            tagged "kmNoteEdited" [ ( "km", E.int r.km ) ]

        KmNoteCleared r ->
            tagged "kmNoteCleared" [ ( "km", E.int r.km ) ]

        KmPaceSet r ->
            tagged "kmPaceSet" [ ( "km", E.int r.km ), ( "seconds", E.int r.seconds ) ]

        KmPaceChanged r ->
            tagged "kmPaceChanged" [ ( "km", E.int r.km ), ( "from", E.int r.from ), ( "to", E.int r.to ) ]

        KmPaceCleared r ->
            tagged "kmPaceCleared" [ ( "km", E.int r.km ) ]

        RaceRenamed r ->
            tagged "raceRenamed" [ ( "from", E.string r.from ), ( "to", E.string r.to ) ]

        RaceDateChanged r ->
            tagged "raceDateChanged" [ ( "from", maybeStr r.from ), ( "to", maybeStr r.to ) ]

        CourseUploaded ->
            tagged "courseUploaded" []

        Merged r ->
            tagged "merged" [ ( "fromAuthor", E.string r.fromAuthor ), ( "count", E.int r.count ) ]


descriptorDecoder : Decoder ChangeDescriptor
descriptorDecoder =
    D.field "kind" D.string
        |> D.andThen
            (\kind ->
                case kind of
                    "aidAdded" ->
                        D.map2 (\id name -> AidAdded { id = id, name = name }) (D.field "id" D.string) (D.field "name" D.string)

                    "aidRemoved" ->
                        D.map2 (\id name -> AidRemoved { id = id, name = name }) (D.field "id" D.string) (D.field "name" D.string)

                    "aidMoved" ->
                        D.map4 (\id name f t -> AidMoved { id = id, name = name, fromKm = f, toKm = t }) (D.field "id" D.string) (D.field "name" D.string) (D.field "fromKm" D.int) (D.field "toKm" D.int)

                    "aidRenamed" ->
                        D.map3 (\id f t -> AidRenamed { id = id, from = f, to = t }) (D.field "id" D.string) (D.field "from" D.string) (D.field "to" D.string)

                    "aidRetimed" ->
                        D.map4 (\id name f t -> AidRetimed { id = id, name = name, fromRest = f, toRest = t }) (D.field "id" D.string) (D.field "name" D.string) (D.field "fromRest" D.int) (D.field "toRest" D.int)

                    "kmNoteAdded" ->
                        D.map (\km -> KmNoteAdded { km = km }) (D.field "km" D.int)

                    "kmNoteEdited" ->
                        D.map (\km -> KmNoteEdited { km = km }) (D.field "km" D.int)

                    "kmNoteCleared" ->
                        D.map (\km -> KmNoteCleared { km = km }) (D.field "km" D.int)

                    "kmPaceSet" ->
                        D.map2 (\km s -> KmPaceSet { km = km, seconds = s }) (D.field "km" D.int) (D.field "seconds" D.int)

                    "kmPaceChanged" ->
                        D.map3 (\km f t -> KmPaceChanged { km = km, from = f, to = t }) (D.field "km" D.int) (D.field "from" D.int) (D.field "to" D.int)

                    "kmPaceCleared" ->
                        D.map (\km -> KmPaceCleared { km = km }) (D.field "km" D.int)

                    "raceRenamed" ->
                        D.map2 (\f t -> RaceRenamed { from = f, to = t }) (D.field "from" D.string) (D.field "to" D.string)

                    "raceDateChanged" ->
                        D.map2 (\f t -> RaceDateChanged { from = f, to = t }) (D.field "from" (D.nullable D.string)) (D.field "to" (D.nullable D.string))

                    "courseUploaded" ->
                        D.succeed CourseUploaded

                    "merged" ->
                        D.map2 (\fa c -> Merged { fromAuthor = fa, count = c }) (D.field "fromAuthor" D.string) (D.field "count" D.int)

                    other ->
                        D.fail ("Unknown change kind: " ++ other)
            )



-- ENCODE / DECODE


{-| The race fields **except** `gpxText`. `encodeRace` appends the (large)
GPX; `encodeRaceMeta` does not — used for plan/aid/metadata saves that must
not re-ship the ~3 MB string across the port (it lives in its own IDB store;
see ADR-0005 / TASK-040). Sharing this list keeps the two encoders in sync.
-}
raceMetaFields : Race -> List ( String, Value )
raceMetaFields r =
    [ ( "id", E.string (raceIdToString r.id) )
    , ( "name", E.string r.name )
    , ( "date", maybeString r.date )
    , ( "location", E.string r.location )
    , ( "url", E.string r.url )
    , ( "notes", E.string r.notes )
    , ( "coverImage", maybeString r.coverImage )
    , ( "distance", E.float r.distance )
    , ( "gain", E.float r.gain )
    , ( "loss", E.float r.loss )
    , ( "createdAt", E.int r.createdAt )
    , ( "aidStations", E.list encodeAidStation r.aidStations )
    , ( "aidStationSeq", E.int r.aidStationSeq )
    , ( "plan", planToValue r.plan )
    , ( "actualSplits"
      , case r.actualSplits of
            Just a ->
                encodeActualSplits a

            Nothing ->
                E.null
      )
    , ( "shareId", E.string r.shareId )
    , ( "courseHash", E.string r.courseHash )
    , ( "owner", E.string r.owner )
    , ( "history", E.list encodeChangeEntry r.history )
    ]


encodeRace : Race -> Value
encodeRace r =
    E.object (raceMetaFields r ++ [ ( "gpxText", E.string r.gpxText ) ])


{-| Race JSON without `gpxText`. The persistence layer stores GPX in a
separate IDB row (written once at import), so plan/aid/metadata edits save
only this — see ADR-0005.
-}
encodeRaceMeta : Race -> Value
encodeRaceMeta r =
    E.object (raceMetaFields r)


encodeActualSplits : ActualSplits -> Value
encodeActualSplits a =
    E.object
        [ ( "splits"
          , a.splits
                |> Dict.toList
                |> E.list
                    (\( idx, secs ) ->
                        E.object
                            [ ( "index", E.int idx )
                            , ( "seconds", E.int secs )
                            ]
                    )
          )
        , ( "totalSeconds", E.int a.totalSeconds )
        , ( "totalDistance", E.float a.totalDistance )
        , ( "uploadedAt", E.int a.uploadedAt )
        , ( "hrPerKm"
          , case a.hrPerKm of
                Just hrs ->
                    hrs
                        |> Dict.toList
                        |> E.list
                            (\( idx, bpm ) ->
                                E.object
                                    [ ( "index", E.int idx )
                                    , ( "bpm", E.int bpm )
                                    ]
                            )

                Nothing ->
                    E.null
          )
        ]


decodeActualSplits : Decoder ActualSplits
decodeActualSplits =
    D.map5 ActualSplits
        (D.field "splits"
            (D.list
                (D.map2 Tuple.pair
                    (D.field "index" D.int)
                    (D.field "seconds" D.int)
                )
            )
            |> D.map Dict.fromList
        )
        (D.field "totalSeconds" D.int)
        (D.field "totalDistance" D.float)
        (D.field "uploadedAt" D.int)
        (D.oneOf
            [ D.field "hrPerKm"
                (D.nullable
                    (D.list
                        (D.map2 Tuple.pair
                            (D.field "index" D.int)
                            (D.field "bpm" D.int)
                        )
                        |> D.map Dict.fromList
                    )
                )
            , D.succeed Nothing
            ]
        )


planToValue : Plan -> Value
planToValue plan =
    E.object
        [ ( "targetSeconds"
          , case plan.targetSeconds of
                Just t ->
                    E.int t

                Nothing ->
                    E.null
          )
        , ( "kmPlans"
          , plan.kmPlans
                |> Dict.toList
                |> E.list
                    (\( idx, kp ) ->
                        E.object
                            [ ( "index", E.int idx )
                            , ( "time", encodeKmTime kp.time )
                            , ( "notes", E.string kp.notes )
                            ]
                    )
          )
        ]


encodeKmTime : KmTime -> Value
encodeKmTime t =
    case t of
        Auto ->
            E.object [ ( "kind", E.string "auto" ) ]

        Manual s ->
            E.object [ ( "kind", E.string "manual" ), ( "seconds", E.int s ) ]


planFromValue : Decoder Plan
planFromValue =
    D.map2 Plan
        (D.field "targetSeconds" (D.nullable D.int))
        (D.field "kmPlans" (D.list kmPlanEntryDecoder)
            |> D.map Dict.fromList
        )


kmPlanEntryDecoder : Decoder ( Int, KmPlan )
kmPlanEntryDecoder =
    D.map3
        (\index time notes ->
            ( index, { time = time, notes = notes } )
        )
        (D.field "index" D.int)
        (D.field "time" kmTimeDecoder)
        (D.field "notes" D.string)


kmTimeDecoder : Decoder KmTime
kmTimeDecoder =
    D.field "kind" D.string
        |> D.andThen
            (\kind ->
                case kind of
                    "auto" ->
                        D.succeed Auto

                    "manual" ->
                        D.field "seconds" D.int |> D.map Manual

                    other ->
                        D.fail ("Unknown km-time kind: " ++ other)
            )


encodeAidStation : AidStation -> Value
encodeAidStation a =
    E.object
        [ ( "id", E.string a.id )
        , ( "name", E.string a.name )
        , ( "distance", E.float a.distance )
        , ( "restSeconds", E.int a.restSeconds )
        , ( "services", E.list (serviceToString >> E.string) a.services )
        , ( "notes", E.string a.notes )
        , ( "cutoff", maybeInt a.cutoff )
        ]


maybeString : Maybe String -> Value
maybeString =
    Maybe.map E.string >> Maybe.withDefault E.null


maybeInt : Maybe Int -> Value
maybeInt =
    Maybe.map E.int >> Maybe.withDefault E.null


decodeRace : Decoder Race
decodeRace =
    -- Overlay the `.trail`-sharing identity + owner onto the core race,
    -- defaulting each to "" / [] for v1 files / pre-existing IDB races
    -- (TASK-047 / ADR-0010; owner: TASK-054 / ADR-0012).
    D.map5
        (\race shareId courseHash owner history ->
            { race | shareId = shareId, courseHash = courseHash, owner = owner, history = history }
        )
        raceCoreDecoder
        (D.oneOf [ D.field "shareId" D.string, D.succeed "" ])
        (D.oneOf [ D.field "courseHash" D.string, D.succeed "" ])
        (D.oneOf [ D.field "owner" D.string, D.succeed "" ])
        (D.oneOf [ D.field "history" (D.list changeEntryDecoder), D.succeed [] ])


raceCoreDecoder : Decoder Race
raceCoreDecoder =
    let
        coreDecoder =
            D.map8 coreBuilder
                (D.field "id" D.string |> D.map RaceId)
                (D.field "name" D.string)
                (D.field "date" (D.nullable D.string))
                (D.field "location" D.string)
                (D.field "url" D.string)
                (D.field "notes" D.string)
                (D.field "coverImage" (D.nullable D.string))
                (D.field "distance" D.float)
    in
    coreDecoder
        |> D.andThen
            (\partial ->
                D.map8 partial
                    (D.field "gain" D.float)
                    (D.field "loss" D.float)
                    -- gpxText is stored in its own IDB row (ADR-0005). JS
                    -- re-attaches it on load; a light-save echo omits it, and
                    -- RaceSaved then refills it from the in-model race.
                    (D.oneOf [ D.field "gpxText" D.string, D.succeed "" ])
                    (D.field "createdAt" D.int)
                    (D.oneOf
                        [ D.field "aidStations" (D.list decodeAidStation)
                        , D.succeed []
                        ]
                    )
                    (D.oneOf
                        [ D.field "aidStationSeq" D.int
                        , D.succeed 0
                        ]
                    )
                    (D.oneOf
                        [ D.field "plan" planFromValue
                        , D.succeed defaultPlan
                        ]
                    )
                    (D.oneOf
                        [ D.field "actualSplits" (D.nullable decodeActualSplits)
                        , D.succeed Nothing
                        ]
                    )
            )


coreBuilder :
    RaceId
    -> String
    -> Maybe String
    -> String
    -> String
    -> String
    -> Maybe String
    -> Float
    -> (Float -> Float -> String -> Int -> List AidStation -> Int -> Plan -> Maybe ActualSplits -> Race)
coreBuilder id name date location url notes cover dist =
    \gain loss gpx ts aids seq plan actual ->
        -- shareId / courseHash / owner are overlaid by `decodeRace` (with
        -- back-compat defaults); placeholders here keep this a complete `Race`.
        { id = id
        , name = name
        , date = date
        , location = location
        , url = url
        , notes = notes
        , coverImage = cover
        , distance = dist
        , gain = gain
        , loss = loss
        , gpxText = gpx
        , createdAt = ts
        , aidStations = aids
        , aidStationSeq = seq
        , plan = plan
        , actualSplits = actual
        , shareId = ""
        , courseHash = ""
        , owner = ""
        , history = []
        }


decodeAidStation : Decoder AidStation
decodeAidStation =
    D.map7
        (\id name distance rest services notes cutoff ->
            { id = id
            , name = name
            , distance = distance
            , restSeconds = rest
            , services = services
            , notes = notes
            , cutoff = cutoff
            }
        )
        (D.field "id" D.string)
        (D.field "name" D.string)
        (D.field "distance" D.float)
        (D.oneOf [ D.field "restSeconds" D.int, D.succeed 120 ])
        (D.oneOf
            [ D.field "services" (D.list serviceDecoder)
            , D.succeed []
            ]
        )
        (D.oneOf [ D.field "notes" D.string, D.succeed "" ])
        (D.oneOf [ D.field "cutoff" (D.nullable D.int), D.succeed Nothing ])


serviceDecoder : Decoder Service
serviceDecoder =
    D.string
        |> D.andThen
            (\s ->
                case serviceFromString s of
                    Just v ->
                        D.succeed v

                    Nothing ->
                        D.fail ("Unknown service: " ++ s)
            )


decodeRaces : Decoder (List Race)
decodeRaces =
    D.list decodeRace
