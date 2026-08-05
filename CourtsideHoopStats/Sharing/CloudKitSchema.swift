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

    /// Write a game's fields (and its parent links) onto an existing record.
    /// See `apply(_:to:)` for why publishing mutates rather than replaces.
    static func apply(_ game: Game, teamID: UUID, in zoneID: CKRecordZone.ID, to record: CKRecord) {
        if let data = try? encoder.encode(game) {
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
        return try? decoder.decode(Game.self, from: data)
    }
}
