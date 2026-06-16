module Identity exposing
    ( UserId, Me, DirEntry, Directory
    , emptyDirectory, resolveName, resolveNameWith
    , learn, mergeDirectory, subsetFor
    , ImportDecision(..), decideImport
    , OwnershipAnswer(..), OwnershipResult(..), resolveOwnership
    , encodeMe, decodeMe, encodeDirEntry, decodeDirEntry, encodeDirectory, decodeDirectory
    )

{-| WI-5 — identity & authorship (TASK-054, ADR-0012). The pure core: who
authored a change, and how two devices agree on who's who without accounts or a
backend (Layer 0). The id *is* the identity; the display name is a mutable label
resolved through a directory. This module holds the data types, codecs, the
name last-write-wins register, and the import mint/adopt *decision* — all pure.
The side effects it implies (minting a UUID, prompting for a name, persisting to
IDB) are performed by the caller; this module never performs them.

`userId` is a person-level identity that layers *over* the device-level
`deviceId` (see ADR-0012): the same person on two devices shares one `userId`
but keeps two `deviceId`s. `deviceId` stays the collision key (version vector,
aid-id prefix, changelog entryId); `userId` is what labels and `Race.owner` use.

@docs UserId, Me, DirEntry, Directory
@docs emptyDirectory, resolveName, resolveNameWith
@docs learn, mergeDirectory, subsetFor
@docs ImportDecision, decideImport
@docs OwnershipAnswer, OwnershipResult, resolveOwnership
@docs encodeMe, decodeMe, encodeDirEntry, decodeDirEntry, encodeDirectory, decodeDirectory

-}

import Dict exposing (Dict)
import Json.Decode as D
import Json.Encode as E


{-| A person. Locally-minted UUID v4 — no coordination, no server. Stable; it
travels with the person across devices and files. -}
type alias UserId =
    String


{-| The one device-global identity record. Kept separate from the athlete
*performance* profile (`AthleteProfile.Profile`): identity is device-level and
singular; the performance profile is race-level and may be plural. -}
type alias Me =
    { userId : UserId
    , displayName : String
    }


{-| A directory entry: a display name plus when it was last set (ms epoch),
which orders the last-write-wins register so importing an *older* file never
reverts a name. -}
type alias DirEntry =
    { displayName : String
    , nameUpdatedAt : Int
    }


{-| `userId -> name`, the local source of truth for all name display. Holds your
own id plus every id you have ever seen. A tiny LWW register on `displayName`,
keyed by `userId`, ordered by `nameUpdatedAt`. -}
type alias Directory =
    Dict UserId DirEntry


emptyDirectory : Directory
emptyDirectory =
    Dict.empty



-- NAME RESOLUTION


{-| Resolve a `userId` to a display name, falling back to a generic label when
the directory has never seen the id (a denormalized `.trail` should make that
rare). -}
resolveName : Directory -> UserId -> String
resolveName =
    resolveNameWith "Someone"


{-| `resolveName` with a caller-chosen fallback (e.g. "You" once you've matched
the id against `me`, or a short id for debugging). -}
resolveNameWith : String -> Directory -> UserId -> String
resolveNameWith fallback dir userId =
    case Dict.get userId dir of
        Just entry ->
            entry.displayName

        Nothing ->
            fallback



-- LAST-WRITE-WINS REGISTER


{-| Learn (or update) a name for a `userId`, but only when the incoming
timestamp is **strictly newer** than what we already hold — the LWW rule. A tie
keeps the existing entry; an older entry is ignored. This is what makes name
propagation coherent: importing a stale file can't flicker a name backwards. -}
learn : UserId -> DirEntry -> Directory -> Directory
learn userId incoming dir =
    case Dict.get userId dir of
        Just existing ->
            if incoming.nameUpdatedAt > existing.nameUpdatedAt then
                Dict.insert userId incoming dir

            else
                dir

        Nothing ->
            Dict.insert userId incoming dir


{-| LWW union of two directories, keyed by `userId`, ordered by `nameUpdatedAt`.
Used on import to fold a file's denormalized name pairs into the local
directory: each incoming entry wins only if it is newer. -}
mergeDirectory : Directory -> Directory -> Directory
mergeDirectory incoming local =
    Dict.foldl learn local incoming


{-| The sub-directory covering exactly the given ids (unknown ids dropped) —
what a `.trail` denormalizes for the ids it references (owner + any authors), so
an importer can show names for people not yet in its own directory. -}
subsetFor : List UserId -> Directory -> Directory
subsetFor ids dir =
    List.foldl
        (\id acc ->
            case Dict.get id dir of
                Just entry ->
                    Dict.insert id entry acc

                Nothing ->
                    acc
        )
        Dict.empty
        ids



-- IMPORT: THE MINT / ADOPT DECISION (pure)


{-| What the import flow should do about identity, given the importer's current
identity and the file owner's id. The two outcomes mirror spec §1.4: a file you
already own imports silently; anything else asks whether you're the owner or a
reviewer. -}
type ImportDecision
    = ImportAsOwner
    | AskOwnership


{-| Pure: decide whether an import prompts. `me`'s id matching the file owner is
the only no-prompt path. No identity, or a different owner, always asks. -}
decideImport : Maybe Me -> UserId -> ImportDecision
decideImport me fileOwner =
    case me of
        Just m ->
            if m.userId == fileOwner then
                ImportAsOwner

            else
                AskOwnership

        Nothing ->
            AskOwnership


{-| The answer to the ownership prompt. -}
type OwnershipAnswer
    = Myself
    | SomeoneElse


{-| The action to take after the ownership prompt is answered. Encodes the
mint discipline: minting happens at exactly one of these (`MintThenReview`), and
the "yourself" path always *adopts* — never mints — which is how a second device
claims an existing person-id (the device-link). -}
type OwnershipResult
    = Adopt UserId
    | MintThenReview
    | ReviewAs Me


{-| Pure: resolve the ownership prompt. "Yourself" adopts the file's owner id
(never mints). "Someone else" reviews as your existing identity, or — if you
have none yet — signals that a name prompt + mint is needed before reviewing. -}
resolveOwnership : OwnershipAnswer -> Maybe Me -> UserId -> OwnershipResult
resolveOwnership answer me fileOwner =
    case answer of
        Myself ->
            Adopt fileOwner

        SomeoneElse ->
            case me of
                Just m ->
                    ReviewAs m

                Nothing ->
                    MintThenReview



-- CODECS


encodeMe : Me -> E.Value
encodeMe m =
    E.object
        [ ( "userId", E.string m.userId )
        , ( "displayName", E.string m.displayName )
        ]


decodeMe : D.Decoder Me
decodeMe =
    D.map2 Me
        (D.field "userId" D.string)
        (D.field "displayName" D.string)


encodeDirEntry : DirEntry -> E.Value
encodeDirEntry entry =
    E.object
        [ ( "displayName", E.string entry.displayName )
        , ( "nameUpdatedAt", E.int entry.nameUpdatedAt )
        ]


decodeDirEntry : D.Decoder DirEntry
decodeDirEntry =
    D.map2 DirEntry
        (D.field "displayName" D.string)
        (D.field "nameUpdatedAt" D.int)


{-| The directory serializes as a list of `{userId, displayName, nameUpdatedAt}`
objects — the codebase's Dict idiom (same shape used for splits / km plans). The
same shape is denormalized into the `.trail` for the ids a file references. -}
encodeDirectory : Directory -> E.Value
encodeDirectory dir =
    dir
        |> Dict.toList
        |> E.list
            (\( userId, entry ) ->
                E.object
                    [ ( "userId", E.string userId )
                    , ( "displayName", E.string entry.displayName )
                    , ( "nameUpdatedAt", E.int entry.nameUpdatedAt )
                    ]
            )


decodeDirectory : D.Decoder Directory
decodeDirectory =
    D.list
        (D.map2 Tuple.pair
            (D.field "userId" D.string)
            decodeDirEntry
        )
        |> D.map Dict.fromList
