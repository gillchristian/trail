module Merge exposing
    ( PlanningLayer
    , mintAidId
    , planningLayer
    , withPlanningLayer
    )

{-| The structural half of *freeze the course, merge the plan* (ADR-0009, WI-2 /
TASK-048). The three-way merge itself (WI-3 / TASK-050) is added here later; this
module starts by fixing the **boundary** the merge is allowed to touch.

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

The exact per-field reconciliation *within* the planning layer (last-write vs.
surfaced conflict, how `coverImage` is treated, etc.) is WI-3's decision, partly
gated on Q3; WI-2 only nails down what is in vs. out of bounds.

-}

import Types exposing (AidStation, Plan, Race)


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


{-| The mergeable subset of a `Race`. Excludes the frozen course, the identity
fields, and the owner-only `coverImage` / `actualSplits`.
-}
type alias PlanningLayer =
    { name : String
    , date : Maybe String
    , location : String
    , url : String
    , notes : String
    , aidStations : List AidStation
    , aidStationSeq : Int
    , plan : Plan
    }


{-| Project the mergeable planning layer out of a race.
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
