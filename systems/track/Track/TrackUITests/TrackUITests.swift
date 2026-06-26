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

    /// Save a screenshot of the current app state into the result bundle (extracted to PNG for the docs).
    /// `XCUIScreen.main` captures the full device screen in the correct (portrait) orientation.
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
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

    /// WI-6: start a configured race, log an aid-station arrival on the AID tab (plan-less ad-hoc),
    /// confirm an Undo toast appeared and the Feed lists it — then relaunch and confirm the event was
    /// durably logged (append + fsync) and is still in the Feed when the in-progress race reopens.
    /// (The intake-grid path shares this same append spine and is unit-covered; this drives the UI
    /// end-to-end without the create-form palette setup.)
    func testTrackingDurablyLogsAnEventAcrossRelaunch() throws {
        let aidRow = NSPredicate(format: "label CONTAINS[c] %@", "Aid 1")
        XCUIDevice.shared.orientation = .portrait   // deterministic orientation for the doc screenshots
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // A plan-less race (name only) — mirrors the proven WI-4 create flow.
        app.buttons["addRace"].tap()
        let nameField = app.textFields["raceName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: nameField)
        waitForExpectations(timeout: 10)
        nameField.tap()
        nameField.typeText("Trail Test")
        let save = app.buttons["saveRace"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 10)
        save.tap()

        // Open the race → Start it → land on the tracking view.
        let row = app.staticTexts["Trail Test"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "the configured race is in the list")
        row.tap()
        let start = app.buttons["startRace"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "a Configured race opens to Start")
        start.tap()

        // Reach the AID tab by a left drag (Nutrition → AID), exercising the cyclic-swipe navigation
        // (the wrap-around math is unit-tested in testTrackingTabIsCyclic). A deliberate press-drag
        // triggers the content's DragGesture more reliably than a quick flick.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.45))
        from.press(forDuration: 0.15, thenDragTo: to)
        let adHoc = app.buttons["startAdHocAid"]
        XCTAssertTrue(adHoc.waitForExistence(timeout: 10),
                      "swiping left moves to the AID tab, which (plan-less) offers Start new aid station")
        adHoc.tap()
        XCTAssertTrue(app.buttons["undoAction"].waitForExistence(timeout: 5),
                      "logging an aid arrival shows the Undo toast")
        XCTAssertTrue(app.buttons["cancelAid"].exists,
                      "the in-progress station offers a persistent Cancel (not just Finish)")
        attach(app, "track-006-aid-tab")   // live AID tab: current visit, Finish + Cancel, chrome, tab bar

        // Feed tab lists the arrival.
        app.buttons["tab-feed"].tap()
        XCTAssertTrue(app.staticTexts.matching(aidRow).firstMatch.waitForExistence(timeout: 10),
                      "the Feed lists the aid-station arrival")
        attach(app, "track-006-feed")

        // Relaunch (no reset): the in-progress race reopens straight to tracking, event still logged.
        app.terminate()
        app.launchArguments = []
        app.launch()

        let reopened = app.staticTexts["Trail Test"]
        XCTAssertTrue(reopened.waitForExistence(timeout: 10), "the race persists")
        XCTAssertTrue(app.staticTexts["status-inProgress"].exists, "and is now In progress")
        reopened.tap()
        let feedTab = app.buttons["tab-feed"]
        XCTAssertTrue(feedTab.waitForExistence(timeout: 10), "the in-progress race reopens to the tracking view")
        feedTab.tap()
        XCTAssertTrue(app.staticTexts.matching(aidRow).firstMatch.waitForExistence(timeout: 10),
                      "the arrival was durably logged (append + fsync) and survives relaunch")
    }

    /// WI-7: finish a race end-to-end, then confirm the post-race view renders its summary header + the
    /// chronological timeline, and that the edit-finish-time flow is reachable and commits. (Inline clip
    /// playback needs a real recording + audio output — unreliable in an XCUITest — so it's verified
    /// manually; the summary/correction arithmetic is unit-tested in TrackTests.)
    func testFinishedRaceShowsSummaryTimelineAndEditFinish() throws {
        let aidRow = NSPredicate(format: "label CONTAINS[c] %@", "Aid 1")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-reset"]
        app.launch()

        // Create a plan-less race and start it (the proven WI-4 → WI-6 path).
        app.buttons["addRace"].tap()
        let nameField = app.textFields["raceName"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "isHittable == true"), evaluatedWith: nameField)
        waitForExpectations(timeout: 10)
        nameField.tap()
        nameField.typeText("Finish Test")
        let save = app.buttons["saveRace"]
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: save)
        waitForExpectations(timeout: 10)
        save.tap()

        app.staticTexts["Finish Test"].tap()
        let start = app.buttons["startRace"]
        XCTAssertTrue(start.waitForExistence(timeout: 10), "a Configured race opens to Start")
        start.tap()

        // Swipe to the AID tab, log + finish one ad-hoc aid visit (so the summary has a visit + dwell),
        // then finish the race via the confirmation dialog.
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.45))
        from.press(forDuration: 0.15, thenDragTo: to)
        let adHoc = app.buttons["startAdHocAid"]
        XCTAssertTrue(adHoc.waitForExistence(timeout: 10), "swiping left reaches the AID tab")
        adHoc.tap()
        app.buttons["finishAid"].tap()                      // leave the station → a passed visit with a dwell

        let finishRace = app.buttons["finishRace"]
        XCTAssertTrue(finishRace.waitForExistence(timeout: 10))
        finishRace.tap()
        // Two buttons carry the label "Finish race" while the dialog is up — the AID trigger behind the
        // scrim and the confirmationDialog's destructive action — so tap the hittable one (the dialog's).
        let finishLabel = NSPredicate(format: "label == %@", "Finish race")
        let confirmCandidates = app.buttons.matching(finishLabel)
        XCTAssertTrue(confirmCandidates.firstMatch.waitForExistence(timeout: 10), "Finish race asks for confirmation")
        let confirm = (0..<confirmCandidates.count).map { confirmCandidates.element(boundBy: $0) }
            .first { $0.isHittable } ?? confirmCandidates.firstMatch
        confirm.tap()

        // Post-race view: the summary header (total duration) + the timeline listing the aid visit.
        XCTAssertTrue(app.staticTexts["totalDuration"].waitForExistence(timeout: 10),
                      "the finished race opens to the summary with a total duration")
        XCTAssertTrue(app.staticTexts.matching(aidRow).firstMatch.waitForExistence(timeout: 10),
                      "the chronological timeline lists the aid-station visit")
        attach(app, "track-007-summary")

        // The edit-finish-time flow opens and a correction commits, returning to the summary.
        app.buttons["editFinish"].tap()
        let saveFinish = app.buttons["saveFinish"]
        XCTAssertTrue(saveFinish.waitForExistence(timeout: 10), "Edit finish opens the correction sheet")
        saveFinish.tap()
        XCTAssertTrue(app.staticTexts["totalDuration"].waitForExistence(timeout: 10),
                      "saving the finish-time correction returns to the post-race summary")
    }
}
