//
//  TrackTests.swift
//  TrackTests
//
//  TRACK-002 (WI-2) — exercises the durability spine and the projections (TrackCore.swift):
//  race.json round-trip + atomic overwrite, append-only events.log with fsync (survives a
//  "relaunch" = a fresh RaceStorage on the same root), crash-torn-line recovery, the
//  status / effectiveEnd / aidStationVisits projections, retraction pre-filtering, and the
//  write-audio-then-append ordering (orphan audio, never a dangling reference).
//

import XCTest
@testable import Track

final class TrackTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "TrackTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    /// A fresh RaceStorage on the same root models a relaunch — in-memory state is gone, only disk remains.
    private func storage() -> RaceStorage { RaceStorage(root: root) }
    private func t(_ seconds: TimeInterval) -> Date { Date(timeIntervalSince1970: seconds) }

    // MARK: - race.json persistence

    func testRaceRoundTripsThroughDisk() throws {
        let race = Race(id: UUID(), name: "UTMB", createdAt: t(1000), date: t(2000),
                        aidStations: [PlannedAidStation(ordinal: 1, name: "Les Houches",
                                                        services: ["water", "food"], distanceKm: 8.0)],
                        palette: [TrackableElement(label: "Gel", category: .nutrition)])
        try storage().saveRace(race)
        XCTAssertEqual(storage().loadRace(id: race.id), race, "race.json should round-trip exactly after relaunch")
    }

    func testLoadAllRacesNewestFirst() throws {
        let store = storage()
        try store.saveRace(Race(name: "older", createdAt: t(1000)))
        try store.saveRace(Race(name: "newer", createdAt: t(2000)))
        XCTAssertEqual(storage().loadAllRaces().map(\.name), ["newer", "older"])
    }

    func testDeleteRaceRemovesBundle() throws {
        let store = storage()
        let race = Race(name: "doomed")
        try store.saveRace(race)
        try store.deleteRace(id: race.id)
        XCTAssertNil(storage().loadRace(id: race.id))
        XCTAssertEqual(storage().loadAllRaces(), [])
    }

    func testRaceOverwriteIsAtomicWithNoStrayTemp() throws {
        let store = storage()
        var race = Race(id: UUID(), name: "v1", createdAt: t(1000))
        try store.saveRace(race)
        race.name = "v2"
        try store.saveRace(race)   // exercises the replace-existing branch (temp + fsync + rename)
        XCTAssertEqual(storage().loadRace(id: race.id)?.name, "v2")
        let tmp = store.bundleDir(for: race.id).appending(path: "race.json.tmp")
        XCTAssertFalse(FileManager.default.fileExists(atPath: tmp.path), "the temp file is consumed by the rename")
    }

    func testTolerantDecodeOfLegacyRaceJSON() throws {
        // A WI-1 race.json carried only id/name/createdAt; it must still load with defaults applied.
        let id = UUID()
        let dir = storage().bundleDir(for: id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacy = #"{"createdAt":12345,"id":"\#(id.uuidString)","name":"Legacy"}"#
        try Data(legacy.utf8).write(to: dir.appending(path: "race.json"))
        let race = try XCTUnwrap(storage().loadRace(id: id))
        XCTAssertEqual(race.name, "Legacy")
        XCTAssertEqual(race.aidStations, [])
        XCTAssertEqual(race.palette, [])
        XCTAssertNil(race.date)
    }

    // MARK: - events.log durability (append-only + fsync + crash recovery)

    func testEventsPersistAndSurviveRelaunch() throws {
        let store = storage()
        let raceID = UUID()
        let events = [
            RaceEvent(id: UUID(), at: t(100), kind: .raceStarted),
            RaceEvent(id: UUID(), at: t(200), kind: .intake(trackableID: nil, label: "Gel")),
            RaceEvent(id: UUID(), at: t(300), kind: .raceEnded),
        ]
        for event in events { try store.append(event, to: raceID) }
        XCTAssertEqual(storage().loadEvents(for: raceID), events,
                       "every fsync'd event survives a relaunch, in append order")
    }

    func testTornLastLineIsDropped() throws {
        let store = storage()
        let raceID = UUID()
        let e1 = RaceEvent(id: UUID(), at: t(100), kind: .raceStarted)
        let e2 = RaceEvent(id: UUID(), at: t(200), kind: .intake(trackableID: nil, label: "Gel"))
        try store.append(e1, to: raceID)
        try store.append(e2, to: raceID)
        // Simulate a crash mid-append: a partial JSON line with no closing brace / newline.
        let log = store.bundleDir(for: raceID).appending(path: "events.log")
        let handle = try FileHandle(forWritingTo: log)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data(#"{"at":99,"id":"truncated"#.utf8))
        try handle.close()
        XCTAssertEqual(storage().loadEvents(for: raceID), [e1, e2],
                       "a torn final line is dropped; everything fsync'd before it survives")
    }

    // MARK: - projections: status / effectiveEnd

    func testStatusProgression() {
        let none: [RaceEvent] = []
        XCTAssertEqual(none.status, .configured)
        let started = RaceEvent(at: t(100), kind: .raceStarted)
        XCTAssertEqual([started].status, .inProgress)
        let ended = RaceEvent(at: t(200), kind: .raceEnded)
        XCTAssertEqual([started, ended].status, .finished)
    }

    func testEffectiveEndUsesLatestCorrection() {
        let started = RaceEvent(at: t(100), kind: .raceStarted)
        let ended = RaceEvent(at: t(900), kind: .raceEnded)            // e.g. phone powered on late
        XCTAssertEqual([started, ended].effectiveEnd, t(900))
        let corrected = RaceEvent(at: t(950), kind: .endTimeCorrected(to: t(500)))
        XCTAssertEqual([started, ended, corrected].effectiveEnd, t(500),
                       "a correction wins over the raceEnded event's own time")
        XCTAssertNil([started].effectiveEnd)
    }

    // MARK: - projections: aid-station visits

    func testVisitPairing() {
        let visitID = UUID()
        let entered = RaceEvent(at: t(100), kind: .aidStationEntered(visitID: visitID, ordinal: 2, label: "AS2"))
        let exited = RaceEvent(at: t(160), kind: .aidStationExited(visitID: visitID))
        let visits = [entered, exited].aidStationVisits
        XCTAssertEqual(visits.count, 1)
        XCTAssertEqual(visits[0].visitID, visitID)
        XCTAssertEqual(visits[0].ordinal, 2)
        XCTAssertEqual(visits[0].enteredAt, t(100))
        XCTAssertEqual(visits[0].state, .departed(at: t(160)))
    }

    func testLoneOpenVisitIsInProgress() {
        let entered = RaceEvent(at: t(100), kind: .aidStationEntered(visitID: UUID(), ordinal: 1, label: "AS1"))
        XCTAssertEqual([entered].aidStationVisits.first?.state, .inProgress)
    }

    func testForgotToFinishMarksPriorVisitExitUnrecorded() {
        let e1 = RaceEvent(at: t(100), kind: .aidStationEntered(visitID: UUID(), ordinal: 1, label: "AS1"))
        let e2 = RaceEvent(at: t(300), kind: .aidStationEntered(visitID: UUID(), ordinal: 2, label: "AS2"))
        let visits = [e1, e2].aidStationVisits
        XCTAssertEqual(visits.count, 2)
        XCTAssertEqual(visits[0].state, .departedExitUnrecorded, "a new arrival implicitly departs the open visit")
        XCTAssertEqual(visits[1].state, .inProgress)
    }

    // MARK: - retraction hides its target everywhere

    func testRetractionHidesIntake() {
        let intake = RaceEvent(id: UUID(), at: t(100), kind: .intake(trackableID: nil, label: "Gel"))
        let undo = RaceEvent(at: t(110), kind: .retraction(target: intake.id))
        XCTAssertTrue([intake, undo].resolved.isEmpty, "the intake and its retraction both vanish")
    }

    func testRetractionOfRaceEndedRevertsStatus() {
        let started = RaceEvent(id: UUID(), at: t(100), kind: .raceStarted)
        let ended = RaceEvent(id: UUID(), at: t(200), kind: .raceEnded)
        let undo = RaceEvent(at: t(210), kind: .retraction(target: ended.id))
        let events = [started, ended, undo]
        XCTAssertEqual(events.status, .inProgress, "undoing the finish returns the race to in-progress")
        XCTAssertNil(events.effectiveEnd)
    }

    func testRetractionHidesAidVisit() {
        let entered = RaceEvent(id: UUID(), at: t(100), kind: .aidStationEntered(visitID: UUID(), ordinal: 1, label: "AS1"))
        let undo = RaceEvent(at: t(110), kind: .retraction(target: entered.id))
        XCTAssertTrue([entered, undo].aidStationVisits.isEmpty)
    }

    // MARK: - voice notes: orphan audio, never a dangling reference

    func testVoiceNoteWritesAudioThenAppendsEvent() throws {
        let store = storage()
        let raceID = UUID()
        let event = try store.appendVoiceNote(audio: Data("fake-m4a".utf8), durationSec: 3.5, to: raceID)
        guard case let .voiceNote(filename, durationSec) = event.kind else {
            return XCTFail("expected a voiceNote event")
        }
        XCTAssertEqual(durationSec, 3.5)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(for: raceID, filename: filename).path),
                      "the audio file is on disk")
        // It's in the log and every voiceNote event references an existing file (no dangling ref).
        let events = storage().loadEvents(for: raceID)
        XCTAssertEqual(events, [event])
        for event in events {
            if case let .voiceNote(name, _) = event.kind {
                XCTAssertTrue(FileManager.default.fileExists(atPath: store.audioURL(for: raceID, filename: name).path),
                              "a voiceNote event must never reference missing audio")
            }
        }
    }

    func testOrphanAudioWithoutEventIsHarmless() throws {
        let store = storage()
        let raceID = UUID()
        // Simulate a crash AFTER the audio write but BEFORE the event append: a stray audio file.
        let audioDir = store.bundleDir(for: raceID).appending(path: "audio", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
        try Data("orphan".utf8).write(to: audioDir.appending(path: "\(UUID().uuidString).m4a"))
        XCTAssertEqual(storage().loadEvents(for: raceID), [],
                       "an orphan audio file yields no event — orphan audio, not a dangling reference")
    }

    // MARK: - WI-3: trackable library

    func testTrackableLibraryStorageRoundTrip() throws {
        let store = TrackableLibraryStorage(root: root)
        let items = [TrackableElement(id: UUID(), label: "Gel", category: .nutrition),
                     TrackableElement(id: UUID(), label: "Water", category: .hydration)]
        try store.save(items)
        XCTAssertEqual(TrackableLibraryStorage(root: root).load(), items, "the library round-trips after relaunch")
    }

    func testTrackableLibraryEmptyByDefault() {
        XCTAssertEqual(TrackableLibraryStorage(root: root).load(), [])
    }

    func testTrackableStoreUpsertCreatesThenEdits() {
        let store = TrackableLibraryStore(storage: TrackableLibraryStorage(root: root))
        var gel = TrackableElement(label: "Gel", category: .nutrition)
        store.upsert(gel)
        XCTAssertEqual(store.items.count, 1)
        gel.label = "Maurten Gel"
        gel.category = .hydration
        store.upsert(gel)   // same id -> edit in place, not a second row
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(store.items.first?.label, "Maurten Gel")
        XCTAssertEqual(store.items.first?.category, .hydration)
    }

    func testTrackableStoreCreatePersistsAcrossReload() {
        let store = TrackableLibraryStore(storage: TrackableLibraryStorage(root: root))
        store.upsert(TrackableElement(label: "Tailwind", category: .hydration))
        store.upsert(TrackableElement(label: "Poles", category: .gear))
        let reloaded = TrackableLibraryStore(storage: TrackableLibraryStorage(root: root))
        XCTAssertEqual(reloaded.items.map(\.label), ["Tailwind", "Poles"], "create persists; order preserved")
    }

    func testTrackableStoreDeletePersists() {
        let store = TrackableLibraryStore(storage: TrackableLibraryStorage(root: root))
        store.upsert(TrackableElement(label: "A", category: .other))
        store.upsert(TrackableElement(label: "B", category: .gear))
        store.delete(at: IndexSet(integer: 0))
        XCTAssertEqual(store.items.map(\.label), ["B"])
        let reloaded = TrackableLibraryStore(storage: TrackableLibraryStorage(root: root))
        XCTAssertEqual(reloaded.items.map(\.label), ["B"], "the delete persisted across relaunch")
    }

    // MARK: - WI-4: create / configure race (RaceDraft + RaceStore)

    func testRaceDraftValidationRequiresNonBlankName() {
        var draft = RaceDraft()
        XCTAssertFalse(draft.isValid, "an empty name is invalid")
        draft.name = "   "
        XCTAssertFalse(draft.isValid, "whitespace-only is still blank")
        draft.name = "  UTMB "
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(draft.build().name, "UTMB", "build() trims the name")
    }

    func testRaceDraftAidStationOrdinalsStayContiguousOnDelete() {
        var draft = RaceDraft()
        draft.addAidStation(name: "Start")
        draft.addAidStation(name: "Mid")
        draft.addAidStation(name: "Finish")
        XCTAssertEqual(draft.aidStations.map(\.ordinal), [1, 2, 3])
        draft.removeAidStations(at: IndexSet(integer: 1))   // drop "Mid"
        XCTAssertEqual(draft.aidStations.map(\.name), ["Start", "Finish"])
        XCTAssertEqual(draft.aidStations.map(\.ordinal), [1, 2], "ordinals renumber after a delete")
    }

    func testRaceDraftMoveRenumbersOrdinals() {
        var draft = RaceDraft()
        for name in ["A", "B", "C"] { draft.addAidStation(name: name) }
        draft.moveAidStations(fromOffsets: IndexSet(integer: 2), toOffset: 0)   // C to the front
        XCTAssertEqual(draft.aidStations.map(\.name), ["C", "A", "B"])
        XCTAssertEqual(draft.aidStations.map(\.ordinal), [1, 2, 3], "ordinals follow position, not identity")
    }

    func testRaceDraftPaletteIsASnapshotMatchedById() {
        var draft = RaceDraft()
        let gel = TrackableElement(label: "Gel", category: .nutrition)
        draft.togglePalette(gel)
        XCTAssertEqual(draft.palette, [gel])
        XCTAssertTrue(draft.paletteContains(gel))
        draft.togglePalette(gel)                       // toggling the same id again removes it
        XCTAssertTrue(draft.palette.isEmpty)
        draft.togglePalette(gel)
        var edited = gel; edited.label = "Maurten Gel" // same id, later library edit
        XCTAssertEqual(draft.palette.first?.label, "Gel", "the snapshot keeps the value as captured")
        XCTAssertTrue(draft.paletteContains(edited), "membership is by id, so the edited item still matches")
    }

    func testRaceDraftBuildProducesConfiguredRace() {
        var draft = RaceDraft()
        draft.name = "Trail 100"
        draft.date = t(5000)
        draft.addAidStation(name: "AS1")
        draft.togglePalette(TrackableElement(label: "Gel", category: .nutrition))
        let race = draft.build(createdAt: t(1000))
        XCTAssertEqual(race.name, "Trail 100")
        XCTAssertEqual(race.date, t(5000))
        XCTAssertEqual(race.createdAt, t(1000))
        XCTAssertEqual(race.aidStations.map(\.name), ["AS1"])
        XCTAssertEqual(race.palette.map(\.label), ["Gel"])
        // No events yet → the race is Configured.
        XCTAssertEqual(storage().loadEvents(for: race.id).status, .configured)
    }

    func testRaceStoreAddPersistsConfiguredRace() {
        let store = RaceStore(storage: storage())
        var draft = RaceDraft()
        draft.name = "Sunset 50K"
        let race = draft.build()
        store.add(race)
        XCTAssertEqual(store.races.first?.id, race.id, "the new race is shown at the top")
        XCTAssertEqual(store.status(for: race), .configured)
        // A fresh store on the same root models a relaunch.
        let reloaded = RaceStore(storage: storage())
        XCTAssertEqual(reloaded.races.map(\.name), ["Sunset 50K"], "the configured race persisted")
        XCTAssertEqual(reloaded.status(for: race), .configured)
    }

    func testRaceStoreInProgressRaceAndLookup() throws {
        let store = RaceStore(storage: storage())
        var draft = RaceDraft(); draft.name = "Lock Race"
        let race = draft.build()
        store.add(race)
        XCTAssertNil(store.inProgressRace, "a configured race is not the active race")
        XCTAssertEqual(store.race(for: race.id)?.id, race.id, "lookup by id finds the race")
        XCTAssertNil(store.race(for: UUID()), "an unknown id finds nothing")

        // Start it (append raceStarted) → a fresh store (relaunch) sees it as the active race.
        try storage().append(RaceEvent(kind: .raceStarted), to: race.id)
        XCTAssertEqual(RaceStore(storage: storage()).inProgressRace?.id, race.id,
                       "a started race is the active race the app forefronts on launch")

        // Finish it → no longer active.
        try storage().append(RaceEvent(kind: .raceEnded), to: race.id)
        XCTAssertNil(RaceStore(storage: storage()).inProgressRace, "a finished race is not active")
    }

    // MARK: - WI-5: aid-station CSV import (AidStationCSV)

    /// A canonical Trail export: 6-column header, pipe-joined services, a quoted name with a comma,
    /// an empty-services finish row. Only name / distance_km / services land in the tracker's model.
    func testCsvImportsTrailExport() {
        let csv = """
        name,distance_km,rest_min,services,cutoff,notes
        Saida / Start,0,0,water,,
        Mirante,4.5,2,water|food,0:45,quick top-up
        Cachoeira,9.0,5,water|food|warm food|wc,1:40,drop bag access
        "Refugio, Le Tour",14.2,3,water|food|medical,2:50,last water
        Chegada / Finish,20.0,0,,3:45,
        """
        let result = AidStationCSV.parse(csv)
        XCTAssertEqual(result.skippedRows, 0)
        XCTAssertEqual(result.stations.map(\.name),
                       ["Saida / Start", "Mirante", "Cachoeira", "Refugio, Le Tour", "Chegada / Finish"])
        XCTAssertEqual(result.stations.map(\.ordinal), [1, 2, 3, 4, 5])
        XCTAssertEqual(result.stations.compactMap(\.distanceKm), [0, 4.5, 9.0, 14.2, 20.0])
        XCTAssertEqual(result.stations[0].services, ["water"])
        XCTAssertEqual(result.stations[2].services, ["water", "food", "warm food", "wc"])
        XCTAssertEqual(result.stations[4].services, [], "an empty services cell is no services")
    }

    func testCsvServicesSplitOnPipeSlashAndSemicolon() {
        let csv = """
        name,distance_km,services
        A,1,water|food
        B,2,water/food
        C,3,water;food
        D,4,water | food / gel ; wc
        """
        let r = AidStationCSV.parse(csv)
        XCTAssertEqual(r.stations[0].services, ["water", "food"])
        XCTAssertEqual(r.stations[1].services, ["water", "food"])
        XCTAssertEqual(r.stations[2].services, ["water", "food"], "';' is a service separator under a comma delimiter")
        XCTAssertEqual(r.stations[3].services, ["water", "food", "gel", "wc"], "mixed separators, trimmed")
    }

    func testCsvQuotedFieldWithEmbeddedCommaAndDoubledQuote() {
        let csv = "name,distance_km,services\r\n\"Base \"\"Camp\"\", North\",7.5,water|food\r\n"
        let r = AidStationCSV.parse(csv)
        guard r.stations.count == 1 else {
            return XCTFail("expected exactly 1 station, got \(r.stations.count)")
        }
        XCTAssertEqual(r.stations[0].name, "Base \"Camp\", North", "RFC-4180: doubled quotes + embedded comma")
        XCTAssertEqual(r.stations[0].distanceKm, 7.5)
        XCTAssertEqual(r.stations[0].services, ["water", "food"])
    }

    func testCsvMilesHeaderConvertsToKm() {
        let csv = """
        name,distance_mi,services
        Start,0,water
        Mid,3,water/food
        """
        let r = AidStationCSV.parse(csv)
        XCTAssertEqual(r.stations.count, 2)
        XCTAssertEqual(r.stations[0].distanceKm ?? -1, 0, accuracy: 0.0001)
        XCTAssertEqual(r.stations[1].distanceKm ?? -1, 3 * 1.609344, accuracy: 0.0001, "miles convert to km")
    }

    func testCsvSkipsRowsMissingNameOrDistance() {
        let csv = """
        name,distance_km,services
        Good,5,water
        ,7,food
        Bad,abc,water
        Also,9,food
        """
        let r = AidStationCSV.parse(csv)
        XCTAssertEqual(r.stations.map(\.name), ["Good", "Also"], "rows lacking a name or parseable distance drop")
        XCTAssertEqual(r.stations.map(\.ordinal), [1, 2], "ordinals are positional over the kept rows")
        XCTAssertEqual(r.skippedRows, 2)
    }

    func testCsvHeaderlessUsesPositionalOrder() {
        // No recognisable header -> Trail's positional order (name, distance_km, rest_min, services).
        let csv = """
        Start,0,0,water
        Mid,5,2,water|food
        """
        let r = AidStationCSV.parse(csv)
        XCTAssertEqual(r.stations.map(\.name), ["Start", "Mid"])
        XCTAssertEqual(r.stations.compactMap(\.distanceKm), [0, 5])
        XCTAssertEqual(r.stations[1].services, ["water", "food"])
        XCTAssertEqual(r.skippedRows, 0)
    }

    func testCsvSemicolonDelimiterWithEuropeanDecimal() {
        let csv = """
        name;distance_km;services
        Alpha;1,5;water|food
        Beta;10;medical
        """
        let r = AidStationCSV.parse(csv)
        XCTAssertEqual(r.stations.map(\.name), ["Alpha", "Beta"])
        XCTAssertEqual(r.stations[0].distanceKm ?? -1, 1.5, accuracy: 0.0001, "comma is the decimal separator")
        XCTAssertEqual(r.stations[1].distanceKm ?? -1, 10, accuracy: 0.0001)
        XCTAssertEqual(r.stations[0].services, ["water", "food"])
    }

    func testCsvHandlesCRLFAndBOM() {
        let csv = "\u{FEFF}name,distance_km,services\r\nStart,0,water\r\nMid,5,water|food\r\n"
        let r = AidStationCSV.parse(csv)
        XCTAssertEqual(r.stations.map(\.name), ["Start", "Mid"], "BOM stripped, CRLF + trailing newline handled")
        XCTAssertEqual(r.stations.compactMap(\.distanceKm), [0, 5])
    }

    func testCsvEmptyInputYieldsNoStations() {
        XCTAssertEqual(AidStationCSV.parse("").stations, [])
        XCTAssertEqual(AidStationCSV.parse("   \n  \n").stations, [])
        XCTAssertEqual(AidStationCSV.parse("").skippedRows, 0)
    }

    func testDistanceToNextKm() {
        let stations = [
            PlannedAidStation(ordinal: 1, name: "A", distanceKm: 0),
            PlannedAidStation(ordinal: 2, name: "B", distanceKm: 4.5),
            PlannedAidStation(ordinal: 3, name: "C", distanceKm: 12.0),
            PlannedAidStation(ordinal: 4, name: "D", distanceKm: nil),
        ]
        XCTAssertEqual(stations.distanceToNextKm(after: 0) ?? -1, 4.5, accuracy: 0.0001)
        XCTAssertEqual(stations.distanceToNextKm(after: 1) ?? -1, 7.5, accuracy: 0.0001)
        XCTAssertNil(stations.distanceToNextKm(after: 2), "next station has no distance")
        XCTAssertNil(stations.distanceToNextKm(after: 3), "no station after the last")
        XCTAssertNil(stations.distanceToNextKm(after: 9), "index out of range")
    }

    func testRaceDraftReplaceAidStationsRenumbers() {
        var draft = RaceDraft()
        draft.addAidStation(name: "old")
        draft.replaceAidStations(with: [
            PlannedAidStation(ordinal: 99, name: "X", distanceKm: 1),
            PlannedAidStation(ordinal: 7, name: "Y", distanceKm: 2),
        ])
        XCTAssertEqual(draft.aidStations.map(\.name), ["X", "Y"], "import replaces the manual entry")
        XCTAssertEqual(draft.aidStations.map(\.ordinal), [1, 2], "ordinals renumber to 1-based")
    }

    /// End-to-end at the model level: CSV → draft → built Race → persisted bundle round-trips.
    func testCsvImportPopulatesRaceViaDraft() throws {
        let csv = """
        name,distance_km,services
        Trailhead,0,water
        Ridge,8.3,water|food|medical
        """
        var draft = RaceDraft()
        draft.name = "Import Test"
        draft.replaceAidStations(with: AidStationCSV.parse(csv).stations)
        let race = draft.build(createdAt: t(1000))
        XCTAssertEqual(race.aidStations.map(\.name), ["Trailhead", "Ridge"])
        XCTAssertEqual(race.aidStations.compactMap(\.distanceKm), [0, 8.3])
        XCTAssertEqual(race.aidStations[1].services, ["water", "food", "medical"])
        XCTAssertEqual(race.aidStations.distanceToNextKm(after: 0) ?? -1, 8.3, accuracy: 0.0001)
        try storage().saveRace(race)
        XCTAssertEqual(storage().loadRace(id: race.id)?.aidStations.map(\.name), ["Trailhead", "Ridge"],
                       "imported stations persist through the WI-2 bundle spine")
    }

    // MARK: - WI-6: tracking view projections (TrackingTab / palette buckets / feed / aid board)

    func testTrackingTabIsCyclic() {
        XCTAssertEqual(TrackingTab.feed.next, .nutrition, "next wraps past the last tab to the first")
        XCTAssertEqual(TrackingTab.nutrition.previous, .feed, "previous wraps past the first to the last")
        XCTAssertEqual(TrackingTab.nutrition.next, .aid)
        XCTAssertEqual(TrackingTab.aid.previous, .nutrition)
        XCTAssertTrue(TrackingTab.aid.isTracking)
        XCTAssertFalse(TrackingTab.feed.isTracking, "Feed is read-only — no record/Undo chrome")
    }

    func testPaletteBucketsByTab() {
        let race = Race(name: "R", palette: [
            TrackableElement(label: "Gel", category: .nutrition),
            TrackableElement(label: "Water", category: .hydration),
            TrackableElement(label: "Poles", category: .gear),
            TrackableElement(label: "Phone", category: .other),
        ])
        XCTAssertEqual(race.paletteItems(for: .nutrition).map(\.label), ["Gel", "Water"], "Nutrition = {nutrition, hydration}")
        XCTAssertEqual(race.paletteItems(for: .others).map(\.label), ["Poles", "Phone"], "Others = {gear, other}")
        XCTAssertTrue(race.paletteItems(for: .aid).isEmpty)
        XCTAssertTrue(race.paletteItems(for: .feed).isEmpty)
    }

    func testPlannedAidStationDisplayName() {
        XCTAssertEqual(PlannedAidStation(ordinal: 3, name: "   ").displayName, "AS 3", "a blank name falls back to AS <ordinal>")
        XCTAssertEqual(PlannedAidStation(ordinal: 1, name: "Ridge").displayName, "Ridge")
    }

    func testFeedEntriesResolveAidLabelsInOrder() {
        let visit = UUID()
        let events = [
            RaceEvent(id: UUID(), at: t(0), kind: .raceStarted),
            RaceEvent(id: UUID(), at: t(10), kind: .intake(trackableID: nil, label: "Gel")),
            RaceEvent(id: UUID(), at: t(20), kind: .aidStationEntered(visitID: visit, ordinal: 2, label: "Aid 2")),
            RaceEvent(id: UUID(), at: t(30), kind: .aidStationExited(visitID: visit)),
            RaceEvent(id: UUID(), at: t(40), kind: .raceEnded),
        ]
        XCTAssertEqual(events.feedEntries.map(\.kind), [
            .raceStarted, .intake(label: "Gel"), .aidArrived(label: "Aid 2"), .aidLeft(label: "Aid 2"), .raceEnded,
        ], "the exit row resolves its label from the matching arrival")
    }

    func testFeedDropsRetractedAndOmitsCorrections() {
        let intake = RaceEvent(id: UUID(), at: t(10), kind: .intake(trackableID: nil, label: "Gel"))
        let undo = RaceEvent(at: t(15), kind: .retraction(target: intake.id))
        let correction = RaceEvent(at: t(20), kind: .endTimeCorrected(to: t(5)))
        XCTAssertTrue([intake, undo, correction].feedEntries.isEmpty,
                      "a retracted intake vanishes from the Feed; corrections are not feed rows")
    }

    func testAidBoardPlannedProgression() throws {
        let race = Race(name: "R", aidStations: [
            PlannedAidStation(ordinal: 1, name: "A", distanceKm: 0),
            PlannedAidStation(ordinal: 2, name: "B", distanceKm: 5),
            PlannedAidStation(ordinal: 3, name: "C", distanceKm: 12),
        ])
        // Nothing entered yet: the first station is upcoming.
        var board = race.aidBoard(for: [])
        XCTAssertTrue(board.isPlanned)
        XCTAssertNil(board.current)
        XCTAssertTrue(board.passed.isEmpty)
        XCTAssertEqual(board.upcoming?.name, "A")

        // Arrive at A → current = A, upcoming = B, leg A→B = 5 km.
        let v1 = UUID()
        let enterA = RaceEvent(at: t(100), kind: .aidStationEntered(visitID: v1, ordinal: 1, label: "A"))
        board = race.aidBoard(for: [enterA])
        XCTAssertEqual(board.current?.label, "A")
        XCTAssertEqual(board.upcoming?.name, "B")
        XCTAssertEqual(try XCTUnwrap(board.legToUpcomingKm), 5, accuracy: 0.0001)

        // Finish A → A passed, no current, B still upcoming.
        let exitA = RaceEvent(at: t(160), kind: .aidStationExited(visitID: v1))
        board = race.aidBoard(for: [enterA, exitA])
        XCTAssertNil(board.current)
        XCTAssertEqual(board.passed.map(\.label), ["A"])
        XCTAssertEqual(board.upcoming?.name, "B")
    }

    func testAidBoardForgotToFinishThenAllReached() {
        let race = Race(name: "R", aidStations: [
            PlannedAidStation(ordinal: 1, name: "A", distanceKm: 0),
            PlannedAidStation(ordinal: 2, name: "B", distanceKm: 5),
        ])
        // Arrive A, then arrive B without finishing A → A is departedExitUnrecorded, B is current.
        let board = race.aidBoard(for: [
            RaceEvent(at: t(1), kind: .aidStationEntered(visitID: UUID(), ordinal: 1, label: "A")),
            RaceEvent(at: t(2), kind: .aidStationEntered(visitID: UUID(), ordinal: 2, label: "B")),
        ])
        XCTAssertEqual(board.passed.map(\.label), ["A"])
        XCTAssertEqual(board.passed.first?.state, .departedExitUnrecorded)
        XCTAssertEqual(board.current?.label, "B")
        XCTAssertNil(board.upcoming, "both planned stations have been entered")
    }

    func testAidBoardPlanlessUsesVisitsOnly() {
        let race = Race(name: "R")   // no planned stations
        let board = race.aidBoard(for: [
            RaceEvent(at: t(1), kind: .aidStationEntered(visitID: UUID(), ordinal: nil, label: "Aid 1")),
        ])
        XCTAssertFalse(board.isPlanned)
        XCTAssertNil(board.upcoming)
        XCTAssertEqual(board.current?.label, "Aid 1")
    }

    func testRaceFormatDuration() {
        XCTAssertEqual(RaceFormat.duration(3 * 3600 + 24 * 60 + 5), "3h 24m")
        XCTAssertEqual(RaceFormat.duration(24 * 60 + 10), "24m 10s")
        XCTAssertEqual(RaceFormat.duration(9), "9s")
        XCTAssertEqual(RaceFormat.duration(-5), "0s", "negative clamps to zero")
    }

    // MARK: - WI-6: RaceTracker (durable append → in-memory mirror)

    func testRaceTrackerStartTrackUndoFinish() throws {
        let race = Race(name: "R", palette: [TrackableElement(label: "Gel", category: .nutrition)])
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())
        XCTAssertEqual(tracker.status, .configured)

        tracker.start()
        XCTAssertEqual(tracker.status, .inProgress)

        tracker.track(race.palette[0])
        XCTAssertEqual(tracker.feed.last?.kind, .intake(label: "Gel"))
        XCTAssertEqual(tracker.lastAction?.description, "Tracked Gel")

        tracker.undoLast()
        XCTAssertNil(tracker.lastAction, "undo clears the toast")
        XCTAssertFalse(tracker.feed.contains { $0.kind == .intake(label: "Gel") },
                       "Undo appends a retraction the Feed honors — the intake vanishes")

        tracker.finishRace()
        XCTAssertEqual(tracker.status, .finished)

        // A fresh tracker on the same storage models a relaunch — rebuilt from the durable log.
        let reloaded = RaceTracker(race: race, storage: storage())
        XCTAssertEqual(reloaded.status, .finished, "every action was fsync'd; the relaunch sees them")
        XCTAssertFalse(reloaded.feed.contains { $0.kind == .intake(label: "Gel") }, "the retraction persisted too")
    }

    func testRaceTrackerAidArriveThenFinish() throws {
        let race = Race(name: "R", aidStations: [
            PlannedAidStation(ordinal: 1, name: "A", distanceKm: 0),
            PlannedAidStation(ordinal: 2, name: "B", distanceKm: 5),
        ])
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())
        tracker.start()

        tracker.arrive(at: try XCTUnwrap(tracker.board.upcoming))
        XCTAssertEqual(tracker.board.current?.label, "A")
        XCTAssertEqual(tracker.lastAction?.description, "Arrived at A")

        tracker.finishAid(try XCTUnwrap(tracker.board.current))
        XCTAssertNil(tracker.board.current)
        XCTAssertEqual(tracker.board.passed.map(\.label), ["A"])
        XCTAssertEqual(tracker.board.upcoming?.name, "B")
    }

    func testRaceTrackerAdHocAidAndVoiceNoteAreDurable() throws {
        let race = Race(name: "R")   // plan-less
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())
        tracker.start()

        tracker.startAdHocAid()
        XCTAssertFalse(tracker.board.isPlanned)
        XCTAssertEqual(tracker.board.current?.label, "Aid 1", "ad-hoc stations auto-label by visit count")

        XCTAssertTrue(tracker.addVoiceNote(data: Data("clip".utf8), durationSec: 2.0))
        guard case .voiceNote = tracker.feed.last?.kind else { return XCTFail("the voice note is in the feed") }

        // The clip is on disk and the persisted event references it (no dangling ref).
        let events = storage().loadEvents(for: race.id)
        guard case let .voiceNote(filename, _) = try XCTUnwrap(events.last).kind else {
            return XCTFail("expected a persisted voiceNote event")
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: storage().audioURL(for: race.id, filename: filename).path),
                      "the clip was written into the race bundle")
    }

    func testRaceTrackerCancelAidRemovesVisitAndRestoresUpcoming() throws {
        let race = Race(name: "R", aidStations: [
            PlannedAidStation(ordinal: 1, name: "A", distanceKm: 0),
            PlannedAidStation(ordinal: 2, name: "B", distanceKm: 5),
        ])
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())
        tracker.start()
        tracker.arrive(at: try XCTUnwrap(tracker.board.upcoming))      // arrive A
        XCTAssertEqual(tracker.board.current?.label, "A")

        tracker.cancelAid(try XCTUnwrap(tracker.board.current))         // mistaken arrival → cancel it
        XCTAssertNil(tracker.board.current, "cancelling retracts the arrival, removing the visit")
        XCTAssertTrue(tracker.board.passed.isEmpty, "it does not become a passed visit (that's what Finish would do)")
        XCTAssertEqual(tracker.board.upcoming?.name, "A", "the planned station returns to Upcoming")
        XCTAssertNil(tracker.lastAction, "the now-stale Undo toast for that arrival is cleared")
        XCTAssertFalse(tracker.feed.contains { if case .aidArrived = $0.kind { return true } else { return false } },
                       "the arrival is gone from the Feed too")
    }

    func testRaceTrackerCancelAdHocAid() throws {
        let race = Race(name: "R")   // plan-less
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())
        tracker.start()
        tracker.startAdHocAid()
        tracker.cancelAid(try XCTUnwrap(tracker.board.current))
        XCTAssertNil(tracker.board.current, "the ad-hoc visit disappears")
        XCTAssertFalse(tracker.feed.contains { if case .aidArrived = $0.kind { return true } else { return false } })
    }

    // MARK: - WI-7: post-race summary projection + finish-time correction

    func testSummaryCountsDurationAndPerVisitDwell() throws {
        let v1 = UUID(), v2 = UUID()
        let events = [
            RaceEvent(at: t(0), kind: .raceStarted),
            RaceEvent(at: t(60), kind: .intake(trackableID: nil, label: "Gel")),
            RaceEvent(at: t(90), kind: .intake(trackableID: nil, label: "Water")),
            RaceEvent(at: t(120), kind: .aidStationEntered(visitID: v1, ordinal: 1, label: "A")),
            RaceEvent(at: t(300), kind: .aidStationExited(visitID: v1)),                          // dwell 180s
            RaceEvent(at: t(600), kind: .aidStationEntered(visitID: v2, ordinal: 2, label: "B")), // no exit marked
            RaceEvent(at: t(900), kind: .raceEnded),
        ]
        let s = events.summary
        XCTAssertEqual(s.startedAt, t(0))
        XCTAssertEqual(s.effectiveEnd, t(900))
        XCTAssertEqual(try XCTUnwrap(s.totalDuration), 900, accuracy: 0.0001)
        XCTAssertEqual(s.aidVisitCount, 2)
        XCTAssertEqual(s.intakeCount, 2)
        XCTAssertEqual(s.voiceNoteCount, 0)
        XCTAssertEqual(s.visits.map(\.label), ["A", "B"])
        XCTAssertEqual(try XCTUnwrap(s.visits[0].dwell), 180, accuracy: 0.0001, "departed visit dwell = exit − entry")
        XCTAssertNil(s.visits[1].dwell, "a visit with no recorded exit has no dwell (GPS reconstructs it later)")
    }

    func testSummaryIntakeTotalsRankedByCountThenLabel() {
        let events: [RaceEvent] = ["Water", "Gel", "Water", "Salt", "Gel", "Water", "Apple"].enumerated().map {
            RaceEvent(at: t(TimeInterval($0.offset)), kind: .intake(trackableID: nil, label: $0.element))
        }
        let totals = events.summary.intakeTotals
        XCTAssertEqual(totals.map { "\($0.label):\($0.count)" }, ["Water:3", "Gel:2", "Apple:1", "Salt:1"],
                       "most-consumed first; the 1-count tie breaks by label A→Z (Apple before Salt)")
        XCTAssertEqual(events.summary.intakeCount, 7)
    }

    func testSummaryHonoursRetractionAndCorrection() throws {
        let gel = RaceEvent(id: UUID(), at: t(10), kind: .intake(trackableID: nil, label: "Gel"))
        let events = [
            RaceEvent(at: t(0), kind: .raceStarted),
            gel,
            RaceEvent(at: t(20), kind: .intake(trackableID: nil, label: "Water")),
            RaceEvent(at: t(30), kind: .retraction(target: gel.id)),      // undo the Gel
            RaceEvent(at: t(900), kind: .raceEnded),                      // e.g. phone powered on late
            RaceEvent(at: t(950), kind: .endTimeCorrected(to: t(500))),   // corrected to the real finish
        ]
        let s = events.summary
        XCTAssertEqual(s.intakeCount, 1, "the retracted Gel is excluded from the totals")
        XCTAssertEqual(s.intakeTotals.map(\.label), ["Water"])
        XCTAssertEqual(s.effectiveEnd, t(500), "the correction wins over the raceEnded time")
        XCTAssertEqual(try XCTUnwrap(s.totalDuration), 500, accuracy: 0.0001, "duration uses the corrected end")
    }

    func testCorrectEndTimeAppendsCorrectionPreservingOriginal() throws {
        let race = Race(name: "R")
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())

        tracker.correctEndTime(to: t(500))
        XCTAssertNil(tracker.effectiveEnd, "correcting a race that hasn't finished is a no-op")

        tracker.start()
        tracker.finishRace()
        let endAtFinish = try XCTUnwrap(tracker.effectiveEnd)

        tracker.correctEndTime(to: t(123))
        XCTAssertEqual(tracker.effectiveEnd, t(123), "the correction becomes the effective end")
        XCTAssertNotEqual(tracker.effectiveEnd, endAtFinish)
        XCTAssertEqual(tracker.status, .finished, "still finished after a correction")

        // A correction is an append, never a rewrite: the original raceEnded survives in the durable log,
        // and a relaunch (fresh tracker on the same root) sees the fsync'd correction.
        let persisted = storage().loadEvents(for: race.id)
        XCTAssertEqual(persisted.filter { if case .raceEnded = $0.kind { return true } else { return false } }.count, 1,
                       "the original raceEnded stays in the log")
        XCTAssertEqual(persisted.filter { if case .endTimeCorrected = $0.kind { return true } else { return false } }.count, 1,
                       "the correction was appended")
        XCTAssertEqual(RaceTracker(race: race, storage: storage()).effectiveEnd, t(123),
                       "the correction was fsync'd and survives relaunch")
    }

    func testFeedVoiceNoteCarriesAudioFilenameForPlayback() throws {
        let race = Race(name: "R")
        try storage().saveRace(race)
        let tracker = RaceTracker(race: race, storage: storage())
        tracker.start()
        XCTAssertTrue(tracker.addVoiceNote(data: Data("clip".utf8), durationSec: 3.0))

        guard case let .voiceNote(filename, duration) = try XCTUnwrap(tracker.feed.last).kind else {
            return XCTFail("the voice note is the last feed entry")
        }
        XCTAssertEqual(duration, 3.0, accuracy: 0.0001)
        XCTAssertFalse(filename.isEmpty, "the feed row carries the clip filename so the post-race view can play it")
        XCTAssertTrue(FileManager.default.fileExists(atPath: tracker.clipURL(filename: filename).path),
                      "and clipURL resolves the filename to the on-disk clip")
    }

    // MARK: - TRACK-008: aid-station notes · recording-aware tab navigation

    func testPlannedAidStationNotesRoundTrip() throws {
        let race = Race(name: "R", aidStations: [
            PlannedAidStation(ordinal: 1, name: "Ridge", services: ["water"], distanceKm: 8,
                              notes: "Drop bag here; swap shoes"),
        ])
        try storage().saveRace(race)
        XCTAssertEqual(storage().loadRace(id: race.id)?.aidStations.first?.notes, "Drop bag here; swap shoes",
                       "a station note round-trips through race.json")
    }

    func testTolerantDecodeOfAidStationWithoutNotes() throws {
        // A pre-notes race.json: an aid station carrying no "notes" key must still load (note → "") rather
        // than failing the whole aid-station array — which would drop the race from the list.
        let id = UUID()
        let dir = storage().bundleDir(for: id)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let legacy = #"{"createdAt":1,"id":"\#(id.uuidString)","name":"R","aidStations":[{"id":"\#(UUID().uuidString)","ordinal":1,"name":"Ridge","services":["water"],"distanceKm":8}]}"#
        try Data(legacy.utf8).write(to: dir.appending(path: "race.json"))
        let race = try XCTUnwrap(storage().loadRace(id: id))
        XCTAssertEqual(race.aidStations.count, 1, "the station still loads")
        XCTAssertEqual(race.aidStations.first?.name, "Ridge")
        XCTAssertEqual(race.aidStations.first?.notes, "", "a missing note defaults to empty")
    }

    func testNotesForVisitOrdinal() {
        let race = Race(name: "R", aidStations: [
            PlannedAidStation(ordinal: 1, name: "A", notes: "first"),
            PlannedAidStation(ordinal: 2, name: "B"),
        ])
        XCTAssertEqual(race.notes(forVisitOrdinal: 1), "first")
        XCTAssertEqual(race.notes(forVisitOrdinal: 2), "", "a station with no note returns empty")
        XCTAssertEqual(race.notes(forVisitOrdinal: nil), "", "an ad-hoc visit (no ordinal) has no note")
        XCTAssertEqual(race.notes(forVisitOrdinal: 99), "", "an unknown ordinal has no note")
    }

    func testTrackingTabSwipeSkipsFeedWhileRecording() {
        // Plain cyclic order: nutrition → aid → others → feed → nutrition.
        XCTAssertEqual(TrackingTab.others.next, .feed)
        XCTAssertEqual(TrackingTab.nutrition.previous, .feed)
        // While recording, the stop-less Feed is skipped so the record/stop button stays reachable.
        XCTAssertEqual(TrackingTab.others.next(excludingFeed: true), .nutrition, "others → (skip feed) → nutrition")
        XCTAssertEqual(TrackingTab.nutrition.previous(excludingFeed: true), .others, "nutrition ← (skip feed) ← others")
        // Transitions that don't touch Feed are unchanged.
        XCTAssertEqual(TrackingTab.nutrition.next(excludingFeed: true), .aid)
        XCTAssertEqual(TrackingTab.aid.next(excludingFeed: true), .others)
        XCTAssertEqual(TrackingTab.aid.previous(excludingFeed: true), .nutrition)
        // excludingFeed:false matches the plain neighbours exactly.
        XCTAssertEqual(TrackingTab.others.next(excludingFeed: false), .feed)
        XCTAssertEqual(TrackingTab.nutrition.previous(excludingFeed: false), .feed)
    }
}
