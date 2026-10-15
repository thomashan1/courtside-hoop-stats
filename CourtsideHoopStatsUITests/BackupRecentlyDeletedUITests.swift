import XCTest

/// Settings ▸ Restore from iCloud: what was deleted in the last 30 days can
/// still be picked and brought back.
final class BackupRecentlyDeletedUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testDeletedGameCanBeRestored() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
        app.buttons["Settings"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 10))
        app.swipeUp()
        // The first tap can land while the swipe is still scrolling.
        let restore = app.buttons["Restore from iCloud…"]
        let browser = app.navigationBars["Restore from iCloud"]
        for _ in 0..<3 where !browser.exists {
            restore.tap()
            _ = browser.waitForExistence(timeout: 3)
        }

        let header = app.staticTexts["Deleted in the Last 30 Days"]
        XCTAssertTrue(browser.waitForExistence(timeout: 10))
        for _ in 0..<4 where !header.isHittable { app.swipeUp() }
        XCTAssertTrue(header.waitForExistence(timeout: 10))

        let deleted = app.buttons.containing(.staticText, identifier: "vs Harbor Hawks").firstMatch
        XCTAssertTrue(deleted.waitForExistence(timeout: 5))
        deleted.tap()
        XCTAssertTrue(app.buttons["Restore (1)"].isEnabled)
        snap("57-restore-recently-deleted")
    }
}
