import XCTest

/// The Live Activity end to end (#260), on the real Lock Screen: scoring puts
/// the game there, End Period updates the opponent and the period, a tap goes
/// back into that game's Live Scoring, and deleting the game takes it down.
///
/// iPhone only — the app starts no activity on an iPad. Captures
/// `60-live-activity-lock-screen` and `61-live-activity-deleted`.
final class LiveActivityUITests: XCTestCase {
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .phone,
                      "Live Activities are iPhone only in this app")
    }

    func testTheGameOnTheLockScreen() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        // Into the game in progress: Swish Warriors 9, Northgate Falcons 9 thru Q1.
        let row = app.staticTexts["vs Northgate Falcons"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10))

        // A three, then End Q2 with the opponent on 14.
        app.buttons["Nicholas #77"].tap()
        XCTAssertTrue(app.buttons["+3"].waitForExistence(timeout: 5))
        app.buttons["+3"].tap()
        app.buttons["No Assist — Skip"].tap()

        let endQ2 = app.buttons["End Q2"]
        XCTAssertTrue(endQ2.waitForExistence(timeout: 5))
        endQ2.tap()
        let total = app.textFields.firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 5))
        total.tap()
        total.typeText("14")
        app.buttons["Next Period"].tap()

        // Leave the game, so the tap below has somewhere to come back from.
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 5))
        app.buttons["Back"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))

        // The Lock Screen: 12–14, in Q3, theirs as of Q2. No player names.
        lockScreen()
        let card = activity(containing: "Northgate Falcons")
        XCTAssertTrue(card.waitForExistence(timeout: 15), "the game should be on the Lock Screen")
        XCTAssertEqual(card.label,
                       "Swish Warriors 12, Northgate Falcons 14, Q3, Northgate Falcons as of Q2")
        XCTAssertFalse(activity(containing: "Nicholas").exists,
                       "the Lock Screen shows teams and scores, never a player")
        // The system asks on an app's first activity ("Allow"), and again
        // after a few ("Always Allow"); a later run may see neither.
        for answer in ["Allow", "Always Allow"] where springboard.buttons[answer].exists {
            springboard.buttons[answer].tap()
            sleep(2)
        }
        snap("60-live-activity-lock-screen")

        // A tap opens that game's Live Scoring.
        card.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 15))
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10),
                      "the activity should open Live Scoring")
        XCTAssertTrue(app.buttons["End Q3"].waitForExistence(timeout: 5),
                      "…for the game it shows")

        // Deleting the game takes it off the Lock Screen at once.
        app.buttons["Back"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        let confirm = app.buttons["Delete Game & Scores"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        XCTAssertFalse(row.waitForExistence(timeout: 2))

        lockScreen()
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 5))
        let gone = expectation(for: NSPredicate(format: "exists == false"),
                               evaluatedWith: activity(containing: "Northgate Falcons"))
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 10), .completed,
                       "a deleted game's activity should be gone")
        snap("61-live-activity-deleted")
        XCUIDevice.shared.press(.home)   // unlock, for whatever runs next
        sleep(1)
    }

    // MARK: - Helpers

    private func activity(containing text: String) -> XCUIElement {
        springboard.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Home, lock, then wake to the Lock Screen (no passcode on the
    /// simulator). Locking straight from the app, or waking too soon, showed
    /// a Lock Screen with the activity list not yet up.
    private func lockScreen() {
        XCUIDevice.shared.press(.home)
        sleep(2)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(3)
        XCUIDevice.shared.perform(NSSelectorFromString("pressLockButton"))
        sleep(4)
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
