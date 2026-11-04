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
// - Two sets. Built-in phrases are graded on the reply only: Siri runs the
//   intent as an App Shortcut, which the framework doesn't record as a call
//   (every such run read "not called" while the reply was our exact text).
//   Natural wording, in no phrase list, is graded on the intent too.
// - Siri varies between runs, so these measure rather than gate: each set
//   wants most of its scenarios, not every one every time.
// - Found so far: "What was the score of the last game in Courtside" goes
//   to Siri's sports answers, not the app, so the tip leads with "Last game
//   score in Courtside"; and free wording never reaches our intents.

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
        // Then out of the way, as when someone asks from the lock screen:
        // with the Games list open, Siri answered by reading the screen.
        XCUIDevice.shared.press(.home)
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
    }

    /// The exact phrases in `CourtsideShortcuts`, graded on what Siri says.
    func testBuiltInPhrases() async throws {
        guard #available(iOS 27.3, *) else { throw XCTSkip("Siri Evaluations needs iOS 27.3") }
        let result = try await CourtsideSiriEvaluation(
            name: "Built-in phrases",
            dataset: SiriScenarioLoader {
                SiriScenario {
                    UserTurn("Last game score in Courtside") {
                        SiriResponse(.contains("Lakeside Lightning"))
                    }
                }
                // Still a phrase, but Siri has answered it as a sports
                // question in every run so far: kept to notice if that changes.
                SiriScenario {
                    UserTurn("What was the score of the last game in Courtside") {
                        SiriResponse(.contains("Lakeside Lightning"))
                    }
                }
                SiriScenario {
                    UserTurn("How did Eastside Eagles do in Courtside") {
                        SiriResponse(.contains("Northgate Falcons"))
                    }
                }
                SiriScenario {
                    UserTurn("Courtside record") {
                        SiriResponse(.contains("2–1–1"))
                    }
                }
                SiriScenario {
                    UserTurn("What's Eastside Eagles's record in Courtside") {
                        SiriResponse(.contains("1–0"))
                    }
                }
            }
        ).run()
        try report(result)
        XCTAssertGreaterThanOrEqual(result.aggregateValue(.mean(of: .siriResponseAllPass)), 0.6)
    }

    /// Wording in no phrase list: Siri has to choose our intent itself, so
    /// the call and the team it finds are graded as well as the reply.
    func testNaturalWording() async throws {
        guard #available(iOS 27.3, *) else { throw XCTSkip("Siri Evaluations needs iOS 27.3") }
        let result = try await CourtsideSiriEvaluation(
            name: "Natural wording",
            dataset: SiriScenarioLoader {
                SiriScenario {
                    UserTurn("What was the final score of our most recent game in Courtside") {
                        Calls { Courtside.lastGameScore }
                        SiriResponse(.contains("48"))
                    }
                }
                SiriScenario {
                    UserTurn("Use Courtside to tell me if the Eastside Eagles won last time") {
                        Calls { Courtside.lastGameScore }
                        Finds { Courtside.team }
                        SiriResponse(.contains("Northgate Falcons"))
                    }
                }
                SiriScenario {
                    UserTurn("Are we winning more than we're losing this season in Courtside") {
                        Calls { Courtside.teamRecord }
                        SiriResponse(.contains("2–1–1"))
                    }
                }
            }
        ).run()
        try report(result)
        // Known gap: Siri hasn't chosen our intents for free wording in any
        // run, even with full descriptions; it says it can't find the game.
        // Probably needs Apple Intelligence's App Intent schemas. Not strict,
        // so this goes quiet, not red, the day Siri starts passing.
        XCTExpectFailure("Siri doesn't choose Courtside's intents for free wording yet (#256)", strict: false)
        XCTAssertGreaterThanOrEqual(result.aggregateValue(.mean(of: .siriResponseAllPass)), 0.66)
    }
}
#endif
