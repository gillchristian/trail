module Calibration exposing
    ( FlatPaceFit
    , Run
    , VmhFit
    , climbGainThreshold
    , fitFlatPace
    , fitVmh
    , runnableSlopeThreshold
    )

{-| Fit an athlete's pace model from the runs they've already linked to a race,
using only data trail already holds: each linked run's per-km course profile
(from `Planning.computeKms`) and its per-km actual times. Both fits follow one
**realized-rate** method (ADR-0006/0007): aggregate the relevant terrain across
runs and divide — no regression, naturally distance/gain-weighted. Pure; the UI
in `Main.elm` decides whether to surface/apply.

  - `fitVmh` — climb rate (`vmh`, m ascent/hour): total ascent on climb kms ÷
    total time on them (TASK-043).
  - `fitFlatPace` — flat-trail pace (s/km): total runnable distance ÷ total
    runnable time, inverted to a pace (TASK-044).

-}

import Dict exposing (Dict)
import Planning exposing (Km)


{-| One linked run: the course's per-km windows and the actual per-km times
(seconds), keyed by `Km.index`.
-}
type alias Run =
    { kms : List Km
    , splits : Dict Int Int
    }


type alias VmhFit =
    { vmh : Float -- fitted climb rate, m of ascent per hour
    , climbKmCount : Int -- climb kms that contributed
    , runCount : Int -- runs that contributed at least one climb km
    , totalGain : Float -- ascent summed over the climb kms (m)
    , totalSeconds : Int -- time summed over the climb kms (s)
    }


{-| Minimum ascent (m) for a km to count as a "climb km". A km that barely
rises is mostly flat running and would bias the climb-rate fit downward.
-}
climbGainThreshold : Float
climbGainThreshold =
    30


{-| Fit `vmh` from linked runs. `Nothing` when there's no usable climb data
(no km clears the gain threshold with a positive recorded time).
-}
fitVmh : List Run -> Maybe VmhFit
fitVmh runs =
    let
        contribsPerRun : List (List ( Float, Int ))
        contribsPerRun =
            List.map runContributions runs

        all : List ( Float, Int )
        all =
            List.concat contribsPerRun

        runCount : Int
        runCount =
            contribsPerRun
                |> List.filter (not << List.isEmpty)
                |> List.length

        totalGain : Float
        totalGain =
            List.foldl (\( g, _ ) acc -> acc + g) 0 all

        totalSeconds : Int
        totalSeconds =
            List.foldl (\( _, s ) acc -> acc + s) 0 all

        climbKmCount : Int
        climbKmCount =
            List.length all
    in
    if climbKmCount == 0 || totalSeconds <= 0 then
        Nothing

    else
        Just
            { vmh = totalGain * 3600 / toFloat totalSeconds
            , climbKmCount = climbKmCount
            , runCount = runCount
            , totalGain = totalGain
            , totalSeconds = totalSeconds
            }


{-| The `(gain, seconds)` pairs a single run contributes: its climb kms (gain
≥ threshold) that have a positive recorded actual time.
-}
runContributions : Run -> List ( Float, Int )
runContributions run =
    run.kms
        |> List.filterMap
            (\km ->
                if km.gain >= climbGainThreshold then
                    case Dict.get km.index run.splits of
                        Just secs ->
                            if secs > 0 then
                                Just ( km.gain, secs )

                            else
                                Nothing

                        Nothing ->
                            Nothing

                else
                    Nothing
            )



-- FLAT-TRAIL PACE (TASK-044, ADR-0007)


type alias FlatPaceFit =
    { paceSecPerKm : Int -- fitted flat-trail pace, seconds per km
    , runnableKmCount : Int -- runnable kms that contributed
    , runCount : Int -- runs that contributed at least one runnable km
    , totalDistanceM : Float -- distance summed over the runnable kms (m)
    , totalSeconds : Int -- time summed over the runnable kms (s)
    }


{-| A km counts as "runnable" when its grade is gentle enough that the predictor
treats it as runnable rather than climb/descent: `abs slope < 0.04`
(`Predictor.elm`). Matching the predictor keeps the fit and the model consistent.
-}
runnableSlopeThreshold : Float
runnableSlopeThreshold =
    0.04


{-| Fit flat-trail pace from linked runs. `Nothing` when there's no usable
runnable data (no gentle-grade km with a positive distance and time).
-}
fitFlatPace : List Run -> Maybe FlatPaceFit
fitFlatPace runs =
    let
        contribsPerRun : List (List ( Float, Int ))
        contribsPerRun =
            List.map runnableContributions runs

        all : List ( Float, Int )
        all =
            List.concat contribsPerRun

        runCount : Int
        runCount =
            contribsPerRun
                |> List.filter (not << List.isEmpty)
                |> List.length

        totalDistanceM : Float
        totalDistanceM =
            List.foldl (\( d, _ ) acc -> acc + d) 0 all

        totalSeconds : Int
        totalSeconds =
            List.foldl (\( _, s ) acc -> acc + s) 0 all

        runnableKmCount : Int
        runnableKmCount =
            List.length all
    in
    if runnableKmCount == 0 || totalDistanceM <= 0 then
        Nothing

    else
        Just
            { paceSecPerKm = round (toFloat totalSeconds / (totalDistanceM / 1000))
            , runnableKmCount = runnableKmCount
            , runCount = runCount
            , totalDistanceM = totalDistanceM
            , totalSeconds = totalSeconds
            }


{-| The `(distanceM, seconds)` pairs a run contributes: its runnable kms
(gentle grade) that have a positive distance and a positive recorded time.
-}
runnableContributions : Run -> List ( Float, Int )
runnableContributions run =
    run.kms
        |> List.filterMap
            (\km ->
                if abs km.slope < runnableSlopeThreshold && km.distance > 0 then
                    case Dict.get km.index run.splits of
                        Just secs ->
                            if secs > 0 then
                                Just ( km.distance, secs )

                            else
                                Nothing

                        Nothing ->
                            Nothing

                else
                    Nothing
            )
