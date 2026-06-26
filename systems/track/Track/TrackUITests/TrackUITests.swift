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
}
