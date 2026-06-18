module Merge exposing
    ( AidFieldKind(..)
    , Conflict
    , ConflictKey(..)
    , MergeResult
    , VersionRel(..)
    , VersionVector
    , bumpVersion
    , classifyVersions
    , conflictKeyLabel
    , mergePlanningLayer
    , mergeVersions
    , mintAidId
    , planningLayer
    , resolve
    , setNote
    , withPlanningLayer
    )

{-| *Freeze the course, merge the plan* (ADR-0009). This module is the merge
layer: WI-2 (TASK-048) fixed the **boundary** the merge may touch, and WI-3
(TASK-050, ADR-0011) adds the three-way merge engine itself.

A `Race` decomposes into three disjoint groups:

  - **Frozen course** — `gpxText` and everything derived from it
    (`distance`, `gain`, `loss`, `courseHash`). Immutable for the lifetime of a
    shared planning session; never a merge input or output.
  - **Mergeable planning layer** — `name`, `date`, `location`, `url`, `notes`,
    the aid stations (+ their id sequence) and the per-km plan. This — and only
    this — is what WI-3 reconciles.
  - **Local / owner-only** — `id` (the IDB key), `shareId`, `createdAt`, plus
    `coverImage` and `actualSplits` (owner-authoritative observed/visual data,
    not a coach's to rewrite). Kept from the *local* race across a merge.

`withPlanningLayer` rebuilds a race from a (merged) planning layer onto a local
race, copying the frozen course and the local/owner-only fields **verbatim**. So
a merge physically cannot alter the track points: they are never passed through
the planning layer. (The complementary guard — refusing an import whose course
differs at all — is WI-1's `TrailSync.classify`.)

The exact per-field reconciliation *within* the planning layer is the WI-3
engine below: scalar fields and the per-km plan merge three-way per field; aid
stations merge as a keyed set (union of adds, honoured removes, per-field
three-way for aids on both sides). `coverImage` and `actualSplits` stay
owner-only (Q3) — they're not in `PlanningLayer` at all.

-}

import Dict exposing (Dict)
import Types exposing (AidStation, KmPlan, Plan, PlanningLayer, Race, emptyKmPlan, sortAidStations)


{-| Mint a fork-collision-safe aid-station id (TASK-049, ADR-0009 grounding #2).

Aid ids used to be `"a" ++ seq` from a per-race counter, so two copies of a race
edited independently (a coach and the owner, both starting from the same `seq`)
would mint *identical* ids for genuinely different new aids — which a merge can't
tell apart. Tagging a new id with the minting device's id keeps the two forks'
new aids distinct: `"a" ++ seq ++ "-" ++ first8(deviceId)`.

Existing `"aN"` ids (including aids inherited from a common ancestor, which
*should* match across a fork) are untouched — only newly minted ids carry the
tag. An empty `deviceId` falls back to the bare `"aN"` form.

-}
mintAidId : String -> Int -> String
mintAidId deviceId seq =
    let
        bare =
            "a" ++ String.fromInt seq

        tag =
            String.left 8 deviceId
    in
    if tag == "" then
        bare

    else
        bare ++ "-" ++ tag


{-| Project the mergeable planning layer out of a race. `PlanningLayer` (the
mergeable subset of a `Race` — no frozen course, no identity/owner-only fields)
is defined in `Types` so `Race.mergeBase` can hold one without an import cycle.
-}
planningLayer : Race -> PlanningLayer
planningLayer race =
    { name = race.name
    , date = race.date
    , location = race.location
    , url = race.url
    , notes = race.notes
    , aidStations = race.aidStations
    , aidStationSeq = race.aidStationSeq
    , plan = race.plan
    }


{-| Reassemble a race from a (merged) planning layer onto a local race. The
local race's frozen course, identity, and owner-only fields are kept verbatim —
this is what makes the course un-merge-able by construction.
-}
withPlanningLayer : PlanningLayer -> Race -> Race
withPlanningLayer layer local =
    { local
        | name = layer.name
        , date = layer.date
        , location = layer.location
        , url = layer.url
        , notes = layer.notes
        , aidStations = layer.aidStations
        , aidStationSeq = layer.aidStationSeq
        , plan = layer.plan
    }



-- ============================================================
-- VERSION VECTOR (Q4) — classify a returned file before merging
-- ============================================================


{-| A per-device edit counter: `deviceId -> number of commits seen`. Lets the
importer tell a clean fast-forward (the coach built straight on top of your exact
version) from genuine divergence (you both edited).
-}
type alias VersionVector =
    Dict String Int


type VersionRel
    = Same
    | FastForward -- theirs strictly dominates mine → adopt theirs, no conflicts
    | Behind -- mine strictly dominates theirs → incoming is an ancestor, no-op
    | Diverged -- concurrent → three-way merge


{-| Compare local (`mine`) against an incoming (`theirs`) vector. Missing keys
read as 0.
-}
classifyVersions : VersionVector -> VersionVector -> VersionRel
classifyVersions mine theirs =
    let
        keys =
            sortedUnique (Dict.keys mine ++ Dict.keys theirs)

        at k v =
            Dict.get k v |> Maybe.withDefault 0

        mineAhead =
            List.any (\k -> at k mine > at k theirs) keys

        theirsAhead =
            List.any (\k -> at k theirs > at k mine) keys
    in
    case ( mineAhead, theirsAhead ) of
        ( False, False ) ->
            Same

        ( False, True ) ->
            FastForward

        ( True, False ) ->
            Behind

        ( True, True ) ->
            Diverged


{-| Record a local commit by `deviceId`.
-}
bumpVersion : String -> VersionVector -> VersionVector
bumpVersion deviceId v =
    Dict.update deviceId (\c -> Just (Maybe.withDefault 0 c + 1)) v


{-| Element-wise max — the version of a merged result that has seen both sides.
-}
mergeVersions : VersionVector -> VersionVector -> VersionVector
mergeVersions a b =
    Dict.merge
        (\k x acc -> Dict.insert k x acc)
        (\k x y acc -> Dict.insert k (max x y) acc)
        (\k y acc -> Dict.insert k y acc)
        a
        b
        Dict.empty



-- ============================================================
-- THREE-WAY MERGE (WI-3 / ADR-0011)
-- ============================================================


{-| Where a conflict lives, so the review UI can present it and `resolve` can
apply a choice.
-}
type ConflictKey
    = KName
    | KDate
    | KLocation
    | KUrl
    | KNotes
    | KTarget
    | KKmTime Int
    | KKmNote Int
    | KAid String AidFieldKind
    | KAidPresence String


type AidFieldKind
    = AidName
    | AidDistance
    | AidRest
    | AidServices
    | AidNotes
    | AidCutoff


type alias Conflict =
    { key : ConflictKey
    , label : String
    , mine : String
    , theirs : String
    }


{-| The outcome of a three-way merge: a fully-built planning layer with every
genuine conflict defaulted to **mine** (so `merged` is always valid and
applies cleanly even if the user resolves nothing), plus the list of conflicts
to review. Disjoint edits from both sides are already folded into `merged`.
-}
type alias MergeResult =
    { merged : PlanningLayer
    , conflicts : List Conflict
    }


{-| Three-way merge of a single comparable field. Resolves to the side that
changed when only one did; on a genuine both-changed-differently conflict it
keeps `mine` and reports the conflict.
-}
field3 : ConflictKey -> (a -> String) -> a -> a -> a -> ( a, Maybe Conflict )
field3 key show base mine theirs =
    if mine == theirs then
        ( mine, Nothing )

    else if mine == base then
        ( theirs, Nothing )

    else if theirs == base then
        ( mine, Nothing )

    else
        ( mine
        , Just { key = key, label = conflictKeyLabel key, mine = show mine, theirs = show theirs }
        )


{-| Three-way merge the mergeable planning layer. The course is not here to
touch (WI-2); this only reconciles `name/date/location/url/notes`, the per-km
plan, and the aid-station set.
-}
mergePlanningLayer : PlanningLayer -> PlanningLayer -> PlanningLayer -> MergeResult
mergePlanningLayer base mine theirs =
    let
        ( name, cName ) =
            field3 KName identity base.name mine.name theirs.name

        ( date, cDate ) =
            field3 KDate (Maybe.withDefault "—") base.date mine.date theirs.date

        ( location, cLoc ) =
            field3 KLocation identity base.location mine.location theirs.location

        ( url, cUrl ) =
            field3 KUrl identity base.url mine.url theirs.url

        ( notes, cNotes ) =
            field3 KNotes identity base.notes mine.notes theirs.notes

        ( target, cTarget ) =
            field3 KTarget showTarget base.plan.targetSeconds mine.plan.targetSeconds theirs.plan.targetSeconds

        ( kmPlans, kmConflicts ) =
            mergeKmPlans base.plan mine.plan theirs.plan

        ( aids, aidConflicts ) =
            mergeAids base.aidStations mine.aidStations theirs.aidStations

        scalarConflicts =
            List.filterMap identity [ cName, cDate, cLoc, cUrl, cNotes, cTarget ]
    in
    { merged =
        { name = name
        , date = date
        , location = location
        , url = url
        , notes = notes
        , aidStations = aids
        , aidStationSeq = max mine.aidStationSeq theirs.aidStationSeq
        , plan = { targetSeconds = target, kmPlans = kmPlans }
        }
    , conflicts = scalarConflicts ++ kmConflicts ++ aidConflicts
    }


mergeKmPlans : Plan -> Plan -> Plan -> ( Dict Int KmPlan, List Conflict )
mergeKmPlans base mine theirs =
    let
        indices =
            sortedUnique (Dict.keys base.kmPlans ++ Dict.keys mine.kmPlans ++ Dict.keys theirs.kmPlans)

        at i p =
            Dict.get i p.kmPlans |> Maybe.withDefault emptyKmPlan

        step i ( accDict, accConflicts ) =
            let
                b =
                    at i base

                m =
                    at i mine

                t =
                    at i theirs

                ( time, cTime ) =
                    field3 (KKmTime i) showTime b.time m.time t.time

                ( note, cNote ) =
                    field3 (KKmNote i) identity b.notes m.notes t.notes

                merged =
                    { time = time, notes = note }
            in
            ( if merged == emptyKmPlan then
                accDict

              else
                Dict.insert i merged accDict
            , accConflicts ++ List.filterMap identity [ cTime, cNote ]
            )
    in
    List.foldl step ( Dict.empty, [] ) indices


mergeAids : List AidStation -> List AidStation -> List AidStation -> ( List AidStation, List Conflict )
mergeAids baseAids mineAids theirsAids =
    let
        byId aids =
            List.map (\a -> ( a.id, a )) aids |> Dict.fromList

        baseM =
            byId baseAids

        mineM =
            byId mineAids

        theirsM =
            byId theirsAids

        ids =
            sortedUnique (Dict.keys baseM ++ Dict.keys mineM ++ Dict.keys theirsM)

        step id ( accAids, accConflicts ) =
            case ( Dict.get id mineM, Dict.get id theirsM ) of
                ( Just m, Just t ) ->
                    let
                        b =
                            Dict.get id baseM |> Maybe.withDefault m

                        ( mergedAid, cs ) =
                            mergeAidFields b m t
                    in
                    ( mergedAid :: accAids, accConflicts ++ cs )

                ( Just m, Nothing ) ->
                    case Dict.get id baseM of
                        Just b ->
                            if m == b then
                                -- theirs removed it, mine left it alone → honour the remove
                                ( accAids, accConflicts )

                            else
                                -- mine edited, theirs removed → conflict; keep mine
                                ( m :: accAids, accConflicts ++ [ presenceConflict id m True ] )

                        Nothing ->
                            -- mine added it → keep
                            ( m :: accAids, accConflicts )

                ( Nothing, Just t ) ->
                    case Dict.get id baseM of
                        Just b ->
                            if t == b then
                                -- mine removed it, theirs left it alone → honour the remove
                                ( accAids, accConflicts )

                            else
                                -- theirs edited, mine removed → conflict; default mine (absent)
                                ( accAids, accConflicts ++ [ presenceConflict id t False ] )

                        Nothing ->
                            -- theirs added it → keep
                            ( t :: accAids, accConflicts )

                ( Nothing, Nothing ) ->
                    ( accAids, accConflicts )

        ( unsorted, conflicts ) =
            List.foldl step ( [], [] ) ids
    in
    ( sortAidStations unsorted, conflicts )


mergeAidFields : AidStation -> AidStation -> AidStation -> ( AidStation, List Conflict )
mergeAidFields b m t =
    let
        ( name, c1 ) =
            field3 (KAid m.id AidName) identity b.name m.name t.name

        ( distance, c2 ) =
            field3 (KAid m.id AidDistance) showMeters b.distance m.distance t.distance

        ( rest, c3 ) =
            field3 (KAid m.id AidRest) showSeconds b.restSeconds m.restSeconds t.restSeconds

        ( services, c4 ) =
            field3 (KAid m.id AidServices) showServices b.services m.services t.services

        ( notes, c5 ) =
            field3 (KAid m.id AidNotes) identity b.notes m.notes t.notes

        ( cutoff, c6 ) =
            field3 (KAid m.id AidCutoff) showCutoff b.cutoff m.cutoff t.cutoff
    in
    ( { id = m.id
      , name = name
      , distance = distance
      , restSeconds = rest
      , services = services
      , notes = notes
      , cutoff = cutoff
      }
    , List.filterMap identity [ c1, c2, c3, c4, c5, c6 ]
    )


presenceConflict : String -> AidStation -> Bool -> Conflict
presenceConflict id aid mineHasIt =
    { key = KAidPresence id
    , label = conflictKeyLabel (KAidPresence id)
    , mine =
        if mineHasIt then
            "keep \"" ++ aid.name ++ "\""

        else
            "removed"
    , theirs =
        if mineHasIt then
            "removed"

        else
            "keep \"" ++ aid.name ++ "\""
    }



-- ============================================================
-- RESOLUTION — fold a "take theirs" choice onto the merged layer
-- ============================================================


{-| Apply a single "take theirs" decision for one conflict onto an
already-merged layer. The review UI starts from `MergeResult.merged` (all
conflicts = mine) and folds `resolve` over the conflicts the user flipped to
theirs. Pure dispatch — unknown shapes simply pass through.
-}
resolve : ConflictKey -> PlanningLayer -> PlanningLayer -> PlanningLayer
resolve key theirs acc =
    case key of
        KName ->
            { acc | name = theirs.name }

        KDate ->
            { acc | date = theirs.date }

        KLocation ->
            { acc | location = theirs.location }

        KUrl ->
            { acc | url = theirs.url }

        KNotes ->
            { acc | notes = theirs.notes }

        KTarget ->
            { acc | plan = setTarget theirs.plan.targetSeconds acc.plan }

        KKmTime i ->
            { acc | plan = updateKm i (\kp -> { kp | time = (kpAt i theirs).time }) acc.plan }

        KKmNote i ->
            { acc | plan = updateKm i (\kp -> { kp | notes = (kpAt i theirs).notes }) acc.plan }

        KAid id kind ->
            { acc | aidStations = updateAidField id kind theirs acc.aidStations }

        KAidPresence id ->
            { acc | aidStations = setAidPresence id theirs acc.aidStations }


{-| Set a prose field (race notes, a km note, or an aid's notes) to an arbitrary
string — the apply path for a hand-merged note (Q-U3 / ADR-0013): when the same
prose field was edited on both sides, the review UI lets the user splice the two
into a custom string, which `resolve` (flip-to-theirs only) can't express.
Non-prose keys are a no-op (the UI only offers the textarea for prose). The km
case goes through `updateKm`, so emptying both note and time drops the row.
-}
setNote : ConflictKey -> String -> PlanningLayer -> PlanningLayer
setNote key note layer =
    case key of
        KNotes ->
            { layer | notes = note }

        KKmNote i ->
            { layer | plan = updateKm i (\kp -> { kp | notes = note }) layer.plan }

        KAid id AidNotes ->
            { layer
                | aidStations =
                    List.map
                        (\a ->
                            if a.id == id then
                                { a | notes = note }

                            else
                                a
                        )
                        layer.aidStations
            }

        _ ->
            layer


setTarget : Maybe Int -> Plan -> Plan
setTarget t plan =
    { plan | targetSeconds = t }


kpAt : Int -> PlanningLayer -> KmPlan
kpAt i layer =
    Dict.get i layer.plan.kmPlans |> Maybe.withDefault emptyKmPlan


updateKm : Int -> (KmPlan -> KmPlan) -> Plan -> Plan
updateKm i f plan =
    let
        current =
            Dict.get i plan.kmPlans |> Maybe.withDefault emptyKmPlan

        updated =
            f current
    in
    if updated == emptyKmPlan then
        { plan | kmPlans = Dict.remove i plan.kmPlans }

    else
        { plan | kmPlans = Dict.insert i updated plan.kmPlans }


findAid : String -> List AidStation -> Maybe AidStation
findAid id aids =
    List.filter (\a -> a.id == id) aids |> List.head


updateAidField : String -> AidFieldKind -> PlanningLayer -> List AidStation -> List AidStation
updateAidField id kind theirs aids =
    case findAid id theirs.aidStations of
        Nothing ->
            aids

        Just ta ->
            List.map
                (\a ->
                    if a.id == id then
                        case kind of
                            AidName ->
                                { a | name = ta.name }

                            AidDistance ->
                                { a | distance = ta.distance }

                            AidRest ->
                                { a | restSeconds = ta.restSeconds }

                            AidServices ->
                                { a | services = ta.services }

                            AidNotes ->
                                { a | notes = ta.notes }

                            AidCutoff ->
                                { a | cutoff = ta.cutoff }

                    else
                        a
                )
                aids


setAidPresence : String -> PlanningLayer -> List AidStation -> List AidStation
setAidPresence id theirs aids =
    case findAid id theirs.aidStations of
        Just ta ->
            if List.any (\a -> a.id == id) aids then
                List.map
                    (\a ->
                        if a.id == id then
                            ta

                        else
                            a
                    )
                    aids

            else
                sortAidStations (ta :: aids)

        Nothing ->
            List.filter (\a -> a.id /= id) aids



-- ============================================================
-- LABELS / DISPLAY
-- ============================================================


conflictKeyLabel : ConflictKey -> String
conflictKeyLabel key =
    case key of
        KName ->
            "Race name"

        KDate ->
            "Race date"

        KLocation ->
            "Location"

        KUrl ->
            "URL"

        KNotes ->
            "Race notes"

        KTarget ->
            "Target time"

        KKmTime i ->
            "Km " ++ String.fromInt (i + 1) ++ " pace"

        KKmNote i ->
            "Km " ++ String.fromInt (i + 1) ++ " note"

        KAid id kind ->
            "Aid " ++ id ++ " · " ++ aidFieldLabel kind

        KAidPresence id ->
            "Aid " ++ id ++ " (added/removed)"


aidFieldLabel : AidFieldKind -> String
aidFieldLabel kind =
    case kind of
        AidName ->
            "name"

        AidDistance ->
            "distance"

        AidRest ->
            "rest"

        AidServices ->
            "services"

        AidNotes ->
            "notes"

        AidCutoff ->
            "cutoff"


showTarget : Maybe Int -> String
showTarget m =
    case m of
        Just s ->
            showSeconds s

        Nothing ->
            "—"


showTime : Types.KmTime -> String
showTime t =
    case t of
        Types.Auto ->
            "auto"

        Types.Manual s ->
            showSeconds s


{-| A duration at the coarsest sensible frame for the review cards: exact
minutes collapse to `5m`, otherwise `5:30`; an hour or more reads `13:59:00`
(targets / cutoffs). Used for pace, aid rest, cutoff, and target conflicts.
-}
showSeconds : Int -> String
showSeconds totalSecs =
    if totalSecs <= 0 then
        "0"

    else
        let
            pad n =
                if n < 10 then
                    "0" ++ String.fromInt n

                else
                    String.fromInt n

            h =
                totalSecs // 3600

            m =
                modBy 60 (totalSecs // 60)

            s =
                modBy 60 totalSecs
        in
        if h > 0 then
            String.fromInt h ++ ":" ++ pad m ++ ":" ++ pad s

        else if s == 0 then
            String.fromInt m ++ "m"

        else
            String.fromInt m ++ ":" ++ pad s


showMeters : Float -> String
showMeters m =
    String.fromInt (round m) ++ "m"


showCutoff : Maybe Int -> String
showCutoff m =
    case m of
        Just s ->
            showSeconds s

        Nothing ->
            "—"


showServices : List Types.Service -> String
showServices services =
    case services of
        [] ->
            "none"

        _ ->
            -- Icons, matching how services render everywhere else in the app
            -- (the conflict value is a plain string, so no per-icon hover title).
            String.join " " (List.map Types.serviceIcon services)


sortedUnique : List comparable -> List comparable
sortedUnique xs =
    List.foldl (\x -> Dict.insert x ()) Dict.empty xs |> Dict.keys
