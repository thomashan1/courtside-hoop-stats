import XCTest

/// **PROPOSAL SHOTS for issue #175 (shooting percentages).**
///
/// Captures each candidate design at a real game's shot volume so the crowding
/// can be judged from a picture rather than argued about. Not a merge gate —
/// delete with the rest of the `Proposal175` scaffolding.
///
/// Run: `scripts/proposal-175-shots.sh`
final class Proposal175ScreenshotTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    private func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"] + extra
        app.launch()
        return app
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Shared navigation

    private func openLiveGame(_ app: XCUIApplication) {
        let row = app.staticTexts["vs Northgate Falcons"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.staticTexts["Score Log"].waitForExistence(timeout: 20))
    }

    private func openFinishedGame(_ app: XCUIApplication) {
        let row = app.staticTexts["vs Lakeside Lightning"]
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        XCTAssertTrue(app.navigationBars["vs Lakeside Lightning"].waitForExistence(timeout: 20))
    }

    /// Drag inside the scrolling region rather than `swipeUp()`, which lands on
    /// the player deck in Live Scoring.
    private func dragUp(_ app: XCUIApplication, times: Int, from: CGFloat = 0.45,
                        to: CGFloat = 0.16) {
        let window = app.windows.firstMatch
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: from))
        let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: to))
        for _ in 0..<times { start.press(forDuration: 0.05, thenDragTo: end) }
    }

    /// Expand the in-game Stats panel and scroll it into view — the narrowest
    /// container `PlayerStatsTable` ever renders in, and therefore the one a new
    /// column has to survive.
    private func showLiveStatsPanel(_ app: XCUIApplication) {
        let toggle = app.buttons["Stats"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        toggle.tap()
        let header = app.staticTexts["AST"]
        XCTAssertTrue(header.waitForExistence(timeout: 20))
        for _ in 0..<10 where !header.isHittable { dragUp(app, times: 1) }
    }

    // MARK: - Baseline (today's app, for comparison)

    func testBaseline() {
        let app = launch()
        openLiveGame(app)
        snap("50-baseline-live-log")

        showLiveStatsPanel(app)
        snap("52-baseline-live-stats-panel")
        app.buttons["Stats"].tap()

        // Last, because the pad sheet is the one thing here that doesn't
        // dismiss reliably from a UI test.
        app.buttons["Nicholas #77"].tap()
        XCTAssertTrue(app.buttons["+2"].waitForExistence(timeout: 20))
        snap("51-baseline-score-pad")
    }

    // MARK: - Option A — misses as events, make/miss pad

    func testOptionAPadAndLog() {
        let app = launch(["-uiTestProposal175", "A"])
        openLiveGame(app)
        snap("61-a-live-log")

        showLiveStatsPanel(app)
        snap("65-a-live-stats-panel")
        app.buttons["Stats"].tap()

        app.buttons["Nicholas #77"].tap()
        XCTAssertTrue(app.buttons["2P ✗"].waitForExistence(timeout: 20),
                      "Option A's pad should offer a missed-2 button")
        snap("60-a-score-pad")
    }

    /// The same seven buttons, ordered by consequence instead of by symmetry:
    /// makes together, misses below a rule. #174 separated REB from `+2` for
    /// exactly this reason.
    func testOptionAGroupedPad() {
        let app = launch(["-uiTestProposal175", "A",
                          "-uiTestProposal175Pad", "grouped"])
        openLiveGame(app)
        app.buttons["Nicholas #77"].tap()
        XCTAssertTrue(app.buttons["MISS 2"].waitForExistence(timeout: 20),
                      "The grouped pad should offer MISS 2 below the makes")
        snap("68-a-score-pad-grouped")
    }

    /// One `FG` column (`5/13`) plus a plain `3P` make count: seven columns
    /// again, and only one of them wide.
    func testStatsFGColumn() {
        let app = launch(["-uiTestProposal175", "A",
                          "-uiTestProposal175Columns", "fg"])
        openFinishedGame(app)
        XCTAssertTrue(app.staticTexts["FG"].waitForExistence(timeout: 20),
                      "The fg variant should show an FG column")
        snap("69-a-stats-fg")

        openLiveGameFromSummary(app)
        showLiveStatsPanel(app)
        snap("69-b-live-stats-panel-fg")
    }

    func testOptionASummaryAndCombinedColumns() {
        let app = launch(["-uiTestProposal175", "A",
                          "-uiTestProposal175Columns", "combined"])
        openFinishedGame(app)
        snap("64-a-stats-combined")

        // Down to the Score Log section, where a full game's misses live.
        dragUp(app, times: 4, from: 0.75, to: 0.25)
        snap("62-a-summary-log")

        // The reorder/delete editor, at 69 events.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openFinishedGame(app)
        app.buttons["Edit Scores"].tap()
        XCTAssertTrue(app.buttons["Edit / Reorder"].waitForExistence(timeout: 20))
        app.buttons["Edit / Reorder"].tap()
        XCTAssertTrue(app.navigationBars["Edit Score Log"].waitForExistence(timeout: 20))
        snap("66-a-log-editor")
    }

    func testOptionASeparateColumns() {
        let app = launch(["-uiTestProposal175", "A",
                          "-uiTestProposal175Columns", "separate"])
        openFinishedGame(app)
        XCTAssertTrue(app.staticTexts["2PA"].waitForExistence(timeout: 20),
                      "The separate-columns variant should show a 2PA column")
        snap("63-a-stats-separate")

        openLiveGameFromSummary(app)
        showLiveStatsPanel(app)
        snap("67-a-live-stats-panel-separate")
    }

    private func openLiveGameFromSummary(_ app: XCUIApplication) {
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openLiveGame(app)
    }

    // MARK: - Option B — misses as a tally, off the log

    func testOptionBArmedDeck() {
        let app = launch(["-uiTestProposal175", "B"])
        openLiveGame(app)
        // The log is untouched by this option — same rows as today.
        snap("71-b-live-log")

        let missTwo = app.buttons["MISS 2"]
        XCTAssertTrue(missTwo.waitForExistence(timeout: 20))
        missTwo.tap()
        // Two taps = two misses, straight into the tally.
        app.buttons["Lucas #30"].tap()
        app.buttons["Lucas #30"].tap()
        app.buttons["Mason #5"].tap()
        snap("70-b-live-armed")

        missTwo.tap()   // disarm; back to scoring
        showLiveStatsPanel(app)
        snap("72-b-live-stats-panel")
    }

    func testOptionBSummary() {
        let app = launch(["-uiTestProposal175", "B"])
        openFinishedGame(app)
        snap("73-b-stats-combined")
        dragUp(app, times: 4, from: 0.75, to: 0.25)
        snap("74-b-summary-log")
    }

    // MARK: - Option D — one team number per period, where the tracker
    // already stops

    func testOptionDPeriodEntry() {
        let app = launch(["-uiTestProposal175", "D"])
        openLiveGame(app)
        let endPeriod = app.buttons["End Q2"]
        XCTAssertTrue(endPeriod.waitForExistence(timeout: 20))
        endPeriod.tap()
        XCTAssertTrue(app.navigationBars["End Q2"].waitForExistence(timeout: 20))
        snap("90-d-end-period")
        app.buttons["Cancel"].tap()

        // And the read side: one row under the linescore.
        XCTAssertTrue(app.buttons["Back"].waitForExistence(timeout: 20))
        app.buttons["Back"].tap()
        openFinishedGame(app)
        XCTAssertTrue(app.staticTexts["Our Shooting"].waitForExistence(timeout: 20),
                      "Option D should show a team shooting section")
        snap("91-d-summary-team-shooting")
    }

    // MARK: - Option C — typed in once, after the game

    func testOptionCPostGameEntry() {
        let app = launch(["-uiTestProposal175", "C"])
        openFinishedGame(app)
        let entry = app.buttons["Enter Shooting Attempts"]
        for _ in 0..<6 where !entry.exists { dragUp(app, times: 1, from: 0.75, to: 0.35) }
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        snap("80-c-summary-row")
        entry.tap()
        XCTAssertTrue(app.navigationBars["Shooting"].waitForExistence(timeout: 20))
        snap("81-c-shooting-sheet")
    }
}
