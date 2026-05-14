module Main exposing (main)

{-| TASK-001 scaffold.

Minimal app: lets the user pick a `.gpx` file, parses it with
`Gpx.parseGPX`, displays track name + total distance + gain + loss.

Persistence, routing, profile rendering, planning, etc. land in
later tasks.

-}

import Browser
import File exposing (File)
import File.Select as Select
import Gpx exposing (Track)
import Html exposing (Html, button, div, h1, p, span, text)
import Html.Attributes as A exposing (class, classList)
import Html.Events exposing (onClick, preventDefaultOn)
import Json.Decode as D
import Task



-- ============================================================
-- MAIN
-- ============================================================


main : Program Flags Model Msg
main =
    Browser.element
        { init = init
        , update = update
        , view = view
        , subscriptions = subscriptions
        }


type alias Flags =
    { width : Float }



-- ============================================================
-- MODEL
-- ============================================================


type State
    = Empty
    | Parsing
    | Failed String
    | Loaded { track : Track, fileName : String }


type alias Model =
    { state : State
    , dragOver : Bool
    }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( { state = Empty, dragOver = False }, Cmd.none )



-- ============================================================
-- MSG / UPDATE
-- ============================================================


type Msg
    = DragEnter
    | DragLeave
    | GotFiles File (List File)
    | OpenPicker
    | PickedFile File
    | GotContent String String
    | Reset


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DragEnter ->
            ( { model | dragOver = True }, Cmd.none )

        DragLeave ->
            ( { model | dragOver = False }, Cmd.none )

        GotFiles file _ ->
            ( { model | dragOver = False, state = Parsing }
            , readFile file
            )

        OpenPicker ->
            ( model, Select.file [ "application/gpx+xml", ".gpx" ] PickedFile )

        PickedFile file ->
            ( { model | state = Parsing }, readFile file )

        GotContent name content ->
            case Gpx.parseGPX content of
                Ok track ->
                    ( { model | state = Loaded { track = track, fileName = name } }
                    , Cmd.none
                    )

                Err err ->
                    ( { model | state = Failed err }, Cmd.none )

        Reset ->
            ( { model | state = Empty }, Cmd.none )


readFile : File -> Cmd Msg
readFile file =
    Task.perform (GotContent (File.name file)) (File.toString file)


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- ============================================================
-- VIEW
-- ============================================================


view : Model -> Html Msg
view model =
    div [ class "min-h-screen flex flex-col" ]
        [ viewHeader
        , div [ class "flex-1 px-6 pb-10" ] [ viewContent model ]
        , viewFooter
        ]


viewHeader : Html Msg
viewHeader =
    div [ class "px-6 py-5 border-b border-slate-800/60 bg-slate-950" ]
        [ div [ class "max-w-screen-2xl mx-auto flex items-baseline gap-4" ]
            [ h1
                [ class "text-2xl font-semibold tracking-tight text-rose-500" ]
                [ text "Trail" ]
            , p [ class "text-sm text-slate-400" ]
                [ text "Prepare your race." ]
            ]
        ]


viewFooter : Html Msg
viewFooter =
    div [ class "px-6 py-4 text-xs text-slate-500 border-t border-slate-800/60 bg-slate-950" ]
        [ div [ class "max-w-screen-2xl mx-auto" ]
            [ text "Local-first. Your GPX never leaves the browser." ]
        ]


viewContent : Model -> Html Msg
viewContent model =
    case model.state of
        Empty ->
            viewDropZone model.dragOver

        Parsing ->
            div [ class "max-w-screen-md mx-auto mt-16 p-6 text-center text-slate-400" ]
                [ text "Parsing GPX…" ]

        Failed err ->
            div [ class "max-w-screen-md mx-auto mt-16 p-6 text-center" ]
                [ p [ class "text-rose-400 mb-4" ] [ text err ]
                , button
                    [ onClick Reset
                    , class "px-4 py-2 bg-rose-600 text-white rounded-md hover:bg-rose-500"
                    ]
                    [ text "Try another file" ]
                ]

        Loaded { track, fileName } ->
            viewLoaded track fileName



-- ============================================================
-- DROP ZONE / LOADED VIEW
-- ============================================================


viewDropZone : Bool -> Html Msg
viewDropZone dragOver =
    div [ class "max-w-screen-md mx-auto mt-20" ]
        [ div
            [ classList
                [ ( "border-2 border-dashed rounded-2xl p-16 text-center transition-colors", True )
                , ( "border-slate-700 bg-slate-900/50", not dragOver )
                , ( "border-rose-500 bg-rose-500/5", dragOver )
                ]
            , preventDefaultOn "dragenter" (D.succeed ( DragEnter, True ))
            , preventDefaultOn "dragover" (D.succeed ( DragEnter, True ))
            , preventDefaultOn "dragleave" (D.succeed ( DragLeave, True ))
            , preventDefaultOn "drop" dropDecoder
            ]
            [ p [ class "text-lg text-slate-200 mb-2" ] [ text "Drop a .gpx file here" ]
            , p [ class "text-sm text-slate-500 mb-6" ] [ text "or" ]
            , button
                [ onClick OpenPicker
                , class "px-5 py-2.5 bg-rose-600 text-white rounded-md hover:bg-rose-500 text-sm font-medium"
                ]
                [ text "Choose a file" ]
            ]
        , p [ class "text-center text-sm text-slate-500 mt-6" ]
            [ text "Your file never leaves the browser." ]
        ]


dropDecoder : D.Decoder ( Msg, Bool )
dropDecoder =
    D.at [ "dataTransfer", "files" ] (D.oneOrMore GotFiles File.decoder)
        |> D.map (\m -> ( m, True ))


viewLoaded : Track -> String -> Html Msg
viewLoaded track fileName =
    div [ class "max-w-screen-md mx-auto mt-16 space-y-8" ]
        [ div [ class "flex items-center justify-between gap-4" ]
            [ div [ class "min-w-0" ]
                [ p [ class "text-2xl font-semibold truncate" ] [ text track.name ]
                , p [ class "text-xs text-slate-500 truncate" ] [ text fileName ]
                ]
            , button
                [ onClick Reset
                , class "px-3 py-1.5 text-sm border border-slate-700 rounded-md hover:bg-slate-800 text-slate-200"
                ]
                [ text "New file" ]
            ]
        , div [ class "grid grid-cols-1 sm:grid-cols-3 gap-4" ]
            [ stat "Distance" (formatKm track.totalDist) "km"
            , stat "Elevation gain" (formatInt track.gain) "m"
            , stat "Elevation loss" (formatInt track.loss) "m"
            ]
        , p [ class "text-sm text-slate-500" ]
            [ text "Parsed "
            , span [ class "text-slate-300" ] [ text (String.fromInt (List.length track.points)) ]
            , text " track points."
            ]
        ]


stat : String -> String -> String -> Html msg
stat label value unit =
    div
        [ class "rounded-xl bg-slate-900 border border-slate-800 p-5" ]
        [ p [ class "text-xs uppercase tracking-wider text-slate-500 mb-2" ] [ text label ]
        , p [ class "flex items-baseline gap-1" ]
            [ span [ class "text-3xl font-semibold text-slate-100" ] [ text value ]
            , span [ class "text-sm text-slate-500" ] [ text unit ]
            ]
        ]



-- ============================================================
-- FORMATTING
-- ============================================================


formatKm : Float -> String
formatKm meters =
    let
        km =
            meters / 1000

        rounded =
            toFloat (round (km * 10)) / 10
    in
    String.fromFloat rounded


formatInt : Float -> String
formatInt v =
    String.fromInt (round v)
