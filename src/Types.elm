module Types exposing
    ( ActualSplits
    , AidStation
    , KmPlan
    , KmTime(..)
    , Plan
    , Race
    , RaceId
    , Service(..)
    , allServices
    , decodeRace
    , decodeRaces
    , defaultPlan
    , emptyKmPlan
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
