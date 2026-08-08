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
        snap("20-following-list")

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
}
