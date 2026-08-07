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
    private func launch(textSizeIndex: Int) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo", "-uiTestTextSizeIndex", "\(textSizeIndex)"]
        app.launch()
        return app
    }

    /// The banner at **xxxLarge** — the top of iOS's ordinary text slider,
    /// reachable without ever turning on Larger Accessibility Sizes.
    ///
    /// This is the size the bug was reported at, and the reason the first fix
    /// missed it: gating the stacked layout on `isAccessibilitySize` skipped
    /// every user of the normal slider.
    func testBannerStacksAtLargestNonAccessibilitySize() throws {
        let app = launch(textSizeIndex: 3)   // AppTextSize.steps[3] == .xxxLarge

        let played = app.staticTexts["vs Lakeside Lightning"]
        for _ in 0..<8 where !played.exists { app.swipeUp() }
        XCTAssertTrue(played.waitForExistence(timeout: 10))
        played.tap()

        let kitLabel = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'HOME ·' OR label BEGINSWITH 'AWAY ·'")).firstMatch
        XCTAssertTrue(kitLabel.waitForExistence(timeout: 10))

        let date = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Wed,' OR label BEGINSWITH 'Mon,' OR label CONTAINS ','")).firstMatch
        XCTAssertTrue(date.exists)
        XCTAssertGreaterThan(kitLabel.frame.minY, date.frame.midY,
                             "Banner should stack at xxxLarge, not share a row")
        snap(app, "94-owner-banner-xxxlarge")

        // The follower's banner at the same size.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["Following"].waitForExistence(timeout: 10))
        app.buttons["Following"].tap()
        let watched = app.staticTexts["vs Harbor Sharks"]
        for _ in 0..<8 where !watched.exists { app.swipeUp() }
        XCTAssertTrue(watched.waitForExistence(timeout: 10))
        watched.tap()
        XCTAssertTrue(app.staticTexts["Live now"].waitForExistence(timeout: 10))
        snap(app, "95-follower-banner-xxxlarge")
    }

    /// …and the same banner must *not* stack at the default size, or every
    /// normal-sized screen pays for the accessibility fix.
    func testBannerStaysOnOneRowAtDefaultTextSize() throws {
        let app = launch(textSizeIndex: 0)

        let played = app.staticTexts["vs Lakeside Lightning"]
        XCTAssertTrue(played.waitForExistence(timeout: 10))
        played.tap()

        let kitLabel = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'HOME ·' OR label BEGINSWITH 'AWAY ·'")).firstMatch
        XCTAssertTrue(kitLabel.waitForExistence(timeout: 10))

        let date = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS ','")).firstMatch
        XCTAssertTrue(date.exists)
        XCTAssertLessThan(abs(kitLabel.frame.midY - date.frame.midY), 12,
                          "At the default size both halves should share one row")
    }

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

    /// Both game banners at the largest text size (#109).
    ///
    /// The band puts a date (or "Following") against a right-hand label. At
    /// accessibility sizes the date alone wraps to two lines and shoulders the
    /// label off the edge — reported from a real phone, where "HOME · PURPLE"
    /// was pushed against the screen edge with the date wrapping beside it.
    /// They stack instead now, so this asserts both halves stay on screen.
    func testGameBannersSurviveLargestTextSize() throws {
        let app = launchAtLargestText()
        let screen = app.windows.firstMatch.frame

        // Owner: a finished game. At this text size the Final Scores section
        // starts below the fold, and a List doesn't realise rows it hasn't
        // shown — so scroll to it rather than assuming it's there.
        let played = app.staticTexts["vs Lakeside Lightning"]
        for _ in 0..<8 where !played.exists { app.swipeUp() }
        XCTAssertTrue(played.waitForExistence(timeout: 10),
                      "Couldn't reach a finished game at the largest text size")
        played.tap()

        let ownerLabel = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'HOME ·' OR label BEGINSWITH 'AWAY ·'")).firstMatch
        XCTAssertTrue(ownerLabel.waitForExistence(timeout: 10),
                      "The owner's banner should show home/away and the kit")

        // The real symptom is the two halves fighting over one row, each
        // wrapping to three lines — not overflowing the screen, which is why
        // asserting they're on screen catches nothing. At this size they must
        // be on separate rows.
        // Matches the day, e.g. "Wed, Jul 8". Deliberately not keyed on a
        // colon — the banner dropped the tip-off time, which is what used to
        // put one there.
        let ownerDate = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS ','")).firstMatch
        XCTAssertTrue(ownerDate.exists, "The banner should show the game date")
        XCTAssertGreaterThan(ownerLabel.frame.minY, ownerDate.frame.midY,
                             "Banner should stack at the largest text size, not share a row")

        snap(app, "91-summary-banner-large-text")
        app.navigationBars.buttons.firstMatch.tap()

        // Follower: a live game.
        XCTAssertTrue(app.buttons["Following"].waitForExistence(timeout: 10))
        app.buttons["Following"].tap()
        let watched = app.staticTexts["vs Harbor Sharks"]
        for _ in 0..<8 where !watched.exists { app.swipeUp() }
        XCTAssertTrue(watched.waitForExistence(timeout: 10))
        watched.tap()

        let live = app.staticTexts["Live now"]
        XCTAssertTrue(live.waitForExistence(timeout: 10), "The follower's banner should show LIVE")
        let followingLabel = app.staticTexts["Following"].firstMatch
        XCTAssertTrue(followingLabel.exists)
        XCTAssertGreaterThan(live.frame.minY, followingLabel.frame.midY,
                             "Banner should stack at the largest text size, not share a row")

        snap(app, "92-follower-banner-large-text")
    }

    /// Save a full-device screenshot as a kept attachment.
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
