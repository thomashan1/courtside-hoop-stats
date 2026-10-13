import Testing
import Foundation
@testable import CourtsideHoopStats

/// A fresh install must never stand in for the owner's real backup.
///
/// Backup used to delete every record the device didn't have, so a new iPad
/// on the same Apple Account — one blank default team, no games — wiped the
/// whole backup 30 seconds after launch.
@MainActor
struct BackupSafetyTests {

    final class RecordingBackupService: BackupService {
        var isAvailable = true
        private(set) var backups: [(teams: [Team], games: [Game], prunable: Set<UUID>)] = []

        func backUp(teams: [Team], games: [Game], prunable: Set<UUID>) async throws -> BackupSnapshot {
            backups.append((teams, games, prunable))
            return BackupSnapshot(backedUpAt: Date(), teamCount: teams.count, gameCount: games.count)
        }

        func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot) {
            ([], [], .none)
        }
    }

    @Test func aDeviceWithNoDataNeverBacksUp() async {
        let store = AppStore(inMemory: true)
        let service = RecordingBackupService()
        store.backupService = service

        #expect(store.hasNoDataOfItsOwn)
        await store.backUpNow()
        #expect(service.backups.isEmpty, "a blank install must not overwrite the backup")
    }

    @Test func aDeviceWithDataBacksUp() async {
        let store = AppStore(inMemory: true)
        let service = RecordingBackupService()
        store.backupService = service
        store.addPlayer(name: "Nicholas", number: "77")

        #expect(!store.hasNoDataOfItsOwn)
        await store.backUpNow()
        #expect(service.backups.count == 1)
    }

    /// The first backup from a device that has never uploaded anything may
    /// add, but has nothing of its own to delete.
    @Test func firstBackupPrunesNothing() async {
        let store = AppStore(inMemory: true)
        let service = RecordingBackupService()
        store.backupService = service
        store.addGame(Game(opponent: "Lakeside"))

        await store.backUpNow()
        #expect(service.backups.first?.prunable.isEmpty == true)
    }
}
