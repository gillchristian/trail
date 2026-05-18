module ActualGpx exposing
    ( ActualPoint
    , ActualTrack
    , computeHrPerKm
    , computeSplits
    , cumulativeDistances
    , parse
    )

{-| Parser for a *completed run's* GPX — the file the user uploads
after finishing a race they planned in trail. Differs from `Gpx.elm`
in two ways:

  - Every track point carries a `<time>` timestamp; the module fails
    if no timestamps are present (we can't compute splits without
    them).
  - Output is `elapsed-seconds-from-first-point`, not wall-clock time
    or epoch seconds. All race-day timezones are accommodated; the
    only invariant we need is monotonic intra-track time.

The time math is inline (no Elm date library): Hinnant's
"days from civil" formula gives a self-consistent epoch
day count; intra-day h/m/s are trivial. See
<https://howardhinnant.github.io/date_algorithms.html>.

-}

import Dict exposing (Dict)
import Regex exposing (Regex)



-- TYPES


type alias ActualPoint =
    { lat : Float
    , lon : Float
    , ele : Float
    , elapsedS : Int -- seconds since the first point
    , hr : Maybe Int -- bpm, when the source carries heart-rate data
    }


type alias ActualTrack =
    { points : List ActualPoint
    , cumDist : List Float -- meters
    , totalDist : Float -- meters
    , totalElapsedS : Int -- seconds (last point's elapsedS)
    }



-- PARSE


parse : String -> Result String ActualTrack
parse content =
    let
        raw =
            Regex.find trkptRe content
                |> List.filterMap matchToRaw
    in
    case raw of
        [] ->
            Err "No track points with timestamps found in this GPX."

        first :: _ ->
            let
                firstTs =
                    first.ts

                points =
                    raw
                        |> List.map
                            (\r ->
                                { lat = r.lat
                                , lon = r.lon
                                , ele = r.ele
                                , elapsedS = r.ts - firstTs
                                , hr = Nothing
                                }
                            )

                cumDist =
                    cumulativeDistances points

                totalDist =
                    List.reverse cumDist |> List.head |> Maybe.withDefault 0

                totalElapsedS =
                    points |> List.reverse |> List.head |> Maybe.map .elapsedS |> Maybe.withDefault 0
            in
            if List.length points < 2 then
                Err "Need at least two timestamped points to compute splits."

            else
                Ok
                    { points = points
                    , cumDist = cumDist
                    , totalDist = totalDist
                    , totalElapsedS = totalElapsedS
                    }


trkptRe : Regex
trkptRe =
    Regex.fromString "<trkpt\\s+([^>]*)>([\\s\\S]*?)</trkpt>"
        |> Maybe.withDefault Regex.never


attrRe : Regex
attrRe =
    Regex.fromString "(\\w+)\\s*=\\s*\"([^\"]*)\""
        |> Maybe.withDefault Regex.never


eleRe : Regex
eleRe =
    Regex.fromString "<ele>\\s*([^<]+)\\s*</ele>"
        |> Maybe.withDefault Regex.never


timeRe : Regex
timeRe =
    Regex.fromString "<time>\\s*([^<]+)\\s*</time>"
        |> Maybe.withDefault Regex.never


type alias RawPoint =
    { ts : Int, lat : Float, lon : Float, ele : Float }


matchToRaw : Regex.Match -> Maybe RawPoint
matchToRaw m =
    case m.submatches of
        (Just attrs) :: (Just inner) :: _ ->
            let
                pairs =
                    Regex.find attrRe attrs
                        |> List.filterMap
                            (\am ->
                                case am.submatches of
                                    (Just k) :: (Just v) :: _ ->
                                        Just ( k, v )

                                    _ ->
                                        Nothing
                            )

                lookup key =
                    pairs
                        |> List.filter (\( k, _ ) -> k == key)
                        |> List.head
                        |> Maybe.map Tuple.second

                lat =
                    lookup "lat" |> Maybe.andThen String.toFloat

                lon =
                    lookup "lon" |> Maybe.andThen String.toFloat

                ele =
                    Regex.findAtMost 1 eleRe inner
                        |> List.head
                        |> Maybe.andThen
                            (\em ->
                                case em.submatches of
                                    (Just s) :: _ ->
                                        String.toFloat (String.trim s)

                                    _ ->
                                        Nothing
                            )
                        |> Maybe.withDefault 0

                ts =
                    Regex.findAtMost 1 timeRe inner
                        |> List.head
                        |> Maybe.andThen
                            (\tm ->
                                case tm.submatches of
                                    (Just s) :: _ ->
                                        parseIso8601 (String.trim s)

                                    _ ->
                                        Nothing
                            )
            in
            Maybe.map3 (\la lo t -> { ts = t, lat = la, lon = lo, ele = ele }) lat lon ts

        _ ->
            Nothing



-- ISO 8601 → SECONDS


{-| Accepts `YYYY-MM-DDTHH:MM:SS[.fff][Z|±HH:MM]`. We treat the
result as if it were UTC because:

  - GPX written by Strava/Garmin/Coros is always UTC with `Z`.
  - For *elapsed* seconds within one track, an absolute timezone
    offset cancels — only consistency matters.

We don't validate timezone offsets; if a non-Z suffix appears, we
parse the leading datetime and ignore the rest. Sub-second precision
is truncated.

-}
parseIso8601 : String -> Maybe Int
parseIso8601 s =
    let
        -- Take just "YYYY-MM-DDTHH:MM:SS" — the first 19 chars.
        head =
            String.left 19 s
    in
    case String.split "T" head of
        [ datePart, timePart ] ->
            Maybe.map2 (+)
                (parseDate datePart |> Maybe.map (\d -> d * 86400))
                (parseTime timePart)

        _ ->
            Nothing


parseDate : String -> Maybe Int
parseDate s =
    case String.split "-" s of
        [ y, m, d ] ->
            Maybe.map3 daysSinceEpoch (String.toInt y) (String.toInt m) (String.toInt d)

        _ ->
            Nothing


parseTime : String -> Maybe Int
parseTime s =
    case String.split ":" (String.left 8 s) of
        [ h, m, sec ] ->
            Maybe.map3 (\hh mm ss -> hh * 3600 + mm * 60 + ss)
                (String.toInt h)
                (String.toInt m)
                (String.toInt sec)

        _ ->
            Nothing


{-| Howard Hinnant's "days from civil" algorithm. Returns the
day-number for the given Gregorian date (1970-01-01 = 0). Works for
all valid dates; we only ever see 2000+ in practice.
-}
daysSinceEpoch : Int -> Int -> Int -> Int
daysSinceEpoch y m d =
    let
        adjY =
            if m <= 2 then
                y - 1

            else
                y

        adjM =
            if m <= 2 then
                m + 9

            else
                m - 3

        era =
            if adjY >= 0 then
                adjY // 400

            else
                (adjY - 399) // 400

        yoe =
            adjY - era * 400

        doy =
            (153 * adjM + 2) // 5 + d - 1

        doe =
            yoe * 365 + yoe // 4 - yoe // 100 + doy
    in
    era * 146097 + doe - 719468



-- DISTANCE


cumulativeDistances : List ActualPoint -> List Float
cumulativeDistances points =
    case points of
        [] ->
            []

        first :: rest ->
            let
                step p ( prev, acc, total ) =
                    let
                        d =
                            haversine prev p

                        running =
                            total + d
                    in
                    ( p, running :: acc, running )

                ( _, listRev, _ ) =
                    List.foldl step ( first, [ 0 ], 0 ) rest
            in
            List.reverse listRev


earthRadius : Float
earthRadius =
    6371000.0


toRadians : Float -> Float
toRadians deg =
    deg * pi / 180


haversine : ActualPoint -> ActualPoint -> Float
haversine a b =
    let
        phi1 =
            toRadians a.lat

        phi2 =
            toRadians b.lat

        dphi =
            toRadians (b.lat - a.lat)

        dlam =
            toRadians (b.lon - a.lon)

        h =
            sin (dphi / 2) ^ 2 + cos phi1 * cos phi2 * sin (dlam / 2) ^ 2
    in
    2 * earthRadius * atan2 (sqrt h) (sqrt (1 - h))



-- SPLITS


type alias SplitState =
    { kmIdx : Int -- next km we haven't closed yet
    , prevBoundaryS : Int -- elapsedS at the start of km `kmIdx`
    , prevPointDist : Float -- last processed point's cumulative distance
    , prevPointS : Int -- last processed point's elapsedS
    , splits : List ( Int, Int ) -- accumulated, reversed
    }


{-| Per-km actual split times. Boundaries are at each 1 km of *actual*
track distance (not snapped to a planned course). Key is the km
index (0-based, matching `Planning.Km.index`). Value is the seconds
spent in that km. The last (possibly partial) km is included.

A single sparse point may straddle multiple km boundaries; we
linearly interpolate elapsedS at each boundary crossing so the
splits stay sensible (rather than putting all of the time into the
last km observed).

-}
computeSplits : ActualTrack -> List ( Int, Int )
computeSplits track =
    case List.map2 Tuple.pair track.cumDist track.points of
        [] ->
            []

        ( d0, p0 ) :: rest ->
            let
                init =
                    { kmIdx = 0
                    , prevBoundaryS = p0.elapsedS -- 0
                    , prevPointDist = d0 -- 0
                    , prevPointS = p0.elapsedS
                    , splits = []
                    }

                final =
                    List.foldl stepPoint init rest

                tailSeconds =
                    final.prevPointS - final.prevBoundaryS

                withTail =
                    if tailSeconds > 0 then
                        ( final.kmIdx, tailSeconds ) :: final.splits

                    else
                        final.splits
            in
            List.reverse withTail


stepPoint : ( Float, ActualPoint ) -> SplitState -> SplitState
stepPoint ( dist, point ) state =
    let
        afterCross =
            crossBoundaries dist point state
    in
    { afterCross
        | prevPointDist = dist
        , prevPointS = point.elapsedS
    }


crossBoundaries : Float -> ActualPoint -> SplitState -> SplitState
crossBoundaries dist point state =
    let
        boundary =
            toFloat (state.kmIdx + 1) * 1000
    in
    if dist >= boundary then
        let
            distSpan =
                dist - state.prevPointDist

            elapsedSpan =
                point.elapsedS - state.prevPointS

            t =
                if distSpan <= 0 then
                    0

                else
                    (boundary - state.prevPointDist) / distSpan

            elapsedAtBoundary =
                state.prevPointS + round (t * toFloat elapsedSpan)

            split =
                elapsedAtBoundary - state.prevBoundaryS
        in
        crossBoundaries dist
            point
            { state
                | kmIdx = state.kmIdx + 1
                , prevBoundaryS = elapsedAtBoundary
                , splits = ( state.kmIdx, split ) :: state.splits
            }

    else
        state



-- HEART RATE


{-| Average heart rate per km, when the source carries HR data.
Returns `Nothing` if no point in the track has a `hr` value (this
is the case for file-uploaded `.gpx` actuals today; the GPX-with-
time parser doesn't extract HR from extensions). Otherwise returns
`Just (Dict.fromList ...)` with km-index → rounded average bpm.

Each point is counted once toward whichever km its current cumulative
distance falls in (`floor (cumDist / 1000)`). Samples are equally
weighted; Strava streams come back at ~1 Hz so this is close to a
time-weighted average in practice.
-}
computeHrPerKm : ActualTrack -> Maybe (Dict Int Int)
computeHrPerKm track =
    let
        sums =
            List.map2 Tuple.pair track.cumDist track.points
                |> List.foldl stepHr Dict.empty
    in
    if Dict.isEmpty sums then
        Nothing

    else
        Just (Dict.map (\_ ( sum, count ) -> sum // max 1 count) sums)


stepHr : ( Float, ActualPoint ) -> Dict Int ( Int, Int ) -> Dict Int ( Int, Int )
stepHr ( dist, point ) acc =
    case point.hr of
        Nothing ->
            acc

        Just bpm ->
            let
                kmIdx =
                    floor (dist / 1000)
            in
            Dict.update kmIdx
                (\existing ->
                    case existing of
                        Nothing ->
                            Just ( bpm, 1 )

                        Just ( sum, count ) ->
                            Just ( sum + bpm, count + 1 )
                )
                acc
