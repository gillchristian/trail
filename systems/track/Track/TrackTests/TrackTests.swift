//
//  TrackTests.swift
//  TrackTests
//
//  Created by Christian Gill on 25/06/2026.
//

import XCTest
@testable import Track

/// WI-1 verifies the skeleton's one durability claim: a race written to a bundle survives a
/// "relaunch" — modeled by a fresh `RaceStorage` reading the same root (the in-memory store
/// is gone; only disk remains). The append-only events.log + fsync spine is WI-2.
final class TrackTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appending(path: "RaceStorageTests-\(UUID().uuidString)", directoryHint: .isDirectory)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testRacePersistsAndSurvivesRelaunch() throws {
        let race = Race(id: UUID(), name: "Marathon des Sables",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_000))

        try RaceStorage(root: root).save(race)            // first launch
        let reloaded = RaceStorage(root: root).loadAll()   // relaunch: fresh instance, same disk

        XCTAssertEqual(reloaded, [race], "the saved race should round-trip from disk after relaunch")
    }

    func testFreshRootHasNoRaces() throws {
        XCTAssertEqual(RaceStorage(root: root).loadAll(), [], "a brand-new bundle root lists no races")
    }

    func testDeleteRemovesRaceFromDisk() throws {
        let storage = RaceStorage(root: root)
        let race = Race(id: UUID(), name: "UTMB",
                        createdAt: Date(timeIntervalSince1970: 1_700_000_500))
        try storage.save(race)
        XCTAssertEqual(storage.loadAll(), [race])

        try storage.delete(race)
        XCTAssertEqual(RaceStorage(root: root).loadAll(), [], "a deleted race is gone after relaunch")
    }

    func testRacesLoadNewestFirst() throws {
        let storage = RaceStorage(root: root)
        let older = Race(id: UUID(), name: "older", createdAt: Date(timeIntervalSince1970: 1_000))
        let newer = Race(id: UUID(), name: "newer", createdAt: Date(timeIntervalSince1970: 2_000))
        try storage.save(older)
        try storage.save(newer)

        XCTAssertEqual(RaceStorage(root: root).loadAll(), [newer, older], "newest race sorts first")
    }
}
