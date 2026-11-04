import Foundation

// Game → what the Live Activity shows (#260). Pure, so `LiveActivityTests`
// covers it without ActivityKit; everything is derived from what's already
// stored, so no `Game` field was added for it.

extension GameActivityAttributes.ContentState {
    /// What the Lock Screen and Dynamic Island show for `game`: exactly what
    /// Live Scoring's scoreboard shows, no more current.
    ///
    /// - The opponent's score is the one typed at the last End Period, as on
    ///   the scoreboard; `opponentThrough` names that break.
    /// - The period comes from `PeriodFormat.periodLabel(_:)` — `Q3`, `H2`,
    ///   `OT`, `2OT` — never rebuilt here. A pickup game shows none.
    /// - A finished game says `Final`, or `Final/OT` only if it really went to
    ///   one: it reads `displayPeriod`, not `currentPeriod`, which on a
    ///   finished game names the period that *would* come next (#201).
    /// - The last basket uses `PlayerDisplayName` over the players in this
    ///   game, so it's `Jake`, or `Jake L.` beside another Jake — never the
    ///   Roster's full name.
    init(game: Game, team: Team) {
        let format = game.periodFormat
        let ourName = team.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let opponentName = game.opponent.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(ourName: ourName.isEmpty ? "Us" : ourName,
                  opponentName: opponentName.isEmpty ? "Opponent" : opponentName,
                  ourScore: game.ourScore,
                  opponentScore: game.opponentScore,
                  periodLabel: nil, opponentThrough: nil, lastBasket: nil, outcome: nil)

        if game.isComplete {
            outcome = switch game.result {
            case .win:  .win
            case .loss: .loss
            case .tie:  .tie
            }
            if format.isOvertime(game.displayPeriod) {
                periodLabel = format.periodLabel(game.displayPeriod)
            }
            return
        }

        if format != .pickup {
            periodLabel = format.periodLabel(game.currentPeriod)
            opponentThrough = game.periodEndScores.keys.max().map(format.periodLabel)
        }
        lastBasket = Self.lastBasket(in: game, roster: team.players)
    }

    /// `Jake +3` for the latest made basket in Score Log order, or nil if
    /// there isn't one — or if its scorer has left the roster, since an older
    /// basket shown as the latest would be wrong.
    static func lastBasket(in game: Game, roster: [Player]) -> String? {
        let made = game.orderedLog().reversed().lazy.compactMap { item -> GameEvent? in
            guard case .event(let event) = item, event.type.points > 0 else { return nil }
            return event
        }
        guard let event = made.first,
              let name = PlayerDisplayName.map(for: game.onTeam(roster))[event.playerID]
        else { return nil }
        return "\(name) +\(event.type.points)"
    }
}
