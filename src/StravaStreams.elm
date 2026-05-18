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

                        hrSlice =
                            -- Heart rate is optional; activities recorded
                            -- without an HR sensor come back with `[]`. Wrap
                            -- present samples in `Just`; `sliceAlignMaybe`
                            -- pads with `Nothing` if the stream is shorter
                            -- than the others.
                            sliceAlignMaybe (List.map Just raw.heartrate) len

                        points =
                            buildPoints (List.take len ts) latlngs altSlice hrSlice

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
    , heartrate : List Int
    }


rawStreamsDecoder : Decoder RawStreams
rawStreamsDecoder =
    D.map5 RawStreams
        (streamData "time" (D.list D.int) [])
        (streamData "distance" (D.list D.float) [])
        (streamData "latlng" (D.list latlngEntry) [])
        (streamData "altitude" (D.list D.float) [])
        (streamData "heartrate" (D.list D.int) [])


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


{-| Walk the four parallel streams together and emit `ActualPoint`
records directly. We sidestep both Elm's 4-tuple ban *and* the
non-tail-recursive `::` trap that bit us before in `zip3`: each
recursive call here is in tail position because the cons happens
inside the accumulator argument.
-}
buildPoints : List Int -> List ( Float, Float ) -> List Float -> List (Maybe Int) -> List ActualPoint
buildPoints times latlngs alts hrs =
    let
        n =
            List.length times

        eleAligned =
            sliceAlign alts n

        hrAligned =
            sliceAlignMaybe hrs n
    in
    buildPointsHelp times latlngs eleAligned hrAligned []


buildPointsHelp :
    List Int
    -> List ( Float, Float )
    -> List Float
    -> List (Maybe Int)
    -> List ActualPoint
    -> List ActualPoint
buildPointsHelp ts lls es hs acc =
    case ( ts, lls, ( es, hs ) ) of
        ( t :: trest, ( lat, lng ) :: llrest, ( e :: erest, h :: hrest ) ) ->
            buildPointsHelp trest
                llrest
                erest
                hrest
                ({ lat = lat
                 , lon = lng
                 , ele = e
                 , elapsedS = t
                 , hr = h
                 }
                    :: acc
                )

        _ ->
            List.reverse acc


sliceAlignMaybe : List (Maybe Int) -> Int -> List (Maybe Int)
sliceAlignMaybe source len =
    let
        cur =
            List.length source
    in
    if cur >= len then
        List.take len source

    else
        source ++ List.repeat (len - cur) Nothing
