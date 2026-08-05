import Testing
import Foundation
@testable import CourtsideHoopStats

/// Tests for the follower-side snapshot model (#57).
struct FollowedTeamTests {

    private func makeFollowed(games: [Game]) -> FollowedTeam {
        FollowedTeam(team: Team(name: "Swish Warriors", players: []),
                     games: games,
                     zoneName: "team-abc",
                     ownerName: "_owner_",
                     updatedAt: Date())
    }

    private func game(daysAgo: Int, started: Bool, complete: Bool) -> Game {
        var game = Game(opponent: "Hawks")
        game.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        game.hasStarted = started
        game.isComplete = complete
        return game
    }

    @Test func gamesAreSortedNewestFirst() {
        let old = game(daysAgo: 10, started: true, complete: true)
        let recent = game(daysAgo: 1, started: true, complete: true)
        let middle = game(daysAgo: 5, started: true, complete: true)

        let followed = makeFollowed(games: [old, recent, middle])
        #expect(followed.sortedGames.map(\.id) == [recent.id, middle.id, old.id])
    }

    /// A follower opens the app mid-game to watch that game — so an in-progress
    /// game wins even when a completed one is more recent.
    @Test func featuredGamePrefersInProgressOverNewer() {
        let liveGame = game(daysAgo: 3, started: true, complete: false)
        let newerFinished = game(daysAgo: 1, started: true, complete: true)

        let followed = makeFollowed(games: [newerFinished, liveGame])
        #expect(followed.featuredGame?.id == liveGame.id)
    }

    @Test func featuredGameFallsBackToMostRecent() {
        let older = game(daysAgo: 9, started: true, complete: true)
        let newer = game(daysAgo: 2, started: true, complete: true)

        let followed = makeFollowed(games: [older, newer])
        #expect(followed.featuredGame?.id == newer.id)
    }

    @Test func featuredGameIsNilWithoutGames() {
        #expect(makeFollowed(games: []).featuredGame == nil)
    }

    /// Two people could share teams whose zones happen to share a name, so
    /// identity has to include the owner.
    @Test func identityCombinesOwnerAndZone() {
        let a = FollowedTeam(team: Team(name: "A", players: []), games: [],
                             zoneName: "team-1", ownerName: "owner-1", updatedAt: Date())
        let b = FollowedTeam(team: Team(name: "B", players: []), games: [],
                             zoneName: "team-1", ownerName: "owner-2", updatedAt: Date())
        #expect(a.id != b.id)
    }

    /// Followed teams are cached to UserDefaults so a follower with no signal
    /// still sees the last known score.
    @Test func survivesCodableRoundTrip() throws {
        var played = game(daysAgo: 1, started: true, complete: true)
        let scorer = UUID()
        played.events = [GameEvent(playerID: scorer, type: .threePoint, period: 1)]

        let followed = makeFollowed(games: [played])
        let data = try JSONEncoder().encode(followed)
        let decoded = try JSONDecoder().decode(FollowedTeam.self, from: data)

        #expect(decoded.id == followed.id)
        #expect(decoded.team.name == "Swish Warriors")
        #expect(decoded.games.count == 1)
        #expect(decoded.games[0].ourScore == 3)
    }
}
