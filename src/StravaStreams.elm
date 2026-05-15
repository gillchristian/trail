module StravaStreams exposing (parse)

{-| Decoder for the keyed-object stream payload cadence's
`/api/activities/{id}/streams?keys=...` returns. Converts to the
same `ActualGpx.ActualTrack` shape that `ActualGpx.parse` produces
so downstream code (split computation, diff column rendering) is
source-agnostic.

The Strava streams API gives us `time` already as elapsed-seconds
from the activity start — no ISO 8601 parsing needed. `distance` is
cumulative meters, `latlng` is `[[lat, lng], …]`, `altitude` is
meters. Streams should all be the same length; we zip with the
shortest if there's a mismatch.

Pure module — no caller in trail today; TASK-024 will plug it into
the actual-run linking UI.

-}

import ActualGpx exposing (ActualPoint, ActualTrack)
import Json.Decode as D exposing (Decoder)



-- DECODE


parse : D.Value -> Result String ActualTrack
parse value =
    case D.decodeValue rawStreamsDecoder value of
        Err e ->
            Err ("Couldn't parse streams JSON: " ++ D.errorToString e)

        Ok raw ->
            case ( raw.time, raw.distance, raw.latlng ) of
                ( [], _, _ ) ->
                    Err "Streams missing 'time' data."

                ( _, [], _ ) ->
                    Err "Streams missing 'distance' data."

                ( _, _, [] ) ->
                    Err "Streams missing 'latlng' data."

                ( ts, ds, latlngs ) ->
                    let
                        len =
                            List.minimum [ List.length ts, List.length ds, List.length latlngs ]
                                |> Maybe.withDefault 0

                        altSlice =
                            sliceAlign raw.altitude len

                        points =
                            buildPoints (List.take len ts) latlngs altSlice

                        cumDist =
                            -- cadence already gave us cumulative distance;
                            -- use it directly rather than re-Haversine-ing.
                            List.take len ds

                        totalDist =
                            List.reverse cumDist |> List.head |> Maybe.withDefault 0

                        totalElapsedS =
                            List.reverse ts |> List.head |> Maybe.withDefault 0
                    in
                    if List.length points < 2 then
                        Err "Need at least two stream points to compute splits."

                    else
                        Ok
                            { points = points
                            , cumDist = cumDist
                            , totalDist = totalDist
                            , totalElapsedS = totalElapsedS
                            }


type alias RawStreams =
    { time : List Int
    , distance : List Float
    , latlng : List ( Float, Float )
    , altitude : List Float
    }


rawStreamsDecoder : Decoder RawStreams
rawStreamsDecoder =
    D.map4 RawStreams
        (streamData "time" (D.list D.int) [])
        (streamData "distance" (D.list D.float) [])
        (streamData "latlng" (D.list latlngEntry) [])
        (streamData "altitude" (D.list D.float) [])


streamData : String -> Decoder a -> a -> Decoder a
streamData key inner default =
    D.oneOf
        [ D.field key (D.field "data" inner)
        , D.succeed default
        ]


latlngEntry : Decoder ( Float, Float )
latlngEntry =
    D.list D.float
        |> D.andThen
            (\xs ->
                case xs of
                    [ lat, lng ] ->
                        D.succeed ( lat, lng )

                    _ ->
                        D.fail "Expected [lat, lng] pair"
            )


sliceAlign : List Float -> Int -> List Float
sliceAlign source len =
    let
        cur =
            List.length source
    in
    if cur >= len then
        List.take len source

    else
        source ++ List.repeat (len - cur) 0


buildPoints : List Int -> List ( Float, Float ) -> List Float -> List ActualPoint
buildPoints times latlngs alts =
    let
        ll =
            List.take (List.length times) latlngs

        ele =
            sliceAlign alts (List.length times)

        zipped =
            zip3 times ll ele
    in
    List.map
        (\( t, ( lat, lng ), elev ) ->
            { lat = lat
            , lon = lng
            , ele = elev
            , elapsedS = t
            }
        )
        zipped


zip3 : List a -> List b -> List c -> List ( a, b, c )
zip3 xs ys zs =
    case ( xs, ys, zs ) of
        ( x :: xRest, y :: yRest, z :: zRest ) ->
            ( x, y, z ) :: zip3 xRest yRest zRest

        _ ->
            []
