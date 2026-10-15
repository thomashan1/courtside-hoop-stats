import XCTest

/// A brand-new install: the welcome screen, and both ways out of it.
final class WelcomeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestFreshInstall"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Welcome to Courtside"].waitForExistence(timeout: 10))
        return app
    }

    /// Follow a Team: straight to Following, which says how to get invited.
    func testFollowATeam() {
        let app = launchFresh()
        snap("50-welcome")
        // No placeholder team anywhere on the first screen.
        XCTAssertFalse(app.staticTexts["My Test Team"].exists)

        app.buttons["Follow a Team"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Not Following a Team Yet"].waitForExistence(timeout: 10))
        // A follower has nothing to score.
        XCTAssertFalse(app.buttons["Games"].exists)
        XCTAssertFalse(app.buttons["Roster"].exists)

        app.buttons["Check for Invites"].tap()
        XCTAssertTrue(app.staticTexts["No invites yet. Once you've tapped the link from your scorekeeper, try again."]
            .waitForExistence(timeout: 10))
        snap("51-welcome-follow")
    }

    /// Keep Score: name the team, land on Games with that name.
    func testKeepScore() {
        let app = launchFresh()
        app.buttons["Keep Score"].firstMatch.tap()
        let name = app.textFields["Team Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Start"].isEnabled, "a team needs a name")
        name.typeText("Swish Warriors")
        snap("52-welcome-name-team")
        app.buttons["Start"].tap()

        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Welcome to Courtside"].exists)
        snap("53-welcome-games")

        // An owner keeps a way to follow someone, without a Following tab.
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 10))
        app.swipeUp()
        XCTAssertTrue(app.buttons["Follow a Team"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["My Test Team"].exists)

        // …and can open the welcome screen again, where Follow a Team
        // explains invites rather than taking their tabs away.
        app.buttons["Welcome Screen"].tap()
        XCTAssertTrue(app.staticTexts["Welcome to Courtside"].waitForExistence(timeout: 10))
        app.buttons["Follow a Team"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Not Following a Team Yet"].waitForExistence(timeout: 10))
        snap("54-welcome-again-follow-help")
    }
}
