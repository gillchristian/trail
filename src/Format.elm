module Format exposing (localizeDecimal, number)

{-| Locale-aware display formatting (i18n epic, WI-5 language half, ADR-0014).

Localizes the **decimal separator** of display quantities — Spanish renders a
comma, English a period (e.g. `42,2 km` vs `42.2 km`). Colon-formatted values
(pace `M:SS`, clock times) are locale-neutral and never pass through here.

**Display only.** Never route SVG path data, input `value`s, CSV, GPX, or `.trail`
text through these — those require a literal `.` decimal and keep their own
formatters. No unit conversion: distances stay in km (the metric/imperial
preference is descoped to TASK-070). Reuses the app's existing hand-rolled
rounding rather than adding a dependency.

-}

import Language exposing (Language(..))


{-| Swap `.` → `,` for Spanish display; identity for English.
-}
localizeDecimal : Language -> String -> String
localizeDecimal language s =
    case language of
        Spanish ->
            String.replace "." "," s

        English ->
            s


{-| Round to `decimals` places (mirroring the app's existing `formatFloat`
rounding) and localize the separator. Whole values drop the fraction, exactly as
`String.fromFloat` already does — so `number Spanish 1 42` is `"42"`, not `"42,0"`.
-}
number : Language -> Int -> Float -> String
number language decimals f =
    let
        mult =
            10 ^ decimals |> toFloat

        rounded =
            toFloat (round (f * mult)) / mult
    in
    String.fromFloat rounded
        |> localizeDecimal language
