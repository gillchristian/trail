module AidCsv exposing
    ( ParseResult
    , RowIssue
    , formatClock
    , parse
    , parseClock
    , toCsv
    )

{-| Aid-station CSV import + export.

The import format is what a race organiser's aid table looks like once
pasted into a spreadsheet and saved as CSV. Parsing is deliberately
lenient: only `name` and a distance column are required, the header row
is optional, and a malformed *optional* field downgrades to a warning
(the row still imports with a fallback) rather than dropping the row.
A bad *required* field (name / distance) drops just that one row — the
rest still import. `parse` therefore returns the valid rows **and** the
issues, so the UI can preview both before the user commits.

Distance unit is chosen by the header: `distance_km` (or `km` /
`distance`) is kilometres; `distance_mi` (or `mi` / `miles`) is miles,
converted to metres on ingest. Storage is always metric. With no
recognizable header, columns are positional
`name, distance_km, rest_min, services, cutoff, notes` and distance is
assumed kilometres.

`toCsv` writes the canonical export columns
`name,distance_km,rest_min,services,cutoff,notes` (always km); the
output re-imports cleanly.

This module owns no ids — `parse` leaves `AidStation.id = ""`; the
caller assigns ids when the user commits the import.

-}

import Types exposing (AidStation, Service(..), serviceToString, sortAidStations)


metresPerMile : Float
metresPerMile =
    1609.344


distanceSlackMetres : Float
distanceSlackMetres =
    5



-- PUBLIC TYPES


type alias ParseResult =
    { stations : List AidStation -- valid rows, id = "", sorted by distance
    , errors : List RowIssue -- rows that did NOT import
    , warnings : List RowIssue -- rows that imported, with a caveat
    }


type alias RowIssue =
    { row : Int -- 1-based data-row number (header excluded); 0 = whole-file
    , message : String
    }



-- COLUMN MAP


type Unit
    = Km
    | Mi


type alias ColMap =
    { name : Int
    , distance : Int
    , unit : Unit
    , rest : Maybe Int
    , services : Maybe Int
    , cutoff : Maybe Int
    , notes : Maybe Int
    }


positionalColMap : ColMap
positionalColMap =
    { name = 0
    , distance = 1
    , unit = Km
    , rest = Just 2
    , services = Just 3
    , cutoff = Just 4
    , notes = Just 5
    }



-- PARSE


parse : { totalDistance : Float, defaultRestSeconds : Int } -> String -> ParseResult
parse cfg raw =
    let
        stripped =
            stripBom raw

        delim =
            detectDelimiter stripped

        records =
            tokenize delim stripped
                |> List.filter (not << isBlankRecord)
    in
    case records of
        [] ->
            fileError "No rows found in the file."

        first :: rest ->
            case headerColMap first of
                Just colMap ->
                    buildRows cfg delim colMap rest

                Nothing ->
                    -- First row isn't a recognizable header → treat every
                    -- record as data, mapped positionally.
                    buildRows cfg delim positionalColMap records


fileError : String -> ParseResult
fileError msg =
    { stations = [], errors = [ { row = 0, message = msg } ], warnings = [] }


buildRows : { totalDistance : Float, defaultRestSeconds : Int } -> Char -> ColMap -> List (List String) -> ParseResult
buildRows cfg delim colMap dataRecords =
    let
        step ( rowNum, fields ) acc =
            case parseRow cfg delim colMap rowNum fields of
                Ok ( station, maybeWarn ) ->
                    { acc
                        | stations = station :: acc.stations
                        , warnings = prependMaybe maybeWarn acc.warnings
                    }

                Err issue ->
                    { acc | errors = issue :: acc.errors }

        result =
            dataRecords
                |> List.indexedMap (\i r -> ( i + 1, r ))
                |> List.foldl step { stations = [], errors = [], warnings = [] }
    in
    { stations = sortAidStations (List.reverse result.stations)
    , errors = List.reverse result.errors
    , warnings = List.reverse result.warnings
    }


prependMaybe : Maybe a -> List a -> List a
prependMaybe m xs =
    case m of
        Just x ->
            x :: xs

        Nothing ->
            xs


parseRow : { totalDistance : Float, defaultRestSeconds : Int } -> Char -> ColMap -> Int -> List String -> Result RowIssue ( AidStation, Maybe RowIssue )
parseRow cfg delim colMap rowNum fields =
    let
        name =
            cell colMap.name fields
    in
    if String.isEmpty name then
        Err { row = rowNum, message = "missing name" }

    else
        case parseDistance colMap.unit (cell colMap.distance fields) of
            Err msg ->
                Err { row = rowNum, message = msg }

            Ok metres ->
                if metres > cfg.totalDistance + distanceSlackMetres then
                    Err
                        { row = rowNum
                        , message =
                            "distance "
                                ++ km1 metres
                                ++ " km is beyond the route end ("
                                ++ km1 cfg.totalDistance
                                ++ " km)"
                        }

                else
                    let
                        ( rest, restWarn ) =
                            parseRestField cfg colMap fields

                        ( services, svcWarn ) =
                            parseServicesField delim colMap fields

                        ( cutoff, cutWarn ) =
                            parseCutoffField colMap fields

                        notes =
                            colMap.notes
                                |> Maybe.map (\i -> cell i fields)
                                |> Maybe.withDefault ""

                        station =
                            { id = ""
                            , name = name
                            , distance = metres
                            , restSeconds = rest
                            , services = services
                            , notes = notes
                            , cutoff = cutoff
                            }
                    in
                    Ok ( station, combineWarnings rowNum [ restWarn, svcWarn, cutWarn ] )


parseDistance : Unit -> String -> Result String Float
parseDistance unit raw =
    if String.isEmpty raw then
        Err "missing distance"

    else
        case String.toFloat (cleanNumber raw) of
            Nothing ->
                Err ("distance \"" ++ raw ++ "\" isn't a number")

            Just v ->
                if v < 0 then
                    Err "distance is negative"

                else
                    Ok
                        (v
                            * (case unit of
                                Km ->
                                    1000

                                Mi ->
                                    metresPerMile
                              )
                        )


parseRestField : { totalDistance : Float, defaultRestSeconds : Int } -> ColMap -> List String -> ( Int, Maybe String )
parseRestField cfg colMap fields =
    case colMap.rest of
        Nothing ->
            ( cfg.defaultRestSeconds, Nothing )

        Just i ->
            let
                raw =
                    cell i fields
            in
            if String.isEmpty raw then
                ( cfg.defaultRestSeconds, Nothing )

            else
                case String.toFloat (cleanNumber raw) of
                    Just m ->
                        if m >= 0 then
                            ( round (m * 60), Nothing )

                        else
                            ( cfg.defaultRestSeconds, Just ("rest \"" ++ raw ++ "\" is negative; used default") )

                    Nothing ->
                        ( cfg.defaultRestSeconds, Just ("rest \"" ++ raw ++ "\" isn't a number; used default") )


parseServicesField : Char -> ColMap -> List String -> ( List Service, Maybe String )
parseServicesField delim colMap fields =
    case colMap.services of
        Nothing ->
            ( [], Nothing )

        Just i ->
            let
                ( known, unknown ) =
                    splitServices delim (cell i fields)
                        |> List.foldr
                            (\tok ( ks, us ) ->
                                case serviceFromToken tok of
                                    Just s ->
                                        ( s :: ks, us )

                                    Nothing ->
                                        ( ks, tok :: us )
                            )
                            ( [], [] )
            in
            ( dedupe known
            , case unknown of
                [] ->
                    Nothing

                _ ->
                    Just
                        ((if List.length unknown == 1 then
                            "unknown service: "

                          else
                            "unknown services: "
                         )
                            ++ String.join ", " unknown
                        )
            )


parseCutoffField : ColMap -> List String -> ( Maybe Int, Maybe String )
parseCutoffField colMap fields =
    case colMap.cutoff of
        Nothing ->
            ( Nothing, Nothing )

        Just i ->
            let
                raw =
                    cell i fields
            in
            if String.isEmpty raw then
                ( Nothing, Nothing )

            else
                case parseClock raw of
                    Just secs ->
                        ( Just secs, Nothing )

                    Nothing ->
                        ( Nothing, Just ("cutoff \"" ++ raw ++ "\" isn't h:mm or h:mm:ss; ignored") )


combineWarnings : Int -> List (Maybe String) -> Maybe RowIssue
combineWarnings rowNum maybes =
    case List.filterMap identity maybes of
        [] ->
            Nothing

        msgs ->
            Just { row = rowNum, message = String.join "; " msgs }



-- CLOCK (elapsed time from start)


{-| Parse an elapsed cutoff. Accepts `h:mm`, `hh:mm`, `hh:mm:ss`, and the
`6h30` form (the `h` is treated as a `:`). A bare number is rejected
(ambiguous) so it surfaces as a warning rather than a silent misread.
-}
parseClock : String -> Maybe Int
parseClock raw =
    let
        parts =
            raw
                |> String.trim
                |> String.replace "h" ":"
                |> String.replace "H" ":"
                |> String.split ":"
                |> List.map String.trim
                |> List.filter (not << String.isEmpty)
                |> List.map String.toInt
    in
    case parts of
        [ Just h, Just m ] ->
            if h >= 0 && m >= 0 && m < 60 then
                Just (h * 3600 + m * 60)

            else
                Nothing

        [ Just h, Just m, Just s ] ->
            if h >= 0 && m >= 0 && m < 60 && s >= 0 && s < 60 then
                Just (h * 3600 + m * 60 + s)

            else
                Nothing

        _ ->
            Nothing


formatClock : Int -> String
formatClock secs =
    let
        h =
            secs // 3600

        m =
            modBy 60 (secs // 60)

        s =
            modBy 60 secs
    in
    String.fromInt h ++ ":" ++ pad2 m ++ ":" ++ pad2 s



-- SERVICES


serviceFromToken : String -> Maybe Service
serviceFromToken raw =
    case normalizeToken raw of
        "water" ->
            Just Water

        "w" ->
            Just Water

        "agua" ->
            Just Water

        "eau" ->
            Just Water

        "food" ->
            Just Food

        "f" ->
            Just Food

        "nutrition" ->
            Just Food

        "comida" ->
            Just Food

        "fruit" ->
            Just Food

        "gel" ->
            Just Food

        "gels" ->
            Just Food

        "warm food" ->
            Just WarmFood

        "warmfood" ->
            Just WarmFood

        "hot food" ->
            Just WarmFood

        "hotfood" ->
            Just WarmFood

        "hot meal" ->
            Just WarmFood

        "hot meals" ->
            Just WarmFood

        "soup" ->
            Just WarmFood

        "broth" ->
            Just WarmFood

        "medical" ->
            Just Medical

        "med" ->
            Just Medical

        "medic" ->
            Just Medical

        "first aid" ->
            Just Medical

        "firstaid" ->
            Just Medical

        "doctor" ->
            Just Medical

        "wc" ->
            Just WC

        "toilet" ->
            Just WC

        "toilets" ->
            Just WC

        "restroom" ->
            Just WC

        "bathroom" ->
            Just WC

        "drop bag" ->
            Just DropBag

        "dropbag" ->
            Just DropBag

        "drop" ->
            Just DropBag

        "bag" ->
            Just DropBag

        _ ->
            Nothing


splitServices : Char -> String -> List String
splitServices delim raw =
    let
        -- Within a cell, services are separated by | or / (and ; too when
        -- the field delimiter isn't ;). Normalize them all to one marker.
        seps =
            if delim == ',' then
                [ '|', '/', ';' ]

            else
                [ '|', '/' ]

        unified =
            List.foldl (\c s -> String.replace (String.fromChar c) "\u{0000}" s) raw seps
    in
    unified
        |> String.split "\u{0000}"
        |> List.map String.trim
        |> List.filter (not << String.isEmpty)


dedupe : List Service -> List Service
dedupe =
    List.foldl
        (\x acc ->
            if List.member x acc then
                acc

            else
                acc ++ [ x ]
        )
        []



-- EXPORT


toCsv : List AidStation -> String
toCsv stations =
    let
        header =
            [ "name", "distance_km", "rest_min", "services", "cutoff", "notes" ]

        row a =
            [ a.name
            , formatKm a.distance
            , formatMinutes a.restSeconds
            , a.services |> List.map serviceToString |> String.join "|"
            , a.cutoff |> Maybe.map formatClock |> Maybe.withDefault ""
            , a.notes
            ]
    in
    (header :: List.map row (sortAidStations stations))
        |> List.map encodeRow
        |> String.join "\u{000D}\n"


encodeRow : List String -> String
encodeRow =
    List.map encodeField >> String.join ","


encodeField : String -> String
encodeField s =
    if
        String.contains "," s
            || String.contains "\"" s
            || String.contains "\n" s
            || String.contains "\u{000D}" s
            || String.contains ";" s
    then
        "\"" ++ String.replace "\"" "\"\"" s ++ "\""

    else
        s



-- CSV TOKENIZER (RFC-4180-ish)


type alias TokState =
    { records : List (List String) -- completed records, reversed
    , row : List String -- current record's fields, reversed
    , field : List Char -- current field's chars, reversed
    , inQuotes : Bool
    , afterQuote : Bool -- previous char closed a quoted field
    , prevCR : Bool -- previous char was '\r' (to collapse CRLF)
    }


tokenize : Char -> String -> List (List String)
tokenize delim input =
    let
        endField st =
            { st | field = [], row = String.fromList (List.reverse st.field) :: st.row }

        endRecord st =
            let
                st2 =
                    endField st
            in
            { st2 | row = [], records = List.reverse st2.row :: st2.records }

        step ch st =
            if st.inQuotes then
                if ch == '"' then
                    { st | inQuotes = False, afterQuote = True, prevCR = False }

                else
                    { st | field = ch :: st.field, prevCR = False }

            else if st.afterQuote && ch == '"' then
                -- "" inside a quoted field → a literal quote; re-enter quotes
                { st | field = '"' :: st.field, inQuotes = True, afterQuote = False, prevCR = False }

            else
                let
                    s0 =
                        { st | afterQuote = False }
                in
                if ch == '"' then
                    { s0 | inQuotes = True, prevCR = False }

                else if ch == delim then
                    endField { s0 | prevCR = False }

                else if ch == '\u{000D}' then
                    endRecord { s0 | prevCR = True }

                else if ch == '\n' then
                    if st.prevCR then
                        { s0 | prevCR = False }

                    else
                        endRecord { s0 | prevCR = False }

                else
                    { s0 | field = ch :: s0.field, prevCR = False }

        final =
            String.foldl step
                { records = [], row = [], field = [], inQuotes = False, afterQuote = False, prevCR = False }
                input

        -- Flush a final field/record when the input doesn't end in a newline.
        flushed =
            if List.isEmpty final.field && List.isEmpty final.row then
                final

            else
                endRecord final
    in
    List.reverse flushed.records



-- HEADER DETECTION


headerColMap : List String -> Maybe ColMap
headerColMap cells =
    let
        indexed =
            List.indexedMap Tuple.pair cells

        findFirst test =
            indexed
                |> List.filter (\( _, c ) -> test c)
                |> List.head
                |> Maybe.map Tuple.first

        distMatch =
            indexed
                |> List.filterMap (\( i, c ) -> distanceUnitFor c |> Maybe.map (\u -> ( i, u )))
                |> List.head
    in
    case ( findFirst isNameHeader, distMatch ) of
        ( Just ni, Just ( di, unit ) ) ->
            Just
                { name = ni
                , distance = di
                , unit = unit
                , rest = findFirst isRestHeader
                , services = findFirst isServicesHeader
                , cutoff = findFirst isCutoffHeader
                , notes = findFirst isNotesHeader
                }

        _ ->
            Nothing


isNameHeader : String -> Bool
isNameHeader c =
    List.member (normalizeToken c)
        [ "name", "station", "aid", "aid station", "aid station name", "location", "place", "point", "checkpoint", "cp" ]


distanceUnitFor : String -> Maybe Unit
distanceUnitFor c =
    let
        n =
            normalizeToken c
    in
    if List.member n [ "distance mi", "dist mi", "mi", "miles", "mile", "distance miles", "miles from start" ] then
        Just Mi

    else if List.member n [ "distance km", "dist km", "km", "distance", "dist", "distance from start", "km from start", "kms" ] then
        Just Km

    else
        Nothing


isRestHeader : String -> Bool
isRestHeader c =
    List.member (normalizeToken c)
        [ "rest", "rest min", "rest minutes", "rest mins", "stop", "stop min", "rest time", "pause", "dwell", "stopped" ]


isServicesHeader : String -> Bool
isServicesHeader c =
    List.member (normalizeToken c)
        [ "services", "service", "supplies", "provisions" ]


isCutoffHeader : String -> Bool
isCutoffHeader c =
    List.member (normalizeToken c)
        [ "cutoff", "cut off", "cutoff time", "cut off time", "barrier", "barriere", "barrier time", "close", "closing", "closes", "limit" ]


isNotesHeader : String -> Bool
isNotesHeader c =
    List.member (normalizeToken c)
        [ "notes", "note", "comment", "comments", "remarks", "info", "description", "desc" ]



-- SMALL HELPERS


{-| Lowercase, trim, and collapse every non-alphanumeric run to a single
space. `"Drop-Bag"` → `"drop bag"`, `"Distance (km)"` → `"distance km"`.
-}
normalizeToken : String -> String
normalizeToken s =
    s
        |> String.toLower
        |> String.map
            (\c ->
                if Char.isAlphaNum c then
                    c

                else
                    ' '
            )
        |> String.words
        |> String.join " "


cell : Int -> List String -> String
cell idx fields =
    fields |> List.drop idx |> List.head |> Maybe.withDefault "" |> String.trim


{-| Make a numeric string parseable: a comma is a decimal point when no
dot is present, otherwise a thousands separator; everything except
digits, dot and minus is dropped (so `"12.4 km"` → `"12.4"`).
-}
cleanNumber : String -> String
cleanNumber s =
    (if String.contains "." s then
        String.replace "," "" s

     else
        String.replace "," "." s
    )
        |> String.filter (\c -> Char.isDigit c || c == '.' || c == '-')


stripBom : String -> String
stripBom s =
    if String.startsWith "\u{FEFF}" s then
        String.dropLeft 1 s

    else
        s


detectDelimiter : String -> Char
detectDelimiter input =
    let
        firstLine =
            input |> String.lines |> List.head |> Maybe.withDefault ""

        count ch =
            String.length firstLine - String.length (String.replace ch "" firstLine)
    in
    if count ";" > count "," then
        ';'

    else
        ','


isBlankRecord : List String -> Bool
isBlankRecord fields =
    List.all (String.trim >> String.isEmpty) fields


pad2 : Int -> String
pad2 =
    String.fromInt >> String.padLeft 2 '0'


km1 : Float -> String
km1 metres =
    let
        km =
            metres / 1000
    in
    String.fromFloat (toFloat (round (km * 10)) / 10)


formatKm : Float -> String
formatKm metres =
    String.fromFloat (toFloat (round (metres / 1000 * 1000)) / 1000)


formatMinutes : Int -> String
formatMinutes secs =
    String.fromFloat (toFloat (round (toFloat secs / 60 * 100)) / 100)
