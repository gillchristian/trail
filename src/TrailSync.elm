module TrailSync exposing
    ( ImportVerdict(..)
    , classify
    , courseHash
    , courseHashFromGpxText
    , ensureIdentity
    , verdictMessage
    )

{-| Identity + integrity for `.trail` file sharing (coach collaboration arc;
ADR-0009 / ADR-0010, spec §2 / WI-1).

Two questions this module answers, both pure:

1.  **What course is a plan built on?** `courseHash` reduces a decoded track to a
    short, stable fingerprint. It hashes the *canonical decoded track*
    (lat/lon rounded to ~1 m, ele to the nearest metre) — **not** the raw GPX
    bytes — so two exports of the same course match even when they differ
    cosmetically (whitespace, decimal precision, reordered metadata, a
    re-export). User decision, Q1 (2026-06-15).

2.  **May this imported `.trail` be merged onto that race?** `classify` compares
    an incoming file's `(shareId, courseHash)` against a local target race and
    returns a typed verdict. Different race → block; same race but a different
    course → **hard-block** (Q1: the "freeze the course" axiom — a plan addressed
    to different geometry can't be safely merged); both match → mergeable.

The hash is a deterministic, non-cryptographic double polynomial over the
canonical string. The threat model is "did these two plans start from the same
course?", not an adversary — so a ~60-bit fingerprint is ample, and a pure-Elm
hash keeps the whole feature Layer-0 with no crypto port. (Each fold stays
within Elm's safe-integer range, so no `Math.imul`-style 32-bit tricks are
needed.) The actual three-way merge that consumes a `Mergeable` verdict is
WI-3 (TASK-050); this module only gates it.

-}

import Gpx exposing (Point, Track)
import Types exposing (Race)


{-| The verdict of comparing an incoming `.trail` against a local target race.
A type, not a runtime failure path — callers `case` on it.
-}
type ImportVerdict
    = Mergeable
    | DifferentRace
    | DifferentCourse


{-| Compare an incoming file's identity against a local target race. Works on
anything carrying the two identity fields (`Race`, or a minimal test record).

An empty incoming `shareId` never matches — a v1 file (or any race that hasn't
been stamped yet) must not silently merge onto an unrelated race just because
both happen to be blank.

-}
classify :
    { a | shareId : String, courseHash : String }
    -> { b | shareId : String, courseHash : String }
    -> ImportVerdict
classify incoming target =
    if incoming.shareId == "" || incoming.shareId /= target.shareId then
        DifferentRace

    else if incoming.courseHash /= target.courseHash then
        DifferentCourse

    else
        Mergeable


{-| Human-facing explanation for a non-mergeable verdict (used by the WI-3
import UI and by the smoke harness). `Mergeable` has no message.
-}
verdictMessage : ImportVerdict -> String
verdictMessage verdict =
    case verdict of
        Mergeable ->
            ""

        DifferentRace ->
            "This file is for a different race."

        DifferentCourse ->
            "This plan was built on a different course — start a fresh share."



-- COURSE HASH


{-| Fingerprint a decoded track. Stable across cosmetically-different GPX that
decodes to the same rounded points; different across genuinely different
courses.
-}
courseHash : Track -> String
courseHash track =
    let
        afterPoints =
            List.foldl hashPoint initialState track.points

        -- Fold the point count in too, so a prefix of another track (same
        -- leading points, fewer of them) can't collide with the whole.
        ( h1, h2 ) =
            hashString (";n=" ++ String.fromInt (List.length track.points)) afterPoints
    in
    String.fromInt h1 ++ "-" ++ String.fromInt h2


{-| Convenience for the import path: hash straight from GPX text. Returns `""`
when the text can't be parsed — the caller treats an empty hash as "unknown"
rather than crashing (a stored race always has parseable GPX, so this only
guards genuinely broken input).
-}
courseHashFromGpxText : String -> String
courseHashFromGpxText gpxText =
    case Gpx.parseGPX gpxText of
        Ok track ->
            courseHash track

        Err _ ->
            ""


{-| Backfill the `.trail`-sharing identity on a race that predates WI-1 (or any
race still carrying the decoder's `""` defaults), so an export stamps it.

`courseHash` is computed from the GPX; `shareId` is seeded from the race's stable
IDB `id` (a UUID) — a unique, stable seed that needs no async mint. They coincide
initially for a backfilled race, but diverge after any import (the IDB `id` is
regenerated then, while the embedded `shareId` is preserved), so the round-trip
identity still holds (ADR-0010). A race that already has both fields is returned
unchanged; new races get their `shareId` minted JS-side at full save, so this
only ever fires for the pre-existing ones.

Called at export time (TASK-053): hashing needs a GPX parse, so it's done lazily
for the race actually being shared rather than for every race on load.

-}
ensureIdentity : Race -> Race
ensureIdentity race =
    { race
        | shareId =
            if race.shareId == "" then
                Types.raceIdToString race.id

            else
                race.shareId
        , courseHash =
            if race.courseHash == "" then
                courseHashFromGpxText race.gpxText

            else
                race.courseHash
    }


{-| Canonical, rounding-tolerant rendering of one point: lat/lon scaled to 5
decimals (~1.1 m) and elevation to the nearest metre, as integers (stringifying
scaled ints sidesteps any float-formatting ambiguity).
-}
canonicalPoint : Point -> String
canonicalPoint p =
    scaled5 p.lat ++ "," ++ scaled5 p.lon ++ "," ++ String.fromInt (round p.ele)


scaled5 : Float -> String
scaled5 f =
    String.fromInt (round (f * 100000))



-- HASH (deterministic double polynomial; stays in safe-integer range)


type alias HashState =
    ( Int, Int )


initialState : HashState
initialState =
    ( 5381, 7919 )


hashPoint : Point -> HashState -> HashState
hashPoint p state =
    hashString (canonicalPoint p ++ ";") state


hashString : String -> HashState -> HashState
hashString s state =
    String.foldl stepChar state s


{-| One polynomial-rolling step per character on each of two independent hashes.
`h * base + c` stays below 2^53 (h < 2^31, base ~131), so plain integer
arithmetic with a final `modBy` is exact — no bit-twiddling required.
-}
stepChar : Char -> HashState -> HashState
stepChar c ( h1, h2 ) =
    let
        code =
            Char.toCode c
    in
    ( modBy 2147483647 (h1 * 131 + code)
    , modBy 1000000007 (h2 * 137 + code)
    )
