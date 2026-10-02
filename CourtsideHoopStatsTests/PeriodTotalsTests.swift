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

/// Overtime that was scored on into Q4 and the game finished, split back out
/// after the fact.
struct AddingOvertimeAfterTheFactTests {

    /// Q1–Q3 empty-ish, then Q4 holds regulation *and* overtime: we reach 10
    /// (the tie), then score 4 more in what was really overtime. The opponent
    /// finished on 12.
    private func scoredOnIntoQ4() -> Game {
        var game = Game(opponent: "Central")
        let a = UUID(), b = UUID()
        game.events = [
            GameEvent(playerID: a, type: .twoPoint, period: 1),     // 2
            GameEvent(playerID: a, type: .twoPoint, period: 3),     // 4
            GameEvent(playerID: b, type: .threePoint, period: 4),   // 7
            GameEvent(playerID: b, type: .threePoint, period: 4),   // 10  ← tie
            GameEvent(playerID: a, type: .ftMissed, period: 4),     // 10
            GameEvent(playerID: a, type: .twoPoint, period: 4),     // 12
            GameEvent(playerID: b, type: .twoPoint, period: 4),     // 14
        ]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 3),
            2: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 5),
            3: PeriodEndScore(ourRunningTotal: 4, opponentRunningTotal: 6),
            4: PeriodEndScore(ourRunningTotal: 14, opponentRunningTotal: 12),
        ]
        game.isComplete = true
        return game
    }

    private func error(_ result: Swift.Result<Game, Game.OvertimeSplitError>) -> Game.OvertimeSplitError? {
        if case .failure(let error) = result { return error }
        return nil
    }

    @Test func splitsAfterTheBasketThatReachedTheTie() throws {
        let original = scoredOnIntoQ4()
        let game = try original.addingOvertime(tiedAt: 10).get()

        #expect(game.events.map(\.period) == [1, 3, 4, 4, 5, 5, 5],
                "everything after the tying basket is overtime")
        #expect(game.periodEndScores[4]?.ourRunningTotal == 10)
        #expect(game.periodEndScores[4]?.opponentRunningTotal == 10, "a tie is one number")
        #expect(game.periodEndScores[5]?.ourRunningTotal == 14)
        #expect(game.periodEndScores[5]?.opponentRunningTotal == 12)
    }

    @Test func theFinalScoreAndResultDoNotChange() throws {
        let original = scoredOnIntoQ4()
        let game = try original.addingOvertime(tiedAt: 10).get()
        #expect(game.ourScore == original.ourScore)
        #expect(game.opponentScore == original.opponentScore)
        #expect(game.result == original.result)
        #expect(game.isComplete, "still finished — this corrects it, it doesn't reopen it")
        #expect(game.displayPeriod == 5)
        #expect(game.periodFormat.periodLabel(game.displayPeriod) == "OT")
    }

    @Test func theLinescoreGainsAnOvertimeColumn() throws {
        let game = try scoredOnIntoQ4().addingOvertime(tiedAt: 10).get()
        let breakdown = game.periodBreakdown()
        #expect(breakdown.count == 5)
        #expect(breakdown.last?.our == 4)
        #expect(breakdown.last?.opponent == 2)
    }

    @Test func rejectsAScoreWeNeverHad() {
        // We went 7 → 10 on a three; we were never on 9.
        #expect(error(scoredOnIntoQ4().addingOvertime(tiedAt: 9)) == (.neverReached))
    }

    @Test func rejectsAScoreAboveEitherFinal() {
        #expect(error(scoredOnIntoQ4().addingOvertime(tiedAt: 13)) == (.aboveFinal),
                "the opponent only finished on 12")
    }

    @Test func rejectsAScoreBelowTheOpponentsLastBreak() {
        // They had 6 after Q3, so regulation can't have ended level on 4.
        #expect(error(scoredOnIntoQ4().addingOvertime(tiedAt: 4))
                == (.belowPreviousBreak(opponentHad: 6)))
    }

    @Test func onlyAFinishedGameWithPeriods() {
        var live = scoredOnIntoQ4()
        live.isComplete = false
        #expect(error(live.addingOvertime(tiedAt: 10)) == (.notApplicable))

        var pickup = scoredOnIntoQ4()
        pickup.periodFormat = .pickup
        #expect(error(pickup.addingOvertime(tiedAt: 10)) == (.notApplicable))
    }

    /// We didn't score in overtime at all — they did. Regulation ended on our
    /// final total, and overtime is all theirs.
    @Test func overtimeWhereWeDidNotScore() throws {
        var game = scoredOnIntoQ4()
        game.events.removeLast(2)                       // we finish on 10
        game.periodEndScores[4] = PeriodEndScore(ourRunningTotal: 10, opponentRunningTotal: 14)
        let split = try game.addingOvertime(tiedAt: 10).get()
        // Only the missed free throw after the tie lands in overtime — the
        // split is at the basket that reached it, not past later zero-point
        // events, which the divider can be dragged across if that's wrong.
        #expect(split.events.filter { $0.period == 5 }.map(\.type) == [.ftMissed])
        #expect(split.periodEndScores[5]?.ourRunningTotal == 10)
        #expect(split.periodEndScores[5]?.opponentRunningTotal == 14)
        #expect(split.result == .loss)
    }

    /// A game that already went to one overtime can gain a second.
    @Test func aSecondOvertime() throws {
        let once = try scoredOnIntoQ4().addingOvertime(tiedAt: 10).get()
        // OT went 10 → 14 for us, 10 → 12 for them; say 2OT really began at 12.
        let twice = try once.addingOvertime(tiedAt: 12).get()
        #expect(twice.periodEndScores.keys.max() == 6)
        #expect(twice.periodFormat.periodLabel(6) == "2OT")
        #expect(twice.ourScore == 14)
    }

    @Test func halvesWork() throws {
        var game = scoredOnIntoQ4()
        game.periodFormat = .halves
        for i in game.events.indices { game.events[i].period = game.events[i].period <= 2 ? 1 : 2 }
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 5),
            2: PeriodEndScore(ourRunningTotal: 14, opponentRunningTotal: 12),
        ]
        let split = try game.addingOvertime(tiedAt: 10).get()
        #expect(split.periodEndScores.keys.max() == 3)
        #expect(split.periodFormat.periodLabel(3) == "OT")
    }

    /// Followers on an older build see overtime folded into Q4 — the same
    /// wire answer any overtime game gets — and a current build sees OT.
    @Test func crossesTheWireLikeAnyOvertimeGame() throws {
        let game = try scoredOnIntoQ4().addingOvertime(tiedAt: 10).get()
        let payload = try #require(CloudKitSchema.payload(for: game))
        let back = try #require(CloudKitSchema.game(fromPayload: payload))
        #expect(back.periodEndScores.keys.max() == 5)
        #expect(back.events.map(\.period) == game.events.map(\.period))
    }
}

/// An event added after the game and dragged into place keeps that place.
struct ReorderedLogOrderTests {

    /// Q2 has two baskets; a missed free throw entered later (so its timestamp
    /// is the newest in the game) has been dragged between them.
    private func gameWithLateEntryMovedIntoQ2() -> (Game, missed: UUID) {
        let a = UUID(), b = UUID()
        let start = Date(timeIntervalSince1970: 1_000)
        let first = GameEvent(playerID: a, type: .twoPoint, period: 2, timestamp: start)
        let second = GameEvent(playerID: b, type: .threePoint, period: 2,
                               timestamp: start.addingTimeInterval(60))
        let lateMiss = GameEvent(playerID: a, type: .ftMissed, period: 2,
                                 timestamp: start.addingTimeInterval(9_000))
        var game = Game(opponent: "Hawks")
        game.events = [first, lateMiss, second]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 0),
            2: PeriodEndScore(ourRunningTotal: 5, opponentRunningTotal: 4),
        ]
        return (game, lateMiss.id)
    }

    @Test func thePeriodKeepsTheDraggedOrderNotTheTimestampOrder() {
        let (game, missed) = gameWithLateEntryMovedIntoQ2()
        #expect(game.events(inPeriod: 2).map(\.id)[1] == missed)
    }

    @Test func thePrintedLogKeepsItToo() {
        let (game, missed) = gameWithLateEntryMovedIntoQ2()
        let printed = ScoreLogPaginator.rows(for: game).compactMap { row -> UUID? in
            if case .event(let event, _) = row { return event.id }
            return nil
        }
        #expect(printed[1] == missed, "the PDF follows the log, not the clock")
    }

    @Test func aReorderInTheEditorSurvivesTheRoundTrip() {
        // The path the bug took: entered at the end, dragged up in the editor.
        var (game, missed) = gameWithLateEntryMovedIntoQ2()
        game.events = [game.events[0], game.events[2], game.events[1]]   // miss last
        var items = game.orderedLog()
        let from = items.firstIndex { $0.id == "e-\(missed.uuidString)" }!
        let moved = items.remove(at: from)
        let firstBasket = items.firstIndex { if case .event(let e) = $0 { return e.period == 2 } else { return false } }!
        items.insert(moved, at: firstBasket + 1)

        let reordered = game.applyingReorderedLog(items)
        #expect(reordered.events(inPeriod: 2).map(\.id)[1] == missed)
    }
}
