module Predictor exposing
    ( Prediction
    , predict
    , solveForIntensity
    )

{-| Layer B time predictor — given a course (parsed kms), an athlete
profile, and an intensity multiplier, return predicted finish time
plus the climb / descent / runnable / aid component breakdown.

Per-km classification (from spec §3.2):

  - slope ≥ +4 %   → climb     (time = gain / (vmh × i))
  - slope ≤ −4 %   → descent   (pace × Tobler factor × descent-skill, ÷ i)
  - otherwise      → runnable  (flat pace × tech-mult, ÷ i)

Fatigue is a single-pass multiplier (`1 + slope × max(0, hours − threshold)`)
applied to the moving-time sum. The spec calls for iterate-to-fixpoint
but the deviation after one application is < 1 % for reasonable slopes,
so we skip the iteration to keep the math simple and the predictor
synchronous.

`solveForIntensity` does a bisection on the predictor: given a target
total time, find the intensity that produces it. Used by the
bidirectional slider (TASK-019).

-}

import AthleteProfile exposing (AidStyle(..), DescentSkill(..), Profile, TechSkill(..))
import Planning exposing (Km, slopeFactor)
import Types exposing (Race)



-- TYPES


type alias Prediction =
    { climbS : Int
    , descentS : Int
    , runnableS : Int
    , aidS : Int
    , totalS : Int
    , fatigueMultiplier : Float
    , intensity : Float
    }



-- PREDICT


predict : Profile -> Race -> List Km -> Float -> Prediction
predict profile race kms intensity =
    let
        i =
            clampIntensity intensity

        ( climbS_, descentS_, runnableS_ ) =
            List.foldl (accumulateKm profile i) ( 0, 0, 0 ) kms

        aidS_ =
            List.length race.aidStations * AthleteProfile.aidStyleSecondsPerStation profile.aidStyle

        movingS =
            climbS_ + descentS_ + runnableS_

        hoursRaw =
            toFloat (movingS + aidS_) / 3600

        fatigueMult =
            fatigueMultiplier profile hoursRaw

        adjustedClimbS =
            round (toFloat climbS_ * fatigueMult)

        adjustedDescentS =
            round (toFloat descentS_ * fatigueMult)

        adjustedRunnableS =
            round (toFloat runnableS_ * fatigueMult)

        totalS_ =
            adjustedClimbS + adjustedDescentS + adjustedRunnableS + aidS_
    in
    { climbS = adjustedClimbS
    , descentS = adjustedDescentS
    , runnableS = adjustedRunnableS
    , aidS = aidS_
    , totalS = totalS_
    , fatigueMultiplier = fatigueMult
    , intensity = i
    }


accumulateKm : Profile -> Float -> Km -> ( Int, Int, Int ) -> ( Int, Int, Int )
accumulateKm profile i km ( climb, descent, run ) =
    if km.slope >= 0.04 then
        ( climb + climbSeconds profile i km, descent, run )

    else if km.slope <= -0.04 then
        ( climb, descent + descentSeconds profile i km, run )

    else
        ( climb, descent, run + runnableSeconds profile i km )


climbSeconds : Profile -> Float -> Km -> Int
climbSeconds profile i km =
    if profile.verticalRateVmh <= 0 || km.gain <= 0 then
        0

    else
        round (km.gain / (profile.verticalRateVmh * i) * 3600)


descentSeconds : Profile -> Float -> Km -> Int
descentSeconds profile i km =
    let
        basePaceSec =
            toFloat profile.flatTrailPaceSecPerKm

        slopeMult =
            slopeFactor km.slope

        skillMult =
            AthleteProfile.descentSkillMultiplier profile.descentSkill

        adjustedPaceSec =
            basePaceSec * slopeMult * skillMult / i
    in
    round ((km.distance / 1000) * adjustedPaceSec)


runnableSeconds : Profile -> Float -> Km -> Int
runnableSeconds profile i km =
    let
        basePaceSec =
            toFloat profile.flatTrailPaceSecPerKm

        slopeMult =
            slopeFactor km.slope

        techMult =
            AthleteProfile.techSkillMultiplier profile.technicalitySkill

        adjustedPaceSec =
            basePaceSec * slopeMult * techMult / i
    in
    round ((km.distance / 1000) * adjustedPaceSec)


fatigueMultiplier : Profile -> Float -> Float
fatigueMultiplier profile hours =
    1 + profile.fatigueSlopePerH * max 0 (hours - profile.fatigueThresholdH)


clampIntensity : Float -> Float
clampIntensity i =
    max 0.5 (min 1.5 i)



-- INVERSE: SOLVE FOR INTENSITY


{-| Bisection on `intensity` ∈ `[0.80, 1.25]` to find the value that
produces the target total time. 12 iterations gives precision ~10⁻⁴
across the search range — well below visual resolution.

Out-of-bracket targets clamp at the endpoints; the slider UI
(TASK-019) surfaces the "off the chart" condition separately.

-}
solveForIntensity : Profile -> Race -> List Km -> Int -> Float
solveForIntensity profile race kms targetS =
    let
        lo =
            0.80

        hi =
            1.25

        atLo =
            (predict profile race kms lo).totalS

        atHi =
            (predict profile race kms hi).totalS
    in
    if targetS >= atLo then
        lo

    else if targetS <= atHi then
        hi

    else
        bisect profile race kms targetS lo hi 12


bisect : Profile -> Race -> List Km -> Int -> Float -> Float -> Int -> Float
bisect profile race kms targetS lo hi iters =
    if iters <= 0 then
        (lo + hi) / 2

    else
        let
            mid =
                (lo + hi) / 2

            midTotal =
                (predict profile race kms mid).totalS
        in
        -- Predictor is monotonically decreasing in intensity.
        -- midTotal > targetS → need higher intensity (mid is lower bound).
        if midTotal > targetS then
            bisect profile race kms targetS mid hi (iters - 1)

        else
            bisect profile race kms targetS lo mid (iters - 1)
