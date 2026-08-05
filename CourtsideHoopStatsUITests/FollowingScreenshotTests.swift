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
        snap("21-following-game")
    }
}
