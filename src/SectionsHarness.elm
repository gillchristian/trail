port module SectionsHarness exposing (main)

{-| Test-only harness: drives the real `Planning.sectionsForRace` from Node
via ports, so `scripts/smoke-sections.mjs` can verify that kms partition
cleanly across sections — a km straddling an aid-station distance is counted
in exactly one section, never both — without a browser. Mirrors
`AidCsvHarness`. Not imported by the app (`main.js` → `Main.elm` only), so it
never ships in the bundle.
-}

import Json.Decode as D
import Json.Encode as E
import Planning
import Platform
import Types exposing (AidStation)


port run : (D.Value -> msg) -> Sub msg


port result : E.Value -> Cmd msg


main : Program () () D.Value
main =
    Platform.worker
        { init = \_ -> ( (), Cmd.none )
        , update = \v model -> ( model, result (handle v) )
        , subscriptions = \_ -> run identity
        }


{-| The fields `sectionsForRace` actually reads off a km; the rest of the
real `Planning.Km` record is filled with neutral values by `toKm`.
-}
type alias KmSpec =
    { index : Int
    , distStart : Float
    , distEnd : Float
    , gain : Float
    , loss : Float
    }


type alias Request =
    { totalDistance : Float
    , kms : List KmSpec
    , aids : List Float
    }


kmSpecDecoder : D.Decoder KmSpec
kmSpecDecoder =
    D.map5 KmSpec
        (D.field "index" D.int)
        (D.field "distStart" D.float)
        (D.field "distEnd" D.float)
        (D.field "gain" D.float)
        (D.field "loss" D.float)


requestDecoder : D.Decoder Request
requestDecoder =
    D.map3 Request
        (D.field "totalDistance" D.float)
        (D.field "kms" (D.list kmSpecDecoder))
        (D.field "aids" (D.list D.float))


toKm : KmSpec -> Planning.Km
toKm s =
    { index = s.index
    , distStart = s.distStart
    , distEnd = s.distEnd
    , distance = s.distEnd - s.distStart
    , eleStart = 0
    , eleEnd = 0
    , minEle = 0
    , maxEle = 0
    , gain = s.gain
    , loss = s.loss
    , slope = 0
    , points = []
    , cumDist = []
    }


toAid : Int -> Float -> AidStation
toAid i d =
    { id = "aid-" ++ String.fromInt i
    , name = "Aid " ++ String.fromInt (i + 1)
    , distance = d
    , restSeconds = 0
    , services = []
    , notes = ""
    , cutoff = Nothing
    }


handle : D.Value -> E.Value
handle v =
    case D.decodeValue requestDecoder v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok req ->
            let
                sections =
                    Planning.sectionsForRace
                        { totalDistance = req.totalDistance
                        , aidStations = List.indexedMap toAid req.aids
                        , kms = List.map toKm req.kms
                        }
            in
            E.object [ ( "sections", E.list encodeSection sections ) ]


encodeSection : Planning.Section -> E.Value
encodeSection s =
    E.object
        [ ( "index", E.int s.index )
        , ( "label", E.string s.label )
        , ( "distStart", E.float s.distStart )
        , ( "distEnd", E.float s.distEnd )
        , ( "distance", E.float s.distance )
        , ( "gain", E.float s.gain )
        , ( "loss", E.float s.loss )
        , ( "kmIndices", E.list E.int s.kmIndices )
        ]
