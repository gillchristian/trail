module AthleteProfile exposing
    ( AidStyle(..)
    , DescentSkill(..)
    , Profile
    , Preset(..)
    , TechSkill(..)
    , aidStyleLabel
    , aidStyleSecondsPerStation
    , allAidStyles
    , allDescentSkills
    , allPresets
    , allTechSkills
    , decode
    , descentSkillLabel
    , descentSkillMultiplier
    , encode
    , midPack
    , presetLabel
    , presetProfile
    , techSkillLabel
    , techSkillMultiplier
    )

{-| The athlete profile — bundle of physiological + skill parameters
the Layer B predictor (TASK-018) consumes. One global active profile
per app; lives in IDB under `settings.activeProfile`.

Every field has a population-tier default. A brand-new user starts on
the `MidPack` preset; the settings page lets them override individual
fields without filling out a wizard. See
`pace-prediction-roadmap.md` §3.

Naming note: `Profile.elm` is already taken by the elevation-renderer
module, so this module is `AthleteProfile`.

-}

import Json.Decode as D exposing (Decoder)
import Json.Encode as E exposing (Value)



-- TYPES


type alias Profile =
    { verticalRateVmh : Float -- m of climb per hour, baseline
    , flatTrailPaceSecPerKm : Int -- on moderate trail at sustainable effort
    , fatigueThresholdH : Float -- hours before pace inflation kicks in
    , fatigueSlopePerH : Float -- 0.015 == 1.5 % / h after threshold
    , descentSkill : DescentSkill
    , technicalitySkill : TechSkill
    , aidStyle : AidStyle
    , lthrBpm : Maybe Int -- lactate threshold HR
    , maxHrBpm : Maybe Int
    }


type DescentSkill
    = DescCautious
    | DescAverage
    | DescConfident
    | DescExpert


type TechSkill
    = TechNovice
    | TechAverage
    | TechExperienced
    | TechExpert


type AidStyle
    = AidElite
    | AidLean
    | AidStandard
    | AidRelaxed



-- PRESETS


type Preset
    = Beginner
    | MidPack
    | StrongMidPack
    | SubElite


allPresets : List Preset
allPresets =
    [ Beginner, MidPack, StrongMidPack, SubElite ]


presetLabel : Preset -> String
presetLabel p =
    case p of
        Beginner ->
            "Beginner"

        MidPack ->
            "Mid-pack"

        StrongMidPack ->
            "Strong mid-pack"

        SubElite ->
            "Sub-elite"


presetProfile : Preset -> Profile
presetProfile p =
    case p of
        Beginner ->
            { verticalRateVmh = 550
            , flatTrailPaceSecPerKm = 420 -- 7:00/km
            , fatigueThresholdH = 1.5
            , fatigueSlopePerH = 0.030
            , descentSkill = DescCautious
            , technicalitySkill = TechNovice
            , aidStyle = AidStandard
            , lthrBpm = Nothing
            , maxHrBpm = Nothing
            }

        MidPack ->
            midPack

        StrongMidPack ->
            { verticalRateVmh = 850
            , flatTrailPaceSecPerKm = 330 -- 5:30/km
            , fatigueThresholdH = 2.5
            , fatigueSlopePerH = 0.015
            , descentSkill = DescConfident
            , technicalitySkill = TechExperienced
            , aidStyle = AidLean
            , lthrBpm = Nothing
            , maxHrBpm = Nothing
            }

        SubElite ->
            { verticalRateVmh = 1000
            , flatTrailPaceSecPerKm = 300 -- 5:00/km
            , fatigueThresholdH = 3.0
            , fatigueSlopePerH = 0.010
            , descentSkill = DescExpert
            , technicalitySkill = TechExpert
            , aidStyle = AidElite
            , lthrBpm = Nothing
            , maxHrBpm = Nothing
            }


midPack : Profile
midPack =
    { verticalRateVmh = 750
    , flatTrailPaceSecPerKm = 360 -- 6:00/km
    , fatigueThresholdH = 2.0
    , fatigueSlopePerH = 0.020
    , descentSkill = DescAverage
    , technicalitySkill = TechAverage
    , aidStyle = AidLean
    , lthrBpm = Nothing
    , maxHrBpm = Nothing
    }



-- SKILL MULTIPLIERS (applied by the predictor)


{-| Descent-skill multiplier on the table-lookup descent pace. <1 means
the runner descends faster than the population average for that
technicality + grade.
-}
descentSkillMultiplier : DescentSkill -> Float
descentSkillMultiplier d =
    case d of
        DescCautious ->
            1.15

        DescAverage ->
            1.0

        DescConfident ->
            0.92

        DescExpert ->
            0.85


{-| Technicality multiplier — applied to flat-trail pace. >1 means
technical terrain slows the runner more than the population average.
-}
techSkillMultiplier : TechSkill -> Float
techSkillMultiplier t =
    case t of
        TechNovice ->
            1.20

        TechAverage ->
            1.10

        TechExperienced ->
            1.0

        TechExpert ->
            0.95


{-| Default seconds-per-aid-station for a given aid style. Used by the
predictor as `aid_count * sec / 3600` to budget non-moving time.
-}
aidStyleSecondsPerStation : AidStyle -> Int
aidStyleSecondsPerStation a =
    case a of
        AidElite ->
            60

        AidLean ->
            180

        AidStandard ->
            450

        AidRelaxed ->
            900



-- LABELS


descentSkillLabel : DescentSkill -> String
descentSkillLabel d =
    case d of
        DescCautious ->
            "Cautious"

        DescAverage ->
            "Average"

        DescConfident ->
            "Confident"

        DescExpert ->
            "Expert"


allDescentSkills : List DescentSkill
allDescentSkills =
    [ DescCautious, DescAverage, DescConfident, DescExpert ]


techSkillLabel : TechSkill -> String
techSkillLabel t =
    case t of
        TechNovice ->
            "Novice"

        TechAverage ->
            "Average"

        TechExperienced ->
            "Experienced"

        TechExpert ->
            "Expert"


allTechSkills : List TechSkill
allTechSkills =
    [ TechNovice, TechAverage, TechExperienced, TechExpert ]


aidStyleLabel : AidStyle -> String
aidStyleLabel a =
    case a of
        AidElite ->
            "Elite (1 min)"

        AidLean ->
            "Lean (3 min)"

        AidStandard ->
            "Standard (7-8 min)"

        AidRelaxed ->
            "Relaxed (15 min)"


allAidStyles : List AidStyle
allAidStyles =
    [ AidElite, AidLean, AidStandard, AidRelaxed ]



-- JSON


encode : Profile -> Value
encode p =
    E.object
        [ ( "verticalRateVmh", E.float p.verticalRateVmh )
        , ( "flatTrailPaceSecPerKm", E.int p.flatTrailPaceSecPerKm )
        , ( "fatigueThresholdH", E.float p.fatigueThresholdH )
        , ( "fatigueSlopePerH", E.float p.fatigueSlopePerH )
        , ( "descentSkill", E.string (descentSkillKey p.descentSkill) )
        , ( "technicalitySkill", E.string (techSkillKey p.technicalitySkill) )
        , ( "aidStyle", E.string (aidStyleKey p.aidStyle) )
        , ( "lthrBpm", maybeInt p.lthrBpm )
        , ( "maxHrBpm", maybeInt p.maxHrBpm )
        ]


decode : Decoder Profile
decode =
    D.map8 mkProfile
        (D.field "verticalRateVmh" D.float)
        (D.field "flatTrailPaceSecPerKm" D.int)
        (D.field "fatigueThresholdH" D.float)
        (D.field "fatigueSlopePerH" D.float)
        (D.field "descentSkill" D.string |> D.map descentSkillFromKey)
        (D.field "technicalitySkill" D.string |> D.map techSkillFromKey)
        (D.field "aidStyle" D.string |> D.map aidStyleFromKey)
        (D.field "lthrBpm" (D.nullable D.int))
        |> D.andThen
            (\partial ->
                D.map partial (D.field "maxHrBpm" (D.nullable D.int))
            )


mkProfile :
    Float
    -> Int
    -> Float
    -> Float
    -> DescentSkill
    -> TechSkill
    -> AidStyle
    -> Maybe Int
    -> (Maybe Int -> Profile)
mkProfile vmh pace ft fs desc tech aid lthr =
    \maxHr ->
        { verticalRateVmh = vmh
        , flatTrailPaceSecPerKm = pace
        , fatigueThresholdH = ft
        , fatigueSlopePerH = fs
        , descentSkill = desc
        , technicalitySkill = tech
        , aidStyle = aid
        , lthrBpm = lthr
        , maxHrBpm = maxHr
        }


maybeInt : Maybe Int -> Value
maybeInt m =
    case m of
        Just i ->
            E.int i

        Nothing ->
            E.null


descentSkillKey : DescentSkill -> String
descentSkillKey d =
    case d of
        DescCautious ->
            "cautious"

        DescAverage ->
            "average"

        DescConfident ->
            "confident"

        DescExpert ->
            "expert"


descentSkillFromKey : String -> DescentSkill
descentSkillFromKey k =
    case k of
        "cautious" ->
            DescCautious

        "confident" ->
            DescConfident

        "expert" ->
            DescExpert

        _ ->
            DescAverage


techSkillKey : TechSkill -> String
techSkillKey t =
    case t of
        TechNovice ->
            "novice"

        TechAverage ->
            "average"

        TechExperienced ->
            "experienced"

        TechExpert ->
            "expert"


techSkillFromKey : String -> TechSkill
techSkillFromKey k =
    case k of
        "novice" ->
            TechNovice

        "experienced" ->
            TechExperienced

        "expert" ->
            TechExpert

        _ ->
            TechAverage


aidStyleKey : AidStyle -> String
aidStyleKey a =
    case a of
        AidElite ->
            "elite"

        AidLean ->
            "lean"

        AidStandard ->
            "standard"

        AidRelaxed ->
            "relaxed"


aidStyleFromKey : String -> AidStyle
aidStyleFromKey k =
    case k of
        "elite" ->
            AidElite

        "standard" ->
            AidStandard

        "relaxed" ->
            AidRelaxed

        _ ->
            AidLean
