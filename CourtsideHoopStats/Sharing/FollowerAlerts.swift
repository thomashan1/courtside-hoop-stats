import Foundation

/// How often a follower wants to hear about a game (#57).
///
/// Notification fatigue is the failure mode here: a grandparent who gets pinged
/// on every basket mutes the app and then misses the final. Period ends are the
/// default because they're the natural beats of a game.
enum FollowerAlertCadence: String, Codable, CaseIterable, Identifiable {
    case everyScore
    case periodEnd
    case startAndFinal
    case off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyScore:    return "Every score"
        case .periodEnd:     return "Each period"
        case .startAndFinal: return "Start and final only"
        case .off:           return "Off"
        }
    }

    var detail: String {
        switch self {
        case .everyScore:    return "A notification for every basket. Busy, but nothing is missed."
        case .periodEnd:     return "Game start, the end of each quarter or half, and the final score."
        case .startAndFinal: return "Only when a game starts and when it ends."
        case .off:           return "No notifications. The Following tab still updates."
        }
    }
}

/// One notification to post about a followed team.
struct FollowerAlert: Equatable {
    /// Stable per event, so the same period end can't be announced twice if a
    /// fetch is repeated.
    let id: String
    let title: String
    let body: String
}

/// Works out what's worth telling a follower about, by comparing the snapshot
/// they last saw against the one just fetched.
///
/// Pure and synchronous on purpose: this is the part that decides whether
/// someone's phone buzzes, so it's worth being able to test exhaustively
/// without CloudKit, notification permission, or a device.
enum FollowerAlertBuilder {

    static func alerts(previous: FollowedTeam?,
                       current: FollowedTeam,
                       cadence: FollowerAlertCadence) -> [FollowerAlert] {
        guard cadence != .off else { return [] }

        // With nothing to compare against — a freshly accepted share, or a
        // reinstall — everything would look new. Announcing a season's worth of
        // finished games at once is the worst possible first impression.
        guard let previous else { return [] }

        var alerts: [FollowerAlert] = []
        let teamName = current.team.name

        // A whole season entered at once shouldn't fire a notification per
        // game, so several new fixtures collapse into one.
        let known = Set(previous.games.map(\.id))
        let newlyScheduled = current.games.filter {
            !known.contains($0.id) && $0.lifecycle == .scheduled
        }
        if newlyScheduled.count > 2 {
            alerts.append(FollowerAlert(
                // Derived from the game ids themselves, not a hash: Swift's
                // hashing is seeded per process, so a hashed id would differ
                // across launches and stack a duplicate notification.
                id: "scheduled-batch-" + newlyScheduled.map(\.id.uuidString).sorted().joined(separator: "-"),
                title: "\(teamName) — \(newlyScheduled.count) games scheduled",
                body: "Added to the schedule. Open Courtside to see them."
            ))
        } else {
            for game in newlyScheduled {
                alerts.append(FollowerAlert(
                    id: "scheduled-\(game.id)",
                    title: "\(teamName) — game scheduled",
                    body: [opponentPhrase(game), game.date.gameDayCompact]
                        .compactMap { $0 }.joined(separator: " · ")
                ))
            }
        }

        for game in current.games {
            let before = previous.games.first { $0.id == game.id }

            if isNewlyStarted(before: before, after: game) {
                alerts.append(FollowerAlert(
                    id: "start-\(game.id)",
                    title: "\(teamName) — game starting",
                    body: opponentPhrase(game).map { "Tip-off \($0). Follow along live." }
                        ?? "Follow along live."
                ))
            }

            if isNewlyComplete(before: before, after: game) {
                alerts.append(FollowerAlert(
                    id: "final-\(game.id)",
                    title: "Final: \(scoreLine(game, teamName: teamName))",
                    body: resultPhrase(game, teamName: teamName)
                ))
                // The final supersedes the period end that lands with it.
                continue
            }

            guard cadence == .periodEnd || cadence == .everyScore else { continue }

            if let period = newlyEndedPeriod(before: before, after: game) {
                alerts.append(FollowerAlert(
                    id: "period-\(game.id)-\(period)",
                    title: scoreLine(game, teamName: teamName),
                    body: "End of \(game.periodFormat.periodLabel(period))."
                ))
                continue
            }

            if cadence == .everyScore, let scorer = newestScorer(before: before, after: game) {
                alerts.append(FollowerAlert(
                    id: "score-\(game.id)-\(scorer.eventID)",
                    title: scoreLine(game, teamName: teamName),
                    body: scorer.summary
                ))
            }
        }

        return alerts
    }

    // MARK: - Change detection

    private static func isNewlyStarted(before: Game?, after: Game) -> Bool {
        after.lifecycle == .inProgress && before?.lifecycle != .inProgress
    }

    private static func isNewlyComplete(before: Game?, after: Game) -> Bool {
        after.lifecycle == .complete && before?.lifecycle != .complete
    }

    /// The highest period that gained an end-score since last time.
    private static func newlyEndedPeriod(before: Game?, after: Game) -> Int? {
        let known = Set(before?.periodEndScores.keys ?? [:].keys)
        return after.periodEndScores.keys.filter { !known.contains($0) }.max()
    }

    /// The most recent scoring event that wasn't there before.
    private static func newestScorer(before: Game?, after: Game) -> (eventID: UUID, summary: String)? {
        let seen = Set(before?.events.map(\.id) ?? [])
        guard let event = after.events.last(where: { !seen.contains($0.id) }),
              event.type.points > 0 else { return nil }
        return (event.id, event.type.scoreLogLabel)
    }

    // MARK: - Copy

    private static func opponentPhrase(_ game: Game) -> String? {
        game.opponent.isEmpty ? nil : "vs \(game.opponent)"
    }

    private static func scoreLine(_ game: Game, teamName: String) -> String {
        let opponent = game.opponent.isEmpty ? "Opponent" : game.opponent
        return "\(teamName) \(game.ourScore) – \(game.opponentScore) \(opponent)"
    }

    private static func resultPhrase(_ game: Game, teamName: String) -> String {
        switch game.result {
        case .win:  return "\(teamName) win."
        case .loss: return "\(teamName) lose."
        case .tie:  return "It's a tie."
        }
    }
}
