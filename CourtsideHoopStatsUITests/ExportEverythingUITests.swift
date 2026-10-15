import XCTest

/// Settings ▸ Export Everything: every team and game as one file.
final class ExportEverythingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testExportEverythingOffersTheFile() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
        app.buttons["Settings"].firstMatch.tap()

        let export = app.buttons["Export Everything"]
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 10))
        // Clear of the tab bar, so the capture shows the row.
        app.swipeUp()
        XCTAssertTrue(export.waitForExistence(timeout: 10))
        snap("55-export-everything")

        export.tap()
        // The share sheet, offering the file.
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 10)
                      || app.buttons["Save to Files"].waitForExistence(timeout: 5))
        snap("56-export-everything-share")
    }
}
