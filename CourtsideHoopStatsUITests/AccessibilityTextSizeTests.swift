import XCTest

/// Live Scoring at accessibility text sizes (#93).
///
/// The player deck is sized by `@ScaledMetric`, so at large text sizes the cards
/// widen, the grid drops to one or two columns, and a ten-player roster grows
/// tall enough to push the Score Log off the screen entirely. The tracker is
/// then scoring blind — and the person most likely to hit it is exactly the
/// person who turned Text Size up.
///
/// The deck is capped at half the screen and scrolls within that instead. This
/// asserts the outcome rather than the mechanism: at the largest text size the
/// scoreboard, the Score Log, and the player cards must all still be on screen
/// at once.
final class AccessibilityTextSizeTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Launches at the app's largest Text Size step (`accessibility3`) — the
    /// top of the slider in Settings, and the setting the end user actually
    /// turned up.
    ///
    /// This drives the *in-app* control rather than the OS content-size
    /// category: the root view applies its own `.dynamicTypeSize` floor, so an
    /// `-UIPreferredContentSizeCategoryName` launch argument never reaches the
    /// views and the test silently exercises the default size instead.
    private func launchAtLargestText() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "-uiTestSeedDemo",
            "-uiTestTextSizeIndex", "6",   // AppTextSize.steps.last == .accessibility3
        ]
        app.launch()
        return app
    }

    func testScoreLogSurvivesLargestTextSize() throws {
        let app = launchAtLargestText()

        XCTAssertTrue(app.staticTexts["vs Northgate Falcons"].waitForExistence(timeout: 10))
        app.staticTexts["vs Northgate Falcons"].tap()

        let scoreLog = app.staticTexts["Score Log"]
        XCTAssertTrue(scoreLog.waitForExistence(timeout: 10),
                      "Score Log header must exist in Live Scoring")

        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = "90-live-scoring-large-text"
        attachment.lifetime = .keepAlways
        add(attachment)

        let screen = app.windows.firstMatch.frame

        // The log header is the thing the deck used to displace. `hittable`
        // rather than `exists`: an element pushed past the bottom edge still
        // exists in the hierarchy, which is why this failed silently before.
        XCTAssertTrue(scoreLog.isHittable,
                      "Score Log header was pushed off screen by the player deck")
        XCTAssertTrue(screen.contains(scoreLog.frame),
                      "Score Log header (\(scoreLog.frame)) left the screen (\(screen))")

        // The deck is capped at half the screen, so the log keeps real room —
        // not just a sliver. Anything above the midpoint is the log's.
        XCTAssertLessThan(scoreLog.frame.maxY, screen.midY,
                          "Score Log header should sit in the top half; the deck is capped at 50%")

        // …and the deck itself must still be usable, not merely present. The
        // roster is alphabetical and the grid is one column wide at this size,
        // so Adrian is the card in view.
        let firstCard = app.buttons["Adrian #19"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.isHittable, "Player card unreachable at large text size")

        // Capping the deck is only half the fix — the players it no longer has
        // room for have to be reachable by scrolling, or benching someone is
        // the only way to score for them. Nicholas is 9th of 10 alphabetically,
        // so he's below the fold until the deck is scrolled.
        let lastCard = app.buttons["Nicholas #77"]
        XCTAssertFalse(lastCard.exists,
                       "Precondition: Nicholas should start below the fold at this text size")

        // The screen has two scroll views — the Score Log and the deck. The
        // deck is the lower one.
        let deck = app.scrollViews.allElementsBoundByIndex
            .max { $0.frame.minY < $1.frame.minY }
        let deckScroll = try XCTUnwrap(deck, "Player deck should be a scroll view")

        // Roughly two cards fit in the capped deck, so reaching the 9th of 10
        // takes several swipes. Bounded so a deck that doesn't scroll at all
        // fails rather than spinning.
        for _ in 0..<8 where !lastCard.exists {
            deckScroll.swipeUp()
        }
        XCTAssertTrue(lastCard.waitForExistence(timeout: 5),
                      "Player deck does not scroll — players below the fold are unreachable")

        // Tapping a card still opens the point pad — the whole purpose of the
        // screen, and worth confirming the scroll wrapper didn't break it.
        lastCard.tap()
        XCTAssertTrue(app.buttons["+2"].waitForExistence(timeout: 5),
                      "Point pad should open at large text size")
    }
}
