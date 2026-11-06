import XCTest
import AppIntentsTesting

// App Intents Testing: the #255 intents and `TeamEntity`, run out of process
// through the same App Intents path Siri and Shortcuts use. Unlike
// `SiriEvaluationTests` these need no Siri, no device and no opt-in, so they
// run with every simulator test pass and catch a renamed intent, a broken
// team query or a missing Spotlight index before Siri Evaluations would.
// https://developer.apple.com/documentation/appintentstesting

/// The app's intents and entity, by the names in its App Intents metadata.
/// A rename in `CourtsideIntents.swift` fails here, and would break every
/// shortcut someone has built from them.
private enum Courtside {
    static let definitions = IntentDefinitions(bundleIdentifier: "com.thomashan.CourtsideHoopStats")
    static let lastGameScore = definitions.intents["LastGameScoreIntent"]
    static let teamRecord = definitions.intents["TeamRecordIntent"]
    static let team = definitions.entities["TeamEntity"]
}

/// Against the demo season, as `SiriEvaluationTests`: Swish Warriors (active)
/// last beat Lakeside Lightning 48–41 and are 2–1–1; Eastside Eagles are 1–0,
/// last beating Northgate Falcons. The demo store is in memory.
final class CourtsideIntentsTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
    }

    private func answer(_ intent: AnyAppIntent) async throws -> String {
        let result = try await intent.run()
        return try result.value
    }

    private func eastside() async throws -> AnyAppEntity {
        let teams = try await Courtside.team.entities(matching: "Eastside")
        XCTAssertEqual(teams.count, 1)
        return try XCTUnwrap(teams.first)
    }

    // MARK: Intents

    /// No team: the active team, as Siri asks when no team is named.
    func testLastGameScoreAnswersForTheActiveTeam() async throws {
        let answer = try await answer(Courtside.lastGameScore.makeIntent())
        XCTAssertTrue(answer.hasPrefix("Swish Warriors beat Lakeside Lightning 48–41 on "), answer)
    }

    func testTeamRecordAnswersForTheActiveTeam() async throws {
        let answer = try await answer(Courtside.teamRecord.makeIntent())
        XCTAssertEqual(answer, "Swish Warriors is 2–1–1 across 4 finished games.")
    }

    /// A team found by name flows into the intent, as "How did Eastside
    /// Eagles do in Courtside" does.
    func testLastGameScoreAnswersForANamedTeam() async throws {
        let answer = try await answer(Courtside.lastGameScore.makeIntent(team: try await eastside()))
        XCTAssertTrue(answer.hasPrefix("Eastside Eagles beat Northgate Falcons "), answer)
    }

    func testTeamRecordAnswersForANamedTeam() async throws {
        let answer = try await answer(Courtside.teamRecord.makeIntent(team: try await eastside()))
        XCTAssertEqual(answer, "Eastside Eagles is 1–0 across 1 finished game.")
    }

    // MARK: Team query

    /// Siri resolves a spoken name by string: part of a name, any case.
    func testTeamQueryMatchesPartOfANameInAnyCase() async throws {
        let teams = try await Courtside.team.entities(matching: "eagles")
        XCTAssertEqual(teams.count, 1)
        let name: String = try XCTUnwrap(teams.first).name
        XCTAssertEqual(name, "Eastside Eagles")
        let none = try await Courtside.team.entities(matching: "Lakeside")
        XCTAssertTrue(none.isEmpty, "an opponent isn't one of your teams")
    }

    /// What Shortcuts offers in the Team picker: every team.
    func testSuggestedTeamsAreEveryTeam() async throws {
        let names: [String] = try await Courtside.team.suggestedEntities().map { try $0.name }
        XCTAssertEqual(Set(names), ["Swish Warriors", "Eastside Eagles"])
    }

    /// A team's identifier comes back as the same team, which is how a saved
    /// shortcut finds its team again.
    func testATeamResolvesByItsIdentifier() async throws {
        let id = try await eastside().identifier.instanceIdentifier
        let again = try await Courtside.team.entities(identifiers: [try XCTUnwrap(UUID(uuidString: id))])
        let names: [String] = try again.map { try $0.name }
        XCTAssertEqual(names, ["Eastside Eagles"])
        let saved = Courtside.team.makeReference(identifier: id)
        let answer = try await answer(Courtside.teamRecord.makeIntent(team: saved))
        XCTAssertEqual(answer, "Eastside Eagles is 1–0 across 1 finished game.")
    }

    // MARK: Spotlight

    /// Siri searches the Spotlight index for a team (#256), so both demo
    /// teams must be in it, and nothing else. The index is written by a task
    /// after launch, so this waits for it.
    func testEveryTeamIsInSpotlight() async throws {
        var names: Set<String> = []
        for _ in 0..<20 {
            names = Set(try await Courtside.team.spotlightQuery(nil).map { try $0.name })
            if names == ["Swish Warriors", "Eastside Eagles"] { break }
            try await Task.sleep(for: .milliseconds(500))
        }
        XCTAssertEqual(names, ["Swish Warriors", "Eastside Eagles"])
        let found: [String] = try await Courtside.team.spotlightQuery("Eastside").map { try $0.name }
        XCTAssertEqual(found, ["Eastside Eagles"])
    }
}
