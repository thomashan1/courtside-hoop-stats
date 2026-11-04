import XCTest
import ActivityKit
@testable import CourtsideHoopStats

/// On an iPad the Live Activity (#260) works as on an iPhone: Live Scoring
/// asking for one puts the game on the Lock Screen. Run on the iPad Pro
/// 13-inch simulator; skipped on an iPhone (`LiveActivityUITests` covers
/// both), and on an iPadOS that has Live Activities off.
@MainActor
final class LiveActivityDeviceTests: XCTestCase {

    func testAnIPadStartsOne() async throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "iPad only")
        try XCTSkipUnless(ActivityAuthorizationInfo().areActivitiesEnabled,
                          "this iPadOS has Live Activities off, so the app correctly starts none")

        let team = DemoData.makeTeam()
        let live = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.lifecycle == .inProgress })
        func active() -> [Activity<GameActivityAttributes>] {
            Activity<GameActivityAttributes>.activities.filter { $0.activityState == .active }
        }
        for stale in active() { await stale.end(nil, dismissalPolicy: .immediate) }

        LiveActivityController.shared.begin(live, teams: [team])
        // Requests are queued, so give the one just made a moment to land.
        let started = expectation(description: "an activity for the game")
        Task {
            for _ in 0..<50 where !active().contains(where: { $0.attributes.gameID == live.id }) {
                try? await Task.sleep(for: .milliseconds(100))
            }
            if active().contains(where: { $0.attributes.gameID == live.id }) { started.fulfill() }
        }
        await fulfillment(of: [started], timeout: 8)

        for activity in active() { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
