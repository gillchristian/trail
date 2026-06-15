port module CalibrationHarness exposing (main)

{-| Test-only harness: drives the real `Calibration.fitVmh` from Node via
ports, so `scripts/smoke-calibration.mjs` can verify the climb-rate fit
without a browser. Mirrors `SectionsHarness`. Not imported by the app, so it
never ships in the bundle.
-}

import Calibration
import Dict
import Json.Decode as D
import Json.Encode as E
import Planning
import Platform


port run : (D.Value -> msg) -> Sub msg


port result : E.Value -> Cmd msg


main : Program () () D.Value
main =
    Platform.worker
        { init = \_ -> ( (), Cmd.none )
        , update = \v model -> ( model, result (handle v) )
        , subscriptions = \_ -> run identity
        }


type alias KmSpec =
    { index : Int, gain : Float }


type alias RunSpec =
    { kms : List KmSpec, splits : List ( Int, Int ) }


kmSpecDecoder : D.Decoder KmSpec
kmSpecDecoder =
    D.map2 KmSpec (D.field "index" D.int) (D.field "gain" D.float)


pairDecoder : D.Decoder ( Int, Int )
pairDecoder =
    D.map2 Tuple.pair (D.index 0 D.int) (D.index 1 D.int)


runSpecDecoder : D.Decoder RunSpec
runSpecDecoder =
    D.map2 RunSpec
        (D.field "kms" (D.list kmSpecDecoder))
        (D.field "splits" (D.list pairDecoder))


requestDecoder : D.Decoder (List RunSpec)
requestDecoder =
    D.field "runs" (D.list runSpecDecoder)


{-| Only `index` and `gain` matter to `fitVmh`; the rest of the real
`Planning.Km` is filled with neutral values.
-}
toKm : KmSpec -> Planning.Km
toKm s =
    { index = s.index
    , distStart = 0
    , distEnd = 0
    , distance = 0
    , eleStart = 0
    , eleEnd = 0
    , minEle = 0
    , maxEle = 0
    , gain = s.gain
    , loss = 0
    , slope = 0
    , points = []
    , cumDist = []
    }


toRun : RunSpec -> Calibration.Run
toRun s =
    { kms = List.map toKm s.kms, splits = Dict.fromList s.splits }


handle : D.Value -> E.Value
handle v =
    case D.decodeValue requestDecoder v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok specs ->
            E.object [ ( "fit", encodeFit (Calibration.fitVmh (List.map toRun specs)) ) ]


encodeFit : Maybe Calibration.VmhFit -> E.Value
encodeFit mf =
    case mf of
        Just fit ->
            E.object
                [ ( "vmh", E.float fit.vmh )
                , ( "climbKmCount", E.int fit.climbKmCount )
                , ( "runCount", E.int fit.runCount )
                , ( "totalGain", E.float fit.totalGain )
                , ( "totalSeconds", E.int fit.totalSeconds )
                ]

        Nothing ->
            E.null
