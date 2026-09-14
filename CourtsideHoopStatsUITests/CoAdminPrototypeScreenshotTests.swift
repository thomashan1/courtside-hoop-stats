import XCTest

/// PROTOTYPE (#169) — captures the co-admin design for review before any of it
/// is built for real.
///
/// Two personas, two launch flavours on top of the existing demo seed:
/// - `-uiTestCoAdminOwner` — you own the team and are handing someone write
///   access. Owner-side screens: the role chooser and the people list.
/// - `-uiTestCoAdminSelf` — the team is someone else's and you're their
///   co-admin. Everything in the ordinary tabs, minus live scoring.
///
/// Split from `ScreenshotUITests` for the same reason `FollowingScreenshotTests`
/// was: it depends on its own seed, and the committed screenshot set must not
/// move while a design is still being argued about.
final class CoAdminPrototypeScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(_ extraArguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"] + extraArguments
        app.launch()
        return app
    }

    // MARK: - Owner side

    func testOwnerGrantsCoAdmin() {
        let app = launch(["-uiTestCoAdminOwner"])

        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))

        // The subtitle now has two populations to report, not one count.
        let peopleButton = app.buttons["Shared with 2 followers, 2 co-admins"]
        XCTAssertTrue(peopleButton.waitForExistence(timeout: 10),
                      "The Games subtitle should separate co-admins from followers")
        snap("30-coadmin-owner-games")

        peopleButton.tap()
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Co-admins"].waitForExistence(timeout: 5),
                      "People who can edit should be listed in their own section")
        XCTAssertTrue(app.staticTexts["Thomas H."].exists)
        XCTAssertTrue(app.staticTexts["Grandma Chen"].exists)
        snap("31-coadmin-people")

        // Tapping someone opens what they may do — the change the invite
        // sheet's footer promises is possible.
        app.staticTexts["Grandma Chen"].tap()
        XCTAssertTrue(app.navigationBars["Grandma Chen"].waitForExistence(timeout: 10),
                      "Tapping a person should open their permissions")
        XCTAssertTrue(app.buttons["Remove from Team"].exists)
        // By identifier: the row combines its children for VoiceOver, so its
        // label is the whole paragraph, not the word "Co-admin".
        app.buttons["role-coTracker"].tap()
        // Wait for the copy that only exists once the choice changed. Snapping
        // straight after the tap photographed two empty radio buttons.
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label BEGINSWITH 'Save to let them edit'"))
            .firstMatch.waitForExistence(timeout: 10),
                      "Promoting a follower should say what Save will do")
        snap("31b-coadmin-change-role")
        app.buttons["Cancel"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Co-admins"].waitForExistence(timeout: 10))

        // The role chooser, in our words, before the system share sheet.
        app.buttons["Add People…"].tap()
        let roleSheet = app.navigationBars["Invite to Swish Warriors"]
        XCTAssertTrue(roleSheet.waitForExistence(timeout: 10),
                      "Inviting should ask what the person may do first")
        snap("32-coadmin-invite-role-default")

        // Picking Co-admin reveals the limit CloudKit's own sheet can't state.
        app.buttons["role-coTracker"].tap()
        XCTAssertTrue(app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS 'Scoring stays with you'"))
            .firstMatch.waitForExistence(timeout: 5),
                      "Choosing Co-admin should say scoring is still the owner's")
        snap("33-coadmin-invite-role-chosen")

        // Stop at the handoff: the system sheet is Apple's and can't be driven
        // from a UI test without a real iCloud account.
        app.buttons["Cancel"].firstMatch.tap()
    }

    // MARK: - Co-admin's own app

    func testCoAdminApp() {
        let app = launch(["-uiTestCoAdminSelf"])

        // A team you can edit is not a team you follow. It belongs in the
        // ordinary tabs, so the Following tab should not appear at all.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.tabBars.buttons["Following"].exists,
                       "A co-admin's team is not a followed team")
        XCTAssertTrue(app.staticTexts["Co-admin · Shared by Jean (Nicky's mom)"]
                        .waitForExistence(timeout: 5),
                      "The Games tab should say whose team this is")
        snap("34-coadmin-games")

        // New Game: a co-admin schedules, and that's all.
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.navigationBars["New Game"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Start Game"].exists,
                       "A co-admin should not be offered Start Game")
        XCTAssertTrue(app.buttons["Save"].exists, "A co-admin can still schedule a game")
        snap("35-coadmin-new-game")
        app.buttons["Cancel"].tap()

        // A scheduled game: fully editable, but not startable.
        app.staticTexts["vs Summit Storm"].tap()
        XCTAssertTrue(app.navigationBars["vs Summit Storm"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Start Game"].exists)
        XCTAssertTrue(app.buttons["Edit"].exists, "Details stay editable for a co-admin")
        snap("36-coadmin-scheduled-game")
        app.navigationBars["vs Summit Storm"].buttons.firstMatch.tap()

        // The one thing a co-admin can't do.
        XCTAssertTrue(app.staticTexts["vs Northgate Falcons"].waitForExistence(timeout: 10))
        app.staticTexts["vs Northgate Falcons"].tap()
        XCTAssertTrue(app.staticTexts["Jean (Nicky's mom) is scoring this game"]
                        .waitForExistence(timeout: 10),
                      "A game in progress should name who is scoring it")
        snap("37-coadmin-live-locked")
        app.navigationBars.buttons.firstMatch.tap()

        // A finished game: correcting the score is squarely a co-admin's job.
        XCTAssertTrue(app.staticTexts["vs Lakeside Lightning"].waitForExistence(timeout: 10))
        app.staticTexts["vs Lakeside Lightning"].tap()
        XCTAssertTrue(app.buttons["Edit Scores"].waitForExistence(timeout: 10),
                      "A co-admin can correct a finished game")
        snap("38-coadmin-finished-game")
        app.navigationBars.buttons.firstMatch.tap()

        // The roster is editable — two people keeping jersey numbers straight
        // is half the reason this was asked for.
        app.tabBars.buttons["Roster"].tap()
        XCTAssertTrue(app.navigationBars["Swish Warriors"].waitForExistence(timeout: 10))
        snap("39-coadmin-roster")

        // Settings ▸ Teams: which of these is actually yours.
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Eastside Eagles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Co-admin"].exists,
                      "Settings should tag a team you co-admin but don't own")
        snap("40-coadmin-settings-teams")
    }
}
