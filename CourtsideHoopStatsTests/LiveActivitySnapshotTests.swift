import XCTest
import SwiftUI
@testable import CourtsideHoopStats

/// Renders the Live Activity's views (#260) to PNGs for review: the Lock
/// Screen card, and the Dynamic Island compact, minimal and expanded, in light
/// and dark, from the demo game.
///
/// The views are the real ones (`CourtsideShared/GameActivityViews.swift`);
/// the island and card *around* them are drawn here at the system's sizes,
/// because the iPhone 14 Plus that takes the store screenshots has no Dynamic
/// Island to capture. `LiveActivityUITests` captures the real Lock Screen.
///
/// Every image is attached to the result bundle. Set
/// `TEST_RUNNER_LIVE_ACTIVITY_SNAPSHOT_DIR` to also write them to a folder.
@MainActor
final class LiveActivitySnapshotTests: XCTestCase {

    private func demoState() throws -> GameActivityState {
        let team = DemoData.makeTeam()
        let live = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.lifecycle == .inProgress })
        return GameActivityState(game: live, team: team)
    }

    /// The demo game a few baskets on, into Q3, so the shots show a game
    /// that's going somewhere rather than a 9–9 opening.
    private func midGameState() throws -> GameActivityState {
        let team = DemoData.makeTeam()
        var live = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.lifecycle == .inProgress })
        let p = team.players
        let more: [(Int, EventType, Int)] = [
            (8, .threePoint, 2), (2, .twoPoint, 2), (7, .twoPoint, 2), (6, .ftMade, 2),
            (4, .twoPoint, 3), (8, .threePoint, 3),
        ]
        live.events += more.map { GameEvent(playerID: p[$0.0].id, type: $0.1, period: $0.2) }
        live.periodEndScores[2] = PeriodEndScore(ourRunningTotal: 17, opponentRunningTotal: 15)
        return GameActivityState(game: live, team: team)
    }

    private func finalState() throws -> GameActivityState {
        let team = DemoData.makeTeam()
        let won = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.opponent == "Lakeside Lightning" })
        return GameActivityState(game: won, team: team)
    }

    func testRendersEveryPresentation() throws {
        let live = try midGameState()
        let final = try finalState()
        XCTAssertEqual(try demoState().status, "Q2")
        XCTAssertEqual(live.status, "Q3")
        XCTAssertEqual(live.opponentThrough, "Q2")
        XCTAssertEqual(final.status, "Final")

        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try save(LockScreenFrame(scheme: scheme) {
                GameActivityLockScreenView(state: live)
            }, scheme: scheme, "live-activity-lock-screen-\(suffix)")
            try save(LockScreenFrame(scheme: scheme) {
                GameActivityLockScreenView(state: final)
            }, scheme: scheme, "live-activity-lock-screen-final-\(suffix)")
            try save(IslandCompactFrame(scheme: scheme, state: live),
                     scheme: scheme, "live-activity-island-compact-\(suffix)")
            try save(IslandMinimalFrame(scheme: scheme, state: live),
                     scheme: scheme, "live-activity-island-minimal-\(suffix)")
            try save(IslandExpandedFrame(scheme: scheme, state: live),
                     scheme: scheme, "live-activity-island-expanded-\(suffix)")
        }
        // The card can't grow, so the largest text it allows has to fit.
        try save(LockScreenFrame(scheme: .light) {
            GameActivityLockScreenView(state: live)
        }
        .dynamicTypeSize(.accessibility5), scheme: .light, "live-activity-lock-screen-largest-text")
    }

    // MARK: - Output

    private func save(_ view: some View, scheme: ColorScheme, _ name: String) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme))
        renderer.scale = 3
        let png = try XCTUnwrap(renderer.uiImage?.pngData(), "\(name) didn't render")
        let size = try XCTUnwrap(renderer.uiImage?.size)
        XCTAssertGreaterThan(size.width, 100, name)
        XCTAssertGreaterThan(size.height, 30, name)

        let attachment = XCTAttachment(data: png, uniformTypeIdentifier: "public.png")
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)

        if let dir = ProcessInfo.processInfo.environment["LIVE_ACTIVITY_SNAPSHOT_DIR"], !dir.isEmpty {
            let folder = URL(fileURLWithPath: dir, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try png.write(to: folder.appendingPathComponent("\(name).png"))
        }
    }
}

// MARK: - System frames, drawn at the system's sizes

/// A strip of Lock Screen wallpaper with the activity card on it: 396pt wide
/// (a 6.7" iPhone less its margins), corner radius 24, navy as
/// `activityBackgroundTint` makes it.
private struct LockScreenFrame<Content: View>: View {
    let scheme: ColorScheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: 396)
            .background(Color.scoreboardBackground,
                        in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(16)
            .background(Wallpaper(scheme: scheme))
    }
}

private struct Wallpaper: View {
    let scheme: ColorScheme

    var body: some View {
        LinearGradient(colors: scheme == .dark
                       ? [Color(white: 0.10), Color(red: 0.10, green: 0.12, blue: 0.20)]
                       : [Color(red: 0.80, green: 0.86, blue: 0.95), Color(white: 0.95)],
                       startPoint: .top, endPoint: .bottom)
    }
}

/// The top of a screen with the island holding our compact views either side
/// of the camera.
private struct IslandCompactFrame: View {
    let scheme: ColorScheme
    let state: GameActivityState

    var body: some View {
        HStack(spacing: 0) {
            GameActivityCompactLeading(state: state)
                .padding(.leading, 14)
            Spacer(minLength: 126)   // the camera and sensors
            GameActivityCompactTrailing(state: state)
                .padding(.trailing, 16)
        }
        .frame(width: 252, height: 37)
        .background(.black, in: Capsule())
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 12)
        .frame(width: 393)
        .background(scheme == .dark ? Color.black : Color(white: 0.96))
    }
}

/// Minimal: ours is the small bubble, beside another app's activity.
private struct IslandMinimalFrame: View {
    let scheme: ColorScheme
    let state: GameActivityState

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(.black).frame(width: 160, height: 37)
            GameActivityMinimal(state: state)
                .padding(4)
                .frame(width: 37, height: 37)
                .background(.black, in: Circle())
        }
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 12)
        .frame(width: 393)
        .background(scheme == .dark ? Color.black : Color(white: 0.96))
    }
}

/// Expanded: leading and trailing beside the camera, centre under it, bottom
/// across — the order `DynamicIsland`'s regions take.
private struct IslandExpandedFrame: View {
    let scheme: ColorScheme
    let state: GameActivityState

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                GameActivityExpandedLeading(state: state)
                    .frame(width: 118)
                VStack(spacing: 6) {
                    Color.clear.frame(height: 26)   // the camera
                    GameActivityExpandedCenter(state: state)
                }
                .frame(maxWidth: .infinity)
                GameActivityExpandedTrailing(state: state)
                    .frame(width: 118)
            }
            GameActivityExpandedBottom(state: state)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(width: 371)
        .background(.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
        .environment(\.colorScheme, .dark)
        .padding(.vertical, 12)
        .frame(width: 393)
        .background(scheme == .dark ? Color.black : Color(white: 0.96))
    }
}
