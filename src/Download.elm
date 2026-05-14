port module Download exposing (file)

{-| One-shot port for "save this string as a download." The JS
side builds a Blob and triggers an `<a download>` click.
-}

import Json.Encode as E


port downloadFile : E.Value -> Cmd msg


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
