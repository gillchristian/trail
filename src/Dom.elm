port module Dom exposing (print, scrollIntoView)

{-| Tiny DOM-effect ports.

`scrollIntoView id` smooth-scrolls the element with that id into view.
The JS side defers to the next animation frame, so Elm has already
rendered the element by the time we scroll — see `main.js`. Used to
bring the aid-station editor into view when it opens above a long list.

`print` opens the browser print dialog (`window.print()`). The plan page's
`@media print` rules in `app.css` strip the app chrome and render the plan
table black-on-white; the Print button on the plan page fires this.

-}


port scrollIntoView : String -> Cmd msg


port print : () -> Cmd msg
