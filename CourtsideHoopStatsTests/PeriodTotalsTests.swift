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

/// Resuming a game that finished level, and the arithmetic that makes it
/// possible (#201).
struct ResumingIntoOvertimeTests {

    /// Four quarters, level at 38–38, finished.
    private func finishedLevel() -> Game {
        var game = Game(opponent: "Central")
        let scorer = UUID()
        game.events = [GameEvent(playerID: scorer, type: .twoPoint, period: 4)]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            2: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            3: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            4: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 2),
        ]
        game.isComplete = true
        return game
    }

    @Test func aFinishedLevelGameCanBeResumedIntoOvertime() {
        var game = finishedLevel()
        #expect(game.result == .tie)
        #expect(game.isInOvertime == false, "it's finished, not playing")

        // What the Score Log's divider does: clears completion and nothing else.
        game.isComplete = false

        #expect(game.currentPeriod == 5)
        #expect(game.isInOvertime)
        #expect(game.periodFormat.periodLabel(game.currentPeriod) == "OT")
        #expect(game.periodEndScores.count == 4, "the recorded periods stand")
        #expect(game.ourScore == 2, "and so does the score")
    }

    /// `currentPeriod` counts from the highest recorded period, not from how
    /// many there are. With a gap, counting them returns a period that already
    /// has a score — which ending the period would overwrite.
    @Test func currentPeriodComesFromTheHighestPeriodNotTheCount() {
        var game = Game(opponent: "Hawks")
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 4, opponentRunningTotal: 5),
            3: PeriodEndScore(ourRunningTotal: 9, opponentRunningTotal: 11),
        ]
        #expect(game.currentPeriod == 4, "counting entries would say 3, which is taken")
        #expect(game.periodEndScores[game.currentPeriod] == nil,
                "the current period must never already have a score")
    }

    @Test func aFinishedGameThatIsNotLevelStaysFinished() {
        var game = finishedLevel()
        game.periodEndScores[4] = PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 5)
        #expect(game.result == .loss)
        // The UI only offers overtime on a level game; this is the guard it reads.
        #expect(game.ourScore != game.opponentScore)
    }
}

/// What the scoreboard shows, which is not the same as what you'd score into
/// (#201).
struct DisplayPeriodTests {

    private func finished(_ format: PeriodFormat, periods: Int) -> Game {
        var game = Game(opponent: "Hawks")
        game.periodFormat = format
        for period in 1...periods {
            game.periodEndScores[period] = PeriodEndScore(ourRunningTotal: period,
                                                          opponentRunningTotal: period)
        }
        game.isComplete = true
        return game
    }

    @Test func aFinishedGameShowsItsLastPeriodNotTheNextOne() {
        let game = finished(.quarters, periods: 4)
        #expect(game.currentPeriod == 5, "scoring would go into period 5")
        #expect(game.displayPeriod == 4, "but the scoreboard says Q4")
        #expect(game.periodFormat.periodLabel(game.displayPeriod) == "Q4",
                "a finished game read OT before #201")
    }

    @Test func aFinishedOvertimeGameStillSaysOvertime() {
        let game = finished(.quarters, periods: 5)
        #expect(game.periodFormat.periodLabel(game.displayPeriod) == "OT")
    }

    @Test func aRunningGameShowsThePeriodBeingPlayed() {
        var game = finished(.quarters, periods: 2)
        game.isComplete = false
        #expect(game.displayPeriod == 3)
        #expect(game.periodFormat.periodLabel(game.displayPeriod) == "Q3")
    }

    @Test func aGameWithNothingRecordedShowsItsFirstPeriod() {
        var game = Game(opponent: "Hawks")
        game.isComplete = true
        #expect(game.displayPeriod == 1, "never zero, which has no label")
    }
}


/// Editing a game after it's finished (#209).
struct EditingAFinishedGameTests {

    private func finishedQuarters() -> Game {
        var game = Game(opponent: "Hawks")
        let scorer = UUID()
        for period in 1...4 {
            game.events.append(GameEvent(playerID: scorer, type: .twoPoint, period: period))
            game.periodEndScores[period] = PeriodEndScore(ourRunningTotal: period * 2,
                                                          opponentRunningTotal: period * 2)
        }
        game.isComplete = true
        return game
    }

    /// The reported bug: an event added while editing a finished game was
    /// tagged with `currentPeriod` — one *past* the last period played — so it
    /// landed in an overtime that never happened.
    @Test func anEventAddedToAFinishedGameLandsInTheLastPeriodPlayed() {
        var game = finishedQuarters()
        #expect(game.currentPeriod == 5, "there is no period 5; this is why it needs its own accessor")
        #expect(game.periodForNewEvent == 4)

        game.events.append(GameEvent(playerID: UUID(), type: .ftMissed,
                                     period: game.periodForNewEvent))

        #expect(game.events.map(\.period).max() == 4)
        #expect(game.periodBreakdownCumulative().count == 4,
                "a phantom overtime row would mean the linescore invented a period")
        #expect(game.periodFormat.periodLabel(game.periodForNewEvent) == "Q4",
                "the entry used to file itself under OT")
    }

    /// A game still being played is unaffected: new events go into the period
    /// being scored.
    @Test func aRunningGameStillRecordsIntoTheCurrentPeriod() {
        var game = finishedQuarters()
        game.isComplete = false
        game.periodEndScores[4] = nil
        #expect(game.periodForNewEvent == game.currentPeriod)
        #expect(game.periodForNewEvent == 4)
    }

    /// And a game genuinely in overtime records into overtime.
    @Test func anOvertimeGameRecordsIntoOvertime() {
        var game = finishedQuarters()
        game.isComplete = false          // resumed into overtime (#201)
        #expect(game.periodForNewEvent == 5)
        #expect(game.periodFormat.periodLabel(game.periodForNewEvent) == "OT")
    }

    /// Reordering a finished game's log must not resurrect completion state or
    /// lose the score — the drag in the report ended with an entry that
    /// wouldn't stay put.
    @Test func reorderingAFinishedGameKeepsItsScoreAndPeriods() {
        var game = finishedQuarters()
        game.events.append(GameEvent(playerID: UUID(), type: .ftMissed,
                                     period: game.periodForNewEvent))
        let before = game.ourScore

        var items = game.orderedLog()
        // Drag the FT miss to the front — "up to end of Q1". Found by id
        // rather than by position: the log ends with the Q4 *marker*, not the
        // last event, which is what makes `removeLast()` the wrong reach.
        let missID = try! #require(game.events.last { $0.type == .ftMissed }).id
        let index = try! #require(items.firstIndex { $0.id == "e-\(missID.uuidString)" })
        let moved = items.remove(at: index)
        items.insert(moved, at: 0)
        let reordered = game.applyingReorderedLog(items)

        #expect(reordered.ourScore == before, "an FT miss is worth nothing either way")
        #expect(reordered.events.first.map { $0.period } == 1, "it should now be in Q1")
        #expect(reordered.periodEndScores.keys.max() == 4, "and no period invented")
        #expect(reordered.isComplete, "reordering doesn't reopen the game")
    }
}
