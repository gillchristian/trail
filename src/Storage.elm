port module Storage exposing
    ( deleteRace
    , gotError
    , gotProfile
    , gotRace
    , gotRaceDeleted
    , gotRaces
    , loadAll
    , loadProfile
    , saveProfile
    , saveRace
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


port storageDelete : String -> Cmd msg


port storageRacesLoaded : (Value -> msg) -> Sub msg


port storageRaceSaved : (Value -> msg) -> Sub msg


port storageRaceDeleted : (String -> msg) -> Sub msg


port storageError : (String -> msg) -> Sub msg


port storageLoadProfile : () -> Cmd msg


port storageSaveProfile : Value -> Cmd msg


port storageProfileLoaded : (Value -> msg) -> Sub msg


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


saveRace : Value -> Cmd msg
saveRace =
    storageSave


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
