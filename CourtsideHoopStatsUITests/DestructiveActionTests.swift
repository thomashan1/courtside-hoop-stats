import XCTest

/// Deletes that lose *other* data must confirm first (UI_GUIDELINES §2).
///
/// Deleting a team takes its roster and every game it ever played. That was
/// confirmed from the team's detail sheet but **not** from the swipe action in
/// Settings ▸ Teams, so the faster path was also the destructive one — a swipe
/// and a tap, no confirm, no undo.
final class DestructiveActionTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testDeletingATeamAsksFirst() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        app.buttons["Settings"].tap()
        let team = app.staticTexts["Eastside Eagles"]
        XCTAssertTrue(team.waitForExistence(timeout: 10))

        team.swipeLeft()
        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 5),
                      "Swipe should reveal a Delete action")
        deleteAction.tap()

        // The team must still be there, behind a confirmation, rather than
        // already gone. Both halves matter: an unconfirmed delete would also
        // leave no dialog, so asserting only the dialog would be ambiguous.
        let confirm = app.buttons["Delete Team & Its Games"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5),
                      "Deleting a team must confirm — it takes every game with it")
        XCTAssertTrue(team.exists, "The team should survive until the delete is confirmed")

        // The dialog's Cancel carries no accessibility label on iOS 26, so it
        // isn't addressable here; the cancel path is exercised by hand. What
        // this can check is that confirming does go through.
        confirm.tap()
        XCTAssertFalse(team.waitForExistence(timeout: 3),
                       "Confirming should delete the team")
    }

    /// The Games list uses `.onDelete` for the same confirm-then-delete flow.
    /// That form is safe — SwiftUI owns the swipe and doesn't pre-empt the data
    /// — but it's the same shape as the team delete, so it's worth holding in
    /// place rather than assuming.
    func testDeletingAPlayedGameAsksFirst() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        let game = app.staticTexts["vs Lakeside Lightning"]
        XCTAssertTrue(game.waitForExistence(timeout: 10))

        game.swipeLeft()
        let deleteAction = app.buttons["Delete"]
        XCTAssertTrue(deleteAction.waitForExistence(timeout: 5))
        deleteAction.tap()

        let confirm = app.buttons["Delete Game & Scores"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5),
                      "A played game has recorded scores — deleting it must confirm")
        XCTAssertTrue(game.exists, "The game should survive until confirmed")

        confirm.tap()
        XCTAssertFalse(game.waitForExistence(timeout: 3),
                       "Confirming should delete the game")
    }
}
