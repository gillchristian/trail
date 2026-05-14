module Types exposing
    ( AidStation
    , Race
    , RaceId
    , Service(..)
    , allServices
    , decodeRace
    , decodeRaces
    , encodeRace
    , raceIdFromString
    , raceIdToString
    , serviceIcon
    , serviceLabel
    , serviceToString
    , sortAidStations
    )

{-| Shared types. A `Race` carries everything we need to render the
index card, jump into the detail page, and (later) export Coros-ready
GPX without going back to the original file: we keep the raw GPX text
on the record.

`RaceId` is wrapped so the compiler stops us from passing a name or
a URL where a race id is expected.

`AidStation` is embedded on `Race`. Ids are issued by a per-race
sequence counter — stable across re-imports, no collisions, no
external uuid library needed.

-}

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
    | Medical
    | WC
    | DropBag


allServices : List Service
allServices =
    [ Water, Food, Medical, WC, DropBag ]


serviceToString : Service -> String
serviceToString s =
    case s of
        Water ->
            "water"

        Food ->
            "food"

        Medical ->
            "medical"

        WC ->
            "wc"

        DropBag ->
            "drop_bag"


serviceFromString : String -> Maybe Service
serviceFromString s =
    case s of
        "water" ->
            Just Water

        "food" ->
            Just Food

        "medical" ->
            Just Medical

        "wc" ->
            Just WC

        "drop_bag" ->
            Just DropBag

        _ ->
            Nothing


serviceLabel : Service -> String
serviceLabel s =
    case s of
        Water ->
            "Water"

        Food ->
            "Food"

        Medical ->
            "Medical"

        WC ->
            "WC"

        DropBag ->
            "Drop bag"


serviceIcon : Service -> String
serviceIcon s =
    case s of
        Water ->
            "💧"

        Food ->
            "🍌"

        Medical ->
            "⛑"

        WC ->
            "🚻"

        DropBag ->
            "🎒"



-- AID STATION


type alias AidStation =
    { id : String
    , name : String
    , distance : Float -- meters from start
    , restSeconds : Int -- planned rest at the station
    , services : List Service
    , notes : String
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
    }



-- ENCODE / DECODE


encodeRace : Race -> Value
encodeRace r =
    E.object
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
        , ( "gpxText", E.string r.gpxText )
        , ( "createdAt", E.int r.createdAt )
        , ( "aidStations", E.list encodeAidStation r.aidStations )
        , ( "aidStationSeq", E.int r.aidStationSeq )
        ]


encodeAidStation : AidStation -> Value
encodeAidStation a =
    E.object
        [ ( "id", E.string a.id )
        , ( "name", E.string a.name )
        , ( "distance", E.float a.distance )
        , ( "restSeconds", E.int a.restSeconds )
        , ( "services", E.list (serviceToString >> E.string) a.services )
        , ( "notes", E.string a.notes )
        ]


maybeString : Maybe String -> Value
maybeString =
    Maybe.map E.string >> Maybe.withDefault E.null


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
                D.map6 partial
                    (D.field "gain" D.float)
                    (D.field "loss" D.float)
                    (D.field "gpxText" D.string)
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
    -> (Float -> Float -> String -> Int -> List AidStation -> Int -> Race)
coreBuilder id name date location url notes cover dist =
    \gain loss gpx ts aids seq ->
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
        }


decodeAidStation : Decoder AidStation
decodeAidStation =
    D.map6
        (\id name distance rest services notes ->
            { id = id
            , name = name
            , distance = distance
            , restSeconds = rest
            , services = services
            , notes = notes
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
