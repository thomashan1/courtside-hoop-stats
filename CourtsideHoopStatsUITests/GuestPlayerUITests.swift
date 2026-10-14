import XCTest

/// A guest (a borrowed jersey for one game) only shows in games where they
/// have a stat — not as a DNP, and not as a row of zeroes in games they
/// missed.
final class GuestPlayerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testAGuestLeavesTheGamesTheyMissed() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        // Wesley sat out the Lakeside game: a DNP while he's a regular player.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        app.staticTexts["vs Lakeside Lightning"].tap()
        XCTAssertTrue(app.staticTexts["DNP"].firstMatch.waitForExistence(timeout: 10))
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Roster"].tap()
        XCTAssertTrue(app.staticTexts["Wesley C."].waitForExistence(timeout: 10))
        app.staticTexts["Wesley C."].tap()
        let guest = app.switches["Guest"]
        XCTAssertTrue(guest.waitForExistence(timeout: 5))
        guest.switches.firstMatch.tap()
        snap("50-guest-switch")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Guest"].waitForExistence(timeout: 5))
        snap("51-guest-roster")

        // As a guest he's simply not in that game.
        app.tabBars.buttons["Games"].tap()
        app.staticTexts["vs Lakeside Lightning"].tap()
        XCTAssertTrue(app.staticTexts["Player Stats"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["DNP"].exists)
        XCTAssertFalse(app.staticTexts["Wesley"].exists)
        snap("52-guest-summary")
    }
}
