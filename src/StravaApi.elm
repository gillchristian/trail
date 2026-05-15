module StravaApi exposing
    ( Activity
    , fetchActivities
    , fetchStreams
    )

{-| Thin HTTP wrapper for cadence's trail-facing endpoints.

Three URLs are used:

  - `GET /api/activities?days=60` — recent activities.
  - `GET /api/activities/{id}/streams?keys=…` — full streams for one
    activity.

Auth: `Authorization: Bearer <sessionToken>` on every request. 401
is surfaced to the caller; the UI prompts re-auth.

-}

import Http
import Json.Decode as D exposing (Decoder)



-- TYPES


type alias Activity =
    { id : Int
    , name : String
    , distance : Float -- meters
    , movingTime : Int -- seconds
    , startDateLocal : String -- ISO 8601
    , sportType : String
    }



-- FETCH


fetchActivities : String -> String -> Int -> (Result Http.Error (List Activity) -> msg) -> Cmd msg
fetchActivities backendUrl token days toMsg =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url = backendUrl ++ "/api/activities?days=" ++ String.fromInt days
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg activityListDecoder
        , timeout = Just 15000
        , tracker = Nothing
        }


fetchStreams : String -> String -> Int -> (Result Http.Error D.Value -> msg) -> Cmd msg
fetchStreams backendUrl token activityId toMsg =
    Http.request
        { method = "GET"
        , headers = [ Http.header "Authorization" ("Bearer " ++ token) ]
        , url =
            backendUrl
                ++ "/api/activities/"
                ++ String.fromInt activityId
                ++ "/streams?keys=time,distance,latlng,altitude,heartrate"
        , body = Http.emptyBody
        , expect = Http.expectJson toMsg D.value
        , timeout = Just 30000
        , tracker = Nothing
        }



-- DECODE


activityListDecoder : Decoder (List Activity)
activityListDecoder =
    D.list activityDecoder


activityDecoder : Decoder Activity
activityDecoder =
    D.map6 Activity
        (D.field "id" D.int)
        (D.field "name" D.string)
        (D.field "distance" D.float)
        (D.field "moving_time" D.int)
        (D.field "start_date_local" D.string)
        (D.oneOf [ D.field "sport_type" D.string, D.field "type" D.string, D.succeed "Run" ])
