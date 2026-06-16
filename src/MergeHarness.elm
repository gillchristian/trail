port module MergeHarness exposing (main)

{-| Test-only harness for the `Merge` module (WI-2 course freeze; grown by WI-3).
Drives the real compiled `Merge.planningLayer` / `Merge.withPlanningLayer` from
Node via `scripts/smoke-merge.mjs`, decoding/encoding races through the real
`Types` codecs so the freeze is verified end-to-end without a browser. Never
imported by the app.

Ops:

  - `freeze`    → reassemble `withPlanningLayer (planningLayer source) local`,
                  echo the encoded result (the runner checks the course came
                  from `local`, the plan from `source`)
  - `roundtrip` → `withPlanningLayer (planningLayer r) r`, echoed (must equal r)

-}

import Json.Decode as D
import Json.Encode as E
import Merge
import Platform
import Types exposing (decodeRace, encodeRace)


port run : (D.Value -> msg) -> Sub msg


port result : E.Value -> Cmd msg


main : Program () () D.Value
main =
    Platform.worker
        { init = \_ -> ( (), Cmd.none )
        , update = \v model -> ( model, result (handle v) )
        , subscriptions = \_ -> run identity
        }


handle : D.Value -> E.Value
handle v =
    case D.decodeValue (D.field "op" D.string) v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok "freeze" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "local" decodeRace) (D.field "source" decodeRace)) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok ( local, source ) ->
                    E.object
                        [ ( "result", encodeRace (Merge.withPlanningLayer (Merge.planningLayer source) local) ) ]

        Ok "roundtrip" ->
            case D.decodeValue (D.field "race" decodeRace) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok race ->
                    E.object
                        [ ( "result", encodeRace (Merge.withPlanningLayer (Merge.planningLayer race) race) ) ]

        Ok other ->
            E.object [ ( "error", E.string ("unknown op: " ++ other) ) ]
