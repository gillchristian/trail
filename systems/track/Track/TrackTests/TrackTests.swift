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
}
