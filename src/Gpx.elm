module Gpx exposing (Point, Track, parseGPX, simplify)

{-| GPX parsing, track-stats computation, and Douglas-Peucker
profile simplification.

GPX is XML, but it's regular enough that a small set of regexes
extracts what we need without pulling in a full XML parser. The
trade-off: self-closing `<trkpt … />` (no nested `<ele>`) is skipped.
Strava and other mainstream exporters always emit the long form.

-}

import Array exposing (Array)
import Regex exposing (Regex)
import Set exposing (Set)



-- TYPES


type alias Point =
    { lat : Float, lon : Float, ele : Float }


type alias Track =
    { name : String
    , points : List Point
    , cumDist : List Float
    , totalDist : Float
    , minEle : Float
    , maxEle : Float
    , gain : Float
    , loss : Float
    }



-- PARSE


parseGPX : String -> Result String Track
parseGPX content =
    let
        points =
            extractPoints content
    in
    if List.length points < 2 then
        Err "No track points found in this GPX file."

    else
        Ok (buildTrack (extractName content) points)


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


nameRe : Regex
nameRe =
    Regex.fromString "<trk>[\\s\\S]*?<name>([^<]+)</name>"
        |> Maybe.withDefault Regex.never


extractName : String -> String
extractName content =
    Regex.findAtMost 1 nameRe content
        |> List.head
        |> Maybe.andThen
            (\m ->
                case m.submatches of
                    (Just n) :: _ ->
                        Just (String.trim n)

                    _ ->
                        Nothing
            )
        |> Maybe.withDefault "Untitled track"


extractPoints : String -> List Point
extractPoints content =
    Regex.find trkptRe content
        |> List.filterMap matchToPoint


matchToPoint : Regex.Match -> Maybe Point
matchToPoint m =
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
            in
            Maybe.map2 (\la lo -> { lat = la, lon = lo, ele = ele }) lat lon

        _ ->
            Nothing



-- BUILD


buildTrack : String -> List Point -> Track
buildTrack name points =
    let
        cumDist =
            cumulativeDistances points

        totalDist =
            List.reverse cumDist |> List.head |> Maybe.withDefault 0

        eles =
            List.map .ele points

        minEle =
            List.minimum eles |> Maybe.withDefault 0

        maxEle =
            List.maximum eles |> Maybe.withDefault 0

        ( gain, loss ) =
            elevationGainLoss eles
    in
    { name = name
    , points = points
    , cumDist = cumDist
    , totalDist = totalDist
    , minEle = minEle
    , maxEle = maxEle
    , gain = gain
    , loss = loss
    }


earthRadius : Float
earthRadius =
    6371000.0


toRadians : Float -> Float
toRadians d =
    d * pi / 180


haversine : Point -> Point -> Float
haversine a b =
    let
        phi1 =
            toRadians a.lat

        phi2 =
            toRadians b.lat

        dPhi =
            toRadians (b.lat - a.lat)

        dLam =
            toRadians (b.lon - a.lon)

        h =
            sin (dPhi / 2) ^ 2 + cos phi1 * cos phi2 * sin (dLam / 2) ^ 2
    in
    earthRadius * 2 * atan2 (sqrt h) (sqrt (1 - h))


cumulativeDistances : List Point -> List Float
cumulativeDistances pts =
    case pts of
        [] ->
            []

        first :: rest ->
            let
                step p ( prev, total, acc ) =
                    let
                        next =
                            total + haversine prev p
                    in
                    ( p, next, next :: acc )

                ( _, _, distancesRev ) =
                    List.foldl step ( first, 0, [ 0 ] ) rest
            in
            List.reverse distancesRev


{-| Iterative Douglas-Peucker on a 2-D series. Tolerance is in the
same unit as the input axes (meters of perpendicular distance to the
chord). Iterative — recursive DP would blow the JS stack on long tracks
(26 k points → up to 26 k stack frames in the worst case).

A track with N points typically reduces to ~50-200 samples at
mPerPx-scale tolerance — enough to be visually indistinguishable from
the raw signal at one-pixel resolution.

-}
simplify : Float -> List ( Float, Float ) -> List ( Float, Float )
simplify tolerance points =
    let
        arr =
            Array.fromList points

        n =
            Array.length arr
    in
    if n < 3 || tolerance <= 0 then
        points

    else
        let
            keep =
                dpStep tolerance arr [ ( 0, n - 1 ) ] (Set.fromList [ 0, n - 1 ])
        in
        points
            |> List.indexedMap Tuple.pair
            |> List.filter (\( i, _ ) -> Set.member i keep)
            |> List.map Tuple.second


dpStep : Float -> Array ( Float, Float ) -> List ( Int, Int ) -> Set Int -> Set Int
dpStep tol arr stack keep =
    case stack of
        [] ->
            keep

        ( a, b ) :: rest ->
            if b - a < 2 then
                dpStep tol arr rest keep

            else
                case ( Array.get a arr, Array.get b arr ) of
                    ( Just pa, Just pb ) ->
                        let
                            ( best, bestDist ) =
                                farthest arr pa pb (a + 1) b ( a, 0 )
                        in
                        if bestDist > tol then
                            dpStep tol arr (( a, best ) :: ( best, b ) :: rest) (Set.insert best keep)

                        else
                            dpStep tol arr rest keep

                    _ ->
                        dpStep tol arr rest keep


farthest : Array ( Float, Float ) -> ( Float, Float ) -> ( Float, Float ) -> Int -> Int -> ( Int, Float ) -> ( Int, Float )
farthest arr a b i stop best =
    if i >= stop then
        best

    else
        case Array.get i arr of
            Just p ->
                let
                    d =
                        perpDistance a b p
                in
                if d > Tuple.second best then
                    farthest arr a b (i + 1) stop ( i, d )

                else
                    farthest arr a b (i + 1) stop best

            Nothing ->
                best


perpDistance : ( Float, Float ) -> ( Float, Float ) -> ( Float, Float ) -> Float
perpDistance ( ax, ay ) ( bx, by ) ( px, py ) =
    let
        dx =
            bx - ax

        dy =
            by - ay

        len2 =
            dx * dx + dy * dy
    in
    if len2 == 0 then
        sqrt ((px - ax) ^ 2 + (py - ay) ^ 2)

    else
        abs ((px - ax) * dy - (py - ay) * dx) / sqrt len2


{-| Cumulative ascent/descent with a noise threshold on the *reference*
elevation: a sample is only "confirmed" when it differs from the last
confirmed sample by more than `threshold` meters. Matches Strava's
ballpark; raw cumulative deltas inflate gain by ~2-5% on typical GPS noise.
-}
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
