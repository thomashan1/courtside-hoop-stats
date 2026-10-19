import Testing
import Foundation
@testable import CourtsideHoopStats

/// One team across several tournaments, told apart by each game's League.
@MainActor
struct TournamentTests {

    private func game(_ league: String, daysAgo: Double, teamID: UUID? = nil) -> Game {
        var game = Game(opponent: "Opponent")
        game.league = league
        game.teamID = teamID
        game.date = Date().addingTimeInterval(-daysAgo * 86_400)
        return game
    }

    @Test func newestTournamentFirstAndBlankLast() {
        let groups = Tournaments.groups([
            game("Summer League", daysAgo: 60),
            game("", daysAgo: 1),
            game("NJB Fall 15U", daysAgo: 3),
            game("Summer League", daysAgo: 50),
        ])
        #expect(groups.map(\.title) == ["NJB Fall 15U", "Summer League", "Other Games"])
        #expect(groups[1].games.count == 2)
    }

    /// A stray capital or space mustn't split a season in two.
    @Test func spellingsThatDifferOnlyInCaseAreOneTournament() {
        let groups = Tournaments.groups([
            game("NJB Fall 15U", daysAgo: 1),
            game("njb fall 15u ", daysAgo: 5),
        ])
        #expect(groups.count == 1)
        #expect(groups[0].title == "NJB Fall 15U")
    }

    @Test func renamingMergesAndOnlyTouchesTheActiveTeam() {
        let store = AppStore(inMemory: true)
        let other = UUID()
        store.games = [
            game("NJB Fall", daysAgo: 1, teamID: store.activeTeamID),
            game("NJB Fall 15U", daysAgo: 2, teamID: store.activeTeamID),
            game("", daysAgo: 3, teamID: store.activeTeamID),
            game("NJB Fall", daysAgo: 1, teamID: other),
        ]
        store.renameTournament("NJB Fall", to: " NJB Fall 15U ")
        store.renameTournament("", to: "Summer League")

        let mine = store.activeTeamGames.map(\.league)
        #expect(mine == ["NJB Fall 15U", "NJB Fall 15U", "Summer League"])
        #expect(store.games.last?.league == "NJB Fall", "another team's games are left alone")
    }

    /// One league is still shown by name; only a season with none stays plain.
    @Test func oneLeagueIsStillNamed() {
        #expect(Tournaments.named(Tournaments.groups([game("NJB Fall 15U", daysAgo: 1)])))
        #expect(!Tournaments.named(Tournaments.groups([game("", daysAgo: 1)])))
        #expect(!Tournaments.named([]))
    }
}
