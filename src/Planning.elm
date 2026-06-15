module Planning exposing
    ( Km
    , KmResult
    , KmSource(..)
    , Section
    , aidRestTotal
    , computeKms
    , distribute
    , kmAtDistance
    , kmsForRace
    , sectionAidRest
    , sectionsForRace
    , slopeFactor
    )

{-| Per-km planning math.

This module knows how to slice a `Track` into 1 km windows, how to
compute the slope-adjusted weight per km (Tobler-normalised, see
ADR-0003), and how to distribute a target total time across kms
with respect to `Manual` locks and aid-station rest.

It exposes nothing about the UI. The data types and JSON codecs
live in `Types.elm` to avoid an import cycle (Planning depends on
`AidStation` from Types).

-}

import Dict exposing (Dict)
import Gpx exposing (Point, Track)
import Types exposing (AidStation, KmPlan, KmTime(..), Plan, kmPlanFor)



-- ============================================================
-- TYPES
-- ============================================================


type alias Km =
    { index : Int
    , distStart : Float -- meters from race start
    , distEnd : Float
    , distance : Float -- distEnd - distStart (≤ 1000)
    , eleStart : Float
    , eleEnd : Float
    , minEle : Float
    , maxEle : Float
    , gain : Float
    , loss : Float
    , slope : Float
    , points : List Point
    , cumDist : List Float -- km-local distances (0 at km start)
    }


type alias KmResult =
    { seconds : Int
    , source : KmSource
    }


type KmSource
    = AutoComputed
    | UserManual



-- ============================================================
-- HELPERS
-- ============================================================


aidRestTotal : List AidStation -> Int
aidRestTotal aids =
    List.foldl (\a acc -> acc + a.restSeconds) 0 aids


{-| Which km does an absolute distance fall in?
-}
kmAtDistance : Float -> Int
kmAtDistance meters =
    floor (meters / 1000)



-- ============================================================
-- KM WINDOWING
-- ============================================================


{-| Convenience: parse-once-then-windows for a race that's already in
the parsed-track cache. Falls back to an empty list if anything
upstream went wrong.
-}
kmsForRace : Maybe Track -> List Km
kmsForRace maybeTrack =
    case maybeTrack of
        Just track ->
            computeKms track

        Nothing ->
            []


{-| Split a `Track` into 1 km windows. The last window is whatever
remains, possibly < 1 km.
-}
computeKms : Track -> List Km
computeKms track =
    if track.totalDist <= 0 then
        []

    else
        let
            count =
                ceiling (track.totalDist / 1000)
        in
        List.range 0 (count - 1)
            |> List.map (windowFor track)


windowFor : Track -> Int -> Km
windowFor track index =
    let
        distStart =
            toFloat index * 1000

        distEnd =
            min track.totalDist (distStart + 1000)

        pairs =
            List.map2 Tuple.pair track.cumDist track.points

        within =
            List.filter (\( d, _ ) -> d >= distStart && d <= distEnd) pairs

        withEdges =
            ensureEdges distStart distEnd pairs within

        winPoints =
            List.map Tuple.second withEdges

        winDists =
            List.map (\( d, _ ) -> d - distStart) withEdges

        eles =
            List.map .ele winPoints

        eleStart =
            List.head eles |> Maybe.withDefault 0

        eleEnd =
            List.reverse eles |> List.head |> Maybe.withDefault eleStart

        minEle =
            List.minimum eles |> Maybe.withDefault eleStart

        maxEle =
            List.maximum eles |> Maybe.withDefault eleStart

        ( gain, loss ) =
            elevationGainLoss eles

        distance =
            distEnd - distStart

        slope =
            if distance <= 0 then
                0

            else
                (eleEnd - eleStart) / distance
    in
    { index = index
    , distStart = distStart
    , distEnd = distEnd
    , distance = distance
    , eleStart = eleStart
    , eleEnd = eleEnd
    , minEle = minEle
    , maxEle = maxEle
    , gain = gain
    , loss = loss
    , slope = slope
    , points = winPoints
    , cumDist = winDists
    }


ensureEdges :
    Float
    -> Float
    -> List ( Float, Point )
    -> List ( Float, Point )
    -> List ( Float, Point )
ensureEdges distStart distEnd allPairs inside =
    let
        startPoint =
            case inside of
                ( d, _ ) :: _ ->
                    if abs (d - distStart) < 0.5 then
                        Nothing

                    else
                        Just ( distStart, interpolate distStart allPairs )

                [] ->
                    Just ( distStart, interpolate distStart allPairs )

        endPoint =
            case List.reverse inside |> List.head of
                Just ( d, _ ) ->
                    if abs (d - distEnd) < 0.5 then
                        Nothing

                    else
                        Just ( distEnd, interpolate distEnd allPairs )

                Nothing ->
                    Just ( distEnd, interpolate distEnd allPairs )

        withStart =
            case startPoint of
                Just sp ->
                    sp :: inside

                Nothing ->
                    inside
    in
    case endPoint of
        Just ep ->
            withStart ++ [ ep ]

        Nothing ->
            withStart


interpolate : Float -> List ( Float, Point ) -> Point
interpolate target pairs =
    case pairs of
        [] ->
            { lat = 0, lon = 0, ele = 0 }

        first :: _ ->
            interpStep target first pairs


interpStep : Float -> ( Float, Point ) -> List ( Float, Point ) -> Point
interpStep target prev pairs =
    case pairs of
        [] ->
            Tuple.second prev

        ( d, p ) :: rest ->
            if d >= target then
                let
                    ( prevD, prevP ) =
                        prev

                    span =
                        d - prevD
                in
                if span <= 0 then
                    p

                else
                    let
                        t =
                            (target - prevD) / span
                    in
                    { lat = prevP.lat + t * (p.lat - prevP.lat)
                    , lon = prevP.lon + t * (p.lon - prevP.lon)
                    , ele = prevP.ele + t * (p.ele - prevP.ele)
                    }

            else
                interpStep target ( d, p ) rest


elevationGainLoss : List Float -> ( Float, Float )
elevationGainLoss eles =
    let
        threshold =
            2.0
    in
    case eles of
        [] ->
            ( 0, 0 )

        first :: rest ->
            let
                step e ( ref, gain, loss ) =
                    let
                        d =
                            e - ref
                    in
                    if abs d < threshold then
                        ( ref, gain, loss )

                    else if d > 0 then
                        ( e, gain + d, loss )

                    else
                        ( e, gain, loss - d )

                ( _, g, l ) =
                    List.foldl step ( first, 0, 0 ) rest
            in
            ( g, l )



-- ============================================================
-- SLOPE FACTOR + DISTRIBUTION
-- ============================================================


{-| Tobler-normalised slope factor.

    f(s) = exp(3.5 * |s + 0.05| - 0.175)

f(0) = 1.0 (flat = baseline pace). f peaks downward at s = -0.05
(slight downhill, fastest) and is symmetric about that axis — not
about 0. So f(+0.10) ≈ 1.42 while f(-0.10) = 1.0, and f(+0.20) ≈ 2.01
while f(-0.20) ≈ 1.42. See ADR-0003.

-}
slopeFactor : Float -> Float
slopeFactor s =
    e ^ (3.5 * abs (s + 0.05) - 0.175)


{-| Distribute a target total time across kms, honoring `Manual`
locks and reserving time for aid-station rest. See ADR-0003.
-}
distribute :
    { target : Maybe Int
    , kms : List Km
    , plan : Plan
    , aidRestSeconds : Int
    }
    -> Dict Int KmResult
distribute opts =
    let
        manualSum =
            opts.kms
                |> List.foldl
                    (\km acc ->
                        case (kmPlanFor km.index opts.plan).time of
                            Manual s ->
                                acc + s

                            Auto ->
                                acc
                    )
                    0

        target =
            Maybe.withDefault 0 opts.target

        budget =
            max 0 (target - opts.aidRestSeconds - manualSum)

        autoWeights =
            opts.kms
                |> List.filter (\km -> (kmPlanFor km.index opts.plan).time == Auto)
                |> List.map (\km -> ( km.index, max 0.001 km.distance * slopeFactor km.slope ))

        sumWeights =
            List.foldl (\( _, w ) acc -> acc + w) 0 autoWeights

        autoSeconds =
            if opts.target == Nothing then
                Dict.empty

            else if sumWeights <= 0 then
                Dict.empty

            else
                autoWeights
                    |> List.map
                        (\( idx, w ) ->
                            ( idx, round (toFloat budget * w / sumWeights) )
                        )
                    |> Dict.fromList
    in
    opts.kms
        |> List.map
            (\km ->
                let
                    kp =
                        kmPlanFor km.index opts.plan
                in
                case kp.time of
                    Manual s ->
                        ( km.index, { seconds = s, source = UserManual } )

                    Auto ->
                        ( km.index
                        , { seconds = Dict.get km.index autoSeconds |> Maybe.withDefault 0
                          , source = AutoComputed
                          }
                        )
            )
        |> Dict.fromList



-- ============================================================
-- SECTIONS (between aid stations)
-- ============================================================


{-| A "section" is a run between two consecutive aid-station distances
(or start↔first aid, last aid↔finish). Useful for the per-section
table view; computed from kms + aid stations.
-}
type alias Section =
    { index : Int
    , label : String
    , distStart : Float
    , distEnd : Float
    , distance : Float
    , gain : Float
    , loss : Float
    , kmIndices : List Int
    , followedByAid : Maybe AidStation
    }


sectionsForRace :
    { totalDistance : Float
    , aidStations : List AidStation
    , kms : List Km
    }
    -> List Section
sectionsForRace opts =
    let
        sorted =
            List.sortBy .distance opts.aidStations

        boundaries =
            (0 :: List.map .distance sorted)
                ++ [ opts.totalDistance ]

        followedAids =
            List.map Just sorted ++ [ Nothing ]

        pairs =
            zip (zipPairs boundaries) followedAids
    in
    pairs
        |> List.indexedMap
            (\i ( ( a, b ), aid ) ->
                let
                    -- Each km belongs to exactly one section, chosen by its
                    -- midpoint: the half-open interval [a, b) that contains the
                    -- km's center. This partitions the kms across sections — a km
                    -- straddling an aid distance lands in one section, not both —
                    -- so the gain/loss sums here, and the seconds callers sum over
                    -- `kmIndices`, never double-count it. (The old test
                    -- `km.distStart < b && km.distEnd > a` put a straddling km in
                    -- both adjacent sections.)
                    kmsInRange =
                        opts.kms
                            |> List.filter
                                (\km ->
                                    let
                                        mid =
                                            (km.distStart + km.distEnd) / 2
                                    in
                                    mid >= a && mid < b
                                )

                    indices =
                        List.map .index kmsInRange

                    rangeGain =
                        sumKmField .gain kmsInRange

                    rangeLoss =
                        sumKmField .loss kmsInRange
                in
                { index = i
                , label =
                    case ( i == 0, aid ) of
                        ( True, Just first ) ->
                            "Start → " ++ first.name

                        ( False, Just next ) ->
                            sectionStartLabel sorted i ++ " → " ++ next.name

                        ( True, Nothing ) ->
                            "Start → Finish"

                        ( False, Nothing ) ->
                            sectionStartLabel sorted i ++ " → Finish"
                , distStart = a
                , distEnd = b
                , distance = b - a
                , gain = rangeGain
                , loss = rangeLoss
                , kmIndices = indices
                , followedByAid = aid
                }
            )


sectionStartLabel : List AidStation -> Int -> String
sectionStartLabel aids index =
    aids
        |> List.drop (index - 1)
        |> List.head
        |> Maybe.map .name
        |> Maybe.withDefault "Start"


sumKmField : (Km -> Float) -> List Km -> Float
sumKmField field kms =
    -- `kms` is this section's slice of the midpoint partition built in
    -- `sectionsForRace`, so every km is counted in exactly one section.
    -- Pro-rating a straddling km's value across the aid boundary would be
    -- marginally more accurate, but per-km plan seconds are indivisible and
    -- the elevation would need re-deriving at the split point; whole-km
    -- attribution by midpoint is the simpler, reversible choice (TASK-039).
    List.foldl (\km acc -> acc + field km) 0 kms


{-| Total planned aid-station rest that falls *inside* a section, by the same
km attribution the section sums use: an aid contributes its rest when its
containing km (`kmAtDistance a.distance`) is one of the section's `kmIndices`.

This is the section-level lift of the per-km clock model (TASK-025): summed
over all sections it equals `aidRestTotal`, because each aid's km belongs to
exactly one section under the midpoint partition (ADR-0004). Use it to turn a
section's *moving* seconds into *clock* seconds (`moving + sectionAidRest`) so a
plan-vs-actual comparison is clock-vs-clock — actual section splits already
include the stoppage in whichever km physically held the aid. Note this can
differ from `followedByAid.restSeconds` when an aid sits in the first half of
its km (its km then belongs to the *next* section); the km attribution is the
one that matches the actual splits. See ADR-0008.
-}
sectionAidRest : List AidStation -> Section -> Int
sectionAidRest aids section =
    aids
        |> List.filter (\a -> List.member (kmAtDistance a.distance) section.kmIndices)
        |> List.foldl (\a acc -> acc + a.restSeconds) 0


zipPairs : List a -> List ( a, a )
zipPairs xs =
    case xs of
        a :: b :: rest ->
            ( a, b ) :: zipPairs (b :: rest)

        _ ->
            []


zip : List a -> List b -> List ( a, b )
zip xs ys =
    case ( xs, ys ) of
        ( x :: xrest, y :: yrest ) ->
            ( x, y ) :: zip xrest yrest

        _ ->
            []
