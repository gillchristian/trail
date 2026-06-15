module Calibration exposing (Run, VmhFit, climbGainThreshold, fitVmh)

{-| Fit an athlete's climb rate (`vmh`, m of ascent per hour) from the runs
they've already linked to a race — the first calibration fit (TASK-043,
ADR-0006). It uses only data trail already holds: each linked run's per-km
course gain (from `Planning.computeKms`) and its per-km actual times.

The fit is the **realized climb rate**: total ascent climbed on climb kms,
divided by the total time spent on them. Gain-weighting falls out naturally —
a long sustained climb counts more than a brief rise. Pure; the UI in
`Main.elm` decides whether to surface/apply it.

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
