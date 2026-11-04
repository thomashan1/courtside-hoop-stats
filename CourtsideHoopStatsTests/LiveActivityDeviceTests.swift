import XCTest
import ActivityKit
@testable import CourtsideHoopStats

/// On an iPad the Live Activity (#260) is a quiet no-op: Live Scoring asking
/// for one starts nothing, and nothing fails. Run on the iPad Pro 13-inch
/// simulator; skipped on an iPhone, where `LiveActivityUITests` covers the
/// real thing. Attaches what ActivityKit reports, which is what
/// `REQUIREMENTS.md` §3.12 records.
@MainActor
final class LiveActivityDeviceTests: XCTestCase {

    func testAnIPadStartsNothing() async throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "iPad only")

        let enabled = ActivityAuthorizationInfo().areActivitiesEnabled
        var report = "\(UIDevice.current.model) \(UIDevice.current.systemName) "
            + "\(UIDevice.current.systemVersion): areActivitiesEnabled = \(enabled)"
        // What ActivityKit itself would do if asked directly, bypassing the
        // app's iPhone-only gate — the fact §3.12 writes down.
        do {
            let probe = try Activity.request(
                attributes: GameActivityAttributes(gameID: UUID()),
                content: ActivityContent(state: GameActivityState(
                    ourName: "Probe", opponentName: "Probe", ourScore: 0, opponentScore: 0,
                    periodLabel: nil, opponentThrough: nil, lastBasket: nil, outcome: nil),
                    staleDate: nil),
                pushType: nil)
            report += "; a direct request succeeded"
            await probe.end(nil, dismissalPolicy: .immediate)
        } catch {
            report += "; a direct request threw \(error)"
        }
        print("LiveActivityDeviceTests:", report)
        let attachment = XCTAttachment(string: report)
        attachment.name = "activitykit-on-ipad"
        attachment.lifetime = .keepAlways
        add(attachment)

        let team = DemoData.makeTeam()
        let live = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.lifecycle == .inProgress })
        func active() -> Int {
            Activity<GameActivityAttributes>.activities.filter { $0.activityState == .active }.count
        }
        let before = active()
        LiveActivityController.shared.begin(live, teams: [team])
        XCTAssertEqual(active(), before, "an iPad shouldn't start a Live Activity")
    }
}
