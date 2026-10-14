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

    /// A game row, by its opponent. The open game's title says the same
    /// thing beside the list, so match the row itself, not the text.
    private func openRow(_ app: XCUIApplication, _ opponent: String) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", opponent + ",")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "no row for \(opponent)")
        row.tap()
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
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].firstMatch.waitForExistence(timeout: 10))
        shot("01-games")

        // Live scoring: the Score Log beside the players.
        openRow(app, "vs Northgate Falcons")
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

        // A finished game: summary and its PDF, beside the list.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].firstMatch.waitForExistence(timeout: 10))
        openRow(app, "vs Lakeside Lightning")
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["DNP"].firstMatch.waitForExistence(timeout: 5))
        shot("07-game-summary")
        app.buttons["Box Score PDF"].tap()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 10))
        shot("08-box-score-pdf")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // The list stays beside the game (#232): the next one is one tap away.
        // A scheduled game.
        openRow(app, "vs Summit Storm")
        XCTAssertTrue(app.buttons["Start Game"].waitForExistence(timeout: 10))
        shot("09-scheduled-game")

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
        // The chosen team is remembered across launches, so a run that
        // stopped on the other team would start there.
        let switchTeam = app.buttons["Switch Team"]
        XCTAssertTrue(switchTeam.waitForExistence(timeout: 10))
        if switchTeam.value as? String != "Swish Warriors" {
            switchTeam.tap()
            app.buttons["Swish Warriors"].tap()
        }
        let liveGame = app.staticTexts["vs Harbor Sharks"]
        XCTAssertTrue(liveGame.waitForExistence(timeout: 10))
        shot("15-following")

        // The team's name heads the list and is the switch: the sidebar's
        // bar has no room for a title beside its buttons.
        XCTAssertEqual(switchTeam.value as? String, "Swish Warriors")
        switchTeam.tap()
        XCTAssertTrue(app.buttons["Swish Warriors"].waitForExistence(timeout: 5),
                      "the team menu didn't open")
        app.buttons["Swish Warriors"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 5))

        // Another team's game doesn't stay open beside this team's list.
        openRow(app, "vs Harbor Sharks")
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10))
        let barY = switchTeam.frame.minY
        switchTeam.tap()
        XCTAssertTrue(app.buttons["Eastside Eagles"].waitForExistence(timeout: 5))
        app.buttons["Eastside Eagles"].tap()
        XCTAssertTrue(app.staticTexts["No Game Selected"].waitForExistence(timeout: 5),
                      "the other team's game stayed open")
        XCTAssertFalse(app.staticTexts["Score Log"].exists)
        XCTAssertEqual(switchTeam.frame.minY, barY, accuracy: 2,
                       "switching teams moved the sidebar")
        shot("17-following-switched-team")
        switchTeam.tap()
        app.buttons["Swish Warriors"].tap()
        XCTAssertTrue(liveGame.waitForExistence(timeout: 5))
        openRow(app, "vs Harbor Sharks")
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10))
        shot("16-following-game")

        // Picking other games beside the list mustn't flash their last
        // basket as if it had just been scored.
        let toast = app.descendants(matching: .any)["ScoreToast"]
        for opponent in ["vs Valley Vipers", "vs Central Cyclones", "vs Harbor Sharks"] {
            openRow(app, opponent)
            XCTAssertFalse(toast.waitForExistence(timeout: 2), "\(opponent) flashed an old basket")
        }
    }
}
