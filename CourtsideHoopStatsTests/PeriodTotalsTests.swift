import Testing
import Foundation
@testable import CourtsideHoopStats

/// The Score Log's period header shows both the points scored *in* a period
/// and the score at the end of it (#183).
///
/// The cumulative figure has to be "through this period", not "everything
/// above this row" — a follower's log runs newest-period-first, so an
/// order-dependent sum would read backwards for exactly the people who can't
/// correct it.
struct PeriodTotalsTests {

    private func game(_ script: [(Int, EventType)]) -> Game {
        let player = UUID()
        var game = Game(opponent: "Hawks")
        game.events = script.map { GameEvent(playerID: player, type: $1, period: $0) }
        return game
    }

    /// Mirrors what the header computes, so the maths is pinned even though
    /// the view itself isn't unit-testable.
    private func cumulative(_ game: Game, through period: Int) -> Int {
        game.events.filter { $0.period <= period }.reduce(0) { $0 + $1.type.points }
    }

    private func inPeriod(_ game: Game, _ period: Int) -> Int {
        game.events.filter { $0.period == period }.reduce(0) { $0 + $1.type.points }
    }

    @Test func theCumulativeTotalAddsUpAcrossPeriods() {
        let g = game([
            (1, .twoPoint), (1, .threePoint),        // Q1: 5
            (2, .twoPoint), (2, .twoPoint),          // Q2: 4  → 9
            (3, .ftMade), (3, .threePoint),          // Q3: 4  → 13
        ])

        #expect(inPeriod(g, 1) == 5)
        #expect(cumulative(g, through: 1) == 5)
        #expect(inPeriod(g, 2) == 4)
        #expect(cumulative(g, through: 2) == 9)
        #expect(cumulative(g, through: 3) == 13)
        #expect(cumulative(g, through: 3) == g.ourScore,
                "the last period's total must equal the game score")
    }

    /// Rebounds and missed free throws are in the log but score nothing, so
    /// neither figure may move (#174).
    @Test func nonScoringEventsDoNotMoveEitherFigure() {
        let g = game([
            (1, .twoPoint), (1, .rebound), (1, .ftMissed), (1, .rebound),
        ])

        #expect(inPeriod(g, 1) == 2)
        #expect(cumulative(g, through: 1) == 2)
    }

    /// A period nobody scored in still shows the running total carried into
    /// it, rather than a misleading zero.
    @Test func aScorelessPeriodStillCarriesTheTotal() {
        let g = game([(1, .threePoint), (3, .twoPoint)])

        #expect(inPeriod(g, 2) == 0)
        #expect(cumulative(g, through: 2) == 3, "Q2 scoreless, but we're still on 3")
        #expect(cumulative(g, through: 3) == 5)
    }

    /// Order-independent, which is what makes it safe in the follower's
    /// reversed log.
    @Test func theTotalDoesNotDependOnEventOrder() {
        let forward = game([(1, .twoPoint), (2, .threePoint), (3, .ftMade)])
        var shuffled = forward
        shuffled.events.reverse()

        for period in 1...3 {
            #expect(cumulative(forward, through: period) == cumulative(shuffled, through: period))
        }
    }
}

/// Overtime: periods past the format's count (#199).
struct OvertimeTests {

    private func tiedAfterRegulation() -> Game {
        let scorer = UUID()
        var game = Game(opponent: "Central")
        game.events = [GameEvent(playerID: scorer, type: .twoPoint, period: 4)]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            2: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            3: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
        ]
        return game
    }

    @Test func periodsPastRegulationAreLabelledAsOvertime() {
        let quarters = PeriodFormat.quarters
        #expect(quarters.periodLabel(4) == "Q4")
        #expect(quarters.periodLabel(5) == "OT")
        #expect(quarters.periodLabel(6) == "2OT")
        #expect(quarters.periodLabel(7) == "3OT")

        // Halves run out after two, so overtime starts one period earlier.
        #expect(PeriodFormat.halves.periodLabel(2) == "H2")
        #expect(PeriodFormat.halves.periodLabel(3) == "OT")

        // A pickup game has no periods to run out of.
        #expect(PeriodFormat.pickup.periodLabel(5) == "Game")
        #expect(PeriodFormat.pickup.isOvertime(5) == false)
    }

    @Test func overtimeIsOfferedOnlyWhenLevelAfterRegulation() {
        // Q4, and the entered total ties our 2 points.
        let game = tiedAfterRegulation()
        #expect(game.currentPeriod == 4)
        #expect(game.endingPeriodAllowsOvertime(opponentTotal: 2))
        #expect(game.endingPeriodAllowsOvertime(opponentTotal: 3) == false,
                "not level, so the game is over")

        // Same score, but there are quarters left to play.
        var earlier = game
        earlier.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0)]
        #expect(earlier.endingPeriodAllowsOvertime(opponentTotal: 2) == false)
    }

    @Test func theLinescoreIncludesOvertimeRows() {
        var game = tiedAfterRegulation()
        game.periodEndScores[4] = PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 2)
        game.events.append(GameEvent(playerID: UUID(), type: .threePoint, period: 5))
        game.periodEndScores[5] = PeriodEndScore(ourRunningTotal: 5, opponentRunningTotal: 4)
        game.isComplete = true      // the overtime marker is in; the game is over

        let rows = game.periodBreakdownCumulative()
        #expect(rows.count == 5, "overtime used to be counted but never listed")
        #expect(rows.last?.our == game.ourScore)
        #expect(rows.last?.opponent == 4)
        #expect(game.isInOvertime == false, "the game is over, not still in overtime")

        // Deltas, not cumulative: overtime contributed 3 and 2.
        let deltas = game.periodBreakdown()
        #expect(deltas.last?.our == 3)
        #expect(deltas.last?.opponent == 2)
    }

    @Test func reorderingKeepsOvertimeRatherThanClampingItAway() {
        var game = tiedAfterRegulation()
        game.periodEndScores[4] = PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 2)
        game.events.append(GameEvent(playerID: UUID(), type: .twoPoint, period: 5))
        game.periodEndScores[5] = PeriodEndScore(ourRunningTotal: 4, opponentRunningTotal: 2)

        let reordered = game.applyingReorderedLog(game.orderedLog())
        #expect(reordered.periodEndScores.keys.max() == 5,
                "the clamp used to cap at the format's period count")
        #expect(reordered.events.map(\.period).max() == 5)
        #expect(reordered.ourScore == game.ourScore)
    }
}
