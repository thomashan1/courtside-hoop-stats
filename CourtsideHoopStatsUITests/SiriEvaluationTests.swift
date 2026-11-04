#if canImport(SiriEvaluations)
import XCTest
import Evaluations
import SiriEvaluations

// Siri Evaluations (#256): scripted requests run through real Siri, checking
// which of the #255 intents it calls and what it says back.
// https://developer.apple.com/documentation/sirievaluations
//
// - Device only: the framework ships for iPhone, Mac and Vision Pro, not the
//   simulator, so this file compiles to nothing for a simulator build.
// - Needs iOS 27.3, Developer Mode, Settings ▸ Developer ▸ Enable UI
//   Automation, and Apple Intelligence on. Older systems skip.
// - Opt-in: skipped unless the run sets TEST_RUNNER_SIRI_EVALS=1, e.g.
//     TEST_RUNNER_SIRI_EVALS=1 xcodebuild test -destination 'id=<device>' \
//       -only-testing:CourtsideHoopStatsUITests/SiriEvaluationTests …
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
        // Opt-in only: each run drives real Siri for a minute or more and
        // replaces the TestFlight build on the device. xcodebuild hands the
        // runner any TEST_RUNNER_-prefixed variable without the prefix.
        guard ProcessInfo.processInfo.environment["SIRI_EVALS"] == "1" else {
            throw XCTSkip("Siri evaluations run only when asked: TEST_RUNNER_SIRI_EVALS=1 xcodebuild test …")
        }
        // Siri answers from the running app's store, so it must be the demo one.
        let app = XCUIApplication()
        app.launchArguments += ["-uiTestSeedDemo"]
        app.launch()
    }

    /// Prints the per-scenario grades and attaches the full result, transcripts
    /// included, so a failure says what Siri did rather than just a number.
    @available(iOS 27.3, *)
    private func report(_ result: EvaluationResult) throws {
        print(result.groupedSummary)
        let attachment = XCTAttachment(data: try result.jsonData(includeTranscripts: true),
                                       uniformTypeIdentifier: "public.json")
        attachment.name = "\(result.evaluationID).json"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertGreaterThanOrEqual(result.aggregateValue(.mean(of: .intentsAllPass)), 0.66)
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
                // Not one of the built-in phrases: Siri has to work it out.
                SiriScenario {
                    UserTurn("How did we do in our last game in Courtside") {
                        Calls { Courtside.lastGameScore }
                        SiriResponse(.contains("48"))
                    }
                }
                SiriScenario {
                    UserTurn("Did Eastside Eagles win their last game? Check Courtside") {
                        Calls { Courtside.lastGameScore }
                        Finds { Courtside.team }
                        SiriResponse(.contains("Northgate Falcons"))
                    }
                }
            }
        ).run()
        try report(result)
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
                // Not one of the built-in phrases.
                SiriScenario {
                    UserTurn("How many games have we won this season in Courtside") {
                        Calls { Courtside.teamRecord }
                        SiriResponse(.contains("2–1–1"))
                    }
                }
            }
        ).run()
        try report(result)
    }
}
#endif
