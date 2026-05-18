module Csv exposing
    ( kmsCsv
    , sectionsCsv
    )

{-| CSV builders for the planning table.

Two modes:

  - `kmsCsv` — one row per km (plus an interleaved row for each aid
    station so the user can see rest time between kms).
  - `sectionsCsv` — one row per section (between aids), plus an
    interleaved aid-station row showing the planned rest.

Both produce RFC-4180-ish CSV: fields with commas / quotes / newlines
get wrapped in double-quotes; embedded double-quotes are doubled.

-}

import Dict exposing (Dict)
import Planning exposing (Km, KmResult, KmSource(..), Section)
import Types exposing (AidStation, Race, kmPlanFor)


kmsCsv :
    { race : Race
    , kms : List Km
    , results : Dict Int KmResult
    }
    -> String
kmsCsv opts =
    let
        header =
            [ "km"
            , "dist_start_km"
            , "dist_end_km"
            , "distance_km"
            , "ele_start_m"
            , "ele_end_m"
            , "delta_ele_m"
            , "gain_m"
            , "loss_m"
            , "slope_pct"
            , "target_time_s"
            , "target_time"
            , "target_pace_min_per_km"
            , "source"
            , "cumulative_time_s"
            , "cumulative_time"
            , "aid_station_at_km"
            , "aid_rest_s"
            , "notes"
            ]

        aidByKm =
            opts.race.aidStations
                |> List.map (\a -> ( Planning.kmAtDistance a.distance, a ))
                |> List.foldl
                    (\( idx, a ) acc -> Dict.update idx (Just << (\v -> a :: Maybe.withDefault [] v)) acc)
                    Dict.empty

        rows =
            buildKmRows opts.race aidByKm opts.results opts.kms
    in
    encodeRows header rows


buildKmRows :
    Race
    -> Dict Int (List AidStation)
    -> Dict Int KmResult
    -> List Km
    -> List (List String)
buildKmRows race aidByKm results kms =
    let
        go km ( running, acc ) =
            let
                result =
                    Dict.get km.index results
                        |> Maybe.withDefault { seconds = 0, source = AutoComputed }

                stops =
                    Dict.get km.index aidByKm |> Maybe.withDefault []

                stopRest =
                    List.foldl (\a sum -> sum + a.restSeconds) 0 stops

                kmClockTime =
                    result.seconds + stopRest

                newRunning =
                    running + kmClockTime

                kp =
                    kmPlanFor km.index race.plan

                source =
                    case result.source of
                        UserManual ->
                            "manual"

                        AutoComputed ->
                            "auto"

                aidName =
                    stops
                        |> List.map .name
                        |> String.join " · "

                pace =
                    paceForRow result.seconds km.distance

                row =
                    [ String.fromInt (km.index + 1)
                    , formatFloat 3 (km.distStart / 1000)
                    , formatFloat 3 (km.distEnd / 1000)
                    , formatFloat 3 (km.distance / 1000)
                    , formatInt km.eleStart
                    , formatInt km.eleEnd
                    , formatInt (km.eleEnd - km.eleStart)
                    , formatInt km.gain
                    , formatInt km.loss
                    , formatFloat 2 (km.slope * 100)
                    , String.fromInt kmClockTime
                    , formatHhmmss kmClockTime
                    , pace
                    , source
                    , String.fromInt newRunning
                    , formatHhmmss newRunning
                    , aidName
                    , String.fromInt stopRest
                    , kp.notes
                    ]
            in
            ( newRunning, row :: acc )

        ( _, rowsRev ) =
            List.foldl go ( 0, [] ) kms
    in
    List.reverse rowsRev


sectionsCsv :
    { race : Race
    , kms : List Km
    , results : Dict Int KmResult
    }
    -> String
sectionsCsv opts =
    let
        header =
            [ "section"
            , "label"
            , "dist_start_km"
            , "dist_end_km"
            , "distance_km"
            , "gain_m"
            , "loss_m"
            , "section_time_s"
            , "section_time"
            , "section_pace_min_per_km"
            , "aid_after"
            , "aid_rest_s"
            , "aid_rest"
            , "cumulative_after_aid_s"
            , "cumulative_after_aid"
            ]

        sections =
            Planning.sectionsForRace
                { totalDistance = opts.race.distance
                , aidStations = opts.race.aidStations
                , kms = opts.kms
                }

        rows =
            buildSectionRows opts.results sections
    in
    encodeRows header rows


buildSectionRows : Dict Int KmResult -> List Section -> List (List String)
buildSectionRows results sections =
    let
        go section ( running, acc ) =
            let
                seconds =
                    section.kmIndices
                        |> List.filterMap (\idx -> Dict.get idx results)
                        |> List.foldl (\r sum -> sum + r.seconds) 0

                aidRest =
                    section.followedByAid
                        |> Maybe.map .restSeconds
                        |> Maybe.withDefault 0

                runningAfterAid =
                    running + seconds + aidRest

                row =
                    [ String.fromInt (section.index + 1)
                    , section.label
                    , formatFloat 3 (section.distStart / 1000)
                    , formatFloat 3 (section.distEnd / 1000)
                    , formatFloat 3 (section.distance / 1000)
                    , formatInt section.gain
                    , formatInt section.loss
                    , String.fromInt seconds
                    , formatHhmmss seconds
                    , paceForRow seconds section.distance
                    , section.followedByAid |> Maybe.map .name |> Maybe.withDefault ""
                    , String.fromInt aidRest
                    , formatHhmmss aidRest
                    , String.fromInt runningAfterAid
                    , formatHhmmss runningAfterAid
                    ]
            in
            ( runningAfterAid, row :: acc )

        ( _, rowsRev ) =
            List.foldl go ( 0, [] ) sections
    in
    List.reverse rowsRev



-- ENCODE


encodeRows : List String -> List (List String) -> String
encodeRows header rows =
    (encodeRow header :: List.map encodeRow rows)
        |> String.join "\u{000D}\n"


encodeRow : List String -> String
encodeRow fields =
    fields
        |> List.map encodeField
        |> String.join ","


encodeField : String -> String
encodeField s =
    let
        needsQuote =
            String.contains "," s
                || String.contains "\"" s
                || String.contains "\n" s
                || String.contains "\u{000D}" s
    in
    if needsQuote then
        "\"" ++ String.replace "\"" "\"\"" s ++ "\""

    else
        s



-- FORMATTING


formatFloat : Int -> Float -> String
formatFloat decimals f =
    let
        mult =
            10 ^ decimals |> toFloat

        rounded =
            toFloat (round (f * mult)) / mult
    in
    String.fromFloat rounded


formatInt : Float -> String
formatInt f =
    String.fromInt (round f)


formatHhmmss : Int -> String
formatHhmmss totalSeconds =
    let
        h =
            totalSeconds // 3600

        m =
            modBy 60 (totalSeconds // 60)

        s =
            modBy 60 totalSeconds
    in
    String.padLeft 2 '0' (String.fromInt h)
        ++ ":"
        ++ String.padLeft 2 '0' (String.fromInt m)
        ++ ":"
        ++ String.padLeft 2 '0' (String.fromInt s)


paceForRow : Int -> Float -> String
paceForRow secs meters =
    if secs <= 0 || meters <= 0 then
        ""

    else
        let
            secPerKm =
                toFloat secs * 1000 / meters

            m =
                floor (secPerKm / 60)

            s =
                round (secPerKm - toFloat (m * 60))
        in
        String.fromInt m ++ ":" ++ String.padLeft 2 '0' (String.fromInt s)
