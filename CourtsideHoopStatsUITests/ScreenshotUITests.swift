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

        // 1) Games list — all three sections, and a win, a loss and a tie so
        // every result badge appears in one shot.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // The owner-side sharing marker (#93). This is what separates the Games
        // tab from the Following tab at a glance, so it has to actually be
        // there — and it has to read as prose. `.navigationSubtitle` takes a
        // plain String, so `^[…](inflect:)` markup renders literally rather
        // than pluralising, which is exactly how it shipped the first time.
        XCTAssertTrue(app.staticTexts["Shared with 2 followers"].waitForExistence(timeout: 5),
                      "Games tab should say who the team is shared with")
        XCTAssertFalse(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS[c] 'inflect'")).firstMatch.exists,
                       "Inflection markup leaked into the UI unrendered")

        snap(app, "01-games-list")

        // 1b) Followers — reachable from Games, not just from a live game.
        app.buttons["Shared with 2 followers"].tap()
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Grandma Chen"].waitForExistence(timeout: 5))
        snap(app, "16-followers")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // 1a) A game played in halves, which also happens to be the tie. Two
        // things worth a look that the quarters games can't show: the linescore
        // collapsing to two rows, and the TIE badge.
        app.staticTexts["vs Pine Ridge Panthers"].tap()
        XCTAssertTrue(app.navigationBars["vs Pine Ridge Panthers"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["H1"].waitForExistence(timeout: 5),
                      "A halves game should label its periods H1/H2, not Q1–Q4")
        XCTAssertFalse(app.staticTexts["Q1"].exists, "Quarter labels leaked into a halves game")
        snap(app, "15-game-summary-halves")
        app.navigationBars["vs Pine Ridge Panthers"].buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

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
        // Exactly one team is shared, so exactly one row is tagged. A service
        // that reports every team as shared put the tag on both — which is a
        // lie about who can see a roster of children's names, so it's asserted
        // rather than eyeballed (#93).
        XCTAssertEqual(app.staticTexts.matching(identifier: "Shared").count, 1,
                       "Only the shared team should carry a Shared tag")

        snap(app, "08-settings-teams")

        // 4c) Team detail — name + jersey editing lives here now. Tapping a row
        // makes it active; the ⓘ button opens the editor.
        app.buttons["Edit Eastside Eagles"].tap()
        // A team is white plus one colour of its own, so the section covers
        // both the colour and which is worn at home.
        XCTAssertTrue(app.staticTexts["Jerseys"].waitForExistence(timeout: 10))

        // Both kits are drawn, and one of them is marked HOME. The old control
        // was a segmented "Worn at home: White | Blue" — which said what it did
        // in words but showed neither jersey, so it wasn't clear what changing
        // the team colour had actually changed.
        let whiteKit = app.buttons["White jersey"]
        let colourKit = app.buttons["Blue jersey"]
        XCTAssertTrue(whiteKit.waitForExistence(timeout: 5), "White kit should be shown")
        XCTAssertTrue(colourKit.exists, "The team's colour kit should be shown")
        XCTAssertEqual(app.staticTexts.matching(identifier: "HOME").count, 1,
                       "Exactly one kit is the home kit")

        snap(app, "09-team-detail")
        // Tapping the other kit moves HOME to it — the whole point of the
        // control, and the part a static screenshot can't vouch for.
        whiteKit.tap()
        XCTAssertEqual(whiteKit.value as? String, "Home",
                       "Tapping a kit should make it the home kit")
        colourKit.tap()   // put it back so the captured state is the default
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

    /// A game started by mistake, with nothing scored yet, can be moved back
    /// to Scheduled (#133) — narrower than "un-start any game": once a single
    /// event exists the option disappears, since reverting then would orphan
    /// real data rather than undo a stray tap.
    func testMoveBackToScheduled() {
        let app = launchSeeded()
        app.tabBars.buttons["Games"].tap()

        app.buttons["New Game"].tap()
        let startGame = app.buttons["Start Game"]
        XCTAssertTrue(startGame.waitForExistence(timeout: 10))
        startGame.tap()

        // Now live, with zero events recorded — open Details.
        let details = app.buttons["Details"]
        XCTAssertTrue(details.waitForExistence(timeout: 10))
        details.tap()

        let moveBack = app.buttons["Move Back to Scheduled"]
        XCTAssertTrue(moveBack.waitForExistence(timeout: 10),
                      "A just-started, unscored game should offer to move back to Scheduled")
        snap(app, "14-move-back-to-scheduled")
        moveBack.tap()

        let confirm = app.buttons["Move Back"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10),
                      "Reverting should ask for confirmation first")
        confirm.tap()

        // Back on the Games list, not still on the scoring screen.
        XCTAssertTrue(app.tabBars.buttons["Games"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Coming Up"].waitForExistence(timeout: 10),
                      "The reverted game should be scheduled again, not live")
    }
}
