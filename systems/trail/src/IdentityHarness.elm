port module IdentityHarness exposing (main)

{-| Test-only harness for the pure `Identity` module (WI-5 / TASK-054, ADR-0012).
Drives the real compiled identity logic from Node via
`scripts/smoke-identity.mjs`: the name last-write-wins register (`learn` /
`mergeDirectory`), the import mint/adopt decision (`decideImport` /
`resolveOwnership`), `subsetFor`, and the codecs. Never imported by the app.

Ops: `decide`, `ownership`, `learn`, `merge`, `subset`, `codec`.

-}

import Dict
import Identity exposing (..)
import Json.Decode as D
import Json.Encode as E
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


err : String -> E.Value
err e =
    E.object [ ( "error", E.string e ) ]


meField : D.Decoder (Maybe Me)
meField =
    D.field "me" (D.nullable decodeMe)


answerField : D.Decoder OwnershipAnswer
answerField =
    D.field "answer" D.string
        |> D.andThen
            (\s ->
                case s of
                    "myself" ->
                        D.succeed Myself

                    "someoneElse" ->
                        D.succeed SomeoneElse

                    other ->
                        D.fail ("bad answer: " ++ other)
            )


run2 : D.Value -> D.Decoder a -> (a -> E.Value) -> E.Value
run2 v decoder f =
    case D.decodeValue decoder v of
        Ok a ->
            f a

        Err e ->
            err (D.errorToString e)


handle : D.Value -> E.Value
handle v =
    case D.decodeValue (D.field "op" D.string) v of
        Err e ->
            err (D.errorToString e)

        Ok "decide" ->
            run2 v (D.map2 Tuple.pair meField (D.field "fileOwner" D.string)) <|
                \( me, fileOwner ) ->
                    E.object
                        [ ( "decision"
                          , E.string <|
                                case decideImport me fileOwner of
                                    ImportAsOwner ->
                                        "importAsOwner"

                                    AskOwnership ->
                                        "askOwnership"
                          )
                        ]

        Ok "ownership" ->
            run2 v (D.map3 (\a m o -> ( a, m, o )) answerField meField (D.field "fileOwner" D.string)) <|
                \( answer, me, fileOwner ) ->
                    case resolveOwnership answer me fileOwner of
                        Adopt id ->
                            E.object [ ( "result", E.string "adopt" ), ( "adopt", E.string id ) ]

                        MintThenReview ->
                            E.object [ ( "result", E.string "mintThenReview" ) ]

                        ReviewAs m ->
                            E.object [ ( "result", E.string "reviewAs" ), ( "name", E.string m.displayName ) ]

        Ok "learn" ->
            run2 v
                (D.map4 (\dir uid dn at -> ( dir, uid, DirEntry dn at ))
                    (D.field "dir" decodeDirectory)
                    (D.field "userId" D.string)
                    (D.field "displayName" D.string)
                    (D.field "nameUpdatedAt" D.int)
                    |> D.map (\( dir, uid, entry ) -> ( learn uid entry dir, uid ))
                )
            <|
                \( newDir, uid ) ->
                    E.object
                        [ ( "name", E.string (resolveName newDir uid) )
                        , ( "at", E.int (Dict.get uid newDir |> Maybe.map .nameUpdatedAt |> Maybe.withDefault -1) )
                        ]

        Ok "merge" ->
            run2 v (D.map2 mergeDirectory (D.field "incoming" decodeDirectory) (D.field "local" decodeDirectory)) <|
                \merged ->
                    E.object
                        [ ( "pairs"
                          , merged
                                |> Dict.toList
                                |> E.list (\( uid, e ) -> E.object [ ( "userId", E.string uid ), ( "name", E.string e.displayName ), ( "at", E.int e.nameUpdatedAt ) ])
                          )
                        ]

        Ok "subset" ->
            run2 v (D.map2 subsetFor (D.field "ids" (D.list D.string)) (D.field "dir" decodeDirectory)) <|
                \sub ->
                    E.object [ ( "ids", E.list E.string (Dict.keys sub) ) ]

        Ok "codec" ->
            run2 v (D.map2 Tuple.pair meField (D.field "dir" decodeDirectory)) <|
                \( me, dir ) ->
                    let
                        meBack =
                            me
                                |> Maybe.map encodeMe
                                |> Maybe.andThen (D.decodeValue decodeMe >> Result.toMaybe)

                        dirBack =
                            D.decodeValue decodeDirectory (encodeDirectory dir)
                    in
                    case dirBack of
                        Ok d ->
                            E.object
                                [ ( "me", Maybe.map encodeMe meBack |> Maybe.withDefault E.null )
                                , ( "dir", encodeDirectory d )
                                ]

                        Err e ->
                            err ("directory codec round-trip failed: " ++ D.errorToString e)

        Ok other ->
            err ("unknown op: " ++ other)
