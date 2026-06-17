port module TrailSyncHarness exposing (main)

{-| Test-only harness: drives the real `TrailSync` (course hash + import guard)
and `ProjectFile.decode` (v1/v2 back-compat) from Node via ports, so
`scripts/smoke-trailsync.mjs` can verify the WI-1 identity/integrity layer
without a browser. Mirrors `SectionsHarness` / `CalibrationHarness`; never
imported by the app, so it stays out of the bundle.

Three ops, dispatched on a `"op"` field:

  - `hash`     → `{ hash }` for a GPX string (`TrailSync.courseHashFromGpxText`)
  - `classify` → `{ verdict, message }` for an incoming/target identity pair
  - `decode`   → `{ ok, shareId, courseHash, owner, name, peopleCount, versionCount,
                 baseName }` for a `.trail` (`peopleCount` = the denormalized WI-5
                 name pairs; `versionCount`/`baseName` = the WI-3 merge state — the
                 version-vector size + the merge-ancestor's name, TASK-056)

-}

import Dict
import Json.Decode as D
import Json.Encode as E
import Platform
import ProjectFile
import TrailSync exposing (ImportVerdict(..))
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

        Ok "hash" ->
            handleHash v

        Ok "classify" ->
            handleClassify v

        Ok "decode" ->
            handleDecode v

        Ok "encode" ->
            handleEncode v

        Ok "ensureIdentity" ->
            case D.decodeValue (D.field "race" decodeRace) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok race ->
                    E.object [ ( "race", encodeRace (TrailSync.ensureIdentity race) ) ]

        Ok other ->
            E.object [ ( "error", E.string ("unknown op: " ++ other) ) ]


handleHash : D.Value -> E.Value
handleHash v =
    case D.decodeValue (D.field "gpx" D.string) v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok gpx ->
            E.object [ ( "hash", E.string (TrailSync.courseHashFromGpxText gpx) ) ]


type alias Identity =
    { shareId : String, courseHash : String }


identityDecoder : D.Decoder Identity
identityDecoder =
    D.map2 Identity
        (D.field "shareId" D.string)
        (D.field "courseHash" D.string)


handleClassify : D.Value -> E.Value
handleClassify v =
    case D.decodeValue (D.map2 Tuple.pair (D.field "incoming" identityDecoder) (D.field "target" identityDecoder)) v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok ( incoming, target ) ->
            let
                verdict =
                    TrailSync.classify incoming target
            in
            E.object
                [ ( "verdict", E.string (verdictName verdict) )
                , ( "message", E.string (TrailSync.verdictMessage verdict) )
                ]


verdictName : ImportVerdict -> String
verdictName verdict =
    case verdict of
        Mergeable ->
            "Mergeable"

        DifferentRace ->
            "DifferentRace"

        DifferentCourse ->
            "DifferentCourse"


handleDecode : D.Value -> E.Value
handleDecode v =
    case D.decodeValue (D.field "trail" D.string) v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok trail ->
            case ProjectFile.decode trail of
                Err err ->
                    E.object [ ( "ok", E.bool False ), ( "error", E.string err ) ]

                Ok ( race, people ) ->
                    E.object
                        [ ( "ok", E.bool True )
                        , ( "shareId", E.string race.shareId )
                        , ( "courseHash", E.string race.courseHash )
                        , ( "owner", E.string race.owner )
                        , ( "name", E.string race.name )
                        , ( "peopleCount", E.int (Dict.size people) )
                        , ( "versionCount", E.int (Dict.size race.version) )
                        , ( "baseName"
                          , race.mergeBase
                                |> Maybe.map (\b -> E.string b.name)
                                |> Maybe.withDefault E.null
                          )
                        ]


{-| Decode a `.trail` then re-encode it, returning the encoded string — so the
runner can confirm the exporter emits the current format version + the identity
fields (and that a v1 doc re-exports as v2).
-}
handleEncode : D.Value -> E.Value
handleEncode v =
    case D.decodeValue (D.field "trail" D.string) v of
        Err e ->
            E.object [ ( "error", E.string (D.errorToString e) ) ]

        Ok trail ->
            case ProjectFile.decode trail of
                Err err ->
                    E.object [ ( "error", E.string err ) ]

                Ok ( race, people ) ->
                    -- Re-encode with the decoded `people` as the directory, so the
                    -- round-trip exercises the denormalization (subsetFor embeds
                    -- the owner's entry) — WI-5 / TASK-054.
                    E.object [ ( "encoded", E.string (ProjectFile.encode people race) ) ]
