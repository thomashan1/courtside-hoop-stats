import Testing
import Foundation
@testable import CourtsideHoopStats

/// Decoding guards for games written by older builds.
///
/// `AppStore.load()` decodes saved games with `try?`, so a single missing key
/// doesn't surface as an error — it silently wipes every game the user has.
/// That makes "does a field added later survive being absent?" a data-loss
/// question, not a style one, and Swift's synthesized `Codable` does **not**
/// fall back to a property's default value for a missing key.
///
/// Each test here removes the keys a given release added and decodes what's
/// left, which is exactly what happens on the first launch after an update.
struct GameMigrationTests {

    /// Keys that did not exist in some shipped version of `Game`. Removing
    /// them reproduces a blob written before the field was introduced.
    private static let laterAdditions = [
        "lineupChanges",      // v1.7 — the on-court five (#144)
        "periodEndTimes",     // v1.7 — period boundaries for time on court
        "hasStarted",         // v1.5 — scheduled vs started
        "benchedPlayerIDs",
        "locationAddress",
        "notes",
        "teamID",
    ]

    private func strip(_ keys: [String], from game: Game) throws -> Data {
        let data = try JSONEncoder().encode(game)
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "game did not encode to an object"))
        }
        for key in keys { object.removeValue(forKey: key) }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private var finishedDemoGame: Game {
        DemoData.makeGames(team: DemoData.makeTeam()).first { $0.isComplete }!
    }

    /// The whole point: a v1.6 game must still load after updating.
    @Test func aGameSavedBeforeLineupsStillDecodes() throws {
        let original = finishedDemoGame
        let trimmed = try strip(["lineupChanges", "periodEndTimes"], from: original)

        let decoded = try JSONDecoder().decode(Game.self, from: trimmed)

        #expect(decoded.opponent == original.opponent)
        #expect(decoded.events.count == original.events.count)
        #expect(decoded.lineupChanges.isEmpty, "absent lineup should decode as none tracked")
        #expect(decoded.periodEndTimes.isEmpty)
    }

    /// Absence of a lineup has to read as "not tracked", never as "played 0:00"
    /// — otherwise every pre-v1.7 game reports a roster that never took the
    /// floor, which is worse than showing nothing.
    @Test func aGameWithoutLineupsReportsNoTimeRatherThanZero() throws {
        let decoded = try JSONDecoder().decode(
            Game.self, from: try strip(["lineupChanges", "periodEndTimes"], from: finishedDemoGame))

        #expect(decoded.tracksLineup == false)
        let stats = decoded.stats(for: DemoData.makeTeam().players)
        #expect(stats.allSatisfy { $0.timeDisplay == nil })
        #expect(decoded.timeOnCourt().isEmpty)
    }

    /// Every field added after 1.0, all absent at once — the worst case for
    /// someone who skipped several updates.
    @Test func aGameMissingEveryLaterFieldStillDecodes() throws {
        let trimmed = try strip(Self.laterAdditions, from: finishedDemoGame)

        let decoded = try JSONDecoder().decode(Game.self, from: trimmed)

        #expect(decoded.events.isEmpty == false)
        #expect(decoded.isStarted, "a game predating hasStarted counts as started")
    }

    /// The same question one level down: an event saved before assists existed.
    @Test func anEventSavedBeforeAssistsStillDecodes() throws {
        let event = GameEvent(playerID: UUID(), type: .twoPoint, period: 1)
        let data = try JSONEncoder().encode(event)
        var object = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        object.removeValue(forKey: "assistPlayerID")

        let decoded = try JSONDecoder().decode(
            GameEvent.self, from: try JSONSerialization.data(withJSONObject: object))

        #expect(decoded.assistPlayerID == nil)
        #expect(decoded.type == .twoPoint)
    }
}
