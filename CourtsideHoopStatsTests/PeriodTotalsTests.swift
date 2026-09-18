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
