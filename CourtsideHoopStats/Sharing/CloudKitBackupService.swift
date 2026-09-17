import Foundation
import CloudKit

/// What the owner's Settings screen needs to say about the backup (#177).
struct BackupSnapshot: Equatable {
    /// When the last successful backup finished, or `nil` if there has never
    /// been one.
    var backedUpAt: Date?
    var teamCount: Int
    var gameCount: Int

    static let none = BackupSnapshot(backedUpAt: nil, teamCount: 0, gameCount: 0)
}

/// Seam so `AppStore` and the Settings UI never touch CloudKit types, matching
/// how `SharingService` is factored.
protocol BackupService: AnyObject {
    var isAvailable: Bool { get }
    /// Writes every team and game to the owner's private iCloud, returning the
    /// snapshot to show afterwards.
    func backUp(teams: [Team], games: [Game]) async throws -> BackupSnapshot
    /// Everything currently in the backup. Used both to restore and to report
    /// what's there without restoring.
    func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot)
}

/// Automatic backup of **all** teams and games to the owner's own private
/// CloudKit database (#177).
///
/// Deliberately separate from sharing, which is a *mirror*: unshare a team or
/// delete it and it vanishes for followers, so sharing can never be the
/// backup. This writes to its own zone with **no `CKShare` and no parent
/// references**, so nothing in the sharing code — `stopSharing`'s zone delete
/// or `deleteGamesNoLongerPresent` — can reach it.
///
/// **One record per game, not one blob.** The whole point is surviving a
/// corrupt record, and a single archive blob would have exactly the failure
/// mode this exists to protect against (#180 fixed the local version of it).
final class CloudKitBackupService: BackupService {
    private let container: CKContainer
    private var database: CKDatabase { container.privateCloudDatabase }

    /// Its own zone, never `team-<id>`: those get deleted when sharing stops.
    private let zoneID = CKRecordZone.ID(zoneName: "backup",
                                         ownerName: CKCurrentUserDefaultName)

    init(container: CKContainer = .default()) {
        self.container = container
    }

    var isAvailable: Bool { true }

    // MARK: - Writing

    func backUp(teams: [Team], games: [Game]) async throws -> BackupSnapshot {
        try await requireAccount()
        try await ensureZone()

        var records = teams.map { CloudKitSchema.backupRecord(for: $0, in: zoneID) }
        records += games.map { CloudKitSchema.backupRecord(for: $0, in: zoneID) }

        // Saved in batches: CloudKit rejects very large modify operations, and a
        // full season plus rosters can exceed the limit in one go.
        for batch in records.chunked(into: 200) {
            _ = try await database.modifyRecords(saving: batch, deleting: [],
                                                 savePolicy: .allKeys)
        }

        try await deleteRecordsNoLongerPresent(teams: teams, games: games)

        return BackupSnapshot(backedUpAt: Date(),
                              teamCount: teams.count,
                              gameCount: games.count)
    }

    /// A game or team deleted on the device is deleted from the backup too.
    ///
    /// The alternative — keeping everything forever — sounds safer but makes
    /// the backup diverge from what the user believes they have, and a restore
    /// would resurrect games they deliberately removed.
    private func deleteRecordsNoLongerPresent(teams: [Team], games: [Game]) async throws {
        let keep = Set(teams.map { CloudKitSchema.backupTeamRecordID($0.id, in: zoneID) })
            .union(games.map { CloudKitSchema.backupGameRecordID($0.id, in: zoneID) })

        let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: nil)
        let stale = changes.modificationResultsByID.keys.filter { !keep.contains($0) }
        guard !stale.isEmpty else { return }

        for batch in Array(stale).chunked(into: 200) {
            _ = try await database.modifyRecords(saving: [], deleting: batch)
        }
    }

    // MARK: - Reading

    func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot) {
        try await requireAccount()
        guard try await zoneExists() else {
            return ([], [], .none)
        }

        // Zone *changes* rather than a query, for the same reason
        // `fetchFollowedTeams` uses them: a query needs the record type marked
        // queryable in the CloudKit schema, change fetching works as-is.
        let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: nil)

        var teams: [Team] = []
        var games: [Game] = []
        var newest: Date?

        for (_, result) in changes.modificationResultsByID {
            // One unreadable record must cost one record, never the archive.
            guard let record = try? result.get().record else { continue }
            if let team = CloudKitSchema.backupTeam(from: record) {
                teams.append(team)
            } else if let game = CloudKitSchema.backupGame(from: record) {
                games.append(game)
            }
            if let changed = record.modificationDate, changed > (newest ?? .distantPast) {
                newest = changed
            }
        }

        let snapshot = BackupSnapshot(backedUpAt: newest,
                                      teamCount: teams.count,
                                      gameCount: games.count)
        return (teams.sorted { $0.name < $1.name },
                games.sorted { $0.date > $1.date },
                snapshot)
    }

    // MARK: - Plumbing

    private func requireAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else { throw SharingError.iCloudAccountUnavailable }
    }

    private func ensureZone() async throws {
        guard try await !zoneExists() else { return }
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)],
                                                 deleting: [])
    }

    private func zoneExists() async throws -> Bool {
        do {
            _ = try await database.recordZone(for: zoneID)
            return true
        } catch let error as CKError where error.code == .zoneNotFound {
            return false
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

/// The persisted half of `BackupSnapshot`, so Settings can show "last backed
/// up" at launch without waiting on the network.
struct StoredBackupState: Codable {
    var backedUpAt: Date?
    var teamCount: Int
    var gameCount: Int
}

#if DEBUG
/// Offline stand-in for the screenshot harness.
///
/// Without it the Settings capture shows "Last backed up: Never", which is the
/// one state the feature exists to avoid — the same trap the followers section
/// hit before `DemoSharingService` existed.
final class DemoBackupService: BackupService {
    var isAvailable: Bool { true }

    func backUp(teams: [Team], games: [Game]) async throws -> BackupSnapshot {
        BackupSnapshot(backedUpAt: Date().addingTimeInterval(-8 * 60),
                       teamCount: teams.count, gameCount: games.count)
    }

    /// Returns the demo team's games plus one game from a team that is *not*
    /// on the device, so the browser captures both states it has to handle:
    /// already-here rows, and a game that has to drag its team back with it.
    func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot) {
        let team = DemoData.makeTeam()
        var games = DemoData.makeGames(team: team)

        var oldTeam = Team(name: "Swish Warriors (2025)", players: Array(team.players.prefix(6)))
        oldTeam.teamColor = .maroon
        var archived = Game(opponent: "Riverside Rockets")
        archived.teamID = oldTeam.id
        archived.date = Date().addingTimeInterval(-300 * 24 * 60 * 60)
        archived.isComplete = true
        archived.hasStarted = true
        archived.events = [GameEvent(playerID: oldTeam.players[0].id, type: .twoPoint, period: 1)]
        archived.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 2, opponentRunningTotal: 5)]
        games.append(archived)

        return ([team, oldTeam], games,
                BackupSnapshot(backedUpAt: Date().addingTimeInterval(-8 * 60),
                               teamCount: 2, gameCount: games.count))
    }
}
#endif
