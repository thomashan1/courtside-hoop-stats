#if canImport(SiriEvaluations)
import XCTest
import Evaluations
import SiriEvaluations

// Siri Evaluations (#256): scripted requests run through real Siri, checking
// which of the #255 intents it calls and what it says back.
//
// - Device only: the framework ships for iPhone, Mac and Vision Pro, not the
//   simulator, so this file compiles to nothing for a simulator build.
// - Needs iOS 27.3, Developer Mode, Settings ▸ Developer ▸ Enable UI
//   Automation, and Apple Intelligence on. Older systems skip.
// - Siri varies between runs, so these measure rather than gate: each test
//   wants two of its three scenarios, not all three every time.

/// The app's intents and entity, by the names in its App Intents metadata.
@available(iOS 27.3, *)
private enum Courtside {
    static let definitions = IntentDefinitions(bundleIdentifier: "com.thomashan.CourtsideHoopStats")
    static let lastGameScore = definitions.intents["LastGameScoreIntent"]
    static let teamRecord = definitions.intents["TeamRecordIntent"]
    static let team = definitions.entities["TeamEntity"]
}

/// One evaluation type for every test here; each passes its own name and set.
@available(iOS 27.3, *)
private struct CourtsideSiriEvaluation: Evaluation {
    let name: String
    let dataset: SiriScenarioLoader

    func subject(from sample: SiriScenario) async throws -> SiriScenarioSubject {
        try await SiriService.run(scenario: sample)
    }

    var evaluators: Evaluators { SiriExpectationEvaluator() }

    func aggregateMetrics(using aggregator: inout MetricsAggregator) {
        Self.computeSiriMetrics(into: &aggregator)
    }
}

/// Against the demo season: Swish Warriors (active) last beat Lakeside
/// Lightning 48–41 and are 2–1–1; Eastside Eagles are the second team.
/// The demo store is in memory, so nothing on the device is touched.
final class SiriEvaluationTests: XCTestCase {
    @MainActor
    override func setUp() async throws {
        guard #available(iOS 27.3, *) else { throw XCTSkip("Siri Evaluations needs iOS 27.3") }
        // Siri answers from the running app's store, so it must be the demo one.
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
    }

    func testLastGameScoreRequests() async throws {
        guard #available(iOS 27.3, *) else { throw XCTSkip("Siri Evaluations needs iOS 27.3") }
        let result = try await CourtsideSiriEvaluation(
            name: "Last game score",
            dataset: SiriScenarioLoader {
                SiriScenario {
                    UserTurn("What was the score of the last game in Courtside") {
                        Calls { Courtside.lastGameScore }
                        Calls(.disallowed) { Courtside.teamRecord }
                        SiriResponse(.contains("Lakeside Lightning"))
                    }
                }
                SiriScenario {
                    UserTurn("Last game score in Courtside") {
                        Calls { Courtside.lastGameScore }
                        SiriResponse(.contains("48"))
                    }
                }
                SiriScenario {
                    UserTurn("How did Eastside Eagles do in Courtside") {
                        Calls { Courtside.lastGameScore }
                        Finds { Courtside.team }
                        SiriResponse(.contains("Eastside Eagles"))
                    }
                }
            }
        ).run()
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.aggregateValue(.mean(of: .intentsAllPass))), 0.66)
    }

    func testTeamRecordRequests() async throws {
        guard #available(iOS 27.3, *) else { throw XCTSkip("Siri Evaluations needs iOS 27.3") }
        let result = try await CourtsideSiriEvaluation(
            name: "Team record",
            dataset: SiriScenarioLoader {
                SiriScenario {
                    UserTurn("What's our record in Courtside") {
                        Calls { Courtside.teamRecord }
                        Calls(.disallowed) { Courtside.lastGameScore }
                        SiriResponse(.contains("Swish Warriors"))
                    }
                }
                SiriScenario {
                    UserTurn("Courtside record") {
                        Calls { Courtside.teamRecord }
                    }
                }
                SiriScenario {
                    UserTurn("What's Eastside Eagles's record in Courtside") {
                        Calls { Courtside.teamRecord }
                        Finds { Courtside.team }
                        SiriResponse(.contains("Eastside Eagles"))
                    }
                }
            }
        ).run()
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(result.aggregateValue(.mean(of: .intentsAllPass))), 0.66)
    }
}
#endif
