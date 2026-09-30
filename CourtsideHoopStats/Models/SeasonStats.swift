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
