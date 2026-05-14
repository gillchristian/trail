module Route exposing
    ( Route(..)
    , fromUrl
    , href
    , toString
    )

{-| Hash-based router.

We keep paths under the URL fragment so the app works as a static
bundle without server-side rewrites (`#/race/abc` → no 404, no
`historyApiFallback` needed).

-}

import Html
import Html.Attributes as A
import Types exposing (RaceId, raceIdFromString, raceIdToString)
import Url exposing (Url)


type Route
    = Index
    | RaceDetail RaceId
    | NotFound


{-| Routes live in the fragment. The first path is "/", encoded as
either an empty fragment or `#/`. Examples:

    https://trail.app/         -> Index
    https://trail.app/#/       -> Index
    https://trail.app/#/race/abc -> RaceDetail (RaceId "abc")

-}
fromUrl : Url -> Route
fromUrl url =
    case url.fragment |> Maybe.withDefault "" |> normalize of
        "" ->
            Index

        "/" ->
            Index

        "/index" ->
            Index

        path ->
            case splitPath path of
                [ "race", id ] ->
                    if String.isEmpty id then
                        NotFound

                    else
                        RaceDetail (raceIdFromString id)

                _ ->
                    NotFound


normalize : String -> String
normalize s =
    -- collapse leading "/", we treat "/x" and "x" the same below
    if String.startsWith "/" s then
        s

    else if String.isEmpty s then
        ""

    else
        "/" ++ s


splitPath : String -> List String
splitPath path =
    path
        |> String.dropLeft 1
        |> String.split "/"
        |> List.filter (not << String.isEmpty)


toString : Route -> String
toString route =
    case route of
        Index ->
            "#/"

        RaceDetail id ->
            "#/race/" ++ raceIdToString id

        NotFound ->
            "#/404"


href : Route -> Html.Attribute msg
href route =
    A.href (toString route)
