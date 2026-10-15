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
    ///
    /// `prunable` is what this device itself uploaded last time: only those
    /// may be deleted from the backup when they're gone locally. Anything else
    /// in the backup came from another device (or an earlier install) and is
    /// never this device's to delete.
    func backUp(teams: [Team], games: [Game], prunable: Set<UUID>) async throws -> BackupSnapshot
    /// Everything currently in the backup. Used both to restore and to report
    /// what's there without restoring.
    func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot)
    /// What left the backup in the last 30 days, kept so Restore can bring
    /// it back. Never part of `fetchBackup`: a plain restore must not
    /// resurrect what was deliberately deleted.
    func fetchRecentlyDeleted() async throws -> DeletedFromBackup

    // MARK: Sync across the owner's devices (#229 stage 2)

    /// Upload just these teams and games, and delete these ids — the changes
    /// this device made since its last sync. Never the whole set: a full
    /// upload would overwrite newer edits another device already made.
    func pushChanges(teams: [Team], games: [Game], deleting: Set<UUID>) async throws
    /// What changed in the backup since `token` (all of it when nil),
    /// including deletions, plus the token to pass next time.
    func pullChanges(since token: Data?) async throws -> SyncPull
    /// Ask iCloud for a silent push whenever this account's own data changes,
    /// so the other device updates within seconds rather than at its next poll.
    func subscribeToChanges() async throws
}

/// Teams and games deleted from the backup in the last 30 days.
struct DeletedFromBackup {
    var teams: [Team] = []
    var games: [Game] = []
    /// When each one was deleted, by team or game id.
    var deletedAt: [UUID: Date] = [:]

    static let days = 30
}

/// One pull's worth of changes from the owner's other devices.
struct SyncPull {
    var teams: [Team] = []
    var games: [Game] = []
    var deletedIDs: Set<UUID> = []
    var token: Data?
}

extension BackupService {
    // Defaults so stand-ins that only exercise backup don't have to know
    // about sync.
    func pushChanges(teams: [Team], games: [Game], deleting: Set<UUID>) async throws {}
    func pullChanges(since token: Data?) async throws -> SyncPull { SyncPull(token: token) }
    func subscribeToChanges() async throws {}
    func fetchRecentlyDeleted() async throws -> DeletedFromBackup { DeletedFromBackup() }
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
    /// Where a deleted record waits 30 days before it's gone for good. A zone
    /// of its own, so no build's sync or restore ever reads it by mistake —
    /// older builds don't know it exists — and the same record types, so it
    /// needs no change to the deployed schema.
    private let deletedZoneID = CKRecordZone.ID(zoneName: "backup-deleted",
                                                ownerName: CKCurrentUserDefaultName)

    init(container: CKContainer = .default()) {
        self.container = container
    }

    var isAvailable: Bool { true }

    // MARK: - Writing

    func backUp(teams: [Team], games: [Game], prunable: Set<UUID>) async throws -> BackupSnapshot {
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

        try await deleteRecordsNoLongerPresent(teams: teams, games: games, prunable: prunable)

        return BackupSnapshot(backedUpAt: Date(),
                              teamCount: teams.count,
                              gameCount: games.count)
    }

    /// A game or team deleted on the device is deleted from the backup too —
    /// into Recently Deleted, and only as far as `BackupDeletionGuard` allows.
    ///
    /// The alternative — keeping everything forever — sounds safer but makes
    /// the backup diverge from what the user believes they have, and a restore
    /// would resurrect games they deliberately removed.
    ///
    /// Only records **this device uploaded** (`prunable`) are candidates. This
    /// used to delete everything not on the device, so a fresh install — a new
    /// phone before its restore, or an iPad on the same Apple Account — wiped
    /// the whole backup down to its one empty team 30 seconds after launch.
    private func deleteRecordsNoLongerPresent(teams: [Team], games: [Game],
                                              prunable: Set<UUID>) async throws {
        let keep = Set(teams.map { CloudKitSchema.backupTeamRecordID($0.id, in: zoneID) })
            .union(games.map { CloudKitSchema.backupGameRecordID($0.id, in: zoneID) })
        let mine = Set(prunable.map { CloudKitSchema.backupTeamRecordID($0, in: zoneID) })
            .union(prunable.map { CloudKitSchema.backupGameRecordID($0, in: zoneID) })

        let changes = try await database.allRecordZoneChanges(in: zoneID)
        let stale = changes.keys.filter { !keep.contains($0) && mine.contains($0) }
        guard !stale.isEmpty else { return }
        try await delete(Array(stale), from: changes)
    }

    /// Deletes what the guard allows of `ids`, copying each record into
    /// Recently Deleted first. `zone` is the backup as it stands, which the
    /// guard needs to tell a deletion from a wipe.
    ///
    /// What the guard refuses stays in iCloud, so the owner's other devices
    /// keep it and Restore can bring it back here.
    private func delete(_ ids: [CKRecord.ID],
                        from zone: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, any Error>])
        async throws {
        let records = zone.values.compactMap { try? $0.get().record }
        // Anything not in the zone is already gone.
        let doomed = ids.compactMap { id in records.first { $0.recordID == id } }
        let allowed = BackupDeletionGuard.allowed(
            teams: doomed.compactMap(CloudKitSchema.backupTeam(from:)),
            games: doomed.compactMap(CloudKitSchema.backupGame(from:)),
            allTeams: records.compactMap(CloudKitSchema.backupTeam(from:)),
            allGames: records.compactMap(CloudKitSchema.backupGame(from:)))
        let going = doomed.filter {
            CloudKitSchema.backupID(from: $0.recordID).map(allowed.contains) ?? false
        }
        guard !going.isEmpty else { return }

        try await ensureZone(deletedZoneID)
        let copies = going.map { CloudKitSchema.copy(of: $0, in: deletedZoneID) }
        // Replaced rather than overwritten, so a copy's creation date is
        // always when it was last deleted — which is what the 30 days count.
        try await database.deleteRecords(copies.map(\.recordID))
        for batch in copies.chunked(into: 200) {
            let result = try await database.modifyRecords(saving: batch, deleting: [],
                                                          savePolicy: .allKeys)
            for (_, outcome) in result.saveResults {
                // No copy, no delete.
                if case .failure(let error) = outcome { throw error }
            }
        }
        try await database.deleteRecords(going.map(\.recordID))
        try? await purgeExpiredDeletions()
    }

    /// Past 30 days a deletion is final.
    private func purgeExpiredDeletions() async throws {
        let cutoff = Date().addingTimeInterval(-Double(DeletedFromBackup.days) * 86_400)
        let expired = try await database.allRecordZoneChanges(in: deletedZoneID)
            .values.compactMap { try? $0.get().record }
            .filter { ($0.creationDate ?? .distantFuture) < cutoff }
            .map(\.recordID)
        if !expired.isEmpty { try await database.deleteRecords(expired) }
    }

    // MARK: - Sync (#229 stage 2)

    func pushChanges(teams: [Team], games: [Game], deleting: Set<UUID>) async throws {
        try await requireAccount()
        try await ensureZone()
        var records = teams.map { CloudKitSchema.backupRecord(for: $0, in: zoneID) }
        records += games.map { CloudKitSchema.backupRecord(for: $0, in: zoneID) }
        for batch in records.chunked(into: 200) {
            let result = try await database.modifyRecords(saving: batch, deleting: [],
                                                          savePolicy: .allKeys)
            for (_, outcome) in result.saveResults {
                if case .failure(let error) = outcome { throw error }
            }
        }
        // Whether an id was a team or a game isn't kept for a deletion, so
        // both names go; the one that never existed counts as already gone.
        let doomed = deleting.flatMap { [CloudKitSchema.backupTeamRecordID($0, in: zoneID),
                                         CloudKitSchema.backupGameRecordID($0, in: zoneID)] }
        if !doomed.isEmpty {
            try await delete(doomed, from: database.allRecordZoneChanges(in: zoneID))
        }
    }

    func subscribeToChanges() async throws {
        try await requireAccount()
        // Fixed id: re-saving overwrites rather than piling up one per launch.
        let subscription = CKDatabaseSubscription(subscriptionID: "own-devices-changed")
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        do {
            _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
        } catch let error as CKError where error.code == .serverRejectedRequest {
            return   // already registered
        }
    }

    func pullChanges(since tokenData: Data?) async throws -> SyncPull {
        try await requireAccount()
        guard try await zoneExists() else { return SyncPull(token: nil) }

        var token = tokenData.flatMap {
            try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0)
        }
        var pull = SyncPull()
        var teamsByID: [UUID: Team] = [:]
        var gamesByID: [UUID: Game] = [:]
        repeat {
            let page: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, any Error>],
                       deletions: [CKDatabase.RecordZoneChange.Deletion],
                       changeToken: CKServerChangeToken,
                       moreComing: Bool)
            do {
                page = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            } catch let error as CKError where error.code == .changeTokenExpired && token != nil {
                // Start over from scratch rather than fail: a full pull is
                // only slower, never wrong.
                token = nil
                teamsByID = [:]; gamesByID = [:]; pull.deletedIDs = []
                continue
            }
            for (_, result) in page.modificationResultsByID {
                guard let record = try? result.get().record else { continue }
                if let team = CloudKitSchema.backupTeam(from: record) {
                    teamsByID[team.id] = team
                } else if let game = CloudKitSchema.backupGame(from: record) {
                    gamesByID[game.id] = game
                }
            }
            for deletion in page.deletions {
                guard let id = CloudKitSchema.backupID(from: deletion.recordID) else { continue }
                teamsByID[id] = nil
                gamesByID[id] = nil
                pull.deletedIDs.insert(id)
            }
            if page.moreComing, page.changeToken == token { break }
            token = page.changeToken
            if !page.moreComing { break }
        } while true

        pull.teams = Array(teamsByID.values)
        pull.games = Array(gamesByID.values)
        pull.token = token.flatMap {
            try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true)
        }
        return pull
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
        let changes = try await database.allRecordZoneChanges(in: zoneID)

        var teams: [Team] = []
        var games: [Game] = []
        var newest: Date?

        for (_, result) in changes {
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

    func fetchRecentlyDeleted() async throws -> DeletedFromBackup {
        try await requireAccount()
        guard try await zoneExists(deletedZoneID) else { return DeletedFromBackup() }
        let cutoff = Date().addingTimeInterval(-Double(DeletedFromBackup.days) * 86_400)
        var deleted = DeletedFromBackup()
        for result in try await database.allRecordZoneChanges(in: deletedZoneID).values {
            guard let record = try? result.get().record,
                  let when = record.creationDate, when > cutoff else { continue }
            if let team = CloudKitSchema.backupTeam(from: record) {
                deleted.teams.append(team)
                deleted.deletedAt[team.id] = when
            } else if let game = CloudKitSchema.backupGame(from: record) {
                deleted.games.append(game)
                deleted.deletedAt[game.id] = when
            }
        }
        deleted.games.sort { $0.date > $1.date }
        return deleted
    }

    // MARK: - Plumbing

    private func requireAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else { throw SharingError.iCloudAccountUnavailable }
    }

    private func ensureZone() async throws { try await ensureZone(zoneID) }

    private func ensureZone(_ zoneID: CKRecordZone.ID) async throws {
        guard try await !zoneExists(zoneID) else { return }
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)],
                                                 deleting: [])
    }

    private func zoneExists() async throws -> Bool { try await zoneExists(zoneID) }

    private func zoneExists(_ zoneID: CKRecordZone.ID) async throws -> Bool {
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
/// Without it the Settings capture shows "Last Backed Up: Never", which is the
/// one state the feature exists to avoid — the same trap the followers section
/// hit before `DemoSharingService` existed.
final class DemoBackupService: BackupService {
    var isAvailable: Bool { true }

    func backUp(teams: [Team], games: [Game], prunable: Set<UUID>) async throws -> BackupSnapshot {
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

    /// One game deleted two days ago, so the browser captures Recently
    /// Deleted too.
    func fetchRecentlyDeleted() async throws -> DeletedFromBackup {
        let team = DemoData.makeTeam()
        var game = Game(opponent: "Harbor Hawks")
        game.teamID = team.id
        game.date = Date().addingTimeInterval(-9 * 24 * 60 * 60)
        game.isComplete = true
        game.hasStarted = true
        game.events = [GameEvent(playerID: team.players[0].id, type: .threePoint, period: 1)]
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 3, opponentRunningTotal: 2)]
        return DeletedFromBackup(teams: [team], games: [game],
                                 deletedAt: [game.id: Date().addingTimeInterval(-2 * 24 * 60 * 60)])
    }
}
#endif
