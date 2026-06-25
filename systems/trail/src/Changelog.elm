module Changelog exposing
    ( courseUploaded
    , diff
    , entryFromChanges
    , union
    )

{-| The change-history *logic* for the coach-collaboration arc (WI-4 /
TASK-051, spec §5). **Derived and cosmetic** — never replayed to reconstruct
state; delete the whole history and a merge still works (ADR-0009). The merge
(WI-3) owns correctness; this owns the human-facing "who changed what, when".

The typed `ChangeDescriptor` / `ChangeEntry` and their codecs live in `Types`
(so `Race` can carry the history without an import cycle); this module produces
entries by a pure two-way `diff` of the mergeable planning layer
(`Types.PlanningLayer` — also defined there so `Race.mergeBase` can hold one),
so a local commit logs `diff before after` and a merge (TASK-056) will log the
diff it applied — no parallel diff engine.

`diff` only emits the spec's taxonomy (aid stations, per-km note/pace, race
name/date). Target-time, location, url and notes changes produce no descriptor —
deliberately, so exploratory slider moves don't spam the feed. The
descriptor→icon/phrasing mapping is a view concern and lives in `Main`.

-}

import Dict
import Types
    exposing
        ( AidStation
        , ChangeDescriptor(..)
        , ChangeEntry
        , KmPlan
        , KmTime(..)
        , Plan
        , PlanningLayer
        )


{-| Build an entry from a set of changes, or `Nothing` when there were none
(so callers can skip logging a no-op). `seq` only has to be locally monotonic;
combined with `author` (the `deviceId`) it makes a globally-unique immutable id.
`authorId` is the person-level `userId` for the feed's name label (WI-5), `""`
when no identity exists yet (the entry then labels via the `author`/device path).
-}
entryFromChanges : String -> String -> Int -> Int -> String -> List ChangeDescriptor -> Maybe ChangeEntry
entryFromChanges author authorId nowMs seq source changes =
    if List.isEmpty changes then
        Nothing

    else
        Just
            { entryId = author ++ "-" ++ String.fromInt seq
            , author = author
            , authorId = authorId
            , timestampMs = nowMs
            , source = source
            , changes = changes
            }


{-| The structural "course uploaded" event seeded when a race is created.
-}
courseUploaded : String -> String -> Int -> Int -> ChangeEntry
courseUploaded author authorId nowMs seq =
    { entryId = author ++ "-" ++ String.fromInt seq
    , author = author
    , authorId = authorId
    , timestampMs = nowMs
    , source = "local"
    , changes = [ CourseUploaded ]
    }



-- DIFF (two-way, before → after)


kmOf : Float -> Int
kmOf meters =
    floor (meters / 1000)


diff : PlanningLayer -> PlanningLayer -> List ChangeDescriptor
diff before after =
    raceMetaChanges before after
        ++ aidChanges before.aidStations after.aidStations
        ++ kmChanges before.plan after.plan


raceMetaChanges : PlanningLayer -> PlanningLayer -> List ChangeDescriptor
raceMetaChanges before after =
    (if before.name /= after.name then
        [ RaceRenamed { from = before.name, to = after.name } ]

     else
        []
    )
        ++ (if before.date /= after.date then
                [ RaceDateChanged { from = before.date, to = after.date } ]

            else
                []
           )


aidChanges : List AidStation -> List AidStation -> List ChangeDescriptor
aidChanges before after =
    let
        beforeById =
            Dict.fromList (List.map (\a -> ( a.id, a )) before)

        afterById =
            Dict.fromList (List.map (\a -> ( a.id, a )) after)

        ids =
            Dict.keys beforeById ++ Dict.keys afterById |> sortedUniqueStrings

        forId id =
            case ( Dict.get id beforeById, Dict.get id afterById ) of
                ( Nothing, Just a ) ->
                    [ AidAdded { id = id, name = a.name } ]

                ( Just a, Nothing ) ->
                    [ AidRemoved { id = id, name = a.name } ]

                ( Just b, Just a ) ->
                    aidFieldChanges b a

                ( Nothing, Nothing ) ->
                    []
    in
    List.concatMap forId ids


aidFieldChanges : AidStation -> AidStation -> List ChangeDescriptor
aidFieldChanges b a =
    (if b.name /= a.name then
        [ AidRenamed { id = a.id, from = b.name, to = a.name } ]

     else
        []
    )
        ++ (if b.distance /= a.distance then
                [ AidMoved { id = a.id, name = a.name, fromKm = kmOf b.distance, toKm = kmOf a.distance } ]

            else
                []
           )
        ++ (if b.restSeconds /= a.restSeconds then
                [ AidRetimed { id = a.id, name = a.name, fromRest = b.restSeconds, toRest = a.restSeconds } ]

            else
                []
           )


kmChanges : Plan -> Plan -> List ChangeDescriptor
kmChanges before after =
    let
        indices =
            Dict.keys before.kmPlans ++ Dict.keys after.kmPlans |> sortedUniqueInts

        at i p =
            Dict.get i p.kmPlans |> Maybe.withDefault Types.emptyKmPlan

        forIndex i =
            kmPlanChanges i (at i before) (at i after)
    in
    List.concatMap forIndex indices


kmPlanChanges : Int -> KmPlan -> KmPlan -> List ChangeDescriptor
kmPlanChanges km b a =
    noteChange km b.notes a.notes ++ paceChange km b.time a.time


noteChange : Int -> String -> String -> List ChangeDescriptor
noteChange km before after =
    case ( before == "", after == "" ) of
        ( True, False ) ->
            [ KmNoteAdded { km = km } ]

        ( False, True ) ->
            [ KmNoteCleared { km = km } ]

        ( False, False ) ->
            if before /= after then
                [ KmNoteEdited { km = km } ]

            else
                []

        ( True, True ) ->
            []


paceChange : Int -> KmTime -> KmTime -> List ChangeDescriptor
paceChange km before after =
    case ( before, after ) of
        ( Auto, Manual s ) ->
            [ KmPaceSet { km = km, seconds = s } ]

        ( Manual _, Auto ) ->
            [ KmPaceCleared { km = km } ]

        ( Manual x, Manual y ) ->
            if x /= y then
                [ KmPaceChanged { km = km, from = x, to = y } ]

            else
                []

        ( Auto, Auto ) ->
            []



-- UNION (conflict-free merge of two histories by entryId)


union : List ChangeEntry -> List ChangeEntry -> List ChangeEntry
union a b =
    List.foldl (\e acc -> Dict.insert e.entryId e acc) Dict.empty (a ++ b)
        |> Dict.values
        |> List.sortBy .timestampMs



-- HELPERS


sortedUniqueStrings : List String -> List String
sortedUniqueStrings xs =
    List.foldl (\x -> Dict.insert x ()) Dict.empty xs |> Dict.keys


sortedUniqueInts : List Int -> List Int
sortedUniqueInts xs =
    List.foldl (\x -> Dict.insert x ()) Dict.empty xs |> Dict.keys
