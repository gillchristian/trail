port module Storage exposing
    ( deleteRace
    , gotError
    , gotIdentity
    , gotProfile
    , gotRace
    , gotRaceDeleted
    , gotRaces
    , gotStravaToken
    , loadAll
    , loadIdentity
    , loadProfile
    , loadStravaToken
    , saveIdentity
    , saveProfile
    , saveRace
    , saveRaceMeta
    , saveStravaToken
    )

{-| IndexedDB facade. Ports talk to a vanilla JS wrapper in
`src/ports.js`. The JS side assigns ids on save (via
`crypto.randomUUID()`) and returns the canonical record back here.

All payloads are `Json.Encode.Value` — Elm's port runtime uses
structured clone, so large strings (a UTMB GPX is ~3 MB) cross
the FFI without re-serialisation.

-}

import Json.Encode exposing (Value)


port storageLoadAll : () -> Cmd msg


port storageSave : Value -> Cmd msg


port storageSaveMeta : Value -> Cmd msg


port storageDelete : String -> Cmd msg


port storageRacesLoaded : (Value -> msg) -> Sub msg


port storageRaceSaved : (Value -> msg) -> Sub msg


port storageRaceDeleted : (String -> msg) -> Sub msg


port storageError : (String -> msg) -> Sub msg


port storageLoadProfile : () -> Cmd msg


port storageSaveProfile : Value -> Cmd msg


port storageProfileLoaded : (Value -> msg) -> Sub msg


port storageLoadStravaToken : () -> Cmd msg


port storageSaveStravaToken : Value -> Cmd msg


port storageStravaTokenLoaded : (Value -> msg) -> Sub msg


port storageLoadIdentity : () -> Cmd msg


port storageSaveIdentity : Value -> Cmd msg


port storageIdentityLoaded : (Value -> msg) -> Sub msg


loadAll : Cmd msg
loadAll =
    storageLoadAll ()


loadProfile : Cmd msg
loadProfile =
    storageLoadProfile ()


saveProfile : Value -> Cmd msg
saveProfile =
    storageSaveProfile


gotProfile : (Value -> msg) -> Sub msg
gotProfile =
    storageProfileLoaded


loadStravaToken : Cmd msg
loadStravaToken =
    storageLoadStravaToken ()


saveStravaToken : Value -> Cmd msg
saveStravaToken =
    storageSaveStravaToken


gotStravaToken : (Value -> msg) -> Sub msg
gotStravaToken =
    storageStravaTokenLoaded


{-| The device-global identity record (`me`) + name directory (WI-5 / TASK-054,
ADR-0012). One row in a dedicated IDB store, loaded at boot and saved on
mint/rename/import-merge. Distinct from `Profile` (the race performance profile)
and from `deviceId` (a localStorage device fingerprint set in flags).
-}
loadIdentity : Cmd msg
loadIdentity =
    storageLoadIdentity ()


saveIdentity : Value -> Cmd msg
saveIdentity =
    storageSaveIdentity


gotIdentity : (Value -> msg) -> Sub msg
gotIdentity =
    storageIdentityLoaded


saveRace : Value -> Cmd msg
saveRace =
    storageSave


{-| Save a race **without** its GPX text — for plan/aid/metadata edits. The
GPX lives in its own IDB row, written once at import via `saveRace`. Both
ports echo the saved race back through `gotRace` (`storageRaceSaved`); the
meta echo omits `gpxText`, which `RaceSaved` refills from the in-model race.
See ADR-0005 / TASK-040.
-}
saveRaceMeta : Value -> Cmd msg
saveRaceMeta =
    storageSaveMeta


deleteRace : String -> Cmd msg
deleteRace =
    storageDelete


gotRaces : (Value -> msg) -> Sub msg
gotRaces =
    storageRacesLoaded


gotRace : (Value -> msg) -> Sub msg
gotRace =
    storageRaceSaved


gotRaceDeleted : (String -> msg) -> Sub msg
gotRaceDeleted =
    storageRaceDeleted


gotError : (String -> msg) -> Sub msg
gotError =
    storageError
