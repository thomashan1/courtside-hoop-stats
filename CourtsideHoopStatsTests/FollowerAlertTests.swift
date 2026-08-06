import Testing
import Foundation
@testable import CourtsideHoopStats

/// Tests for what a follower gets notified about (#57).
///
/// This is the logic that decides whether someone's phone buzzes, so it's worth
/// covering properly — the failure modes are silent (a missed final score) or
/// obnoxious (a season's worth of games announced at once), and neither shows
/// up in a build.
struct FollowerAlertTests {

    private let roster = [Player(name: "Nicholas Han", number: "77")]

    private func team(_ games: [Game]) -> FollowedTeam {
        FollowedTeam(team: Team(name: "Swish Warriors", players: roster),
                     games: games,
                     zoneName: "z", ownerName: "o", updatedAt: Date())
    }

    private func game(id: UUID = UUID(),
                      started: Bool = true,
                      complete: Bool = false,
                      events: [GameEvent] = [],
                      periodEnds: [Int: PeriodEndScore] = [:]) -> Game {
        var game = Game(opponent: "Hawks")
        game.id = id
        game.hasStarted = started
        game.isComplete = complete
        game.events = events
        game.periodEndScores = periodEnds
        return game
    }

    private func basket(_ type: EventType = .twoPoint, period: Int = 1) -> GameEvent {
        GameEvent(playerID: roster[0].id, type: type, period: period)
    }

    // MARK: - The first-fetch trap

    /// A freshly accepted share has nothing to compare against, so every game
    /// looks new. Announcing a whole season at once is the worst possible first
    /// impression — and the reason `previous` being nil means silence.
    @Test func firstFetchNeverNotifies() {
        let existing = team([game(complete: true), game(complete: true)])
        let alerts = FollowerAlertBuilder.alerts(previous: nil, current: existing,
                                                 cadence: .periodEnd)
        #expect(alerts.isEmpty)
    }

    // MARK: - Cadence

    @Test func offNeverNotifies() {
        let id = UUID()
        let before = team([game(id: id, started: false)])
        let after = team([game(id: id, started: true)])
        #expect(FollowerAlertBuilder.alerts(previous: before, current: after,
                                            cadence: .off).isEmpty)
    }

    @Test func startAndFinalIgnoresPeriodEnds() {
        let id = UUID()
        let before = team([game(id: id, events: [basket()])])
        let after = team([game(id: id, events: [basket()],
                               periodEnds: [1: PeriodEndScore(ourRunningTotal: 2,
                                                              opponentRunningTotal: 4)])])
        #expect(FollowerAlertBuilder.alerts(previous: before, current: after,
                                            cadence: .startAndFinal).isEmpty)
        #expect(FollowerAlertBuilder.alerts(previous: before, current: after,
                                            cadence: .periodEnd).count == 1)
    }

    @Test func everyScoreNotifiesOnABasketButPeriodEndDoesNot() {
        let id = UUID()
        let before = team([game(id: id)])
        let after = team([game(id: id, events: [basket(.threePoint)])])

        #expect(FollowerAlertBuilder.alerts(previous: before, current: after,
                                            cadence: .everyScore).count == 1)
        #expect(FollowerAlertBuilder.alerts(previous: before, current: after,
                                            cadence: .periodEnd).isEmpty)
    }

    // MARK: - Lifecycle events

    @Test func gameStartingIsAnnounced() throws {
        let id = UUID()
        let before = team([game(id: id, started: false)])
        let after = team([game(id: id, started: true)])

        let alerts = FollowerAlertBuilder.alerts(previous: before, current: after,
                                                 cadence: .periodEnd)
        let alert = try #require(alerts.first)
        #expect(alert.title.contains("game starting"))
        #expect(alert.id == "start-\(id)")
    }

    @Test func finalScoreIsAnnouncedWithTheResult() throws {
        let id = UUID()
        let ends = [1: PeriodEndScore(ourRunningTotal: 3, opponentRunningTotal: 2)]
        let before = team([game(id: id, events: [basket(.threePoint)], periodEnds: ends)])
        let after = team([game(id: id, complete: true,
                               events: [basket(.threePoint)], periodEnds: ends)])

        let alert = try #require(FollowerAlertBuilder.alerts(
            previous: before, current: after, cadence: .periodEnd).first)
        #expect(alert.title.hasPrefix("Final:"))
        #expect(alert.body.contains("win"))
    }

    /// A game usually ends *and* closes its last period in the same publish.
    /// Two notifications for one moment is noise, so the final wins.
    @Test func finalSupersedesTheClosingPeriodEnd() {
        let id = UUID()
        let before = team([game(id: id, events: [basket()])])
        let after = team([game(id: id, complete: true, events: [basket()],
                               periodEnds: [1: PeriodEndScore(ourRunningTotal: 2,
                                                              opponentRunningTotal: 0)])])

        let alerts = FollowerAlertBuilder.alerts(previous: before, current: after,
                                                 cadence: .periodEnd)
        #expect(alerts.count == 1)
        #expect(alerts[0].title.hasPrefix("Final:"))
    }

    @Test func periodEndCarriesTheRunningScore() throws {
        let id = UUID()
        let before = team([game(id: id, events: [basket(.threePoint)])])
        let after = team([game(id: id, events: [basket(.threePoint)],
                               periodEnds: [1: PeriodEndScore(ourRunningTotal: 3,
                                                              opponentRunningTotal: 5)])])

        let alert = try #require(FollowerAlertBuilder.alerts(
            previous: before, current: after, cadence: .periodEnd).first)
        #expect(alert.title.contains("3"))
        #expect(alert.title.contains("5"))
        #expect(alert.body.contains("End of"))
    }

    // MARK: - Not notifying

    @Test func nothingChangedMeansNoAlerts() {
        let id = UUID()
        let same = game(id: id, events: [basket()])
        #expect(FollowerAlertBuilder.alerts(previous: team([same]), current: team([same]),
                                            cadence: .everyScore).isEmpty)
    }

    /// A missed free throw changes the log but not the score, and isn't worth
    /// interrupting anyone for.
    @Test func aMissDoesNotNotify() {
        let id = UUID()
        let before = team([game(id: id)])
        let after = team([game(id: id, events: [basket(.ftMissed)])])
        #expect(FollowerAlertBuilder.alerts(previous: before, current: after,
                                            cadence: .everyScore).isEmpty)
    }

    /// Ids are derived from the event, so re-fetching the same state replaces
    /// the notification rather than stacking a duplicate.
    @Test func alertIdsAreStableAcrossRepeatedFetches() {
        let id = UUID()
        let before = team([game(id: id, events: [basket()])])
        let after = team([game(id: id, events: [basket()],
                               periodEnds: [1: PeriodEndScore(ourRunningTotal: 2,
                                                              opponentRunningTotal: 1)])])

        let first = FollowerAlertBuilder.alerts(previous: before, current: after, cadence: .periodEnd)
        let second = FollowerAlertBuilder.alerts(previous: before, current: after, cadence: .periodEnd)
        #expect(first == second)
        #expect(first.first?.id == "period-\(id)-1")
    }
}
