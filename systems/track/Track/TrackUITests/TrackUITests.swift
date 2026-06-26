//
//  TrackUITests.swift
//  TrackUITests
//
//  Created by Christian Gill on 25/06/2026.
//

import XCTest

/// WI-1 acceptance, end-to-end through the UI: the app launches to an empty races list, and a
/// race added with `+` survives a full relaunch.
final class TrackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testStubRacePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]     // start from an empty bundle root
        app.launch()

        XCTAssertTrue(app.staticTexts["No races yet"].waitForExistence(timeout: 10),
                      "launches to the empty-races state")
        XCTAssertFalse(app.staticTexts["Stub race 1"].exists)

        app.buttons["addRace"].tap()
        XCTAssertTrue(app.staticTexts["Stub race 1"].waitForExistence(timeout: 10),
                      "adding a race shows its row")

        app.terminate()
        app.launchArguments = []                     // relaunch WITHOUT reset
        app.launch()

        XCTAssertTrue(app.staticTexts["Stub race 1"].waitForExistence(timeout: 10),
                      "the race persists across relaunch")
    }

    /// WI-3: the trackable library opens from the Races toolbar, a created trackable appears, and
    /// it survives a relaunch.
    func testTrackablePersistsAcrossRelaunch() throws {
        let labelContains = NSPredicate(format: "label CONTAINS[c] %@", "Maurten Gel 100")
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        app.buttons["openLibrary"].tap()
        XCTAssertTrue(app.staticTexts["No trackables"].waitForExistence(timeout: 10),
                      "the library opens to its empty state")

        app.buttons["addTrackable"].tap()
        let field = app.textFields["trackableLabel"]
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        field.typeText("Maurten Gel 100")
        app.buttons["saveTrackable"].tap()
        XCTAssertTrue(app.buttons.matching(labelContains).firstMatch.waitForExistence(timeout: 10),
                      "the new trackable appears in the list")

        app.terminate()
        app.launchArguments = []                      // relaunch WITHOUT reset
        app.launch()
        app.buttons["openLibrary"].tap()
        XCTAssertTrue(app.buttons.matching(labelContains).firstMatch.waitForExistence(timeout: 10),
                      "the trackable persists across relaunch")
    }
}
