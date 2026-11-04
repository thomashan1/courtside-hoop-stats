import Testing
import Foundation
@testable import CourtsideHoopStats

/// The Live Activity's content (#260): a `Game` and its team, mapped to what
/// the Lock Screen and Dynamic Island show — which must be exactly what Live
/// Scoring's scoreboard shows — and the plan for an activity already running.
/// No ActivityKit here: both are pure.
struct LiveActivityTests {

    private let team = Team(name: "Swish Warriors", players: [
        Player(name: "Jake Lawson", number: "7"),
        Player(name: "Ava Mitchell", number: "4"),
        Player(name: "Nicholas Han", number: "77"),
    ])

    private var jake: UUID { team.players[0].id }
    private var ava: UUID { team.players[1].id }
    private var nicholas: UUID { team.players[2].id }

    private func game(_ format: PeriodFormat = .quarters, opponent: String = "Lakeside",
                      events: [GameEvent] = [], breaks: [Int: Int] = [:],
                      complete: Bool = false) -> Game {
        var game = Game(opponent: opponent, periodFormat: format, events: events,
                        isComplete: complete, hasStarted: true)
        game.teamID = team.id
        // Our side of a break is derived from events; only theirs matters here.
        for (period, opponentTotal) in breaks {
            game.periodEndScores[period] = PeriodEndScore(ourRunningTotal: 0,
                                                          opponentRunningTotal: opponentTotal)
        }
        return game
    }

    private func state(_ game: Game, team: Team? = nil) -> GameActivityState {
        GameActivityState(game: game, team: team ?? self.team)
    }

    // MARK: Score and period

    @Test func showsTheScoreboardsScoreAndPeriod() {
        let g = game(events: [
            GameEvent(playerID: jake, type: .threePoint, period: 1),
            GameEvent(playerID: ava, type: .twoPoint, period: 2),
            GameEvent(playerID: nicholas, type: .ftMade, period: 3),
        ], breaks: [1: 8, 2: 15])
        let s = state(g)

        #expect(s.ourName == "Swish Warriors")
        #expect(s.opponentName == "Lakeside")
        #expect(s.ourScore == g.ourScore)
        #expect(s.ourScore == 6)
        #expect(s.periodLabel == "Q3")
        #expect(s.status == "Q3")
        #expect(s.outcome == nil)
        #expect(!s.isFinal)
    }

    /// The opponent's total is typed at End Period, so mid-period it's the
    /// one from the last break — the scoreboard's number, and named as such.
    @Test func opponentIsAsOfTheLastBreak() {
        let s = state(game(breaks: [1: 8, 2: 15]))
        #expect(s.opponentScore == 15)
        #expect(s.opponentThrough == "Q2")
        #expect(s.opponentNote == "thru Q2")
    }

    @Test func beforeTheFirstBreakTheOpponentHasNothingToDate() {
        let s = state(game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 1)]))
        #expect(s.opponentScore == 0)
        #expect(s.opponentThrough == nil)
        #expect(s.periodLabel == "Q1")
    }

    @Test func fourthQuarter() {
        #expect(state(game(breaks: [1: 5, 2: 10, 3: 15])).periodLabel == "Q4")
    }

    @Test func halves() {
        let s = state(game(.halves, breaks: [1: 20]))
        #expect(s.periodLabel == "H2")
        #expect(s.opponentThrough == "H1")
    }

    /// Period 5 of a quarters game is overtime — `OT`, never `Q5`.
    @Test func overtimeIsOTNotQ5() {
        let s = state(game(breaks: [1: 10, 2: 20, 3: 30, 4: 40]))
        #expect(s.periodLabel == "OT")
        #expect(s.opponentThrough == "Q4")
    }

    @Test func doubleOvertime() {
        let s = state(game(breaks: [1: 10, 2: 20, 3: 30, 4: 40, 5: 44]))
        #expect(s.periodLabel == "2OT")
        #expect(s.opponentThrough == "OT")
        #expect(s.opponentScore == 44)
    }

    /// Pickup has no periods to show — not "Game", which is the label the
    /// rest of the app uses for its one running period.
    @Test func pickupShowsNoPeriod() {
        let s = state(game(.pickup, events: [GameEvent(playerID: jake, type: .twoPoint, period: 1)]))
        #expect(s.periodLabel == nil)
        #expect(s.status == "")
        #expect(s.opponentThrough == nil)
    }

    @Test func aGameWithNoOpponentNameSaysOpponent() {
        #expect(state(game(opponent: "")).opponentName == "Opponent")
        #expect(state(game(opponent: "   ")).opponentName == "Opponent")
    }

    // MARK: Final

    @Test func aFinishedWinSaysFinalAndW() {
        let g = game(events: [GameEvent(playerID: jake, type: .threePoint, period: 4)],
                     breaks: [1: 0, 2: 0, 3: 0, 4: 2], complete: true)
        let s = state(g)
        #expect(s.isFinal)
        #expect(s.outcome == .win)
        #expect(s.outcome?.letter == "W")
        #expect(s.status == "Final")
        #expect(s.opponentThrough == nil)
        #expect(s.lastBasket == nil)
    }

    /// A game that finished level in regulation (#201) mustn't claim
    /// overtime: on a finished game `currentPeriod` reads 5.
    @Test func aTieThatStoodIsFinalNotOvertime() {
        let g = game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 4)],
                     breaks: [1: 0, 2: 0, 3: 0, 4: 2], complete: true)
        let s = state(g)
        #expect(s.outcome == .tie)
        #expect(s.outcome?.letter == "T")
        #expect(s.periodLabel == nil)
        #expect(s.status == "Final")
    }

    @Test func aGameDecidedInOvertimeSaysSo() {
        let g = game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 5)],
                     breaks: [1: 0, 2: 0, 3: 0, 4: 0, 5: 4], complete: true)
        let s = state(g)
        #expect(s.outcome == .loss)
        #expect(s.outcome?.letter == "L")
        #expect(s.status == "Final/OT")
    }

    @Test func pickupFinal() {
        let g = game(.pickup, events: [GameEvent(playerID: jake, type: .twoPoint, period: 1)],
                     breaks: [1: 1], complete: true)
        #expect(state(g).status == "Final")
        #expect(state(g).outcome == .win)
    }

    // MARK: Last basket, first names only

    @Test func lastBasketIsAFirstName() {
        let g = game(events: [
            GameEvent(playerID: ava, type: .twoPoint, period: 1),
            GameEvent(playerID: jake, type: .threePoint, period: 1),
        ])
        #expect(state(g).lastBasket == "Jake +3")
    }

    /// Two Jakes get the same treatment as everywhere else that shortens
    /// names — a last initial — never the Roster's full name.
    @Test func firstNameCollisionAddsAnInitial() {
        var roster = team
        roster.players.append(Player(name: "Jake Moore", number: "12"))
        let g = game(events: [GameEvent(playerID: jake, type: .threePoint, period: 1)])
        let s = state(g, team: roster)
        #expect(s.lastBasket == "Jake L. +3")
        #expect(s.lastBasket?.contains("Lawson") == false)
    }

    /// A guest who recorded nothing isn't in the game, so they can't make a
    /// regular player's name longer.
    @Test func anAbsentGuestDoesNotCollide() {
        var roster = team
        roster.players.append(Player(name: "Jake Moore", number: "12", isGuest: true))
        let g = game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 1)])
        #expect(state(g, team: roster).lastBasket == "Jake +2")
    }

    @Test func reboundsAndMissesAreNotBaskets() {
        let g = game(events: [
            GameEvent(playerID: nicholas, type: .ftMade, period: 1),
            GameEvent(playerID: jake, type: .rebound, period: 1),
            GameEvent(playerID: ava, type: .ftMissed, period: 1),
        ])
        #expect(state(g).lastBasket == "Nicholas +1")
    }

    /// Score Log order, which is what a reorder changes — not timestamps.
    @Test func lastBasketFollowsAReorder() {
        let early = GameEvent(playerID: ava, type: .twoPoint, period: 1,
                              timestamp: Date(timeIntervalSince1970: 100))
        let late = GameEvent(playerID: jake, type: .threePoint, period: 1,
                             timestamp: Date(timeIntervalSince1970: 200))
        let g = game(events: [early, late])
        #expect(state(g).lastBasket == "Jake +3")

        let reordered = g.applyingReorderedLog([.event(late), .event(early)])
        #expect(state(reordered).lastBasket == "Ava +2")
    }

    @Test func deletingTheLastBasketUpdatesScoreAndBasket() {
        let three = GameEvent(playerID: jake, type: .threePoint, period: 1)
        var g = game(events: [GameEvent(playerID: ava, type: .twoPoint, period: 1), three])
        g.removeEvent(id: three.id)
        let s = state(g)
        #expect(s.ourScore == 2)
        #expect(s.lastBasket == "Ava +2")
    }

    /// Its scorer left the roster: no name to show, and an older basket
    /// shown as the latest would be wrong.
    @Test func aRemovedPlayersBasketShowsNoName() {
        let stranger = UUID()
        let g = game(events: [
            GameEvent(playerID: jake, type: .twoPoint, period: 1),
            GameEvent(playerID: stranger, type: .threePoint, period: 1),
        ])
        #expect(state(g).lastBasket == nil)
    }

    // MARK: Demo data

    /// The screenshot game: Northgate, partway through Q2.
    @Test func demoGameInProgress() throws {
        let team = DemoData.makeTeam()
        let live = try #require(DemoData.makeGames(team: team).first { $0.lifecycle == .inProgress })
        let s = GameActivityState(game: live, team: team)

        #expect(s.ourName == "Swish Warriors")
        #expect(s.opponentName == "Northgate Falcons")
        #expect(s.ourScore == live.ourScore)
        #expect(s.opponentScore == live.opponentScore)
        #expect(s.periodLabel == "Q2")
        #expect(s.opponentThrough == "Q1")
        #expect(s.lastBasket == "Jake +2")
        // The Roster's "Jake L." is a full name there; here it's a first name.
        #expect(team.players.contains { $0.name == "Jake L." })
    }

    @Test func demoOvertimeLossIsFinalOT() throws {
        let team = DemoData.makeTeam()
        let lost = try #require(DemoData.makeGames(team: team).first { $0.opponent == "Central Cyclones" })
        let s = GameActivityState(game: lost, team: team)
        #expect(s.status == "Final/OT")
        #expect(s.outcome == .loss)
        #expect(s.ourScore == 40)
        #expect(s.opponentScore == 46)
    }

    // MARK: Accessibility

    @Test func accessibilitySummaryReadsAsASentence() {
        let s = state(game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 2)],
                           breaks: [1: 4]))
        #expect(s.accessibilitySummary == "Swish Warriors 2, Lakeside 4, Q2, Lakeside as of Q1")
    }

    // MARK: Plan for a running activity

    @Test func planUpdatesALiveGameOnlyWhenItChanged() {
        let g = game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 1)])
        let showing = state(g)
        #expect(LiveActivityPlan.plan(gameID: g.id, showing: showing,
                                      games: [g], teams: [team]) == .keep)

        var scored = g
        scored.events.append(GameEvent(playerID: ava, type: .threePoint, period: 1))
        #expect(LiveActivityPlan.plan(gameID: g.id, showing: showing,
                                      games: [scored], teams: [team]) == .update(state(scored)))
    }

    @Test func planEndsAFinishedGameWithItsFinal() {
        let g = game(events: [GameEvent(playerID: jake, type: .twoPoint, period: 4)],
                     breaks: [1: 0, 2: 0, 3: 0, 4: 0], complete: true)
        let plan = LiveActivityPlan.plan(gameID: g.id, showing: nil, games: [g], teams: [team])
        #expect(plan == .endWithFinal(state(g)))
        if case .endWithFinal(let final) = plan { #expect(final.outcome == .win) }
    }

    @Test func planTakesDownADeletedOrMissingGameAtOnce() {
        let other = game()
        #expect(LiveActivityPlan.plan(gameID: UUID(), showing: nil,
                                      games: [other], teams: [team]) == .endNow)
        #expect(LiveActivityPlan.plan(gameID: UUID(), showing: nil,
                                      games: [], teams: [team]) == .endNow)
    }

    /// "Move Back to Scheduled" (#133): not live any more, and no final.
    @Test func planTakesDownAGameMovedBackToScheduled() {
        var g = game()
        g.hasStarted = false
        #expect(LiveActivityPlan.plan(gameID: g.id, showing: nil,
                                      games: [g], teams: [team]) == .endNow)
    }

    /// Reopened into overtime (#201): live again, so it's updated, not ended.
    @Test func planFollowsAGameReopenedIntoOvertime() {
        var g = game(breaks: [1: 0, 2: 0, 3: 0, 4: 0], complete: true)
        g.isComplete = false
        let plan = LiveActivityPlan.plan(gameID: g.id, showing: nil, games: [g], teams: [team])
        #expect(plan == .update(state(g)))
        #expect(state(g).periodLabel == "OT")
    }

    @Test func planUsesTheGamesOwnTeam() {
        let other = Team(name: "Eastside Eagles", players: [])
        var g = game()
        g.teamID = other.id
        guard case .update(let s) = LiveActivityPlan.plan(gameID: g.id, showing: nil,
                                                          games: [g], teams: [team, other])
        else { Issue.record("expected an update"); return }
        #expect(s.ourName == "Eastside Eagles")
    }

    // MARK: Link

    @Test func linkRoundTrips() {
        let id = UUID()
        let url = GameLink.url(for: id)
        #expect(url.absoluteString == "courtsidehoopstats://game/\(id.uuidString)")
        #expect(GameLink.gameID(from: url) == id)
    }

    @Test func linkIgnoresAnythingElse() {
        #expect(GameLink.gameID(from: URL(string: "https://example.com/game/\(UUID().uuidString)")!) == nil)
        #expect(GameLink.gameID(from: URL(string: "courtsidehoopstats://team/\(UUID().uuidString)")!) == nil)
        #expect(GameLink.gameID(from: URL(string: "courtsidehoopstats://game/not-a-uuid")!) == nil)
    }

    // MARK: Transient by design

    /// ActivityKit moves the state between the app and its extension as
    /// JSON. It's never saved, but it does have to survive that trip.
    @Test func stateRoundTripsThroughJSON() throws {
        let s = state(game(events: [GameEvent(playerID: jake, type: .threePoint, period: 2)],
                           breaks: [1: 9]))
        let decoded = try JSONDecoder().decode(GameActivityState.self,
                                               from: JSONEncoder().encode(s))
        #expect(decoded == s)
    }
}
