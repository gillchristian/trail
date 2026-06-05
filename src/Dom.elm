port module Dom exposing (scrollIntoView)

{-| Tiny DOM-effect port.

`scrollIntoView id` smooth-scrolls the element with that id into view.
The JS side defers to the next animation frame, so Elm has already
rendered the element by the time we scroll — see `main.js`. Used to
bring the aid-station editor into view when it opens above a long list.

-}


port scrollIntoView : String -> Cmd msg
