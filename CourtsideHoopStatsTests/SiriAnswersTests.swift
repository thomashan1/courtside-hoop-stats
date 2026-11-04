import Testing
import Foundation
@testable import CourtsideHoopStats

/// What Siri says for the last game and the record (#255).
struct SiriAnswersTests {
    let swish = Team(name: "Swish", players: [])

    /// A finished game for `swish`; scores must be even (built from 2s).
    private func game(_ ours: Int, _ theirs: Int, vs opponent: String = "Lakeside",
                      on day: Int = 18, complete: Bool = true, team: UUID? = nil) -> Game {
        var game = Game(opponent: opponent)
        game.teamID = team ?? swish.id
        game.date = DateComponents(calendar: .current, year: 2026, month: 10, day: day).date!
        let scorer = UUID()
        for _ in 0..<(ours / 2) {
            game.events.append(GameEvent(playerID: scorer, type: .twoPoint, period: 1))
        }
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: ours, opponentRunningTotal: theirs)]
        game.isComplete = complete
        game.hasStarted = true
        return game
    }

    @Test func aWinNamesTheOpponentWithTheWinnersScoreFirst() {
        #expect(SiriAnswers.lastGame(of: swish, in: [game(42, 30)]) == "Swish beat Lakeside 42–30 on Oct 18.")
    }

    @Test func aLossStillPutsTheHigherScoreFirst() {
        #expect(SiriAnswers.lastGame(of: swish, in: [game(30, 42)]) == "Swish lost to Lakeside 42–30 on Oct 18.")
    }

    @Test func aTieAndAMissingOpponentReadNaturally() {
        #expect(SiriAnswers.lastGame(of: swish, in: [game(30, 30)]) == "Swish tied Lakeside 30–30 on Oct 18.")
        #expect(SiriAnswers.lastGame(of: swish, in: [game(42, 30, vs: " ")]) == "Swish won 42–30 on Oct 18.")
    }

    @Test func theLastGameIsTheNewestFinishedOneOfThatTeam() {
        let games = [
            game(20, 10, vs: "Older", on: 4),
            game(22, 12, vs: "Newest", on: 18),
            game(0, 0, vs: "In progress", on: 25, complete: false),
            game(40, 2, vs: "Other team", on: 26, team: UUID()),
        ]
        #expect(SiriAnswers.lastGame(of: swish, in: games) == "Swish beat Newest 22–12 on Oct 18.")
    }

    @Test func noFinishedGamesSaysSo() {
        let unfinished = [game(10, 8, complete: false)]
        #expect(SiriAnswers.lastGame(of: swish, in: unfinished) == "Swish has no finished games yet.")
        #expect(SiriAnswers.record(of: swish, in: unfinished) == "Swish has no finished games yet.")
    }

    @Test func theRecordCountsOnlyThisTeamsFinishedGames() {
        let games = [game(20, 10), game(10, 20), game(20, 10), game(10, 10),
                     game(20, 10, complete: false), game(20, 10, team: UUID())]
        #expect(SiriAnswers.record(of: swish, in: games) == "Swish is 2–1–1 across 4 finished games.")
        #expect(SiriAnswers.record(of: swish, in: [game(20, 10)]) == "Swish is 1–0 across 1 finished game.")
    }
}
