import Testing
import Foundation
@testable import CourtsideHoopStats

/// Unit tests for the pure model logic in `Models.swift` (issue #14).
///
/// These have no UI dependencies — they exercise the app's real computation:
/// score derivation, period tracking, result, per-period breakdown, and the
/// per-player stat aggregation.
///
/// NOTE: these tests need a **unit test target** in the Xcode project. The cloud
/// session couldn't add one safely (editing the .pbxproj blind risks corrupting
/// the build), so on the Mac add a "Unit Testing Bundle" target named
/// `CourtsideHoopStatsTests` (File ▸ New ▸ Target… ▸ Unit Testing Bundle). With
/// the project's file-system-synchronized groups, this file is then picked up
/// automatically. (XCTest can be used instead of Swift Testing if preferred.)
struct ModelsTests {

    // MARK: - Helpers

    private func player(_ name: String, _ number: String = "0") -> Player {
        Player(name: name, number: number)
    }

    private func event(_ playerID: UUID, _ type: EventType, period: Int = 1) -> GameEvent {
        GameEvent(playerID: playerID, type: type, period: period)
    }

    // MARK: - EventType.points

    @Test func eventTypePoints() {
        #expect(EventType.twoPoint.points == 2)
        #expect(EventType.threePoint.points == 3)
        #expect(EventType.ftMade.points == 1)
        #expect(EventType.ftMissed.points == 0)
        #expect(EventType.foul.points == 0)
    }

    @Test func selectableExcludesFoul() {
        #expect(!EventType.selectable.contains(.foul))
        #expect(EventType.selectable.contains(.twoPoint))
        #expect(EventType.selectable.count == 4)
    }

    // MARK: - PeriodFormat

    @Test func periodFormatCountsAndLabels() {
        #expect(PeriodFormat.quarters.periodCount == 4)
        #expect(PeriodFormat.halves.periodCount == 2)
        #expect(PeriodFormat.quarters.periodLabel(3) == "Q3")
        #expect(PeriodFormat.halves.periodLabel(1) == "H1")
    }

    // MARK: - Game.ourScore

    @Test func ourScoreEmptyIsZero() {
        let game = Game(opponent: "Hawks")
        #expect(game.ourScore == 0)
    }

    @Test func ourScoreSumsEventPoints() {
        let p = player("Lucas")
        var game = Game(opponent: "Hawks")
        game.events = [
            event(p.id, .twoPoint),    // 2
            event(p.id, .threePoint),  // 3
            event(p.id, .ftMade),      // 1
            event(p.id, .ftMissed),    // 0
            event(p.id, .foul),        // 0
        ]
        #expect(game.ourScore == 6)
    }

    // MARK: - Game.opponentScore

    @Test func opponentScoreZeroWhenNoPeriodsRecorded() {
        let game = Game(opponent: "Hawks")
        #expect(game.opponentScore == 0)
    }

    @Test func opponentScoreIsHighestRecordedPeriodTotal() {
        var game = Game(opponent: "Hawks")
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 4, opponentRunningTotal: 5),
            2: PeriodEndScore(ourRunningTotal: 12, opponentRunningTotal: 9),
        ]
        #expect(game.opponentScore == 9)   // period 2 is the latest
    }

    // MARK: - Game.currentPeriod / isFinalPeriod

    @Test func currentPeriodStartsAtOne() {
        let game = Game(opponent: "Hawks")   // quarters, none recorded
        #expect(game.currentPeriod == 1)
        #expect(game.isFinalPeriod == false)
    }

    @Test func currentPeriodAdvancesWithRecordedPeriods() {
        var game = Game(opponent: "Hawks")
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 4, opponentRunningTotal: 5)]
        #expect(game.currentPeriod == 2)
    }

    @Test func currentPeriodCapsAtFormatCount() {
        var game = Game(opponent: "Hawks")   // 4 quarters
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 4, opponentRunningTotal: 5),
            2: PeriodEndScore(ourRunningTotal: 8, opponentRunningTotal: 9),
            3: PeriodEndScore(ourRunningTotal: 12, opponentRunningTotal: 14),
            4: PeriodEndScore(ourRunningTotal: 20, opponentRunningTotal: 18),
        ]
        #expect(game.currentPeriod == 4)     // capped, not 5
        #expect(game.isFinalPeriod == true)
    }

    @Test func isFinalPeriodForHalves() {
        var game = Game(opponent: "Hawks")
        game.periodFormat = .halves          // 2 halves
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 10, opponentRunningTotal: 8)]
        #expect(game.currentPeriod == 2)
        #expect(game.isFinalPeriod == true)
    }

    // MARK: - Game.result

    @Test func resultWinLossTie() {
        let p = player("Lucas")
        func game(ourPoints: Int, opp: Int) -> Game {
            var g = Game(opponent: "Hawks")
            g.events = (0..<ourPoints).map { _ in event(p.id, .ftMade) }  // 1 pt each
            g.periodEndScores = [1: PeriodEndScore(ourRunningTotal: ourPoints, opponentRunningTotal: opp)]
            return g
        }
        #expect(game(ourPoints: 10, opp: 8).result == .win)
        #expect(game(ourPoints: 6, opp: 9).result == .loss)
        #expect(game(ourPoints: 7, opp: 7).result == .tie)
    }

    // MARK: - Game.periodBreakdown

    @Test func periodBreakdownDeltas() {
        let p = player("Lucas")
        var game = Game(opponent: "Hawks")
        game.events = [
            event(p.id, .twoPoint, period: 1),    // Q1: 2
            event(p.id, .threePoint, period: 2),  // Q2: 3
            event(p.id, .twoPoint, period: 2),    // Q2: +2 = 5
        ]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 5),
            2: PeriodEndScore(ourRunningTotal: 7, opponentRunningTotal: 9),
        ]
        let rows = game.periodBreakdown()
        #expect(rows.count == 2)
        #expect(rows[0].period == 1)
        #expect(rows[0].our == 2)
        #expect(rows[0].opponent == 5)
        #expect(rows[1].period == 2)
        #expect(rows[1].our == 5)          // our delta from events, not stored total
        #expect(rows[1].opponent == 4)     // 9 - 5
    }

    @Test func periodBreakdownStopsAtFirstMissingPeriod() {
        var game = Game(opponent: "Hawks")
        // Only period 2 recorded, period 1 missing → breakdown stops immediately.
        game.periodEndScores = [2: PeriodEndScore(ourRunningTotal: 5, opponentRunningTotal: 6)]
        #expect(game.periodBreakdown().isEmpty)
    }

    // MARK: - Game.stats(for:)

    @Test func statsAggregatePerPlayer() {
        let lucas = player("Lucas", "10")
        let nick = player("Nicholas", "7")
        var game = Game(opponent: "Hawks")
        game.events = [
            event(lucas.id, .twoPoint),
            event(lucas.id, .threePoint),
            event(lucas.id, .ftMade),
            event(lucas.id, .ftMissed),
            event(lucas.id, .foul),
            event(nick.id, .twoPoint),
        ]
        let stats = game.stats(for: [lucas, nick])
        let lucasStats = try! #require(stats.first { $0.player.id == lucas.id })
        #expect(lucasStats.points == 6)          // 2 + 3 + 1
        #expect(lucasStats.twoPointers == 1)
        #expect(lucasStats.threePointers == 1)
        #expect(lucasStats.ftMade == 1)
        #expect(lucasStats.ftAttempts == 2)      // made + missed
        #expect(lucasStats.fouls == 1)
        #expect(lucasStats.freeThrowDisplay == "1/2")
    }

    @Test func statsSortedByPointsDescending() {
        let a = player("A")
        let b = player("B")
        var game = Game(opponent: "Hawks")
        game.events = [
            event(a.id, .twoPoint),                    // A: 2
            event(b.id, .threePoint),                  // B: 3
        ]
        let stats = game.stats(for: [a, b])
        #expect(stats.first?.player.id == b.id)        // higher scorer first
    }

    @Test func statsIncludePlayersWithNoEvents() {
        let a = player("A")
        let b = player("B")
        var game = Game(opponent: "Hawks")
        game.events = [event(a.id, .twoPoint)]
        let stats = game.stats(for: [a, b])
        #expect(stats.count == 2)
        let bStats = try! #require(stats.first { $0.player.id == b.id })
        #expect(bStats.points == 0)
    }

    @Test func statsIgnoreEventsForUnknownPlayers() {
        let known = player("Known")
        let ghostID = UUID()
        var game = Game(opponent: "Hawks")
        game.events = [
            event(known.id, .twoPoint),
            event(ghostID, .threePoint),   // player not in the roster passed in
        ]
        let stats = game.stats(for: [known])
        #expect(stats.count == 1)
        #expect(stats[0].points == 2)      // ghost's 3 is ignored
    }

    // MARK: - Lifecycle

    @Test func lifecycleReflectsState() {
        var scheduled = Game(opponent: "Hawks")
        scheduled.hasStarted = false
        #expect(scheduled.lifecycle == .scheduled)

        var inProgress = Game(opponent: "Hawks")
        inProgress.hasStarted = true
        #expect(inProgress.lifecycle == .inProgress)

        var complete = Game(opponent: "Hawks")
        complete.isComplete = true
        #expect(complete.lifecycle == .complete)

        // Legacy games (hasStarted nil) count as started.
        var legacy = Game(opponent: "Hawks")
        legacy.hasStarted = nil
        #expect(legacy.isStarted == true)
    }

    // MARK: - Reorderable score log (#9)

    /// A complete 2-half game: two events in H1, one in H2, both period markers.
    /// Uses `.halves` so the period cap (2) matches the two markers.
    private func twoPeriodGame() -> (Game, [UUID]) {
        let a = UUID(), b = UUID()
        var game = Game(opponent: "Hawks", periodFormat: .halves)
        game.events = [
            GameEvent(playerID: a, type: .twoPoint, period: 1),
            GameEvent(playerID: b, type: .threePoint, period: 1),
            GameEvent(playerID: a, type: .twoPoint, period: 2),
        ]
        game.periodEndScores = [
            1: PeriodEndScore(ourRunningTotal: 5, opponentRunningTotal: 8),
            2: PeriodEndScore(ourRunningTotal: 7, opponentRunningTotal: 15),
        ]
        return (game, [a, b])
    }

    @Test func orderedLogInterleavesEventsAndMarkers() {
        let (game, _) = twoPeriodGame()
        let log = game.orderedLog()
        // Q1 event, Q1 event, END Q1, Q2 event, END Q2
        #expect(log.count == 5)
        if case .periodEnd(let p) = log[2] { #expect(p == 1) } else { Issue.record("expected marker") }
        if case .periodEnd(let p) = log[4] { #expect(p == 2) } else { Issue.record("expected marker") }
    }

    @Test func reorderIdentityPreservesPeriods() {
        let (game, _) = twoPeriodGame()
        let same = game.applyingReorderedLog(game.orderedLog())
        #expect(same.events.map(\.period) == [1, 1, 2])
        #expect(same.periodEndScores[1]?.opponentRunningTotal == 8)
        #expect(same.periodEndScores[2]?.opponentRunningTotal == 15)
        // Our running totals recomputed: after Q1 = 2+3 = 5, after Q2 = +2 = 7.
        #expect(same.periodEndScores[1]?.ourRunningTotal == 5)
        #expect(same.periodEndScores[2]?.ourRunningTotal == 7)
    }

    @Test func draggingEventPastMarkerChangesItsPeriod() {
        let (game, _) = twoPeriodGame()
        var log = game.orderedLog()          // [e0, e1, END1, e2, END2]
        // Move the END-Q1 marker (index 2) up above e1 (index 1): now only e0 is Q1.
        let marker = log.remove(at: 2)
        log.insert(marker, at: 1)            // [e0, END1, e1, e2, END2]
        let result = game.applyingReorderedLog(log)
        // e0 → Q1; e1, e2 → Q2.
        #expect(result.events.map(\.period) == [1, 2, 2])
        // Our Q1 running total is now just e0's 2 points.
        #expect(result.periodEndScores[1]?.ourRunningTotal == 2)
        // Opponent totals ride with their markers unchanged.
        #expect(result.periodEndScores[1]?.opponentRunningTotal == 8)
        #expect(result.periodEndScores[2]?.opponentRunningTotal == 15)
    }

    @Test func reorderNeverInventsExtraPeriod() {
        let (game, _) = twoPeriodGame()
        var log = game.orderedLog()
        // Move an event below the final marker — it must clamp to the last period,
        // not become a phantom period 3.
        let last = log.remove(at: 3)         // the Q2 event
        log.append(last)                     // now after END Q2
        let result = game.applyingReorderedLog(log)
        #expect(result.events.map(\.period).allSatisfy { $0 <= 2 })
        #expect(result.periodEndScores.keys.allSatisfy { $0 <= 2 })
    }
}
