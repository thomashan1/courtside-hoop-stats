import ActivityKit
import Combine
import Foundation
import UIKit
import os

/// What should happen to a Live Activity, given the games as they now stand
/// (#260). Pure, so `LiveActivityTests` covers every case without ActivityKit.
enum LiveActivityPlan: Equatable {
    /// Already showing this; nothing to send.
    case keep
    /// Still being played: show `state`.
    case update(GameActivityState)
    /// Over: show the final score until the system takes it down.
    case endWithFinal(GameActivityState)
    /// Deleted, missing, or moved back to Scheduled: take it down now.
    case endNow

    static func plan(gameID: UUID, showing current: GameActivityState?,
                     games: [Game], teams: [Team]) -> LiveActivityPlan {
        guard let game = games.first(where: { $0.id == gameID }),
              let team = team(for: game, in: teams) else { return .endNow }
        let state = GameActivityState(game: game, team: team)
        switch game.lifecycle {
        case .scheduled:  return .endNow
        case .complete:   return .endWithFinal(state)
        case .inProgress: return state == current ? .keep : .update(state)
        }
    }

    /// The team a game was played by. Games are stamped with their team on
    /// load (#20), so the fallback is for a game somehow without one.
    static func team(for game: Game, in teams: [Team]) -> Team? {
        teams.first { $0.id == game.teamID } ?? teams.first
    }
}

/// Starts, updates and ends the Live Activity for the game being scored
/// (#260). Local updates only: no push token, no server.
///
/// - **Start:** Live Scoring opening a game in progress calls `begin`. One
///   activity per game, found again by `gameID`, so going back into the same
///   game reuses it. One game on the Lock Screen at a time: starting another
///   takes the previous one down, final score and all.
/// - **Update and end:** `follow(_:)` watches the store, so every path that
///   changes a game — a basket, an edit or delete in the Score Log, a
///   reorder, End Period, Finish, deleting the game, the owner's other device
///   (#229) — reaches the activity without each screen having to remember to.
///   A finished game's final stays up for the system's usual while; a deleted
///   game's activity goes at once, even if it was already showing a final.
/// - **Launch:** the store's first value is reconciled too, which ends
///   anything a killed app left behind for a game that's since finished, been
///   deleted, or isn't there.
///
/// Owner only by construction: a follower's games are `FollowedTeam`s, never
/// in `store.games`, and Live Scoring never opens one. iPhone only: on iPad
/// and Mac it does nothing at all (`REQUIREMENTS.md` §3.12).
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private typealias GameActivity = Activity<GameActivityAttributes>

    private let log = Logger(subsystem: "com.thomashan.CourtsideHoopStats", category: "LiveActivity")
    private var subscription: AnyCancellable?
    /// Requests go out one at a time, in order, so a quick +2 then +3 can't
    /// land as +3 then +2.
    private var queue: Task<Void, Never>?
    /// What each activity was last sent, so an unchanged state isn't re-sent
    /// on every unrelated store change.
    private var sent: [String: GameActivityState] = [:]
    /// Activities already told to end: `true` if taken down at once, `false`
    /// if left showing a final. Ending is asynchronous, so until it lands the
    /// activity still reads as active.
    private var ended: [String: Bool] = [:]
    /// Activities this launch started, in case `Activity.activities` hasn't
    /// caught up with a request made a moment ago — Live Scoring can ask
    /// twice as it appears, and that mustn't make two.
    private var requested: [GameActivity] = []

    /// The device can show one: an iPhone (not iPad, not Mac), with Live
    /// Activities allowed for the app in Settings.
    private var canStart: Bool {
        isPhone && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && !ProcessInfo.processInfo.isiOSAppOnMac
    }

    /// Everything still on screen: live, or ended with its final showing.
    private var onScreen: [GameActivity] {
        var all = GameActivity.activities
        for activity in requested where !all.contains(where: { $0.id == activity.id }) {
            all.append(activity)
        }
        return all.filter { $0.activityState != .dismissed && ended[$0.id] != true }
    }

    private func isLive(_ activity: GameActivity) -> Bool {
        (activity.activityState == .active || activity.activityState == .stale)
            && ended[activity.id] == nil
    }

    /// Keep every activity in step with `store` from now on, starting with
    /// whatever an earlier launch left behind.
    func follow(_ store: AppStore) {
        guard isPhone, subscription == nil else { return }
        // `@Published` emits the current value on subscribing, which is the
        // launch reconcile; after that, every change to a game or a team.
        subscription = store.$games.combineLatest(store.$teams)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] games, teams in
                MainActor.assumeIsolated {
                    self?.reconcile(games: games, teams: teams)
                }
            }
    }

    /// Live Scoring opened `game`: put it on the Lock Screen, or bring the
    /// one already there up to date.
    func begin(_ game: Game, teams: [Team]) {
        guard canStart, game.lifecycle == .inProgress,
              let team = LiveActivityPlan.team(for: game, in: teams) else { return }
        let state = GameActivityState(game: game, team: team)

        let activities = onScreen
        if let existing = activities.first(where: { isLive($0) && $0.attributes.gameID == game.id }) {
            send(state, to: existing)
            return
        }
        // One game on the Lock Screen: the one being scored now. That takes
        // down a final left from an earlier game — or from this one, reopened
        // into overtime.
        for other in activities { takeDown(other) }
        do {
            let activity = try GameActivity.request(
                attributes: GameActivityAttributes(gameID: game.id),
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil)
            sent[activity.id] = state
            requested.append(activity)
        } catch {
            // Turned off in Settings, or the system's limit reached. The game
            // scores the same either way, so there's nothing to tell anyone.
            log.debug("Live Activity not started: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Bring every activity on screen in line with `games`.
    func reconcile(games: [Game], teams: [Team]) {
        for activity in onScreen {
            let live = isLive(activity)
            let current = sent[activity.id] ?? activity.content.state
            switch LiveActivityPlan.plan(gameID: activity.attributes.gameID, showing: current,
                                         games: games, teams: teams) {
            case .keep:
                break
            case .update(let state):
                // A final for a game that's live again belongs to the past.
                if live { send(state, to: activity) } else { takeDown(activity) }
            case .endWithFinal(let state):
                if live { finish(activity, showing: state) }
            case .endNow:
                takeDown(activity)
            }
        }
    }

    // MARK: - Requests

    private func send(_ state: GameActivityState, to activity: GameActivity) {
        guard sent[activity.id] != state else { return }
        sent[activity.id] = state
        enqueue {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// End with the final score left up for the system's usual while.
    private func finish(_ activity: GameActivity, showing final: GameActivityState) {
        sent[activity.id] = nil
        ended[activity.id] = false
        enqueue {
            await activity.end(ActivityContent(state: final, staleDate: nil),
                               dismissalPolicy: .default)
        }
    }

    /// End and take it off the screen at once.
    private func takeDown(_ activity: GameActivity) {
        guard ended[activity.id] != true else { return }
        sent[activity.id] = nil
        ended[activity.id] = true
        requested.removeAll { $0.id == activity.id }
        let content = activity.content
        enqueue {
            await activity.end(content, dismissalPolicy: .immediate)
        }
    }

    private func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await work()
        }
    }
}
