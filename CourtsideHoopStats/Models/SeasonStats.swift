import Foundation

/// A player's season: their per-game averages across every completed game they
/// actually played (#211).
///
/// Pure aggregation — nothing new is recorded to produce this, which is what
/// makes it free courtside, unlike per-shot tracking (#175).
struct SeasonStats: Identifiable {
    let player: Player
    /// Games **played**: completed games where the player wasn't benched.
    /// Counting every game on the schedule would quietly deflate every average
    /// for anyone who missed a week — wrong in the direction people notice.
    var gamesPlayed: Int = 0

    var points: Int = 0
    var twoPointers: Int = 0
    var threePointers: Int = 0
    var assists: Int = 0
    var rebounds: Int = 0
    var ftMade: Int = 0
    var ftAttempts: Int = 0

    var id: UUID { player.id }

    private func average(_ total: Int) -> Double {
        gamesPlayed > 0 ? Double(total) / Double(gamesPlayed) : 0
    }

    var pointsPerGame: Double { average(points) }
    var twosPerGame: Double { average(twoPointers) }
    var threesPerGame: Double { average(threePointers) }
    var assistsPerGame: Double { average(assists) }
    var reboundsPerGame: Double { average(rebounds) }

    /// A season rate rather than an average — the standard way free throws are
    /// read, and the only number here that isn't per-game.
    var freeThrowPercent: Int? {
        guard ftAttempts > 0 else { return nil }
        return Int((Double(ftMade) / Double(ftAttempts) * 100).rounded())
    }
}

extension SeasonStats {

    /// Season lines for a roster across `games`, best scorer first.
    ///
    /// Only **completed** games count: a game in progress would drag every
    /// average down mid-way through, and a scheduled one has nothing in it.
    static func season(for roster: [Player], in games: [Game]) -> [SeasonStats] {
        var byPlayer: [UUID: SeasonStats] = [:]
        for player in roster { byPlayer[player.id] = SeasonStats(player: player) }

        for game in games where game.lifecycle == .complete {
            // `stats(for:)` applies benching itself and keeps anyone who
            // actually recorded something — the same rule the box score uses,
            // so a season line can't disagree with the games behind it (#59).
            for line in game.stats(for: roster) {
                guard var season = byPlayer[line.player.id] else { continue }
                season.gamesPlayed += 1
                season.points += line.points
                season.twoPointers += line.twoPointers
                season.threePointers += line.threePointers
                season.assists += line.assists
                season.rebounds += line.rebounds
                season.ftMade += line.ftMade
                season.ftAttempts += line.ftAttempts
                byPlayer[line.player.id] = season
            }
        }

        return byPlayer.values
            .filter { $0.gamesPlayed > 0 }
            .sorted {
                $0.pointsPerGame == $1.pointsPerGame
                    ? $0.player.name < $1.player.name
                    : $0.pointsPerGame > $1.pointsPerGame
            }
    }

    /// Whether a column is worth showing at all.
    ///
    /// Rebounds have barely been tracked since they proved too hard to catch
    /// live, and assists are optional by design. An average drawn from games
    /// where nothing was recorded reads as "he gets one a game" rather than
    /// "nobody was counting" — worse than leaving the column out, which is the
    /// same call #187 made for a single game's REB column.
    static func hasAny(_ value: (SeasonStats) -> Int, in season: [SeasonStats]) -> Bool {
        season.contains { value($0) > 0 }
    }
}


/// A team's record across the games it actually recorded (#213).
///
/// Deliberately **not** league standings: the app only knows the games this
/// tracker kept, so a missed game — or one somebody else tracked — leaves this
/// disagreeing with the league table. It says what it counted so the number
/// can't quietly pass for an official standing.
struct TeamRecord {
    var wins: Int = 0
    var losses: Int = 0
    var ties: Int = 0
    var pointsFor: Int = 0
    var pointsAgainst: Int = 0

    var gamesPlayed: Int { wins + losses + ties }

    /// Wins over games played, with a tie counting half — the usual convention,
    /// and the only one that puts a 1-0-1 team above a 1-1-0 one.
    var winPercent: Double {
        guard gamesPlayed > 0 else { return 0 }
        return (Double(wins) + Double(ties) / 2) / Double(gamesPlayed)
    }

    /// "63%", not the standings-page ".625" — a family reading this didn't
    /// know what ".625" under "PCT" meant.
    var winPercentDisplay: String {
        "\(Int((winPercent * 100).rounded()))%"
    }

    /// "7–2" or "7–2–1": the tie is only shown when there is one, since most
    /// records don't have any and a trailing "–0" reads as noise.
    var display: String {
        ties > 0 ? "\(wins)–\(losses)–\(ties)" : "\(wins)–\(losses)"
    }

    var pointsForPerGame: Double {
        gamesPlayed > 0 ? Double(pointsFor) / Double(gamesPlayed) : 0
    }

    var pointsAgainstPerGame: Double {
        gamesPlayed > 0 ? Double(pointsAgainst) / Double(gamesPlayed) : 0
    }

    /// The record across every **completed** game; one in progress has no
    /// result yet, and a scheduled one has nothing at all.
    static func record(from games: [Game]) -> TeamRecord {
        var record = TeamRecord()
        for game in games where game.lifecycle == .complete {
            switch game.result {
            case .win:  record.wins += 1
            case .loss: record.losses += 1
            case .tie:  record.ties += 1
            }
            record.pointsFor += game.ourScore
            record.pointsAgainst += game.opponentScore
        }
        return record
    }
}
