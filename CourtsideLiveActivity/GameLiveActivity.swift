import ActivityKit
import SwiftUI
import WidgetKit

/// The extension's only widget: the game being scored, on the Lock Screen and
/// in the Dynamic Island (#260). The app drives it with local updates
/// (`LiveActivityController`); there is no push and no server. The views are
/// in `CourtsideShared/GameActivityViews.swift`.
@main
struct CourtsideLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        GameLiveActivity()
    }
}

struct GameLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: GameActivityAttributes.self) { context in
            GameActivityLockScreenView(state: context.state)
                // Solid navy whatever the appearance — the scoreboard banner.
                .activityBackgroundTint(Color.scoreboardBackground)
                .activitySystemActionForegroundColor(.white)
                .widgetURL(GameLink.url(for: context.attributes.gameID))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    GameActivityExpandedLeading(state: context.state)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    GameActivityExpandedTrailing(state: context.state)
                        .dynamicIsland(verticalPlacement: .belowIfTooWide)
                }
                DynamicIslandExpandedRegion(.center) {
                    GameActivityExpandedCenter(state: context.state)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    GameActivityExpandedBottom(state: context.state)
                }
            } compactLeading: {
                GameActivityCompactLeading(state: context.state)
            } compactTrailing: {
                GameActivityCompactTrailing(state: context.state)
            } minimal: {
                GameActivityMinimal(state: context.state)
            }
            .widgetURL(GameLink.url(for: context.attributes.gameID))
            .keylineTint(Color.scoreboardAccent)
        }
    }
}

#if DEBUG
private extension GameActivityState {
    static let midGame = GameActivityState(
        ourName: "Swish Warriors", opponentName: "Northgate Falcons",
        ourScore: 31, opponentScore: 27, periodLabel: "Q3",
        opponentThrough: "Q2", lastBasket: "Nicholas +3", outcome: nil)
    static let final = GameActivityState(
        ourName: "Swish Warriors", opponentName: "Northgate Falcons",
        ourScore: 48, opponentScore: 41, periodLabel: nil,
        opponentThrough: nil, lastBasket: nil, outcome: .win)
}

#Preview("Lock Screen", as: .content,
         using: GameActivityAttributes(gameID: UUID())) {
    GameLiveActivity()
} contentStates: {
    GameActivityState.midGame
    GameActivityState.final
}

#Preview("Expanded", as: .dynamicIsland(.expanded),
         using: GameActivityAttributes(gameID: UUID())) {
    GameLiveActivity()
} contentStates: {
    GameActivityState.midGame
}

#Preview("Compact", as: .dynamicIsland(.compact),
         using: GameActivityAttributes(gameID: UUID())) {
    GameLiveActivity()
} contentStates: {
    GameActivityState.midGame
}
#endif
