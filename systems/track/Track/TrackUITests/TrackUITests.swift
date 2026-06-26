//
//  TrackUITests.swift
//  TrackUITests
//
//  Created by Christian Gill on 25/06/2026.
//

import XCTest

/// End-to-end acceptance through the UI: the app launches to an empty races list; a race created
/// and configured via the WI-4 form appears as Configured and survives a full relaunch.
final class TrackUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// WI-4: `+` opens the create form; a saved race appears with a Configured badge and persists.
    func testConfiguredRacePersistsAcrossRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]     // start from an empty bundle root
        app.launch()

        XCTAssertTrue(app.staticTexts["No races yet"].waitForExistence(timeout: 10),
                      "launches to the empty-races state")

        app.buttons["addRace"].tap()
        let nameField = app.textFields["raceName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10), "the create/configure form opens")
        XCTAssertTrue(app.buttons["importAidCsv"].exists, "the form offers Trail-CSV aid-station import (WI-5)")
        // Wait out the sheet's presentation animation so the tap reliably focuses the field.
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: nameField)
        waitForExpectations(timeout: 10)
        nameField.tap()
        nameField.typeText("Sunset 50K")

        // Save enables only once the name registers — waiting on it both confirms the text landed
        // and avoids tapping a disabled button.
        let save = app.buttons["saveRace"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 10)
        save.tap()

        XCTAssertTrue(app.staticTexts["Sunset 50K"].waitForExistence(timeout: 10),
                      "the configured race appears in the list")
        XCTAssertTrue(app.staticTexts["status-configured"].waitForExistence(timeout: 10),
                      "with a Configured status badge")

        app.terminate()
        app.launchArguments = []                     // relaunch WITHOUT reset
        app.launch()

        XCTAssertTrue(app.staticTexts["Sunset 50K"].waitForExistence(timeout: 10),
                      "the race persists across relaunch")
        XCTAssertTrue(app.staticTexts["status-configured"].waitForExistence(timeout: 10),
                      "and is still Configured")
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
