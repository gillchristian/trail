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
    | RaceMap RaceId
    | PlanTable RaceId
    | PlanKm RaceId Int
    | PlanSection RaceId Int
    | ProfileSettings
    | NotFound


{-| Routes live in the fragment. Examples:

    /                          -> Index
    /#/                        -> Index
    /#/race/abc                -> RaceDetail (RaceId "abc")
    /#/race/abc/plan           -> PlanTable (RaceId "abc")
    /#/race/abc/plan/0         -> PlanKm (RaceId "abc") 0

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

        "/profile" ->
            ProfileSettings

        path ->
            case splitPath path of
                [ "race", id ] ->
                    if String.isEmpty id then
                        NotFound

                    else
                        RaceDetail (raceIdFromString id)

                [ "race", id, "plan" ] ->
                    if String.isEmpty id then
                        NotFound

                    else
                        PlanTable (raceIdFromString id)

                [ "race", id, "map" ] ->
                    if String.isEmpty id then
                        NotFound

                    else
                        RaceMap (raceIdFromString id)

                [ "race", id, "plan", kmStr ] ->
                    case ( String.isEmpty id, String.toInt kmStr ) of
                        ( False, Just km ) ->
                            if km >= 0 then
                                PlanKm (raceIdFromString id) km

                            else
                                NotFound

                        _ ->
                            NotFound

                [ "race", id, "plan", "section", secStr ] ->
                    case ( String.isEmpty id, String.toInt secStr ) of
                        ( False, Just sec ) ->
                            if sec >= 0 then
                                PlanSection (raceIdFromString id) sec

                            else
                                NotFound

                        _ ->
                            NotFound

                _ ->
                    NotFound


normalize : String -> String
normalize s =
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

        RaceMap id ->
            "#/race/" ++ raceIdToString id ++ "/map"

        PlanTable id ->
            "#/race/" ++ raceIdToString id ++ "/plan"

        PlanKm id km ->
            "#/race/" ++ raceIdToString id ++ "/plan/" ++ String.fromInt km

        PlanSection id sec ->
            "#/race/" ++ raceIdToString id ++ "/plan/section/" ++ String.fromInt sec

        ProfileSettings ->
            "#/profile"

        NotFound ->
            "#/404"


href : Route -> Html.Attribute msg
href route =
    A.href (toString route)
