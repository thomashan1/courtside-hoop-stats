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
        /// The true period numbers of an overtime game, held **outside** the
        /// regulation-shaped `events`/`periodEndScores` an older build reads.
        /// See `payload(for:)`.
        static let laterPeriods = "laterPeriods"
    }

    /// The overtime detail an older build can't represent: the real period map,
    /// and the real period of any event that had to be folded back into
    /// regulation for the wire (#199).
    private struct OvertimeSidecar: Codable {
        /// Period number (as a string, since JSON object keys are strings) to
        /// that period's end score.
        var periodEndScores: [String: PeriodEndScore]
        /// Event id to its true period. Only carries events past regulation.
        var eventPeriods: [String: Int]
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
        let overtime = overtimeSidecar(for: game)
        guard !later.isEmpty || overtime != nil else { return try? encoder.encode(game) }

        var trimmed = game
        if !later.isEmpty {
            trimmed.events = game.events.filter { typesEveryShippedBuildKnows.contains($0.type) }
        }
        if overtime != nil {
            trimmed = foldingOvertimeIntoRegulation(trimmed, of: game)
        }

        guard let base = try? encoder.encode(trimmed),
              var object = try? JSONSerialization.jsonObject(with: base) as? [String: Any]
        else {
            // Worst case, publish without the newer detail rather than not at
            // all: the game still reaches every follower, score intact.
            return try? encoder.encode(trimmed)
        }

        if !later.isEmpty {
            guard let laterData = try? encoder.encode(later),
                  let laterArray = try? JSONSerialization.jsonObject(with: laterData) as? [Any]
            else { return try? encoder.encode(trimmed) }
            object[Key.laterEvents] = laterArray
        }
        if let overtime,
           let data = try? encoder.encode(overtime),
           let dictionary = try? JSONSerialization.jsonObject(with: data) {
            object[Key.laterPeriods] = dictionary
        }

        return (try? JSONSerialization.data(withJSONObject: object))
            ?? (try? encoder.encode(trimmed))
    }

    /// The overtime sidecar for a game that went past regulation, or nil for
    /// one that didn't.
    private static func overtimeSidecar(for game: Game) -> OvertimeSidecar? {
        let regulation = game.periodFormat.periodCount
        let highest = max(game.periodEndScores.keys.max() ?? 0,
                          game.events.map(\.period).max() ?? 0)
        guard game.periodFormat != .pickup, highest > regulation else { return nil }

        var periods: [String: PeriodEndScore] = [:]
        for (period, score) in game.periodEndScores { periods["\(period)"] = score }

        var eventPeriods: [String: Int] = [:]
        for event in game.events where event.period > regulation {
            eventPeriods[event.id.uuidString] = event.period
        }
        return OvertimeSidecar(periodEndScores: periods, eventPeriods: eventPeriods)
    }

    /// Reshapes an overtime game so a build that has never heard of overtime
    /// still reads it correctly (#199).
    ///
    /// An older `periodBreakdown()` loops `1...periodCount`, so overtime rows
    /// simply don't exist for it — while `ourScore`, summed from every event,
    /// does include the overtime baskets. Left alone, that build would show a
    /// linescore ending at 48–48 under a scoreboard reading 52–48.
    ///
    /// So the wire copy folds overtime into the last regulation period: its
    /// events move there, and that period's marker carries the **final**
    /// totals. An old follower sees exactly what a tracker sees when they keep
    /// scoring into Q4 rather than starting overtime — the workaround this
    /// feature replaces — with the score right and one fewer row. A current
    /// build puts the true periods back from the sidecar.
    private static func foldingOvertimeIntoRegulation(_ wire: Game, of game: Game) -> Game {
        let regulation = game.periodFormat.periodCount
        var folded = wire
        folded.events = wire.events.map { event in
            var copy = event
            copy.period = min(event.period, regulation)
            return copy
        }

        var scores = wire.periodEndScores.filter { $0.key <= regulation }
        if let lastPlayed = game.periodEndScores.keys.max(), lastPlayed > regulation,
           let finalScore = game.periodEndScores[lastPlayed] {
            scores[regulation] = finalScore
        }
        folded.periodEndScores = scores
        return folded
    }

    /// Rebuilds a game from `payload(for:)`, restoring `laterEvents` into
    /// `events` at their timestamp positions.
    ///
    /// Insertion preserves the existing array order rather than re-sorting the
    /// whole log: a manual reorder (`applyingReorderedLog`) can leave array
    /// order deliberately out of timestamp order, and re-sorting would undo it.
    static func game(fromPayload data: Data) -> Game? {
        guard var game = try? decoder.decode(Game.self, from: data) else { return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return game }
        game = restoringOvertime(game, from: object)

        guard let raw = object[Key.laterEvents],
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

    /// Puts an overtime game's real periods back, undoing the fold that
    /// `payload(for:)` applies for older builds (#199).
    private static func restoringOvertime(_ game: Game, from object: [String: Any]) -> Game {
        guard let raw = object[Key.laterPeriods],
              let data = try? JSONSerialization.data(withJSONObject: raw),
              let sidecar = try? decoder.decode(OvertimeSidecar.self, from: data)
        else { return game }

        var restored = game
        var periods: [Int: PeriodEndScore] = [:]
        for (key, score) in sidecar.periodEndScores {
            guard let period = Int(key) else { continue }
            periods[period] = score
        }
        if !periods.isEmpty { restored.periodEndScores = periods }

        for index in restored.events.indices {
            if let period = sidecar.eventPeriods[restored.events[index].id.uuidString] {
                restored.events[index].period = period
            }
        }
        return restored
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

    // MARK: - Backup (#177)

    /// Record types for the owner's **private backup**, distinct from the
    /// shared ones so a backup record can never be mistaken for a shared one
    /// (or vice versa) by a fetch that walks a zone.
    static let backupTeamRecordType = "BackupTeam"
    static let backupGameRecordType = "BackupGame"

    static func backupTeamRecordID(_ id: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "backup-team-\(id.uuidString)", zoneID: zoneID)
    }

    static func backupGameRecordID(_ id: UUID, in zoneID: CKRecordZone.ID) -> CKRecord.ID {
        CKRecord.ID(recordName: "backup-game-\(id.uuidString)", zoneID: zoneID)
    }

    /// A team as a backup record.
    ///
    /// **No parent reference and no share.** The sharing records use a parent
    /// to make a game travel with its team and cascade-delete with it; a
    /// backup must do the opposite and outlive whatever happens to the live
    /// copy, which is the whole reason sharing can't double as a backup.
    static func backupRecord(for team: Team, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: backupTeamRecordType,
                              recordID: backupTeamRecordID(team.id, in: zoneID))
        record[Key.name] = team.name as CKRecordValue
        if let data = try? encoder.encode(team) {
            record[Key.payload] = data as CKRecordValue
        }
        return record
    }

    static func backupRecord(for game: Game, in zoneID: CKRecordZone.ID) -> CKRecord {
        let record = CKRecord(recordType: backupGameRecordType,
                              recordID: backupGameRecordID(game.id, in: zoneID))
        // The same `laterEvents` split as the shared payload. Not strictly
        // required here — only this build reads its own backup — but a restore
        // onto an older build is exactly the situation where it matters.
        if let data = payload(for: game) {
            record[Key.payload] = data as CKRecordValue
        }
        return record
    }

    static func backupTeam(from record: CKRecord) -> Team? {
        guard record.recordType == backupTeamRecordType,
              let data = record[Key.payload] as? Data else { return nil }
        return try? decoder.decode(Team.self, from: data)
    }

    static func backupGame(from record: CKRecord) -> Game? {
        guard record.recordType == backupGameRecordType,
              let data = record[Key.payload] as? Data else { return nil }
        return game(fromPayload: data)
    }
}
