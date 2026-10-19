import XCTest

/// One team, several tournaments: games grouped by League, the season by
/// tournament, and a follower seeing the league.
final class TournamentUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
        return app
    }

    func testGamesAndSeasonByTournament() {
        let app = launch()
        app.buttons["Games"].firstMatch.tap()
        // The demo's pickup game has no league, so it's a second group.
        let other = app.staticTexts["Other Games"]
        for _ in 0..<4 where !other.exists { app.swipeUp() }
        XCTAssertTrue(other.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Metro Youth League"].exists)
        XCTAssertFalse(app.staticTexts["Final Scores"].exists)
        snap("58-games-by-tournament")

        // Name the pickup game's tournament.
        app.buttons["Other Games options"].tap()
        app.buttons["Name Tournament…"].tap()
        app.textFields["Tournament"].typeText("Summer Pickup")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Summer Pickup"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Other Games"].exists)

        // The season opens on the current tournament, and can show it all.
        app.buttons["Roster"].firstMatch.tap()
        app.buttons["Season Averages"].tap()
        XCTAssertTrue(app.staticTexts["Per game, across 3 games"].waitForExistence(timeout: 10))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tournament'")).firstMatch.tap()
        snap("59-season-tournament-picker")
        app.buttons["All Games"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Per game, across 4 games"].waitForExistence(timeout: 10))
    }

    /// One league is still a named section, and the season carries its name.
    func testOneLeagueIsStillNamed() {
        let app = launch()
        app.buttons["Games"].firstMatch.tap()
        let other = app.staticTexts["Other Games"]
        for _ in 0..<4 where !other.exists { app.swipeUp() }
        // Merge the pickup game in, leaving a single league.
        app.buttons["Other Games options"].tap()
        app.buttons["Name Tournament…"].tap()
        app.textFields["Tournament"].typeText("Metro Youth League")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Metro Youth League"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Other Games"].exists)
        XCTAssertFalse(app.staticTexts["Final Scores"].exists)
        for _ in 0..<4 { app.swipeDown() }
        snap("61-games-one-league")

        app.buttons["Roster"].firstMatch.tap()
        app.buttons["Season Averages"].tap()
        XCTAssertTrue(app.staticTexts["Per game, across 4 games"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Tournament'"))
            .firstMatch.exists)
        snap("62-season-one-league")
    }

    /// A follower sees which league a game was in, and where.
    func testFollowerSeesTheLeague() {
        let app = launch()
        app.buttons["Following"].firstMatch.tap()
        let game = app.staticTexts["vs Valley Vipers"]
        for _ in 0..<6 where !game.exists { app.swipeUp() }
        XCTAssertTrue(game.waitForExistence(timeout: 10))
        game.tap()
        // A LabeledContent row reads as one element: "League, Metro Youth League".
        let details = app.staticTexts["Details"]
        for _ in 0..<8 where !details.isHittable { app.swipeUp() }
        let league = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Metro Youth League'")).firstMatch
        XCTAssertTrue(league.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Location"].exists)
        snap("60-follower-game-details")
    }
}
