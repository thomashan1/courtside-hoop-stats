import Testing
import Foundation
@testable import CourtsideHoopStats

/// Time on court, derived from the lineup history (#144).
///
/// This is arithmetic nobody can eyeball in the UI: a number that's quietly
/// 20% high still looks plausible in a box score, and the whole feature exists
/// to answer "did my kid get a fair run?" — so it either measures correctly or
/// it's worse than not shipping.
struct LineupTests {

    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private func ids(_ n: Int) -> [UUID] { (0..<n).map { _ in UUID() } }

    /// One period, one lineup, no changes: everyone on the floor gets the
    /// whole period and nobody else gets anything.
    @Test func aSingleLineupAccruesTheWholePeriod() {
        let players = ids(6)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.lineupChanges = [LineupChange(period: 1, timestamp: start,
                                           onCourt: Array(players.prefix(5)))]
        game.periodEndTimes = [1: start.addingTimeInterval(600)]
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0)]

        let time = game.timeOnCourt(now: start.addingTimeInterval(600))

        for player in players.prefix(5) {
            #expect(time[player] == 600)
        }
        #expect(time[players[5]] == nil, "a player who never took the floor has no time")
    }

    /// A substitution splits the period between the two lineups.
    @Test func aSubstitutionSplitsTheTime() {
        let players = ids(6)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.lineupChanges = [
            LineupChange(period: 1, timestamp: start, onCourt: Array(players.prefix(5))),
            LineupChange(period: 1, timestamp: start.addingTimeInterval(200),
                         onCourt: Array(players.prefix(4)) + [players[5]]),
        ]
        game.periodEndTimes = [1: start.addingTimeInterval(600)]
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0)]

        let time = game.timeOnCourt(now: start.addingTimeInterval(600))

        #expect(time[players[0]] == 600, "never subbed, so the whole period")
        #expect(time[players[4]] == 200, "came off after 200s")
        #expect(time[players[5]] == 400, "came on for the remaining 400s")
    }

    /// The headline correctness claim: halftime is not court time.
    ///
    /// Q1 runs 600s, then a 900s break, then Q2 runs 600s. Only the 1200s of
    /// actual play may count — crediting the break to whoever finished Q1 is
    /// precisely the distortion that would make "who got a fair run?"
    /// unanswerable.
    @Test func theBreakBetweenPeriodsDoesNotCount() {
        let players = ids(5)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        let q2Start = start.addingTimeInterval(1500)   // 900s after Q1 ended
        game.lineupChanges = [
            LineupChange(period: 1, timestamp: start, onCourt: players),
            LineupChange(period: 2, timestamp: q2Start, onCourt: players),
        ]
        game.periodEndTimes = [1: start.addingTimeInterval(600),
                               2: start.addingTimeInterval(2100)]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            2: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
        ]

        let now = start.addingTimeInterval(2100)
        let time = game.timeOnCourt(now: now)

        #expect(time[players[0]] == 1200, "600s of Q1 + 600s of Q2, and none of the break")
        #expect(game.periodsPlayed(now: now)[players[0]] == [1, 2])
    }

    /// The same five carry into the next period without a fresh entry — the
    /// lineup is a running state, not a per-period declaration.
    @Test func aLineupCarriesIntoTheNextPeriod() {
        let players = ids(5)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.lineupChanges = [LineupChange(period: 1, timestamp: start, onCourt: players)]
        // Q2 has a basket but no substitution, so the Q1 five is still out.
        game.events = [GameEvent(playerID: players[0], type: .twoPoint, period: 2,
                                 timestamp: start.addingTimeInterval(700))]
        game.periodEndTimes = [1: start.addingTimeInterval(600),
                               2: start.addingTimeInterval(1000)]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            2: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 0),
        ]

        let now = start.addingTimeInterval(1000)

        // Q1: 600s. Q2 opens at its first basket (700) and ends at 1000: 300s.
        #expect(game.timeOnCourt(now: now)[players[0]] == 900)
        #expect(game.periodsPlayed(now: now)[players[0]] == [1, 2])
    }

    /// A game recorded before lineups existed reports nothing, not zeroes.
    @Test func aGameWithoutLineupsReportsNothing() {
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.events = [GameEvent(playerID: UUID(), type: .twoPoint, period: 1)]

        #expect(game.tracksLineup == false)
        #expect(game.timeOnCourt().isEmpty)
        #expect(game.periodsPlayed().isEmpty)
    }

    /// An in-progress period accrues up to now, so the deck can show a running
    /// count while the game is still being played.
    @Test func theCurrentPeriodAccruesUpToNow() {
        let players = ids(5)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.lineupChanges = [LineupChange(period: 1, timestamp: start, onCourt: players)]

        let time = game.timeOnCourt(now: start.addingTimeInterval(300))

        #expect(time[players[0]] == 300)
    }

    /// A game left unfinished must not keep running.
    ///
    /// Nothing marks a game as abandoned — only ending a period stops the
    /// clock — so a live period accruing straight to `now` credits everyone on
    /// the floor for every hour since. Opening yesterday's forgotten game
    /// showed 93,599 minutes, and it would have shipped looking like that.
    @Test func anAbandonedGameStopsAccruingInsteadOfRunningForever() {
        let players = ids(5)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.lineupChanges = [LineupChange(period: 1, timestamp: start, onCourt: players)]

        // Reopened two days later, nothing recorded since.
        let time = game.timeOnCourt(now: start.addingTimeInterval(2 * 24 * 3600))

        let minutes = (time[players[0]] ?? 0) / 60
        #expect(minutes < 60, "An abandoned period accrued \(minutes) minutes")
    }

    /// …while a game that *is* being scored keeps ticking. The stop above is
    /// keyed to the last thing recorded, not to wall-clock age, so a long
    /// scoring drought inside a live period must not freeze the clock.
    @Test func aLivePeriodKeepsTickingWhileItIsBeingScored() {
        let players = ids(5)
        var game = Game(opponent: "Test", periodFormat: .quarters)
        game.lineupChanges = [LineupChange(period: 1, timestamp: start, onCourt: players)]
        game.events = [
            GameEvent(playerID: players[0], type: .twoPoint, period: 1,
                      timestamp: start.addingTimeInterval(600)),
        ]

        // Five minutes after the last basket — a normal quiet spell.
        let time = game.timeOnCourt(now: start.addingTimeInterval(900))

        #expect(time[players[0]] == 900)
    }

    /// The demo game the screenshots and the PDF are built from has to add up:
    /// five players on the floor for every second of every period.
    @Test func theDemoGamesTimeAddsUp() {
        let team = DemoData.makeTeam()
        let game = DemoData.makeGames(team: team).first { $0.isComplete }!

        #expect(game.tracksLineup)
        let segments = game.lineupSegments()
        let played = segments.reduce(0) { $0 + $1.seconds }
        let total = game.timeOnCourt().values.reduce(0, +)

        #expect(segments.allSatisfy { $0.onCourt.count == 5 }, "five on the floor at all times")
        #expect(total == played * 5, "everyone's time should sum to five times the clock")
        #expect(game.stats(for: team.players).allSatisfy { $0.timeDisplay != nil })
    }
}
