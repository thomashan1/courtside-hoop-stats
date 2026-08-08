import XCTest

/// The build identifier at the bottom of Settings (#111).
///
/// Builds reach the phones from two routes — a direct install and TestFlight —
/// and they talk to different CloudKit databases. Devices on different routes
/// can't see each other's shares, which looks exactly like sharing being
/// broken, so the device has to be able to answer "which build is this, and
/// which iCloud does it use?" on its own.
///
/// Kept apart from the screenshot capture: driving Settings to the bottom in
/// the middle of that long test made it hang.
final class BuildInfoTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSettingsNamesTheBuildAndCloudKitEnvironment() {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Teams"].waitForExistence(timeout: 10))

        // Matched on the accessibility label, which is spelled out for
        // VoiceOver rather than the interpunct-separated line on screen.
        let footer = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] 'version' AND label CONTAINS 'iCloud'")).firstMatch

        app.swipeUp()
        XCTAssertTrue(footer.waitForExistence(timeout: 5),
                      "Settings should name the build and its iCloud environment")

        let label = footer.label
        XCTAssertTrue(label.contains("Development") || label.contains("Production"),
                      "Footer should name the CloudKit environment, got: \(label)")

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "17-version-footer"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
