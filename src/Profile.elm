module Profile exposing
    ( Marker
    , ScaleMode(..)
    , defaultTrueScale
    , isTrueScale
    , metersPerPixel
    , view
    , viewToolbar
    )

{-| True-scale elevation chart, ported from the crest prototype.

The whole point: same `meters/pixel` on both axes. A 100 m climb
over 1 km draws as a 1 km × 100 m rectangle, not a screen-tall
spike. Two display modes:

  - `FitWidth` — the route fits the container; `m/px` is whatever it
    needs to be. The chart is short, but truthful.
  - `TrueScale m` — fixed `m/px`. Horizontal scroll kicks in when the
    chart is wider than the container.

The path is Douglas-Peucker-simplified at half-pixel tolerance —
sub-pixel detail isn't visible anyway, and the simplification keeps
26 k-point UTMB tracks rendering snappily.

-}

import Gpx exposing (Track)
import Html exposing (Html, button, div, span, text)
import Html.Attributes as A exposing (class, classList)
import Html.Events exposing (onClick)
import Svg exposing (Svg, g, line, path, svg, text_)
import Svg.Attributes as SA



-- TYPES


type ScaleMode
    = FitWidth
    | TrueScale Float -- meters per pixel


metersPerPixel : ScaleMode -> Float -> Float -> Float
metersPerPixel mode totalDist containerWidth =
    case mode of
        FitWidth ->
            if containerWidth <= 0 then
                1

            else
                totalDist / containerWidth

        TrueScale m ->
            m


isTrueScale : ScaleMode -> Bool
isTrueScale m =
    case m of
        TrueScale _ ->
            True

        _ ->
            False


defaultTrueScale : Track -> Float -> ScaleMode
defaultTrueScale track containerWidth =
    -- Aim for a chart ~ 2× the container width — feels like a
    -- meaningful zoom-in over fit without being absurdly long.
    let
        target =
            track.totalDist / (containerWidth * 2)

        snap =
            [ 1, 2, 5, 10, 20, 50, 100 ]
                |> List.filter (\v -> toFloat v >= target)
                |> List.head
                |> Maybe.withDefault 100
    in
    TrueScale (toFloat snap)



-- TOOLBAR


viewToolbar :
    { mode : ScaleMode
    , track : Track
    , containerWidth : Float
    , onSetMode : ScaleMode -> msg
    }
    -> Html msg
viewToolbar opts =
    div [ class "flex flex-wrap items-center gap-3 mb-3" ]
        [ div [ class "flex items-center gap-1 bg-slate-900 border border-slate-800 rounded-lg p-1" ]
            [ modeButton "Fit width" (opts.mode == FitWidth) (opts.onSetMode FitWidth)
            , modeButton "True scale"
                (isTrueScale opts.mode)
                (opts.onSetMode (defaultTrueScale opts.track opts.containerWidth))
            ]
        , case opts.mode of
            TrueScale current ->
                div [ class "flex flex-wrap items-center gap-1 bg-slate-900 border border-slate-800 rounded-lg p-1" ]
                    (List.map (presetButton current opts.onSetMode) [ 1, 2, 5, 10, 20, 50, 100 ])

            FitWidth ->
                text ""
        , div [ class "text-xs text-slate-500 ml-auto" ]
            [ text (scaleLegend opts.mode opts.track opts.containerWidth) ]
        ]


modeButton : String -> Bool -> msg -> Html msg
modeButton label active msg =
    button
        [ onClick msg
        , classList
            [ ( "px-3 py-1.5 text-sm rounded transition-colors", True )
            , ( "bg-rose-600 text-white font-medium shadow-sm", active )
            , ( "text-slate-400 hover:text-slate-100", not active )
            ]
        ]
        [ text label ]


presetButton : Float -> (ScaleMode -> msg) -> Int -> Html msg
presetButton current onSetMode value =
    let
        v =
            toFloat value

        active =
            current == v
    in
    button
        [ onClick (onSetMode (TrueScale v))
        , classList
            [ ( "px-2.5 py-1.5 text-xs rounded transition-colors min-w-[3rem]", True )
            , ( "bg-rose-600 text-white font-medium shadow-sm", active )
            , ( "text-slate-400 hover:text-slate-100", not active )
            ]
        ]
        [ text (String.fromInt value ++ " m/px") ]


scaleLegend : ScaleMode -> Track -> Float -> String
scaleLegend mode track containerWidth =
    let
        mpp =
            metersPerPixel mode track.totalDist containerWidth
    in
    "1 px = " ++ formatFloat 1 mpp ++ " m (both axes · 1:1)"



-- MARKERS


type alias Marker =
    { distance : Float
    , label : String
    , index : Int -- 1-based position among aid stations
    }



-- CHART


view : Track -> ScaleMode -> Float -> List Marker -> Html msg
view track mode containerWidth markers =
    let
        eleRange =
            track.maxEle - track.minEle

        mPerPx =
            metersPerPixel mode track.totalDist containerWidth

        drawWidth =
            track.totalDist / mPerPx

        chartHeight =
            max 60 (eleRange / mPerPx)

        padTop =
            if List.isEmpty markers then
                16

            else
                58 -- room for badge + name pill above the chart

        padBottom =
            34

        padLeft =
            60

        padRight =
            16

        totalWidth =
            drawWidth + padLeft + padRight

        totalHeight =
            chartHeight + padTop + padBottom

        toX d =
            padLeft + d / mPerPx

        toY ele =
            padTop + (track.maxEle - ele) / mPerPx

        profile =
            List.map2 (\d p -> ( d, p.ele )) track.cumDist track.points
                |> Gpx.simplify (mPerPx * 0.5)

        coords =
            List.map (\( d, e ) -> ( toX d, toY e )) profile

        -- Chromium (and other engines) truncate single SVG `<path>`
        -- elements whose rendered extent grows past a soft per-element
        -- limit, observed at ~16-20 k px in practice. The pure-Elm
        -- pipeline produces the full coord list correctly for 400 km
        -- courses (Cocodona 250 → 1 195 simplified points reaching
        -- d=393 467 m), but the resulting single `<path>` gets clipped
        -- mid-track in the browser. Splitting the coords into
        -- max-10 000 px-wide chunks keeps every path element well
        -- below that limit; adjacent chunks share their boundary point
        -- so the rendered line stays visually continuous.
        coordChunks =
            chunkByXExtent 10000 coords

        areaPaths =
            List.map (\c -> buildAreaPath c (padTop + chartHeight)) coordChunks

        strokePaths =
            List.map buildStrokePath coordChunks

        gridLines =
            elevationGridLines track mPerPx padTop padLeft (padLeft + drawWidth) chartHeight

        kmTicks =
            distanceTicks track.totalDist mPerPx padLeft (padTop + chartHeight) drawWidth

        markerNodes =
            List.map (viewMarker padTop (padTop + chartHeight) toX) markers
    in
    div [ class "bg-slate-900 border border-slate-800 rounded-2xl overflow-x-auto" ]
        [ svg
            [ SA.width (String.fromFloat totalWidth)
            , SA.height (String.fromFloat totalHeight)
            , SA.viewBox
                ("0 0 "
                    ++ String.fromFloat totalWidth
                    ++ " "
                    ++ String.fromFloat totalHeight
                )
            ]
            [ Svg.defs []
                [ Svg.linearGradient
                    [ SA.id "elev-fill"
                    , SA.x1 "0"
                    , SA.y1 "0"
                    , SA.x2 "0"
                    , SA.y2 "1"
                    ]
                    [ Svg.stop [ SA.offset "0%", SA.stopColor "#E52E3A", SA.stopOpacity "0.65" ] []
                    , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A", SA.stopOpacity "0.05" ] []
                    ]
                , Svg.linearGradient
                    [ SA.id "elev-stroke"
                    , SA.x1 "0"
                    , SA.y1 "0"
                    , SA.x2 "1"
                    , SA.y2 "0"
                    ]
                    [ Svg.stop [ SA.offset "0%", SA.stopColor "#fbbf24" ] []
                    , Svg.stop [ SA.offset "30%", SA.stopColor "#ff5f6a" ] []
                    , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A" ] []
                    ]
                ]
            , g [] gridLines
            , g []
                (List.map
                    (\d ->
                        path
                            [ SA.d d
                            , SA.fill "url(#elev-fill)"
                            , SA.stroke "none"
                            ]
                            []
                    )
                    areaPaths
                )
            , g [] (List.concatMap ghostLayers strokePaths)
            , g []
                (List.map
                    (\d ->
                        path
                            [ SA.d d
                            , SA.fill "none"
                            , SA.stroke "url(#elev-stroke)"
                            , SA.strokeWidth "1.8"
                            , SA.strokeLinejoin "round"
                            , SA.strokeLinecap "round"
                            , SA.class "trail-stroke"
                            ]
                            []
                    )
                    strokePaths
                )
            , g [] kmTicks
            , g [] markerNodes
            ]
        ]


{-| The UTMB-style "sound wave" echo: a fan of ghost copies of the
profile stroke, each translated vertically by ±n pixels with a
fading opacity. Reads as depth / movement on the main chart.
-}
ghostLayers : String -> List (Svg msg)
ghostLayers d =
    let
        offsets =
            [ -8, -6, -4, -2, 2, 4, 6, 8 ]

        toLayer dy =
            let
                op =
                    max 0.06 (0.22 - 0.02 * toFloat (abs dy))
            in
            path
                [ SA.d d
                , SA.fill "none"
                , SA.stroke "#ff5f6a"
                , SA.strokeWidth "1"
                , SA.strokeOpacity (String.fromFloat op)
                , SA.strokeLinejoin "round"
                , SA.strokeLinecap "round"
                , SA.transform ("translate(0," ++ String.fromInt dy ++ ")")
                , SA.class "trail-ghost"
                ]
                []
    in
    List.map toLayer offsets


viewMarker : Float -> Float -> (Float -> Float) -> Marker -> Svg msg
viewMarker yTop yBottom toX marker =
    let
        x =
            toX marker.distance

        label =
            marker.label

        -- Circular numbered badge sits above the chart; rectangular
        -- name pill sits just below the badge. Vertical dashed line
        -- drops to the chart.
        badgeR =
            12

        badgeCy =
            yTop - 22

        pillW =
            max 48 (toFloat (String.length label) * 7 + 14)

        pillH =
            16

        pillTop =
            badgeCy + badgeR + 3
    in
    g []
        [ line
            [ SA.x1 (fmt x)
            , SA.x2 (fmt x)
            , SA.y1 (fmt (badgeCy + badgeR))
            , SA.y2 (fmt yBottom)
            , SA.stroke "#fbbf24"
            , SA.strokeWidth "1"
            , SA.strokeDasharray "2 3"
            , SA.opacity "0.7"
            ]
            []
        -- Badge ring (outer)
        , Svg.circle
            [ SA.cx (fmt x)
            , SA.cy (fmt badgeCy)
            , SA.r (String.fromFloat badgeR)
            , SA.fill "#0b0b21"
            , SA.stroke "#fbbf24"
            , SA.strokeWidth "2"
            ]
            []
        , text_
            [ SA.x (fmt x)
            , SA.y (fmt (badgeCy + 4))
            , SA.textAnchor "middle"
            , SA.fontSize "11"
            , SA.fontWeight "700"
            , SA.fill "#fbbf24"
            , SA.fontFamily "system-ui, -apple-system, sans-serif"
            ]
            [ Svg.text (String.fromInt marker.index) ]
        -- Name pill
        , Svg.rect
            [ SA.x (fmt (x - pillW / 2))
            , SA.y (fmt pillTop)
            , SA.width (fmt pillW)
            , SA.height (fmt pillH)
            , SA.rx "8"
            , SA.fill "#fbbf24"
            , SA.opacity "0.95"
            ]
            []
        , text_
            [ SA.x (fmt x)
            , SA.y (fmt (pillTop + 11))
            , SA.textAnchor "middle"
            , SA.fontSize "10"
            , SA.fontWeight "600"
            , SA.fill "#0b0b21"
            , SA.fontFamily "system-ui, -apple-system, sans-serif"
            ]
            [ Svg.text label ]
        ]



-- PATHS


buildAreaPath : List ( Float, Float ) -> Float -> String
buildAreaPath coords baseline =
    case coords of
        [] ->
            ""

        ( x0, y0 ) :: _ ->
            let
                middle =
                    coords
                        |> List.drop 1
                        |> List.map (\( x, y ) -> "L " ++ fmt x ++ " " ++ fmt y)
                        |> String.join " "

                xLast =
                    coords
                        |> List.reverse
                        |> List.head
                        |> Maybe.map Tuple.first
                        |> Maybe.withDefault x0
            in
            String.join " "
                [ "M " ++ fmt x0 ++ " " ++ fmt baseline
                , "L " ++ fmt x0 ++ " " ++ fmt y0
                , middle
                , "L " ++ fmt xLast ++ " " ++ fmt baseline
                , "Z"
                ]


buildStrokePath : List ( Float, Float ) -> String
buildStrokePath coords =
    case coords of
        [] ->
            ""

        ( x0, y0 ) :: rest ->
            ("M " ++ fmt x0 ++ " " ++ fmt y0)
                :: List.map (\( x, y ) -> "L " ++ fmt x ++ " " ++ fmt y) rest
                |> String.join " "


{-| Split a polyline into pieces that each span no more than `maxWidth`
pixels horizontally. Adjacent chunks share their boundary point so the
rendered line stays continuous. Used to dodge a per-element SVG path
rendering limit observed in Chromium at very wide profiles (400 km @
10 m/px ≈ 39 000 px — single `<path>` truncates mid-track even though
the underlying coord list is complete).
-}
chunkByXExtent : Float -> List ( Float, Float ) -> List (List ( Float, Float ))
chunkByXExtent maxWidth coords =
    case coords of
        [] ->
            []

        first :: rest ->
            chunkByXExtentHelp maxWidth (Tuple.first first) rest [ first ] []


chunkByXExtentHelp :
    Float
    -> Float
    -> List ( Float, Float )
    -> List ( Float, Float )
    -> List (List ( Float, Float ))
    -> List (List ( Float, Float ))
chunkByXExtentHelp maxWidth startX coords currentRev completedRev =
    case coords of
        [] ->
            List.reverse (List.reverse currentRev :: completedRev)

        (( x, _ ) as pt) :: rest ->
            let
                shouldClose =
                    x - startX > maxWidth
            in
            if shouldClose then
                let
                    closedChunk =
                        List.reverse (pt :: currentRev)
                in
                chunkByXExtentHelp maxWidth x rest [ pt ] (closedChunk :: completedRev)

            else
                chunkByXExtentHelp maxWidth startX rest (pt :: currentRev) completedRev


fmt : Float -> String
fmt f =
    -- 2 decimal places — avoids "1.299999…" spam in the path string.
    let
        rounded =
            toFloat (round (f * 100)) / 100
    in
    String.fromFloat rounded



-- GRID + TICKS


elevationGridLines : Track -> Float -> Float -> Float -> Float -> Float -> List (Svg msg)
elevationGridLines track mPerPx padTop x1 x2 chartHeight =
    let
        -- 28 px between elevation labels keeps them from stacking even on
        -- tight (FitWidth on a phone) charts.
        targetTicks =
            max 2 (floor (chartHeight / 28))

        step =
            niceStep (track.maxEle - track.minEle) targetTicks

        first =
            toFloat (ceiling (track.minEle / step)) * step

        ys =
            buildSeries first (track.maxEle + 0.0001) step

        lineFor e =
            let
                y =
                    padTop + (track.maxEle - e) / mPerPx
            in
            g []
                [ line
                    [ SA.x1 (fmt x1)
                    , SA.x2 (fmt x2)
                    , SA.y1 (fmt y)
                    , SA.y2 (fmt y)
                    , SA.stroke "#1e293b"
                    , SA.strokeDasharray "3 3"
                    ]
                    []
                , text_
                    [ SA.x (fmt (x1 - 8))
                    , SA.y (fmt (y + 4))
                    , SA.textAnchor "end"
                    , SA.fontSize "11"
                    , SA.fill "#64748b"
                    , SA.fontFamily "system-ui, -apple-system, sans-serif"
                    ]
                    [ Svg.text (formatM e) ]
                ]
    in
    List.map lineFor ys


distanceTicks : Float -> Float -> Float -> Float -> Float -> List (Svg msg)
distanceTicks totalDist mPerPx padLeft yBaseline drawWidth =
    let
        -- Reserve ~70 px per distance label ("22 km" with whitespace). Below
        -- 2 ticks we still show start + end; above that, niceStep snaps to
        -- a clean interval.
        targetTicks =
            max 2 (floor (drawWidth / 70))

        step =
            niceStep totalDist targetTicks

        ds =
            buildSeries 0 (totalDist + 0.0001) step

        tick d =
            let
                x =
                    padLeft + d / mPerPx
            in
            g []
                [ line
                    [ SA.x1 (fmt x)
                    , SA.x2 (fmt x)
                    , SA.y1 (fmt yBaseline)
                    , SA.y2 (fmt (yBaseline + 4))
                    , SA.stroke "#475569"
                    ]
                    []
                , text_
                    [ SA.x (fmt x)
                    , SA.y (fmt (yBaseline + 18))
                    , SA.textAnchor "middle"
                    , SA.fontSize "11"
                    , SA.fill "#94a3b8"
                    , SA.fontFamily "system-ui, -apple-system, sans-serif"
                    ]
                    [ Svg.text (formatKmShort d) ]
                ]
    in
    List.map tick ds


buildSeries : Float -> Float -> Float -> List Float
buildSeries start stop step =
    let
        go cur acc =
            if cur > stop then
                List.reverse acc

            else
                go (cur + step) (cur :: acc)
    in
    if step <= 0 then
        []

    else
        go start []


{-| "Nice" axis step — snaps to 1/2/5 × 10^k.
-}
niceStep : Float -> Int -> Float
niceStep range targetTicks =
    if range <= 0 then
        1

    else
        let
            rough =
                range / toFloat targetTicks

            mag =
                10 ^ toFloat (floor (logBase 10 rough))

            normalized =
                rough / mag
        in
        if normalized < 1.5 then
            mag

        else if normalized < 3 then
            2 * mag

        else if normalized < 7 then
            5 * mag

        else
            10 * mag



-- FORMATTING


formatM : Float -> String
formatM m =
    formatFloat 0 m ++ " m"


formatKmShort : Float -> String
formatKmShort m =
    if m == 0 then
        "0"

    else if m < 1000 then
        formatFloat 0 m ++ " m"

    else
        formatFloat 1 (m / 1000) ++ " km"


formatFloat : Int -> Float -> String
formatFloat decimals f =
    let
        mult =
            10 ^ decimals |> toFloat

        rounded =
            toFloat (round (f * mult)) / mult

        s =
            String.fromFloat rounded
    in
    if decimals == 0 then
        case String.split "." s of
            [ whole, _ ] ->
                whole

            _ ->
                s

    else
        s
