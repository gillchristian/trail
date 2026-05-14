module Types exposing
    ( Race
    , RaceId
    , decodeRace
    , decodeRaces
    , encodeRace
    , raceIdFromString
    , raceIdToString
    , unwrapRaceId
    )

{-| Shared types. A `Race` carries everything we need to render the
index card, jump into the detail page, and (later) export Coros-ready
GPX without going back to the original file: we keep the raw GPX text
on the record.

`RaceId` is wrapped so the compiler stops us from passing a name or
a URL where a race id is expected.

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


unwrapRaceId : RaceId -> String
unwrapRaceId =
    raceIdToString



-- RACE


type alias Race =
    { id : RaceId
    , name : String
    , date : Maybe String -- ISO 8601, e.g. "2026-05-23"
    , location : String
    , url : String
    , notes : String
    , coverImage : Maybe String -- data URL
    , distance : Float -- meters
    , gain : Float
    , loss : Float
    , gpxText : String -- raw GPX, retained for re-export
    , createdAt : Int -- millis since epoch
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
        ]


maybeString : Maybe String -> Value
maybeString =
    Maybe.map E.string >> Maybe.withDefault E.null


decodeRace : Decoder Race
decodeRace =
    D.map8 build
        (D.field "id" D.string |> D.map RaceId)
        (D.field "name" D.string)
        (D.field "date" (D.nullable D.string))
        (D.field "location" D.string)
        (D.field "url" D.string)
        (D.field "notes" D.string)
        (D.field "coverImage" (D.nullable D.string))
        (D.field "distance" D.float)
        |> D.andThen
            (\f ->
                D.map4 (\gain loss gpx ts -> f gain loss gpx ts)
                    (D.field "gain" D.float)
                    (D.field "loss" D.float)
                    (D.field "gpxText" D.string)
                    (D.field "createdAt" D.int)
            )


build :
    RaceId
    -> String
    -> Maybe String
    -> String
    -> String
    -> String
    -> Maybe String
    -> Float
    -> (Float -> Float -> String -> Int -> Race)
build id name date location url notes cover dist =
    \gain loss gpx ts ->
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
        }


decodeRaces : Decoder (List Race)
decodeRaces =
    D.list decodeRace
