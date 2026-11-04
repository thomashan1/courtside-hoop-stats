import Foundation

/// What Siri says back (#255) — kept apart from the intents so it's plain
/// data in, a sentence out, and the tests need no Siri at all.
enum SiriAnswers {
    /// The team's games that count: finished, newest first. One in progress
    /// has no final score yet, and a scheduled one has nothing at all.
    static func finishedGames(of team: Team, in games: [Game]) -> [Game] {
        games
            .filter { ($0.teamID ?? team.id) == team.id && $0.lifecycle == .complete }
            .sorted { $0.date > $1.date }
    }

    /// "Swish beat Lakeside 42–30 on Oct 18." The winner's score comes first,
    /// as people say it.
    static func lastGame(of team: Team, in games: [Game]) -> String {
        guard let game = finishedGames(of: team, in: games).first else {
            return "\(team.name) has no finished games yet."
        }
        let day = game.date.formatted(.dateTime.month(.abbreviated).day())
        let us = game.ourScore, them = game.opponentScore
        let high = max(us, them), low = min(us, them)
        let opponent = game.opponent.trimmingCharacters(in: .whitespaces)
        switch (game.result, opponent.isEmpty) {
        case (.win, false):  return "\(team.name) beat \(opponent) \(high)–\(low) on \(day)."
        case (.win, true):   return "\(team.name) won \(high)–\(low) on \(day)."
        case (.loss, false): return "\(team.name) lost to \(opponent) \(high)–\(low) on \(day)."
        case (.loss, true):  return "\(team.name) lost \(high)–\(low) on \(day)."
        case (.tie, false):  return "\(team.name) tied \(opponent) \(us)–\(them) on \(day)."
        case (.tie, true):   return "\(team.name) tied \(us)–\(them) on \(day)."
        }
    }

    /// "Swish is 7–2 across 9 finished games." The same record the Season
    /// Averages screen shows, and like it, only the games this tracker kept.
    static func record(of team: Team, in games: [Game]) -> String {
        let record = TeamRecord.record(from: finishedGames(of: team, in: games))
        guard record.gamesPlayed > 0 else {
            return "\(team.name) has no finished games yet."
        }
        let count = record.gamesPlayed == 1 ? "1 finished game" : "\(record.gamesPlayed) finished games"
        return "\(team.name) is \(record.display) across \(count)."
    }
}
