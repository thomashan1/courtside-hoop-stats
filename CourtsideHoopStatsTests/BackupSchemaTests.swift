import Testing
import Foundation
import CloudKit
@testable import CourtsideHoopStats

/// Record mapping for the iCloud backup (#177).
///
/// Pure mapping only — no network, like `CloudKitSchemaTests`. The parts that
/// need a real account (zone creation, restore onto a fresh install) can't be
/// proven here and need a device, the same as sharing did.
struct BackupSchemaTests {

    private let zoneID = CKRecordZone.ID(zoneName: "backup",
                                         ownerName: CKCurrentUserDefaultName)

    private func demoGame() -> Game {
        DemoData.makeGames(team: DemoData.makeTeam()).first { $0.isComplete }!
    }

    @Test func aGameRoundTripsThroughABackupRecord() throws {
        let game = demoGame()
        let record = CloudKitSchema.backupRecord(for: game, in: zoneID)

        let restored = try #require(CloudKitSchema.backupGame(from: record))

        #expect(restored.id == game.id)
        #expect(restored.opponent == game.opponent)
        #expect(restored.events.count == game.events.count)
        #expect(restored.ourScore == game.ourScore)
        #expect(restored.notes == game.notes)
    }

    @Test func aTeamAndItsRosterRoundTrip() throws {
        let team = DemoData.makeTeam()
        let record = CloudKitSchema.backupRecord(for: team, in: zoneID)

        let restored = try #require(CloudKitSchema.backupTeam(from: record))

        #expect(restored.id == team.id)
        #expect(restored.players.count == team.players.count)
        #expect(restored.players.map(\.name) == team.players.map(\.name))
    }

    /// Rebounds must survive the backup, which means the `laterEvents` split
    /// has to be applied and undone here too (#174).
    @Test func reboundsSurviveTheBackup() throws {
        var game = Game(opponent: "Lakeside")
        let boarder = UUID()
        game.events = [
            GameEvent(playerID: boarder, type: .twoPoint, period: 1),
            GameEvent(playerID: boarder, type: .rebound, period: 1),
        ]

        let record = CloudKitSchema.backupRecord(for: game, in: zoneID)
        let restored = try #require(CloudKitSchema.backupGame(from: record))

        #expect(restored.events.filter { $0.type == .rebound }.count == 1)
        #expect(restored.ourScore == 2)
    }

    /// **A backup record must never carry a parent reference.** The sharing
    /// records use one so a game travels with its team and cascade-deletes
    /// with it; a backup has to outlive the live copy, which is the entire
    /// reason sharing can't double as one.
    @Test func backupRecordsHaveNoParentAndNoShare() {
        let game = CloudKitSchema.backupRecord(for: demoGame(), in: zoneID)
        let team = CloudKitSchema.backupRecord(for: DemoData.makeTeam(), in: zoneID)

        #expect(game.parent == nil)
        #expect(game.share == nil)
        #expect(team.parent == nil)
        #expect(team.share == nil)
    }

    /// Distinct record types, so a zone walk can't confuse a backup record for
    /// a shared one.
    @Test func backupRecordTypesAreDistinctFromTheSharedOnes() {
        let backup = CloudKitSchema.backupRecord(for: demoGame(), in: zoneID)

        #expect(backup.recordType == "BackupGame")
        #expect(backup.recordType != CloudKitSchema.gameRecordType)
        // And the shared decoders must refuse it, rather than half-reading it.
        #expect(CloudKitSchema.game(from: backup) == nil)
    }

    /// Record ids are derived from the model id, so a second backup updates the
    /// same record instead of piling up duplicates.
    @Test func backingUpTwiceTargetsTheSameRecord() {
        let game = demoGame()

        let first = CloudKitSchema.backupRecord(for: game, in: zoneID)
        let second = CloudKitSchema.backupRecord(for: game, in: zoneID)

        #expect(first.recordID == second.recordID)
    }
}
