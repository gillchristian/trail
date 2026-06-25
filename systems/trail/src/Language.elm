module Language exposing (Language(..), decoder, encode, fromCode, toCode)

{-| The set of UI languages trail ships (i18n epic, ADR-0014).

Hand-rolled, type-driven localization: a missing translation must not compile,
so every translation function (`Translations`) and formatter (`Format`) is total
over this type. The codec is keyed on **ISO 639-1 codes** (`toCode`/`fromCode`),
so the serialized form is stable across constructor renames/reorderings. The leaf
`decoder` is strict and total — it fails on an unknown code rather than defaulting
— and the back-compat tolerance for older/partial settings blobs lives one level
up, in `Settings.settingsDecoder` (WI-2).

-}

import Json.Decode as D
import Json.Encode as E


type Language
    = English
    | Spanish


{-| ISO 639-1 code. Total with **no `_ ->`** — adding a constructor fails to
compile here, which is the WI-1 exhaustiveness guarantee.
-}
toCode : Language -> String
toCode lang =
    case lang of
        English ->
            "en"

        Spanish ->
            "es"


fromCode : String -> Maybe Language
fromCode code =
    case code of
        "en" ->
            Just English

        "es" ->
            Just Spanish

        _ ->
            Nothing


encode : Language -> E.Value
encode =
    toCode >> E.string


decoder : D.Decoder Language
decoder =
    D.string
        |> D.andThen
            (\code ->
                case fromCode code of
                    Just lang ->
                        D.succeed lang

                    Nothing ->
                        D.fail ("Unknown language: " ++ code)
            )
