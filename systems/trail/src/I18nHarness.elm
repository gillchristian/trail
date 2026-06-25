port module I18nHarness exposing (main)

{-| Test-only harness for the pure i18n core (i18n epic, ADR-0014). Drives the
real compiled modules from Node via `scripts/smoke-i18n.mjs`, the same
`Platform.worker` + `run`/`result` port shape as the other smoke harnesses.

Grows with the machinery tasks:

  - TASK-058: `Language` — codec round-trip + strict decode.
  - TASK-059: `Settings` — first-run/back-compat resolution + codec.
  - TASK-060 (this slice): `Format` — decimal-separator localization.

Never imported by the app.

Ops:

  - `decode` (Language code → ok? + re-encoded code)
  - `resolveSettings` (raw value + browser locale → resolved language code)
  - `encodeSettings` (language code → the encoded Settings JSON)
  - `format` (language + decimals + value → localized number string)
  - `localize` (language + string → separator-localized string)

-}

import Format
import Json.Decode as D
import Json.Encode as E
import Language
import Platform
import Settings


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


handle : D.Value -> E.Value
handle v =
    case D.decodeValue (D.field "op" D.string) v of
        Err e ->
            err (D.errorToString e)

        Ok "decode" ->
            case D.decodeValue (D.field "code" D.string) v of
                Err e ->
                    err (D.errorToString e)

                Ok code ->
                    -- Decode the code through the real leaf decoder, then
                    -- re-encode via toCode: proves both the fromCode→toCode
                    -- round-trip and the strict-failure path in one op.
                    case D.decodeValue Language.decoder (E.string code) of
                        Ok lang ->
                            E.object
                                [ ( "ok", E.bool True )
                                , ( "code", E.string (Language.toCode lang) )
                                ]

                        Err _ ->
                            E.object [ ( "ok", E.bool False ) ]

        Ok "resolveSettings" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "raw" D.value) (D.field "browser" D.string)) v of
                Err e ->
                    err (D.errorToString e)

                Ok ( raw, browser ) ->
                    -- The real boot path: a stored object wins (field defaults),
                    -- null routes to the browser primary-subtag default.
                    E.object
                        [ ( "code", E.string (Language.toCode (Settings.fromFlags raw browser).language) ) ]

        Ok "encodeSettings" ->
            case D.decodeValue (D.field "code" D.string) v of
                Err e ->
                    err (D.errorToString e)

                Ok code ->
                    let
                        lang =
                            Language.fromCode code |> Maybe.withDefault Language.English
                    in
                    E.object [ ( "encoded", Settings.encode { language = lang } ) ]

        Ok "format" ->
            case D.decodeValue (D.map3 (\l d val -> ( l, d, val )) (D.field "lang" Language.decoder) (D.field "decimals" D.int) (D.field "value" D.float)) v of
                Err e ->
                    err (D.errorToString e)

                Ok ( lang, decimals, value ) ->
                    E.object [ ( "out", E.string (Format.number lang decimals value) ) ]

        Ok "localize" ->
            case D.decodeValue (D.map2 Tuple.pair (D.field "lang" Language.decoder) (D.field "s" D.string)) v of
                Err e ->
                    err (D.errorToString e)

                Ok ( lang, s ) ->
                    E.object [ ( "out", E.string (Format.localizeDecimal lang s) ) ]

        Ok other ->
            err ("unknown op: " ++ other)
