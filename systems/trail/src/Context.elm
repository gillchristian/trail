module Context exposing (Context)

{-| Render-time locale context (i18n epic, WI-3, ADR-0014).

Bundles just what a localized view needs to render text + quantities, derived
from the model (`toContext` lives near `Main`) and threaded as the first argument
to localized views — so leaf views never reach into `model.settings`. It is a
**record** holding one field today (`language`); the descoped unit system
(TASK-070) joins as `units` with no change to any view signature, only to the
formatters that read it.

Lives in its own module (not `Main`) so `Format`/`Translations` can take a
`Context` without importing `Main`, which imports them.

-}

import Language exposing (Language)


type alias Context =
    { language : Language }
