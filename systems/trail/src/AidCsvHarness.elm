port module AidCsvHarness exposing (main)

{-| Test-only harness: drives the real `AidCsv.parse` / `AidCsv.toCsv`
from Node via ports, so `scripts/smoke-aid-csv.mjs` can verify the
parser/encoder against fixtures without a browser. Not imported by the
app (`main.js` → `Main.elm` only), so it never ships in the bundle.
-}

import AidCsv
import Json.Decode as D
import Json.Encode as E
import Platform
import Types exposing (AidStation, serviceToString)


port run : (D.Value -> msg) -> Sub msg


port result : E.Value -> Cmd msg


main : Program () () D.Value
main =
    Platform.worker
        { init = \_ -> ( (), Cmd.none )
        , update = \v model -> ( model, result (handle v) )
        , subscriptions = \_ -> run identity
        }


type alias Request =
    { op : String
    , csv : String
    , totalDistance : Float
    , defaultRestSeconds : Int
    }


requestDecoder : D.Decoder Request
requestDecoder =
    D.map4 Request
        (D.field "op" D.string)
        (D.field "csv" D.string)
        (D.field "totalDistance" D.float)
        (D.field "defaultRestSeconds" D.int)


handle : D.Value -> E.Value
handle v =
    case D.decodeValue requestDecoder v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok req ->
            let
                cfg =
                    { totalDistance = req.totalDistance
                    , defaultRestSeconds = req.defaultRestSeconds
                    }
            in
            if req.op == "roundtrip" then
                let
                    first =
                        AidCsv.parse cfg req.csv

                    csv =
                        AidCsv.toCsv first.stations
                in
                E.object
                    [ ( "op", E.string "roundtrip" )
                    , ( "csv", E.string csv )
                    , ( "result", encodeResult (AidCsv.parse cfg csv) )
                    ]

            else
                E.object
                    [ ( "op", E.string "parse" )
                    , ( "result", encodeResult (AidCsv.parse cfg req.csv) )
                    ]


encodeResult : AidCsv.ParseResult -> E.Value
encodeResult r =
    E.object
        [ ( "stations", E.list encodeStation r.stations )
        , ( "errors", E.list encodeIssue r.errors )
        , ( "warnings", E.list encodeIssue r.warnings )
        ]


encodeStation : AidStation -> E.Value
encodeStation a =
    E.object
        [ ( "name", E.string a.name )
        , ( "distanceM", E.float a.distance )
        , ( "restSeconds", E.int a.restSeconds )
        , ( "services", E.list (serviceToString >> E.string) a.services )
        , ( "cutoff", Maybe.withDefault E.null (Maybe.map E.int a.cutoff) )
        , ( "notes", E.string a.notes )
        ]


encodeIssue : AidCsv.RowIssue -> E.Value
encodeIssue i =
    E.object
        [ ( "row", E.int i.row )
        , ( "message", E.string i.message )
        ]
