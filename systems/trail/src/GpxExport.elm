module GpxExport exposing
    ( exportWithAidStations
    , filenameFor
    )

{-| Re-emit a GPX with `<wpt>` elements for each aid station,
inserted before the `<trk>` element so the order follows GPX 1.1
convention (waypoints first, then tracks).

Schema chosen per ADR-0002:

    <wpt lat="…" lon="…">
      <ele>…</ele>
      <name>…</name>
      <desc>…</desc>
      <sym>Restaurant</sym>
      <type>Aid Station</type>
    </wpt>

We snap each aid station to the closest track point at the
declared distance (Haversine via cumDist). We never invent
coordinates.

-}

import Gpx exposing (Point, Track)
import Types exposing (AidStation, Race, Service(..), serviceLabel)


{-| Build the export. Returns the new GPX string. Falls back to the
input if we can't locate the `<trk>` element (shouldn't happen for
well-formed inputs).
-}
exportWithAidStations : Race -> Track -> String
exportWithAidStations race track =
    if List.isEmpty race.aidStations then
        race.gpxText

    else
        let
            sorted =
                List.sortBy .distance race.aidStations

            waypointsXml =
                sorted
                    |> List.map (waypointXml race track)
                    |> String.join "\n"
                    |> (\s -> "\n" ++ s ++ "\n  ")
        in
        injectBeforeTrk waypointsXml race.gpxText


injectBeforeTrk : String -> String -> String
injectBeforeTrk waypoints gpx =
    case findIndex "<trk>" gpx of
        Just i ->
            String.left i gpx ++ waypoints ++ String.dropLeft i gpx

        Nothing ->
            -- No <trk>? Try <trk with attributes.
            case findIndex "<trk " gpx of
                Just i ->
                    String.left i gpx ++ waypoints ++ String.dropLeft i gpx

                Nothing ->
                    -- Give up and return the original. UI surfaces the
                    -- result, so the user can re-export later.
                    gpx


findIndex : String -> String -> Maybe Int
findIndex needle haystack =
    String.indexes needle haystack |> List.head


waypointXml : Race -> Track -> AidStation -> String
waypointXml _ track aid =
    let
        snapped =
            findClosestPoint aid.distance track
                |> Maybe.withDefault { lat = 0, lon = 0, ele = 0 }

        sym =
            symbolForAid aid

        desc =
            buildDesc aid
    in
    String.concat
        [ "  <wpt lat=\""
        , formatCoord snapped.lat
        , "\" lon=\""
        , formatCoord snapped.lon
        , "\">\n"
        , "    <ele>"
        , formatFloat 1 snapped.ele
        , "</ele>\n"
        , "    <name>"
        , escapeXml aid.name
        , "</name>\n"
        , "    <desc>"
        , escapeXml desc
        , "</desc>\n"
        , "    <sym>"
        , sym
        , "</sym>\n"
        , "    <type>Aid Station</type>\n"
        , "  </wpt>"
        ]


symbolForAid : AidStation -> String
symbolForAid aid =
    -- Garmin-standard sym values that Coros / Garmin recognise.
    if List.member Food aid.services then
        "Restaurant"

    else if List.member Water aid.services then
        "Drinking Water"

    else if List.member Medical aid.services then
        "First Aid"

    else
        "Flag, Blue"


buildDesc : AidStation -> String
buildDesc aid =
    let
        services =
            aid.services
                |> List.map serviceLabel
                |> String.join ", "

        kmStr =
            "Km " ++ formatFloat 1 (aid.distance / 1000)

        restStr =
            if aid.restSeconds > 0 then
                let
                    m =
                        aid.restSeconds // 60

                    s =
                        modBy 60 aid.restSeconds
                in
                "Rest "
                    ++ String.fromInt m
                    ++ ":"
                    ++ String.padLeft 2 '0' (String.fromInt s)

            else
                ""

        bits =
            List.filter (not << String.isEmpty) [ kmStr, services, restStr ]
    in
    String.join " · " bits


findClosestPoint : Float -> Track -> Maybe Point
findClosestPoint distance track =
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
        |> Maybe.map Tuple.second



-- FORMATTING


formatCoord : Float -> String
formatCoord f =
    -- 6 decimal places ≈ 11 cm at the equator. Generous for trail running.
    let
        rounded =
            toFloat (round (f * 1000000)) / 1000000
    in
    String.fromFloat rounded


formatFloat : Int -> Float -> String
formatFloat decimals f =
    let
        mult =
            10 ^ decimals |> toFloat

        rounded =
            toFloat (round (f * mult)) / mult
    in
    String.fromFloat rounded


escapeXml : String -> String
escapeXml =
    String.replace "&" "&amp;"
        >> String.replace "<" "&lt;"
        >> String.replace ">" "&gt;"
        >> String.replace "\"" "&quot;"
        >> String.replace "'" "&apos;"


filenameFor : Race -> String
filenameFor race =
    safeFilename race.name ++ "-coros.gpx"


safeFilename : String -> String
safeFilename s =
    let
        trimmed =
            String.trim s

        sanitized =
            String.toList trimmed
                |> List.map sanitizeChar
                |> String.fromList
                |> String.replace "  " " "
                |> String.trim

        result =
            String.replace " " "-" sanitized
    in
    if String.isEmpty result then
        "race"

    else
        result


sanitizeChar : Char -> Char
sanitizeChar c =
    let
        code =
            Char.toCode c
    in
    if Char.isAlphaNum c || c == '-' || c == '_' || c == '.' then
        c

    else if code < 32 then
        ' '

    else
        ' '
