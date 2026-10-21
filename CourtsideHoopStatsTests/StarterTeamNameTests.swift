import Testing
import Foundation
@testable import CourtsideHoopStats

/// A "My Test Team" someone scored with but never renamed becomes "My Team";
/// the untouched placeholder keeps the name every build recognises it by.
struct StarterTeamNameTests {
    @Test func aStarterWithPlayersIsRenamed() {
        var teams = [Team(name: Team.starterName, players: [Player(name: "Jake L", number: "7")])]
        let renamed = AppStore.renameUsedStarters(&teams, games: [])
        #expect(teams[0].name == "My Team")
        #expect(teams[0].players.map(\.name) == ["Jake L"])
        #expect(renamed == [teams[0].id])
    }

    @Test func aStarterWithOnlyGamesIsRenamed() {
        var teams = [Team(name: Team.starterName, players: [])]
        var game = Game(opponent: "Graham Bears")
        game.teamID = teams[0].id
        _ = AppStore.renameUsedStarters(&teams, games: [game])
        #expect(teams[0].name == "My Team")
    }

    @Test func anUntouchedStarterKeepsItsName() {
        var teams = [Team(name: Team.starterName, players: [])]
        var other = Game(opponent: "Graham Bears")
        other.teamID = UUID()
        let renamed = AppStore.renameUsedStarters(&teams, games: [other])
        #expect(teams[0].name == Team.starterName)
        #expect(renamed.isEmpty)
    }

    @Test func aRealNameIsLeftAlone() {
        var teams = [Team(name: "Swish Warriors", players: [Player(name: "Jake L", number: "7")])]
        _ = AppStore.renameUsedStarters(&teams, games: [])
        #expect(teams[0].name == "Swish Warriors")
    }
}
