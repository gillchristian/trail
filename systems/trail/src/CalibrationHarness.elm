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
    { index : Int, gain : Float, slope : Float, distance : Float }


type alias RunSpec =
    { kms : List KmSpec, splits : List ( Int, Int ) }


kmSpecDecoder : D.Decoder KmSpec
kmSpecDecoder =
    D.map4 KmSpec
        (D.field "index" D.int)
        (optionalFloat "gain")
        (optionalFloat "slope")
        (optionalFloat "distance")


optionalFloat : String -> D.Decoder Float
optionalFloat key =
    D.oneOf [ D.field key D.float, D.succeed 0 ]


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


{-| Only `index`/`gain` (fitVmh) and `slope`/`distance` (fitFlatPace) matter;
the rest of the real `Planning.Km` is filled with neutral values.
-}
toKm : KmSpec -> Planning.Km
toKm s =
    { index = s.index
    , distStart = 0
    , distEnd = 0
    , distance = s.distance
    , eleStart = 0
    , eleEnd = 0
    , minEle = 0
    , maxEle = 0
    , gain = s.gain
    , loss = 0
    , slope = s.slope
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
            let
                runs =
                    List.map toRun specs
            in
            E.object
                [ ( "vmh", encodeVmhFit (Calibration.fitVmh runs) )
                , ( "flat", encodeFlatFit (Calibration.fitFlatPace runs) )
                ]


encodeVmhFit : Maybe Calibration.VmhFit -> E.Value
encodeVmhFit mf =
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


encodeFlatFit : Maybe Calibration.FlatPaceFit -> E.Value
encodeFlatFit mf =
    case mf of
        Just fit ->
            E.object
                [ ( "paceSecPerKm", E.int fit.paceSecPerKm )
                , ( "runnableKmCount", E.int fit.runnableKmCount )
                , ( "runCount", E.int fit.runCount )
                , ( "totalDistanceM", E.float fit.totalDistanceM )
                , ( "totalSeconds", E.int fit.totalSeconds )
                ]

        Nothing ->
            E.null
