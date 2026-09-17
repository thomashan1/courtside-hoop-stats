import Foundation
import CloudKit

/// Translates the app's Codable models to and from `CKRecord`s for CloudKit
/// sharing (#57).
///
/// Layout: one **`SharedTeam`** root record per shared team, plus one
/// **`SharedGame`** child record per game. A game's events, period scores, and
/// bench list ride *inside* its JSON payload rather than as separate records —
/// the data is tiny (a season is a few kilobytes), so re-uploading a whole game
/// on any edit is cheaper than normalizing every basket into its own record and
/// reconciling them.
///
/// Each `SharedGame` points at its team via a **parent reference**, so a single
/// `CKShare` placed on the team root shares every game along with it (CloudKit's
/// hierarchical sharing) and deleting the team cascades to its games.
///
/// This type is deliberately pure — it never touches the network, so the
/// mapping is exercised directly in unit tests (`CloudKitSchemaTests`).
enum CloudKitSchema {
    static let teamRecordType = "SharedTeam"
    static let gameRecordType = "SharedGame"

    enum Key {
        /// Human-readable team name, stored alongside the payload so a share
        /// can show a title without decoding the blob.
        static let name = "name"
        /// JSON-encoded model (`Team` or `Game`), the source of truth on fetch.
        static let payload = "payload"
        /// Reference from a game to its owning team record.
        static let team = "team"
        /// Events whose `EventType` did not exist in every shipped build, held
        /// **outside** `events` inside the same JSON payload. See
        /// `payload(for:)`.
        static let laterEvents = "laterEvents"
    }

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Record IDs

    static func teamRecordID(_ id: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "team-\(id.uuidString)", zoneID: zoneID)
    }

    static func gameRecordID(_ id: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "game-\(id.uuidString)", zoneID: zoneID)
    }

    // MARK: - Team

    /// Write a team's fields onto an existing record.
    ///
    /// Publishing **mutates a record fetched from the server** rather than
    /// replacing it, because CloudKit keeps system fields — crucially the
    /// `share` reference — on the record itself. Saving a freshly-built record
    /// over a shared one risks dropping that association and silently
    /// un-sharing the team.
    static func apply(_ team: Team, to record: CKRecord) {
        record[Key.name] = team.name as CKRecordValue
        if let data = try? encoder.encode(team) {
            record[Key.payload] = data as CKRecordValue
        }
    }

    static func record(for team: Team, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: teamRecordType,
                              recordID: teamRecordID(team.id, in: zoneID))
        apply(team, to: record)
        return record
    }

    static func team(from record: CKRecord) -> Team? {
        guard record.recordType == teamRecordType,
              let data = record[Key.payload] as? Data else { return nil }
        return try? decoder.decode(Team.self, from: data)
    }

    // MARK: - Game

    /// Event types that **every shipped build** can decode.
    ///
    /// The list is frozen history, not a preference: it's what `EventType`
    /// contained in the last release before `laterEvents` existed. Never add to
    /// it — a type added here would go straight into `events` and break exactly
    /// the builds this exists to protect.
    private static let typesEveryShippedBuildKnows: Set<EventType> = [
        .twoPoint, .threePoint, .ftMade, .ftMissed, .foul,
    ]

    /// The JSON a follower receives, with newer event types moved out of
    /// `events` into `laterEvents`.
    ///
    /// **Why this exists.** A `Game` crosses as one blob, and an older build's
    /// `GameEvent` decoder throws on an `EventType` it doesn't recognise —
    /// which fails the *whole* game, so `game(from:)` returns nil, the caller
    /// skips it, and the game silently disappears from that follower's list.
    /// Adding `rebound` (#174) would have done exactly that to everyone still
    /// on v1.6.
    ///
    /// The old build's `Game.init(from:)` reads a fixed set of keys and ignores
    /// the rest, so an unknown *top-level* key costs it nothing. Newer events
    /// therefore ride there: an old follower sees the game with its score
    /// intact and simply no rebounds, and a current one gets them merged back
    /// in `game(fromPayload:)`. Degrading beats vanishing.
    ///
    /// Rebounds are worth 0 points, so the score an old follower computes is
    /// still correct. **A future scoring event type could not be split out this
    /// way** without the old build showing a wrong total — it would need its
    /// own answer.
    static func payload(for game: Game) -> Data? {
        let later = game.events.filter { !typesEveryShippedBuildKnows.contains($0.type) }
        guard !later.isEmpty else { return try? encoder.encode(game) }

        var trimmed = game
        trimmed.events = game.events.filter { typesEveryShippedBuildKnows.contains($0.type) }

        guard let base = try? encoder.encode(trimmed),
              var object = try? JSONSerialization.jsonObject(with: base) as? [String: Any],
              let laterData = try? encoder.encode(later),
              let laterArray = try? JSONSerialization.jsonObject(with: laterData) as? [Any]
        else {
            // Worst case, publish without the newer events rather than not at
            // all: the game still reaches every follower, score intact.
            return try? encoder.encode(trimmed)
        }
        object[Key.laterEvents] = laterArray
        return (try? JSONSerialization.data(withJSONObject: object))
            ?? (try? encoder.encode(trimmed))
    }

    /// Rebuilds a game from `payload(for:)`, restoring `laterEvents` into
    /// `events` at their timestamp positions.
    ///
    /// Insertion preserves the existing array order rather than re-sorting the
    /// whole log: a manual reorder (`applyingReorderedLog`) can leave array
    /// order deliberately out of timestamp order, and re-sorting would undo it.
    static func game(fromPayload data: Data) -> Game? {
        guard var game = try? decoder.decode(Game.self, from: data) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let raw = object[Key.laterEvents],
              let laterData = try? JSONSerialization.data(withJSONObject: raw),
              let later = try? decoder.decode([GameEvent].self, from: laterData)
        else { return game }

        for event in later {
            let index = game.events.firstIndex { $0.timestamp > event.timestamp }
                ?? game.events.count
            game.events.insert(event, at: index)
        }
        return game
    }

    /// Write a game's fields (and its parent links) onto an existing record.
    /// See `apply(_:to:)` for why publishing mutates rather than replaces.
    static func apply(_ game: Game, teamID: UUID, in zoneID: CKRecordZone.ID, to record: CKRecord) {
        if let data = payload(for: game) {
            record[Key.payload] = data as CKRecordValue
        }

        // A parent reference makes the game share along with its team and
        // cascade-delete with it. CloudKit requires `record.parent` itself to
        // use `.none`; the explicit `team` field carries the `.deleteSelf`
        // cascade.
        let teamRecordID = teamRecordID(teamID, in: zoneID)
        record[Key.team] = CKRecord.Reference(recordID: teamRecordID, action: .deleteSelf)
        record.parent = CKRecord.Reference(recordID: teamRecordID, action: .none)
    }

    static func record(for game: Game, teamID: UUID, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: gameRecordType,
                              recordID: gameRecordID(game.id, in: zoneID))
        apply(game, teamID: teamID, in: zoneID, to: record)
        return record
    }

    static func game(from record: CKRecord) -> Game? {
        guard record.recordType == gameRecordType,
              let data = record[Key.payload] as? Data else { return nil }
        return game(fromPayload: data)
    }
}
