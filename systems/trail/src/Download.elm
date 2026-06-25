port module Download exposing (file, imagePicked, pickImageFile)

{-| Client-side file ports.

`file` — save a string as a download. The JS side builds a Blob and
triggers a hidden `<a download>` click.

`pickImageFile` / `imagePicked` — open a native image picker on the
JS side, read the chosen file as a base64 data URL via FileReader,
and ship the result back. We need a data URL (not a `blob:` URL)
so the value survives in IndexedDB across reloads.

-}

import Json.Encode as E


port downloadFile : E.Value -> Cmd msg


port pickImageFilePort : () -> Cmd msg


port imagePickedAsDataUrl : (String -> msg) -> Sub msg


{-| Trigger a file download in the browser.
-}
file : { filename : String, content : String, mime : String } -> Cmd msg
file opts =
    downloadFile
        (E.object
            [ ( "filename", E.string opts.filename )
            , ( "content", E.string opts.content )
            , ( "mime", E.string opts.mime )
            ]
        )


pickImageFile : Cmd msg
pickImageFile =
    pickImageFilePort ()


imagePicked : (String -> msg) -> Sub msg
imagePicked =
    imagePickedAsDataUrl
