module ProjectFile exposing
    ( decode
    , encode
    , filenameFor
    )

{-| `.trail` project file: a single JSON document carrying the
full `Race` (including the original GPX text, all aid stations,
and the per-km plan). Re-importing one creates a *new* race
record — the id is regenerated on save so the user can import the
same `.trail` twice without collisions.

Wrapped with a `version` field so a future format bump (different
shape, additional metadata) can be detected and rejected with a
clear error instead of silently mis-decoding.

**v2 (TASK-047)** adds the `.trail`-sharing identity (`shareId` +
`courseHash`) to the embedded race. The two are plain extra fields that
`decodeRace` already tolerates as absent (back-compat defaults), so a v1
document decodes through the same path — the only change here is widening
the accepted version set to `{1, 2}` instead of an exact-match gate.

-}

import Json.Decode as D
import Json.Encode as E
import Types exposing (Race, decodeRace, encodeRace)


currentVersion : Int
currentVersion =
    2


{-| Versions this build can read. v1 had no `shareId`/`courseHash`; both decode
to "" and are stamped on import (see `Main` / TASK-047).
-}
isSupportedVersion : Int -> Bool
isSupportedVersion v =
    v == 1 || v == 2


encode : Race -> String
encode race =
    E.encode 2
        (E.object
            [ ( "format", E.string "trail-project" )
            , ( "version", E.int currentVersion )
            , ( "race", encodeRace race )
            ]
        )


decode : String -> Result String Race
decode raw =
    case D.decodeString documentDecoder raw of
        Ok race ->
            Ok race

        Err err ->
            Err (D.errorToString err)


documentDecoder : D.Decoder Race
documentDecoder =
    D.field "format" D.string
        |> D.andThen
            (\fmt ->
                if fmt == "trail-project" then
                    D.field "version" D.int
                        |> D.andThen
                            (\v ->
                                if isSupportedVersion v then
                                    D.field "race" decodeRace

                                else
                                    D.fail
                                        ("This .trail file was written for version "
                                            ++ String.fromInt v
                                            ++ ". This build reads versions 1 and "
                                            ++ String.fromInt currentVersion
                                            ++ "."
                                        )
                            )

                else
                    D.fail ("Unknown format field: " ++ fmt)
            )


filenameFor : Race -> String
filenameFor race =
    safe race.name ++ ".trail"


safe : String -> String
safe s =
    let
        trimmed =
            String.trim s

        sanitized =
            String.toList trimmed
                |> List.map sanitizeChar
                |> String.fromList
                |> String.trim

        result =
            String.replace " " "-" sanitized
    in
    if String.isEmpty result then
        "race"

    else
        result


sanitizeChar : Char -> Char
sanitizeChar c =
    if Char.isAlphaNum c || c == '-' || c == '_' || c == '.' then
        c

    else
        ' '
