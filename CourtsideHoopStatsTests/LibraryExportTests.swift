import Testing
import Foundation
@testable import CourtsideHoopStats

/// Export Everything, and reading it back: the copy of the season that
/// doesn't depend on iCloud.
@MainActor
struct LibraryExportTests {

    private func season() -> (teams: [Team], games: [Game]) {
        let warriors = Team(name: "Swish Warriors", players: [Player(name: "Nicholas H", number: "77")])
        let eagles = Team(name: "Eastside Eagles", players: [Player(name: "Jake M", number: "7")])
        var lakeside = Game(opponent: "Lakeside Lightning")
        lakeside.teamID = warriors.id
        lakeside.events = [GameEvent(playerID: warriors.players[0].id, type: .twoPoint, period: 1)]
        var harbor = Game(opponent: "Harbor Sharks")
        harbor.teamID = eagles.id
        return ([warriors, eagles], [lakeside, harbor])
    }

    private func file(_ teams: [Team], _ games: [Game]) throws -> Data {
        try JSONEncoder().encode(LibraryExport(teams: teams, games: games))
    }

    @Test func aWipedPhoneGetsEverythingBack() throws {
        let original = season()
        let data = try file(original.teams, original.games)

        let wiped = AppStore(inMemory: true)
        let read = try #require(LibraryExport.read(data))
        let added = wiped.restore(teams: read.teams, games: read.games)

        #expect(added.teams == 2)
        #expect(added.games == 2)
        let lakeside = try #require(wiped.games.first { $0.opponent == "Lakeside Lightning" })
        #expect(lakeside.events.count == 1)
        #expect(lakeside.teamID == original.teams[0].id)
        #expect(wiped.teams.contains { $0.name == "Swish Warriors" && $0.players.count == 1 })
    }

    /// Importing never overwrites: the phone's copy of a game wins, so an
    /// old file can't roll back a game scored since.
    @Test func importingOnlyAddsWhatsMissing() throws {
        let original = season()
        let data = try file(original.teams, original.games)

        let store = AppStore(inMemory: true)
        var newer = original.games[0]
        newer.events.append(GameEvent(playerID: original.teams[0].players[0].id, type: .threePoint, period: 2))
        store.restore(teams: [original.teams[0]], games: [newer])

        let read = try #require(LibraryExport.read(data))
        let added = store.restore(teams: read.teams, games: read.games)

        #expect(added.teams == 1)
        #expect(added.games == 1)
        #expect(store.games.first { $0.id == newer.id }?.events.count == 2)

        // A second import adds nothing.
        let again = store.restore(teams: read.teams, games: read.games)
        #expect(again.teams == 0 && again.games == 0)
    }

    /// One unreadable game costs that game, not the file.
    @Test func anUnreadableGameIsSkippedNotTheFile() throws {
        let original = season()
        var object = try #require(
            JSONSerialization.jsonObject(with: try file(original.teams, original.games)) as? [String: Any])
        var games = try #require(object["games"] as? [Any])
        games.append(["id": "not-a-uuid", "events": 42])
        object["games"] = games

        let read = try #require(LibraryExport.read(try JSONSerialization.data(withJSONObject: object)))
        #expect(read.games.count == 2)
        #expect(read.teams.count == 2)
    }

    /// A single-team export (roster only) isn't mistaken for a library.
    @Test func aTeamExportIsNotALibrary() throws {
        let data = try JSONEncoder().encode(TeamExport(team: season().teams[0]))
        #expect(LibraryExport.read(data) == nil)
    }
}
