port module ChangelogHarness exposing (main)

{-| Test-only harness for the `Changelog` module (WI-4 / TASK-051). Drives the
real compiled `Changelog.diff` (two-way planning-layer diff), the entry codecs
(in `Types`), and `Changelog.union` from Node via `scripts/smoke-changelog.mjs`,
decoding races through the real `Types` codecs. Never imported by the app.

Ops:

  - `diff`  → the typed descriptors `diff (planningLayer before) (planningLayer after)`
              produces, round-tripped through the entry codec
  - `union` → `union a b` over two entry lists, echoing the resulting entryIds

-}

import Changelog
import Json.Decode as D
import Json.Encode as E
import Merge
import Platform
import Types exposing (ChangeDescriptor(..), changeEntryDecoder, decodeRace, encodeChangeEntry)


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

        Ok "diff" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "before" decodeRace) (D.field "after" decodeRace)) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok ( before, after ) ->
                    let
                        changes =
                            Changelog.diff (Merge.planningLayer before) (Merge.planningLayer after)

                        -- Round-trip through the entry codec so a bad encoder/decoder is caught too.
                        entry =
                            { entryId = "t-0", author = "t", authorId = "t-u", timestampMs = 0, source = "local", changes = changes }
                    in
                    case D.decodeValue changeEntryDecoder (encodeChangeEntry entry) of
                        Ok back ->
                            E.object [ ( "changes", E.list (\d -> E.string (kindOf d)) back.changes ) ]

                        Err e ->
                            E.object [ ( "error", E.string ("entry codec round-trip failed: " ++ D.errorToString e) ) ]

        Ok "union" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "a" (D.list changeEntryDecoder)) (D.field "b" (D.list changeEntryDecoder))) v of
                Err e ->
                    E.object [ ( "error", E.string (D.errorToString e) ) ]

                Ok ( a, b ) ->
                    let
                        merged =
                            Changelog.union a b
                    in
                    E.object
                        [ ( "entryIds", E.list (\e -> E.string e.entryId) merged )
                        , ( "count", E.int (List.length merged) )
                        ]

        Ok other ->
            E.object [ ( "error", E.string ("unknown op: " ++ other) ) ]


{-| A coarse tag for each descriptor so the runner can assert what `diff` found.
-}
kindOf : ChangeDescriptor -> String
kindOf d =
    case d of
        AidAdded _ ->
            "aidAdded"

        AidRemoved _ ->
            "aidRemoved"

        AidMoved _ ->
            "aidMoved"

        AidRenamed _ ->
            "aidRenamed"

        AidRetimed _ ->
            "aidRetimed"

        KmNoteAdded _ ->
            "kmNoteAdded"

        KmNoteEdited _ ->
            "kmNoteEdited"

        KmNoteCleared _ ->
            "kmNoteCleared"

        KmPaceSet _ ->
            "kmPaceSet"

        KmPaceChanged _ ->
            "kmPaceChanged"

        KmPaceCleared _ ->
            "kmPaceCleared"

        RaceRenamed _ ->
            "raceRenamed"

        RaceDateChanged _ ->
            "raceDateChanged"

        CourseUploaded ->
            "courseUploaded"

        Merged _ ->
            "merged"
