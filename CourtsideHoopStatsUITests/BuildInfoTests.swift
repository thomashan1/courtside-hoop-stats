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
        // Keyed on the version alone. The CloudKit label is deliberately
        // absent from an App Store build, so requiring it would tie the test to
        // the channel it happens to run under.
        let footer = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'App version '")).firstMatch

        app.swipeUp()
        XCTAssertTrue(footer.waitForExistence(timeout: 5),
                      "Settings should name the build and its iCloud environment")

        let label = footer.label
        // Tests only ever run on a debug build, which is the Xcode channel —
        // the one where knowing the environment matters most.
        XCTAssertTrue(label.contains("CloudKit Dev"),
                      "A development build should name its CloudKit environment, got: \(label)")

        // Spoken, not the compact on-screen line: "v1.2" is read as
        // "vee one point two" and the interpuncts as nothing.
        XCTAssertTrue(label.hasPrefix("App version "),
                      "VoiceOver should get the spelled-out form, got: \(label)")

        // Deliberately not asserting the height: the frame reported here is the
        // list row's (a constant 52pt), not the text's, so it says nothing
        // about whether the line wrapped. Wrapping is checked by eye against
        // the attached screenshot.

        // A directly-installed build must show *when* it was built. Its build
        // number is a static value in the project file that nothing
        // increments, so it can't tell one direct install from another — which
        // is the whole question this footer exists to answer.
        if label.contains("Xcode") {
            XCTAssertTrue(label.contains("built"),
                          "An Xcode build should show its build time, got: \(label)")
        }

        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "17-version-footer"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
