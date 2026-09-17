import Testing
import Foundation
@testable import CourtsideHoopStats

/// Blast-radius tests for loading saved data (#180).
///
/// `AppStore.load()` used to decode every game as one array, so a single
/// unreadable game threw for the whole thing, `try?` turned it into `nil`, and
/// the next `save()` wrote that emptiness over the file. Losing one game is
/// recoverable; losing a season is not.
struct StoreSalvageTests {

    /// A unique key per test, so nothing here touches the app's real defaults.
    private func scratchKey(_ name: String = #function) -> String {
        "chs.test.salvage.\(name).\(UUID().uuidString)"
    }

    private func games(_ count: Int) -> [Game] {
        (0..<count).map { Game(opponent: "Team \($0)") }
    }

    /// Corrupts one element of an encoded array, the way an unknown enum case
    /// or a removed field would.
    private func withOneBadElement<T: Encodable>(_ values: [T], at index: Int) throws -> Data {
        let data = try JSONEncoder().encode(values)
        var array = try #require(
            try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        array[index]["id"] = "not-a-uuid"
        return try JSONSerialization.data(withJSONObject: array)
    }

    // MARK: - Games

    @Test func everythingLoadsWhenNothingIsWrong() throws {
        let original = games(4)
        let data = try JSONEncoder().encode(original)
        let key = scratchKey()

        let loaded = AppStore.salvagingElements([Game].self, from: data, quarantinedAs: key)

        #expect(loaded.count == 4)
        #expect(loaded.map(\.opponent) == original.map(\.opponent))
        #expect(UserDefaults.standard.data(forKey: key) == nil,
                "a clean load must not quarantine anything")
    }

    /// The whole point: one bad game costs one game.
    @Test func oneUnreadableGameDoesNotTakeTheSeason() throws {
        let data = try withOneBadElement(games(5), at: 2)
        let key = scratchKey()
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let loaded = AppStore.salvagingElements([Game].self, from: data, quarantinedAs: key)

        #expect(loaded.count == 4, "four of five games should survive")
        #expect(!loaded.contains { $0.opponent == "Team 2" })
        // Before #180 this array was empty and the season was gone.
        #expect(!loaded.isEmpty)
    }

    /// The dropped record has to survive somewhere, or this is just a smaller
    /// kind of data loss.
    @Test func theOriginalBytesAreKeptWhenAnythingIsDropped() throws {
        let data = try withOneBadElement(games(3), at: 0)
        let key = scratchKey()
        defer { UserDefaults.standard.removeObject(forKey: key) }

        _ = AppStore.salvagingElements([Game].self, from: data, quarantinedAs: key)

        #expect(UserDefaults.standard.data(forKey: key) == data,
                "the unreadable game must still be recoverable")
    }

    @Test func dataThatIsNotEvenAnArrayIsKeptRatherThanDiscarded() throws {
        let data = Data("{\"not\":\"an array\"}".utf8)
        let key = scratchKey()
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let loaded = AppStore.salvagingElements([Game].self, from: data, quarantinedAs: key)

        #expect(loaded.isEmpty)
        #expect(UserDefaults.standard.data(forKey: key) == data)
    }

    // MARK: - Teams

    /// A team that won't decode takes its whole roster with it, so it gets the
    /// same treatment.
    @Test func oneUnreadableTeamDoesNotTakeTheOthers() throws {
        let teams = [
            Team(name: "Swish Warriors", players: [Player(name: "Nicholas H.", number: "77")]),
            Team(name: "Eastside Eagles", players: [Player(name: "Ava M.", number: "3")]),
        ]
        let state = TeamsState(teams: teams, activeTeamID: teams[0].id)
        let encoded = try JSONEncoder().encode(state)
        var object = try #require(
            try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        var rawTeams = try #require(object["teams"] as? [[String: Any]])
        rawTeams[1]["id"] = "not-a-uuid"
        object["teams"] = rawTeams
        let data = try JSONSerialization.data(withJSONObject: object)
        defer { UserDefaults.standard.removeObject(forKey: "chs.teams.unreadable.v1") }

        let salvaged = try #require(AppStore.salvagedTeamsState(from: data))

        #expect(salvaged.teams.count == 1)
        #expect(salvaged.teams[0].name == "Swish Warriors")
        #expect(salvaged.teams[0].players.count == 1, "the surviving roster is intact")
        #expect(salvaged.activeTeamID == teams[0].id)
    }

    @Test func anIntactTeamsBlobIsUnaffected() throws {
        let teams = [Team(name: "Swish Warriors", players: [])]
        let state = TeamsState(teams: teams, activeTeamID: teams[0].id)
        let data = try JSONEncoder().encode(state)

        let loaded = try #require(AppStore.salvagedTeamsState(from: data))

        #expect(loaded.teams.count == 1)
        #expect(loaded.activeTeamID == teams[0].id)
    }
}
