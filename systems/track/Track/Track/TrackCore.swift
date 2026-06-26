//
//  TrackCore.swift
//  Track
//
//  TRACK-002 (WI-2) — the domain model, projections, and durable persistence: the
//  Foundation-only core of the tracker (no SwiftUI). Lifted out of ContentView.swift,
//  where WI-1's stub lived. Load-bearing invariants (mvp-plan.md §2) live here:
//  the event log is append-only and fsync'd after every append; race status / effective
//  end / aid-station visit state are *projections* over the log, never stored flags; and
//  voice notes write audio → fsync → *then* append the referencing event (an orphan audio
//  file is the safe failure direction, never an event pointing at missing audio).
//

import Foundation

// MARK: - Identity

typealias RaceID = UUID
typealias EventID = UUID
typealias TrackableID = UUID

// MARK: - Trackable library

struct TrackableElement: Identifiable, Codable, Equatable {
    let id: TrackableID
    var label: String
    var category: TrackableCategory

    init(id: TrackableID = UUID(), label: String, category: TrackableCategory) {
        self.id = id
        self.label = label
        self.category = category
    }
}

enum TrackableCategory: String, Codable, CaseIterable {
    case nutrition, hydration, gear, other

    var displayName: String { rawValue.capitalized }
}

// MARK: - Race (metadata; events live separately in events.log)

struct Race: Identifiable, Codable, Equatable {
    let id: RaceID
    var name: String
    var createdAt: Date          // when created in the app
    var date: Date?              // scheduled race date (optional); != createdAt, != raceStarted
    var aidStations: [PlannedAidStation]
    var palette: [TrackableElement]   // snapshot of selected library items + ad-hoc
    var planRef: PlanRef?

    init(id: RaceID = UUID(), name: String, createdAt: Date = Date(),
         date: Date? = nil, aidStations: [PlannedAidStation] = [],
         palette: [TrackableElement] = [], planRef: PlanRef? = nil) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.date = date
        self.aidStations = aidStations
        self.palette = palette
        self.planRef = planRef
    }

    // Tolerant decode: WI-1's race.json carried only id/name/createdAt. Default the fields
    // WI-2 adds so older bundles (and partial writes) still load instead of being dropped.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(RaceID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        date = try c.decodeIfPresent(Date.self, forKey: .date)
        aidStations = try c.decodeIfPresent([PlannedAidStation].self, forKey: .aidStations) ?? []
        palette = try c.decodeIfPresent([TrackableElement].self, forKey: .palette) ?? []
        planRef = try c.decodeIfPresent(PlanRef.self, forKey: .planRef)
    }
}

struct PlannedAidStation: Identifiable, Codable, Equatable {
    let id: UUID
    var ordinal: Int             // 1-based
    var name: String             // may be "" -> display "AS <ordinal>"
    var services: [String]       // mirrors Trail's CSV (cell encoding lifted in WI-5)
    var distanceKm: Double?       // from the CSV; powers distance-to-next

    init(id: UUID = UUID(), ordinal: Int, name: String = "",
         services: [String] = [], distanceKm: Double? = nil) {
        self.id = id
        self.ordinal = ordinal
        self.name = name
        self.services = services
        self.distanceKm = distanceKm
    }
}

struct PlanRef: Codable, Equatable {
    let planID: UUID             // Trail plan identity
    let integrityHash: String    // lets app 3 verify the exact plan version
}

/// The create/configure-race editing buffer (mvp-plan.md §6.2; WI-4). A pure value type so the
/// load-bearing logic — keeping aid-station ordinals 1-based after a reorder, and toggling the
/// palette snapshot by id — is unit-testable without the SwiftUI layer. `build()` freezes it into a
/// `Race`; `palette` is the SNAPSHOT the race stores (selected library items + ad-hoc), per §4.
struct RaceDraft: Equatable {
    var name: String = ""
    var date: Date?
    var aidStations: [PlannedAidStation] = []
    var palette: [TrackableElement] = []

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isValid: Bool { !trimmedName.isEmpty }

    // ── Aid stations: ordinals stay 1-based + contiguous through every edit ──
    mutating func addAidStation(name: String = "") {
        aidStations.append(PlannedAidStation(ordinal: aidStations.count + 1, name: name))
    }

    mutating func removeAidStations(at offsets: IndexSet) {
        aidStations.remove(atOffsets: offsets)
        renumberAidStations()
    }

    mutating func moveAidStations(fromOffsets: IndexSet, toOffset: Int) {
        aidStations.move(fromOffsets: fromOffsets, toOffset: toOffset)
        renumberAidStations()
    }

    /// Replace the aid stations wholesale (a CSV import, WI-5) and renumber to 1-based ordinals.
    mutating func replaceAidStations(with stations: [PlannedAidStation]) {
        aidStations = stations
        renumberAidStations()
    }

    private mutating func renumberAidStations() {
        for index in aidStations.indices { aidStations[index].ordinal = index + 1 }
    }

    // ── Palette: a snapshot, matched by id (a later library edit must not mutate the snapshot) ──
    func paletteContains(_ item: TrackableElement) -> Bool {
        palette.contains { $0.id == item.id }
    }

    mutating func togglePalette(_ item: TrackableElement) {
        if let index = palette.firstIndex(where: { $0.id == item.id }) {
            palette.remove(at: index)
        } else {
            palette.append(item)
        }
    }

    /// Build the configured race. `createdAt` defaults to now; the caller may pin it (tests).
    func build(createdAt: Date = Date()) -> Race {
        Race(name: trimmedName, createdAt: createdAt, date: date,
             aidStations: aidStations, palette: palette)
    }
}

// MARK: - Aid-station distances (derived)

extension Array where Element == PlannedAidStation {
    /// Leg distance from the station at `index` to the next one, in km. Distances are cumulative
    /// from the start, so this is `next - here`; nil if either distance is missing or there is no
    /// next station. Lets a view show "→ next aid: N km" (mvp-plan.md §5).
    func distanceToNextKm(after index: Int) -> Double? {
        guard indices.contains(index), index + 1 < count,
              let here = self[index].distanceKm, let next = self[index + 1].distanceKm
        else { return nil }
        return next - here
    }
}

// MARK: - Aid-station CSV import (Trail's format)

/// Parses the aid-station CSV that Trail imports/exports (format lifted from Trail's `AidCsv.elm`)
/// into `[PlannedAidStation]`. The tracker models only the three columns it needs — **name**,
/// cumulative **distance** (km), and **services** — and ignores Trail's rest/cutoff/notes (plan
/// richness that arrives with full `.trail` ingestion, WI-9). Faithful to Trail on the load-bearing
/// details: RFC-4180 quoting, comma-or-semicolon delimiter, the services-cell separators, and km/mi
/// headers. Lenient like Trail: a header row is optional, and a row missing a name or a parseable
/// distance is skipped (counted) rather than failing the whole import. Services are kept as the raw
/// cell tokens (the tracker is a passive recorder; it does not normalise to Trail's typed enum).
enum AidStationCSV {
    struct Result {
        var stations: [PlannedAidStation]
        var skippedRows: Int
    }

    static func parse(_ raw: String) -> Result {
        let text = normalizeNewlines(stripBOM(raw))
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return Result(stations: [], skippedRows: 0)
        }
        let delimiter = detectDelimiter(text)
        var rows = tokenize(text, delimiter: delimiter).filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        guard !rows.isEmpty else { return Result(stations: [], skippedRows: 0) }

        let layout = columnLayout(header: rows[0])
        if layout.fromHeader { rows.removeFirst() }

        var stations: [PlannedAidStation] = []
        var skipped = 0
        for row in rows {
            if let station = station(from: row, layout: layout, delimiter: delimiter,
                                     ordinal: stations.count + 1) {
                stations.append(station)
            } else {
                skipped += 1
            }
        }
        return Result(stations: stations, skippedRows: skipped)
    }

    // ── Column layout ─────────────────────────────────────────
    private struct Layout {
        var name: Int
        var distance: Int
        var services: Int
        var distanceInMiles: Bool
        var fromHeader: Bool
    }

    /// Recognise a header row and map columns by name; else fall back to Trail's positional order
    /// (name, distance_km, rest_min, services, cutoff, notes) and treat row 0 as data.
    private static func columnLayout(header: [String]) -> Layout {
        var name: Int?, distance: Int?, services: Int?
        var miles = false
        for (index, cell) in header.enumerated() {
            switch headerKind(cell) {
            case .name where name == nil:           name = index
            case .distanceKm where distance == nil: distance = index
            case .distanceMiles where distance == nil: distance = index; miles = true
            case .services where services == nil:   services = index
            default: break
            }
        }
        if name != nil || distance != nil || services != nil {
            return Layout(name: name ?? 0, distance: distance ?? 1, services: services ?? 3,
                          distanceInMiles: miles, fromHeader: true)
        }
        return Layout(name: 0, distance: 1, services: 3, distanceInMiles: false, fromHeader: false)
    }

    private enum HeaderKind { case name, distanceKm, distanceMiles, services, other }

    private static func headerKind(_ cell: String) -> HeaderKind {
        var normalized = ""
        for scalar in cell.lowercased().unicodeScalars {
            normalized.append(CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " ")
        }
        let key = normalized.split(separator: " ").joined(separator: " ")
        switch key {
        case "name", "station", "aid", "aid station", "aid station name",
             "location", "place", "point", "checkpoint", "cp":
            return .name
        case "distance mi", "dist mi", "mi", "miles", "mile", "distance miles", "miles from start":
            return .distanceMiles
        case "distance km", "dist km", "km", "distance", "dist",
             "distance from start", "km from start", "kms":
            return .distanceKm
        case "services", "service", "facilities", "amenities":
            return .services
        default:
            return .other
        }
    }

    // ── One row -> station ────────────────────────────────────
    private static func station(from row: [String], layout: Layout, delimiter: Character,
                                ordinal: Int) -> PlannedAidStation? {
        let name = field(row, layout.name).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }                      // name required (Trail rejects)
        guard let km = distanceKm(field(row, layout.distance), miles: layout.distanceInMiles) else {
            return nil                                               // distance required + parseable
        }
        let services = splitServices(field(row, layout.services), delimiter: delimiter)
        return PlannedAidStation(ordinal: ordinal, name: name, services: services, distanceKm: km)
    }

    private static func field(_ row: [String], _ index: Int) -> String {
        index >= 0 && index < row.count ? row[index] : ""
    }

    /// Trail's `cleanNumber`: a comma is the decimal separator when there's no period, else thousands
    /// punctuation to strip; then keep only digits / `.` / `-`. Miles convert to km.
    private static func distanceKm(_ raw: String, miles: Bool) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let unified = trimmed.contains(".") ? trimmed.replacingOccurrences(of: ",", with: "")
                                            : trimmed.replacingOccurrences(of: ",", with: ".")
        let cleaned = unified.filter { $0.isNumber || $0 == "." || $0 == "-" }
        guard let value = Double(cleaned) else { return nil }
        return miles ? value * 1.609344 : value
    }

    /// Trail's `splitServices`: split the one cell on `|` and `/` (and `;` when the field delimiter
    /// is a comma), trim, drop empties. Tokens are kept verbatim.
    private static func splitServices(_ raw: String, delimiter: Character) -> [String] {
        let separators: Set<Character> = delimiter == "," ? ["|", "/", ";"] : ["|", "/"]
        return raw.split(whereSeparator: { separators.contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    // ── RFC-4180 tokenizer ────────────────────────────────────
    private static func stripBOM(_ s: String) -> String {
        s.hasPrefix("\u{FEFF}") ? String(s.dropFirst()) : s
    }

    /// Normalise CRLF and lone CR to LF first. Swift treats `\r\n` as a *single* `Character`
    /// (one grapheme cluster), so the tokenizer — which iterates Characters — would otherwise never
    /// match it against `"\n"`; collapsing line endings up front lets it see only `"\n"`.
    private static func normalizeNewlines(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    /// Pick `;` over `,` only if the first line has strictly more semicolons (Trail's heuristic).
    private static func detectDelimiter(_ text: String) -> Character {
        let firstLine = text.prefix { $0 != "\n" }
        let semis = firstLine.filter { $0 == ";" }.count
        let commas = firstLine.filter { $0 == "," }.count
        return semis > commas ? ";" : ","
    }

    /// Split into rows of fields honouring RFC-4180 quoting: `"`-quoted fields may contain the
    /// delimiter, embedded `\n`, and doubled `""` for a literal quote. Line endings are already
    /// normalised to `\n` by `normalizeNewlines`, so only `"\n"` ends a row here.
    private static func tokenize(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 2 }
                    else { inQuotes = false; i += 1 }
                } else {
                    field.append(c); i += 1
                }
            } else if c == "\"" {
                inQuotes = true; i += 1
            } else if c == delimiter {
                row.append(field); field = ""; i += 1
            } else if c == "\n" {
                row.append(field); rows.append(row); field = ""; row = []; i += 1
            } else {
                field.append(c); i += 1
            }
        }
        row.append(field)
        rows.append(row)
        return rows
    }
}

// MARK: - Events (the append-only log)

struct RaceEvent: Identifiable, Codable, Equatable {
    let id: EventID
    var at: Date                 // logical wall-clock; the JOIN KEY for app 3's GPS pairing
    let kind: RaceEventKind

    init(id: EventID = UUID(), at: Date = Date(), kind: RaceEventKind) {
        self.id = id
        self.at = at
        self.kind = kind
    }
}

enum RaceEventKind: Codable, Equatable {
    case raceStarted
    case raceEnded
    case endTimeCorrected(to: Date)                                     // correction, not mutation
    case aidStationEntered(visitID: UUID, ordinal: Int?, label: String) // arrival; label inline
    case aidStationExited(visitID: UUID)                                // departure; pairs by visitID
    case intake(trackableID: TrackableID?, label: String)               // one tap = one item
    case voiceNote(audioFilename: String, durationSec: Double)
    case retraction(target: EventID)                                    // Undo: hides target; never deletes
    // deferred: deviation(...), feeling(rpe:tags:), marker(kind:)
}

// MARK: - Projections (derived, never stored)

enum RaceStatus: Equatable { case configured, inProgress, finished }

enum VisitState: Equatable {
    case inProgress                 // entered; no exit; no later entry -> you are here now
    case departed(at: Date)         // explicit exit recorded (approximate; GPS may refine dwell)
    case departedExitUnrecorded     // open visit superseded by a later entry -> forgot to Finish
}

struct AidStationVisit: Identifiable, Equatable {
    let visitID: UUID
    let ordinal: Int?
    let label: String
    let enteredAt: Date             // approximate anchor (as tapped); GPS may refine
    var state: VisitState

    var id: UUID { visitID }
}

extension Array where Element == RaceEvent {
    /// Undo = retraction (mvp-plan.md §4): collect retracted target ids, then drop both the
    /// retracted events *and* the retractions themselves. Every projection folds this list, so
    /// a retraction hides its target everywhere.
    var resolved: [RaceEvent] {
        var retracted = Set<EventID>()
        for event in self {
            if case let .retraction(target) = event.kind { retracted.insert(target) }
        }
        return filter { event in
            if case .retraction = event.kind { return false }
            return !retracted.contains(event.id)
        }
    }

    var status: RaceStatus {
        let events = resolved
        let ended = events.contains { if case .raceEnded = $0.kind { return true } else { return false } }
        if ended { return .finished }
        let started = events.contains { if case .raceStarted = $0.kind { return true } else { return false } }
        return started ? .inProgress : .configured
    }

    /// Effective finish = the latest correction, else the raceEnded event's own time, else nil.
    var effectiveEnd: Date? {
        let events = resolved
        if let corrected = events.last(where: { if case .endTimeCorrected = $0.kind { return true } else { return false } }),
           case let .endTimeCorrected(to) = corrected.kind {
            return to
        }
        if let ended = events.last(where: { if case .raceEnded = $0.kind { return true } else { return false } }) {
            return ended.at
        }
        return nil
    }

    /// Aid-station visits, paired by visitID. A new arrival implicitly departs any still-open
    /// visit with no recorded exit ("forgot to tap Finish" -> .departedExitUnrecorded). The lone
    /// open visit with no later entry is the current station (.inProgress).
    var aidStationVisits: [AidStationVisit] {
        var visits: [AidStationVisit] = []
        var openIndex: Int?
        for event in resolved {
            switch event.kind {
            case let .aidStationEntered(visitID, ordinal, label):
                if let open = openIndex { visits[open].state = .departedExitUnrecorded }
                visits.append(AidStationVisit(visitID: visitID, ordinal: ordinal,
                                              label: label, enteredAt: event.at, state: .inProgress))
                openIndex = visits.count - 1
            case let .aidStationExited(visitID):
                if let idx = visits.lastIndex(where: { $0.visitID == visitID }) {
                    visits[idx].state = .departed(at: event.at)
                    if openIndex == idx { openIndex = nil }
                }
            default:
                break
            }
        }
        return visits
    }
}

// MARK: - Persistence (the durability spine)

/// Each race is a directory bundle (mvp-plan.md §3):
///
///     Races/<raceID>/race.json   metadata — rewritten atomically (temp + fsync + rename)
///     Races/<raceID>/events.log  append-only, one JSON object per line, fsync after each append
///     Races/<raceID>/audio/<eventID>.m4a   voice clips, written *before* their referencing event
///
/// Durability is a primary constraint: a force-quit or dead battery loses at most the single
/// in-flight append; everything already fsync'd survives. Listing races = scan the root; a race's
/// timeline / status = fold its log. The root is injectable so tests use a throwaway directory.
struct RaceStorage {
    let racesRoot: URL

    init(root: URL? = nil) {
        if let root {
            racesRoot = root
        } else {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            racesRoot = documents.appending(path: "Races", directoryHint: .isDirectory)
        }
        try? FileManager.default.createDirectory(at: racesRoot, withIntermediateDirectories: true)
    }

    // ── Bundle layout ─────────────────────────────────────────
    func bundleDir(for id: RaceID) -> URL {
        racesRoot.appending(path: id.uuidString, directoryHint: .isDirectory)
    }
    private func raceJSONURL(for id: RaceID) -> URL { bundleDir(for: id).appending(path: "race.json") }
    private func eventsLogURL(for id: RaceID) -> URL { bundleDir(for: id).appending(path: "events.log") }
    private func audioDir(for id: RaceID) -> URL {
        bundleDir(for: id).appending(path: "audio", directoryHint: .isDirectory)
    }
    func audioURL(for id: RaceID, filename: String) -> URL { audioDir(for: id).appending(path: filename) }

    // ── Coders ────────────────────────────────────────────────
    private static let raceEncoder: JSONEncoder = {          // config — human-readable
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private static let eventEncoder: JSONEncoder = {         // log — compact, ONE line per event
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()
    private static let decoder = JSONDecoder()

    // ── race.json: atomic write (temp + fsync + rename) ───────
    func saveRace(_ race: Race) throws {
        let dir = bundleDir(for: race.id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try DurableFile.atomicWrite(Self.raceEncoder.encode(race), to: raceJSONURL(for: race.id))
    }

    func loadRace(id: RaceID) -> Race? {
        guard let data = try? Data(contentsOf: raceJSONURL(for: id)) else { return nil }
        return try? Self.decoder.decode(Race.self, from: data)
    }

    /// Scan the bundle root, decoding each race.json. A single unreadable bundle is skipped, not
    /// fatal. Newest first.
    func loadAllRaces() -> [Race] {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: racesRoot, includingPropertiesForKeys: nil)) ?? []
        let races = contents.compactMap { dir -> Race? in
            guard let data = try? Data(contentsOf: dir.appending(path: "race.json")) else { return nil }
            return try? Self.decoder.decode(Race.self, from: data)
        }
        return races.sorted { $0.createdAt > $1.createdAt }
    }

    func deleteRace(id: RaceID) throws {
        try FileManager.default.removeItem(at: bundleDir(for: id))
    }

    /// Test affordance: remove every race bundle. Invoked once at launch under `-uitest-reset`
    /// (from TrackApp.init), never from a store init — see that call site for why.
    func reset() {
        let contents = (try? FileManager.default.contentsOfDirectory(
            at: racesRoot, includingPropertiesForKeys: nil)) ?? []
        for url in contents { try? FileManager.default.removeItem(at: url) }
    }

    // ── events.log: append-only, fsync after EVERY append ─────
    func append(_ event: RaceEvent, to raceID: RaceID) throws {
        let dir = bundleDir(for: raceID)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = eventsLogURL(for: raceID)
        if !FileManager.default.fileExists(atPath: url.path) {
            try Data().write(to: url)
        }
        var line = try Self.eventEncoder.encode(event)
        line.append(0x0A)   // '\n' — one JSON object per line
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: line)
        try handle.synchronize()   // fsync: the "resilient to shutdown" guarantee
    }

    /// Crash-tolerant read: decode line by line; a torn final line (a crash mid-append) fails to
    /// decode and is dropped — losing at most the single in-flight event, never the whole log.
    func loadEvents(for raceID: RaceID) -> [RaceEvent] {
        guard let data = try? Data(contentsOf: eventsLogURL(for: raceID)) else { return [] }
        return data.split(separator: 0x0A, omittingEmptySubsequences: true)
            .compactMap { try? Self.decoder.decode(RaceEvent.self, from: Data($0)) }
    }

    // ── voice notes: write audio → fsync → THEN append the event ──
    /// The safe failure direction (mvp-plan.md §3): a crash after the audio write but before the
    /// append leaves an orphan audio file (harmless), never an event referencing missing audio.
    @discardableResult
    func appendVoiceNote(audio: Data, durationSec: Double, to raceID: RaceID,
                         id: EventID = UUID(), at: Date = Date()) throws -> RaceEvent {
        try FileManager.default.createDirectory(at: audioDir(for: raceID), withIntermediateDirectories: true)
        let filename = "\(id.uuidString).m4a"
        try audio.write(to: audioURL(for: raceID, filename: filename))
        try DurableFile.sync(audioURL(for: raceID, filename: filename))   // audio durably on disk FIRST
        let event = RaceEvent(id: id, at: at,
                              kind: .voiceNote(audioFilename: filename, durationSec: durationSec))
        try append(event, to: raceID)                                // THEN the referencing event
        return event
    }

}

// MARK: - Durable file primitives

/// The crash-safe write primitives shared by the whole-file config writers (race.json,
/// trackables.json). `sync` is fsync (FileHandle.synchronize). The append-only events.log fsyncs
/// inline in `RaceStorage.append`; these are only for atomic *replacement* of a whole file.
enum DurableFile {
    static func sync(_ url: URL) throws {
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.synchronize()
    }

    /// Atomic write: temp → fsync → rename. You get either the old bytes or the new, never a
    /// half-written file.
    static func atomicWrite(_ data: Data, to url: URL) throws {
        let tmp = url.appendingPathExtension("tmp")
        try data.write(to: tmp)
        try sync(tmp)
        if FileManager.default.fileExists(atPath: url.path) {
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tmp)
        } else {
            try FileManager.default.moveItem(at: tmp, to: url)
        }
    }
}

// MARK: - Trackable library storage

/// The trackable library — a flat list persisted as `trackables.json` at the persistence root
/// (sibling to `Races/`). Config-like, so it's written atomically (not appended). The source for
/// race palettes (mvp-plan.md §6.5). Root is injectable for tests.
struct TrackableLibraryStorage {
    let fileURL: URL

    init(root: URL? = nil) {
        let base = root ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appending(path: "trackables.json")
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private static let decoder = JSONDecoder()

    func load() -> [TrackableElement] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? Self.decoder.decode([TrackableElement].self, from: data)) ?? []
    }

    func save(_ items: [TrackableElement]) throws {
        try DurableFile.atomicWrite(Self.encoder.encode(items), to: fileURL)
    }

    /// Test affordance: clear the library. Invoked once at launch under `-uitest-reset`.
    func reset() { try? FileManager.default.removeItem(at: fileURL) }
}
