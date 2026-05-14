module Profile exposing
    ( ScaleMode(..)
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



-- CHART


view : Track -> ScaleMode -> Float -> Html msg
view track mode containerWidth =
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
            16

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

        pathD =
            buildAreaPath coords (padTop + chartHeight)

        strokeD =
            buildStrokePath coords

        gridLines =
            elevationGridLines track mPerPx padTop padLeft (padLeft + drawWidth)

        kmTicks =
            distanceTicks track.totalDist mPerPx padLeft (padTop + chartHeight)
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
                    , Svg.stop [ SA.offset "100%", SA.stopColor "#E52E3A", SA.stopOpacity "0.1" ] []
                    ]
                ]
            , g [] gridLines
            , path
                [ SA.d pathD
                , SA.fill "url(#elev-fill)"
                , SA.stroke "none"
                ]
                []
            , path
                [ SA.d strokeD
                , SA.fill "none"
                , SA.stroke "#ff5f6a"
                , SA.strokeWidth "1.5"
                , SA.strokeLinejoin "round"
                , SA.strokeLinecap "round"
                ]
                []
            , g [] kmTicks
            ]
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


fmt : Float -> String
fmt f =
    -- 2 decimal places — avoids "1.299999…" spam in the path string.
    let
        rounded =
            toFloat (round (f * 100)) / 100
    in
    String.fromFloat rounded



-- GRID + TICKS


elevationGridLines : Track -> Float -> Float -> Float -> Float -> List (Svg msg)
elevationGridLines track mPerPx padTop x1 x2 =
    let
        step =
            niceStep (track.maxEle - track.minEle) 5

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


distanceTicks : Float -> Float -> Float -> Float -> List (Svg msg)
distanceTicks totalDist mPerPx padLeft yBaseline =
    let
        step =
            niceStep totalDist 8

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
