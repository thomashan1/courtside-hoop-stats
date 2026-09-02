import XCTest

/// Captures the follower experience (#57) — the read-only view someone sees
/// when a team is shared with them.
///
/// Split from `ScreenshotUITests` because it's the only flow that depends on
/// seeded *followed* teams (`DemoData.makeFollowedTeam`) rather than the
/// user's own team.
final class FollowingScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureFollowingScreens() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        // The Following tab only exists when something is actually shared with
        // you — its presence is itself the assertion.
        let followingTab = app.tabBars.buttons["Following"]
        XCTAssertTrue(followingTab.waitForExistence(timeout: 10),
                      "Following tab should appear when a followed team is seeded")
        followingTab.tap()

        // Titled with the followed team, like the Games tab — not "Following"
        // (#69). The tab bar already says where you are.
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10),
                      "Following should be titled with the followed team's name")
        // "Shared by Jean" (#120) — who shared it, not just when it last synced.
        XCTAssertTrue(app.staticTexts["Shared by Jean · Updated Just Now"].waitForExistence(timeout: 10),
                      "Following should say who shared the team")
        snap("20-following-list")

        // Two followed teams (#120, #121) — the "Switch Team" menu should
        // offer both, and picking the other one should update the title and
        // "Shared by" line. Regression coverage for #121: the previous
        // ToolbarTitleMenu-based switcher never actually opened.
        let switchTeam = app.buttons["Switch Team"]
        XCTAssertTrue(switchTeam.waitForExistence(timeout: 10))
        switchTeam.tap()
        let otherTeam = app.buttons["Eastside Eagles"]
        XCTAssertTrue(otherTeam.waitForExistence(timeout: 10),
                      "The switcher should list the other followed team")
        snap("20a-following-switcher")
        otherTeam.tap()
        XCTAssertTrue(app.navigationBars["Eastside Eagles"].waitForExistence(timeout: 10),
                      "Picking the other team should switch to it")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Shared by Mike'"))
                        .firstMatch.waitForExistence(timeout: 10),
                      "Switching teams should update who shared it")
        snap("20b-following-second-team")

        // Back to the first team for the rest of the flow below.
        app.buttons["Switch Team"].tap()
        app.buttons["Swish Warriors"].tap()
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10))

        // Open the live game a follower would most likely be here to watch.
        // Rows reuse GameRowView, so the label matches the Games tab's wording.
        let liveGame = app.staticTexts["vs Harbor Sharks"]
        XCTAssertTrue(liveGame.waitForExistence(timeout: 10))
        liveGame.tap()

        // Wait for the detail screen before capturing. Snapping straight after
        // the tap is a race, and it lost: the committed screenshot was the
        // Following *list* for a while, because nothing here failed when the
        // push hadn't landed yet.
        XCTAssertTrue(app.staticTexts["Most recent on top"].waitForExistence(timeout: 10),
                      "Should be on the followed game's detail before capturing")
        snap("21-following-game")

        // A live game must NOT offer the PDF: the page stamps FINAL and a
        // win/loss result, which would state an outcome that hasn't happened.
        XCTAssertFalse(app.buttons["Box Score PDF"].exists,
                       "A game in progress should not offer a box score")

        // A finished one does (#91) — the tracker isn't the only person who
        // wants it in the family group chat.
        app.navigationBars.buttons.firstMatch.tap()
        let finished = app.staticTexts["vs Valley Vipers"]
        XCTAssertTrue(finished.waitForExistence(timeout: 10))
        finished.tap()

        let pdfButton = app.buttons["Box Score PDF"]
        XCTAssertTrue(pdfButton.waitForExistence(timeout: 10),
                      "A finished followed game should offer the box score PDF")
        pdfButton.tap()
        XCTAssertTrue(app.buttons["Share"].waitForExistence(timeout: 10),
                      "The PDF preview should offer Share")
        snap("22-following-pdf")
        app.buttons["Done"].tap()
    }

    /// Unfollowing (#123) removes just this device's copy of one team,
    /// leaving the other followed team and the tab itself in place.
    func testUnfollowRemovesTeam() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        app.tabBars.buttons["Following"].tap()
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10))

        // Switch to the second team before unfollowing it, so the assertions
        // below can't accidentally pass by looking at the wrong team.
        app.buttons["Switch Team"].tap()
        app.buttons["Eastside Eagles"].tap()
        XCTAssertTrue(app.navigationBars["Eastside Eagles"].waitForExistence(timeout: 10))

        app.buttons["More"].tap()
        let unfollow = app.buttons["Unfollow Eastside Eagles"]
        XCTAssertTrue(unfollow.waitForExistence(timeout: 10))
        unfollow.tap()

        let confirm = app.buttons["Unfollow"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 10),
                      "Unfollowing should ask for confirmation first")
        snap("23-following-unfollow")
        confirm.tap()

        // Back down to one followed team: the switcher (only shown for 2+)
        // should disappear, and the remaining team should be what's left.
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10),
                      "Unfollowing the second team should fall back to the first")
        XCTAssertFalse(app.buttons["Switch Team"].exists,
                       "The switcher shouldn't show for only one followed team")
    }
}
