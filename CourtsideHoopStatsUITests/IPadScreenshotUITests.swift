import XCTest

/// The iPad layout (#232), captured in both orientations.
///
/// Every main screen in portrait and in landscape, named
/// `40-ipad-<orientation>-<screen>`. The portrait set is where the iPad store
/// screenshots come from (`docs/img/ipad/`, see docs/SCREENSHOTS.md); the
/// landscape set is the check that nothing only works one way up.
///
/// Skipped on an iPhone, so the iPhone harness run is unchanged.
final class IPadScreenshotUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad only")
    }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// iPad's tab bar sits at the top, and isn't always reported as a tab bar.
    private func openTab(_ app: XCUIApplication, _ name: String) {
        let inBar = app.tabBars.buttons[name]
        if inBar.exists { inBar.tap() } else { app.buttons[name].firstMatch.tap() }
    }

    func testPortrait() { capture(.portrait, "portrait") }
    func testLandscape() { capture(.landscapeLeft, "landscape") }

    private func capture(_ orientation: UIDeviceOrientation, _ label: String) {
        XCUIDevice.shared.orientation = orientation
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
        let shot: (String) -> Void = { self.snap("40-ipad-\(label)-\($0)") }

        // Games.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        shot("01-games")

        // Live scoring: the Score Log beside the players.
        app.staticTexts["vs Northgate Falcons"].tap()
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10))
        shot("02-live-scoring")

        app.buttons["Nicholas #77"].tap()
        XCTAssertTrue(app.buttons["+2"].waitForExistence(timeout: 5))
        shot("03-score-pad")
        app.buttons["+2"].tap()
        XCTAssertTrue(app.staticTexts["ASSIST BY"].waitForExistence(timeout: 5))
        shot("04-assist")
        app.buttons["Bradley"].tap()
        XCTAssertTrue(app.staticTexts["ast. Bradley"].waitForExistence(timeout: 5))

        // The bench strip open, as on the iPhone's first store image.
        app.buttons["Wesley #88"].tap()
        XCTAssertTrue(app.buttons["Not playing"].waitForExistence(timeout: 5))
        app.buttons["Not playing"].tap()
        let benchToggle = app.buttons["Not playing (1)"]
        XCTAssertTrue(benchToggle.waitForExistence(timeout: 5))
        benchToggle.tap()
        shot("05-live-bench")

        app.buttons["Stats"].tap()
        XCTAssertTrue(app.staticTexts["AST"].waitForExistence(timeout: 5))
        shot("06-live-stats")
        app.buttons["Stats"].tap()

        app.buttons["Back"].tap()
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // A finished game: summary and its PDF.
        app.staticTexts["vs Lakeside Lightning"].tap()
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["DNP"].firstMatch.waitForExistence(timeout: 5))
        shot("07-game-summary")
        app.buttons["Box Score PDF"].tap()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 10))
        shot("08-box-score-pdf")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        app.navigationBars["vs Lakeside Lightning"].buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["vs Northgate Falcons"].waitForExistence(timeout: 10))

        // A scheduled game.
        app.staticTexts["vs Summit Storm"].tap()
        XCTAssertTrue(app.buttons["Start Game"].waitForExistence(timeout: 10))
        shot("09-scheduled-game")
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // New Game form.
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.buttons["Start Game"].waitForExistence(timeout: 10))
        shot("10-new-game")
        app.buttons["Cancel"].tap()

        // Roster and the season.
        openTab(app, "Roster")
        XCTAssertTrue(app.staticTexts["Nicholas H."].waitForExistence(timeout: 10))
        shot("11-roster")
        app.buttons["Season Averages"].tap()
        XCTAssertTrue(app.staticTexts["PPG"].waitForExistence(timeout: 10))
        shot("12-season")
        app.navigationBars.buttons.firstMatch.tap()

        // Settings and a team.
        openTab(app, "Settings")
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 10))
        shot("13-settings")
        app.buttons["Edit Eastside Eagles"].tap()
        XCTAssertTrue(app.buttons["Done"].firstMatch.waitForExistence(timeout: 10)
                      || app.buttons["Save"].firstMatch.waitForExistence(timeout: 5))
        shot("14-team-detail")
        if app.buttons["Cancel"].exists { app.buttons["Cancel"].tap() }
        else { app.buttons["Done"].firstMatch.tap() }

        // Following: the list and a live game.
        openTab(app, "Following")
        let liveGame = app.staticTexts["vs Harbor Sharks"]
        XCTAssertTrue(liveGame.waitForExistence(timeout: 10))
        shot("15-following")
        liveGame.tap()
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10))
        shot("16-following-game")
    }
}
