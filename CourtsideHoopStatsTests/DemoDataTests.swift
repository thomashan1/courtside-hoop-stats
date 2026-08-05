import Testing
import Foundation
@testable import CourtsideHoopStats

/// Consistency checks for the screenshot demo data.
///
/// These exist because seeded games have twice drifted into states the real app
/// can't produce — a period's recorded running total disagreeing with the sum
/// of its events, and a script indexing past the end of a shorter roster. Both
/// surface as a wrong or crashed screenshot rather than a test failure, which is
/// the slowest possible way to find out.
struct DemoDataTests {

    /// Every recorded period-end total must equal the cumulative points from
    /// events up to that period — otherwise the scoreboard and the linescore
    /// disagree in the screenshots.
    private func assertPeriodTotalsMatchEvents(_ game: Game, _ label: Comment) {
        var cumulative = 0
        for period in 1...game.periodFormat.periodCount {
            cumulative += game.events
                .filter { $0.period == period }
                .reduce(0) { $0 + $1.type.points }
            guard let recorded = game.periodEndScores[period] else { continue }
            #expect(recorded.ourRunningTotal == cumulative, label)
        }
    }

    private func assertEventsReferenceRoster(_ game: Game, roster: [Player], _ label: Comment) {
        let ids = Set(roster.map(\.id))
        #expect(game.events.allSatisfy { ids.contains($0.playerID) }, label)
    }

    // MARK: - Owner's own team

    @Test func demoGamesAreInternallyConsistent() {
        let team = DemoData.makeTeam()
        for game in DemoData.makeGames(team: team) {
            assertPeriodTotalsMatchEvents(game, "period totals vs events: \(game.opponent)")
            assertEventsReferenceRoster(game, roster: team.players, "roster ids: \(game.opponent)")
        }
    }

    // MARK: - Followed team (#57)

    @Test func followedTeamGamesAreInternallyConsistent() {
        let followed = DemoData.makeFollowedTeam()
        for game in followed.games {
            assertPeriodTotalsMatchEvents(game, "period totals vs events: \(game.opponent)")
            assertEventsReferenceRoster(game, roster: followed.team.players,
                                        "roster ids: \(game.opponent)")
        }
    }

    /// Screenshots should read as one consistent team across the whole app, and
    /// lean on Nicholas (#77) hitting threes as the standout.
    @Test func followedTeamUsesTheWarriorsAndFeaturesNicholas() {
        let followed = DemoData.makeFollowedTeam()
        #expect(followed.team.name == "Swish Warriors")

        let nicholas = followed.team.players.first { $0.number == "77" }
        let nicholasID = try? #require(nicholas?.id)

        for game in followed.games {
            let stats = game.stats(for: followed.team.players)
            let top = stats.first          // stats(for:) sorts by points descending
            #expect(top?.player.id == nicholasID, "Nicholas should lead \(game.opponent)")
            #expect((top?.threePointers ?? 0) >= 3,
                    "Nicholas should be hitting threes in \(game.opponent)")
        }
    }

    /// The live game is what a follower opens the app to watch, so one game must
    /// actually be in progress and one finished.
    @Test func followedTeamHasALiveGameAndAFinishedOne() {
        let followed = DemoData.makeFollowedTeam()
        #expect(followed.games.contains { $0.lifecycle == .inProgress })
        #expect(followed.games.contains { $0.lifecycle == .complete })
        #expect(followed.featuredGame?.lifecycle == .inProgress)
    }
}
