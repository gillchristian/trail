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

import Dict exposing (Dict)
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

        Ok "mintAid" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "deviceId" D.string) (D.field "seq" D.int)) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok ( deviceId, seq ) ->
                    E.object [ ( "id", E.string (Merge.mintAidId deviceId seq) ) ]

        Ok "classify" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "mine" vectorDecoder) (D.field "theirs" vectorDecoder)) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok ( mine, theirs ) ->
                    E.object [ ( "rel", E.string (relName (Merge.classifyVersions mine theirs)) ) ]

        Ok "merge" ->
            case D.decodeValue mergeInputDecoder v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok ( baseR, mineR, theirsR ) ->
                    let
                        mineLayer =
                            Merge.planningLayer mineR

                        theirsLayer =
                            Merge.planningLayer theirsR

                        res =
                            Merge.mergePlanningLayer (Merge.planningLayer baseR) mineLayer theirsLayer

                        -- Fold every conflict to theirs, to exercise `resolve`.
                        resolvedLayer =
                            List.foldl (\c acc -> Merge.resolve c.key theirsLayer acc) res.merged res.conflicts
                    in
                    E.object
                        [ ( "merged", encodeRace (Merge.withPlanningLayer res.merged mineR) )
                        , ( "resolvedAll", encodeRace (Merge.withPlanningLayer resolvedLayer mineR) )
                        , ( "conflicts"
                          , E.list
                                (\c ->
                                    E.object
                                        [ ( "label", E.string c.label )
                                        , ( "mine", E.string c.mine )
                                        , ( "theirs", E.string c.theirs )
                                        ]
                                )
                                res.conflicts
                          )
                        ]

        Ok other ->
            E.object [ ( "error", E.string ("unknown op: " ++ other) ) ]


vectorDecoder : D.Decoder (Dict String Int)
vectorDecoder =
    D.dict D.int


mergeInputDecoder : D.Decoder ( Types.Race, Types.Race, Types.Race )
mergeInputDecoder =
    D.map3 (\b m t -> ( b, m, t ))
        (D.field "base" decodeRace)
        (D.field "mine" decodeRace)
        (D.field "theirs" decodeRace)


relName : Merge.VersionRel -> String
relName rel =
    case rel of
        Merge.Same ->
            "Same"

        Merge.FastForward ->
            "FastForward"

        Merge.Behind ->
            "Behind"

        Merge.Diverged ->
            "Diverged"
