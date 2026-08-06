import XCTest

/// Drives the app through its main screens with deterministic demo data
/// (`-uiTestSeedDemo`) and captures full-screen screenshots. These serve three
/// purposes: merge-gate visual verification, README imagery, and App Store
/// listing screenshots.
///
/// Run: `xcodebuild test -scheme CourtsideHoopStats \
///   -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
///   -only-testing:CourtsideHoopStatsUITests`
/// then extract attachments from the .xcresult (see docs/SCREENSHOTS.md).
final class ScreenshotUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launchSeeded() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
        return app
    }

    /// Save a full-device screenshot as a kept attachment.
    private func snap(_ app: XCUIApplication, _ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreens() {
        let app = launchSeeded()

        // 1) Games list — upcoming + played sections.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        snap(app, "01-games-list")

        // 2) Finished game → Summary (final score, period grid, player stats).
        app.staticTexts["vs Lakeside Lightning"].tap()
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        snap(app, "02-game-summary")

        // Absent players are listed as DNP rather than dropped from the table —
        // a roster that silently loses people reads as a bug. The demo game
        // benches Wesley, so a DNP row must be present.
        XCTAssertTrue(app.staticTexts["DNP"].firstMatch.waitForExistence(timeout: 5),
                      "Benched players should appear as DNP in the stats table")

        // 2a) Box-score PDF preview (#55) — the share sheet is opened from here,
        // so the preview is the last screen we can capture deterministically.
        app.buttons["Box Score PDF"].tap()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 10))
        snap(app, "14-box-score-pdf")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // 2b) Edit a finished game in the scoring view (#8): the Summary's
        // "Edit Scores" button opens the same two-tap Live Scoring UI.
        app.buttons["Edit Scores"].tap()
        // The edit cover is Live Scoring, which now uses its own Back button.
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 10))
        snap(app, "05-edit-finished-game")

        // 2c) Score-log editor (#9): reorder events + movable period dividers.
        app.buttons["Edit / Reorder"].tap()
        XCTAssertTrue(app.navigationBars["Edit Score Log"].waitForExistence(timeout: 10))
        snap(app, "07-score-log-editor")
        app.navigationBars["Edit Score Log"].buttons["Done"].tap()

        app.buttons["Back"].tap()   // close the edit cover
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // Back to the list.
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // 3) In-progress game → Live Scoring.
        XCTAssertTrue(app.staticTexts["vs Northgate Falcons"].waitForExistence(timeout: 10))
        app.staticTexts["vs Northgate Falcons"].tap()
        // The live scoring screen always shows the Score Log header.
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 10))
        snap(app, "03-live-scoring")

        // 3a) Tap a player → the big point pad (#33).
        app.buttons["Nicholas #77"].tap()
        XCTAssertTrue(app.buttons["+2"].waitForExistence(timeout: 5))
        snap(app, "12-score-pad")
        app.buttons["+2"].tap()   // records + dismisses

        // 3b) Bench players via the pad's "Not playing"; they collapse into a strip.
        app.buttons["Wesley #88"].tap()
        XCTAssertTrue(app.buttons["Not playing"].waitForExistence(timeout: 5))
        app.buttons["Not playing"].tap()
        app.buttons["Kaleb #24"].tap()
        XCTAssertTrue(app.buttons["Not playing"].waitForExistence(timeout: 5))
        app.buttons["Not playing"].tap()
        let benchToggle = app.buttons["Not playing (2)"]
        XCTAssertTrue(benchToggle.waitForExistence(timeout: 5))
        benchToggle.tap()   // expand the collapsed strip to show the chips
        snap(app, "11-bench")

        // 3b) Details editor (Cancel/Save) — edit location/notes mid-game.
        app.buttons["Details"].tap()
        XCTAssertTrue(app.navigationBars["Edit Game"].waitForExistence(timeout: 10))
        snap(app, "10-game-details")
        app.navigationBars["Edit Game"].buttons["Cancel"].tap()

        // Pop back to the Games list so the stack is clean for later steps.
        // (Live Scoring hides the system nav bar; use its custom Back button.)
        app.buttons["Back"].tap()
        // Games/Roster nav titles are the active team name now — assert on content.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // 4) Roster tab.
        app.tabBars.buttons["Roster"].tap()
        XCTAssertTrue(app.staticTexts["Players"].waitForExistence(timeout: 10))
        snap(app, "04-roster")

        // 4b) Settings → team management (#20).
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 10))
        snap(app, "08-settings-teams")

        // 4c) Team detail — name + jersey editing lives here now. Tapping a row
        // makes it active; the ⓘ button opens the editor.
        app.buttons["Edit Eastside Eagles"].tap()
        XCTAssertTrue(app.staticTexts["Home Jersey"].waitForExistence(timeout: 10))
        snap(app, "09-team-detail")
        // Dismiss the editor sheet before moving on (Cancel/Save now).
        app.navigationBars["Eastside Eagles"].buttons["Cancel"].tap()

        app.tabBars.buttons["Games"].tap()

        // 5) New Game form (#44) — "+" opens a form; every field is optional.
        // "Start Game" begins scoring immediately, "Save" schedules for later.
        app.buttons["New Game"].tap()   // labeled "+" button
        XCTAssertTrue(app.buttons["Start Game"].waitForExistence(timeout: 10))
        snap(app, "13-new-game")

        // 6) Location autocomplete (#13) in the New Game form — type a fragment
        // of a previously-used gym; the prior-value suggestion is deterministic
        // (live MapKit results may also appear but aren't asserted).
        let location = app.textFields["Location / Gym"]
        XCTAssertTrue(location.waitForExistence(timeout: 10))
        location.tap()
        location.typeText("Riverside")
        XCTAssertTrue(app.buttons["Riverside Community Gym"].waitForExistence(timeout: 10))
        snap(app, "06-location-autocomplete")
    }
}
