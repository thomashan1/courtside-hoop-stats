import Testing
import Foundation
import CloudKit
@testable import CourtsideHoopStats

/// Round-trip tests for the CloudKit record mapping (#57, `CloudKitSchema`).
///
/// `CKRecord` is a plain in-memory object — constructing one and reading its
/// fields needs no iCloud account or network — so the struct ⇄ record mapping
/// is fully testable in the simulator without the CloudKit capability. This is
/// the correctness-critical core of sharing: if a game doesn't survive the
/// round trip, a follower sees wrong data.
struct CloudKitSchemaTests {

    private let zoneID = CKRecordZone.ID(zoneName: "TestZone",
                                         ownerName: CKCurrentUserDefaultName)

    // MARK: - Team

    @Test func teamSurvivesRoundTrip() throws {
        var team = Team(name: "Swish Warriors", players: [
            Player(name: "Nicholas Han", number: "77"),
            Player(name: "Ava Reyes", number: "4"),
        ])
        team.homeJersey = .blue

        let record = CloudKitSchema.record(for: team, in: zoneID)
        let decoded = try #require(CloudKitSchema.team(from: record))

        #expect(decoded.id == team.id)
        #expect(decoded.name == "Swish Warriors")
        #expect(decoded.homeJersey == .blue)
        #expect(decoded.players.map(\.name) == ["Nicholas Han", "Ava Reyes"])
        #expect(decoded.players.map(\.number) == ["77", "4"])
        #expect(decoded.players.map(\.id) == team.players.map(\.id))
    }

    @Test func teamNameIsAQueryableField() {
        let team = Team(name: "Hawks", players: [])
        let record = CloudKitSchema.record(for: team, in: zoneID)
        // The name is mirrored to a plain field so a share can show a title
        // without decoding the payload.
        #expect(record[CloudKitSchema.Key.name] as? String == "Hawks")
        #expect(record.recordType == CloudKitSchema.teamRecordType)
    }

    // MARK: - Game

    @Test func gameSurvivesRoundTripWithEventsAndScores() throws {
        let p1 = UUID(), p2 = UUID()
        var game = Game(opponent: "Hawks", periodFormat: .quarters)
        game.league = "Rec League"
        game.location = "Central Gym"
        game.events = [
            GameEvent(playerID: p1, type: .twoPoint, period: 1),
            GameEvent(playerID: p2, type: .threePoint, period: 1),
            GameEvent(playerID: p1, type: .ftMade, period: 2),
        ]
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 5, opponentRunningTotal: 4)]
        game.benchedPlayerIDs = [p2]
        game.isComplete = true

        let record = CloudKitSchema.record(for: game, teamID: UUID(), in: zoneID)
        let decoded = try #require(CloudKitSchema.game(from: record))

        #expect(decoded.id == game.id)
        #expect(decoded.opponent == "Hawks")
        #expect(decoded.league == "Rec League")
        #expect(decoded.periodFormat == .quarters)
        #expect(decoded.events.count == 3)
        #expect(decoded.ourScore == 6)                       // 2 + 3 + 1
        #expect(decoded.periodEndScores[1]?.opponentRunningTotal == 4)
        #expect(decoded.benchedPlayerIDs == [p2])
        #expect(decoded.isComplete)
    }

    @Test func gamePointsToItsTeamForHierarchicalSharing() {
        let teamID = UUID()
        let game = Game(opponent: "Rivals")
        let record = CloudKitSchema.record(for: game, teamID: teamID, in: zoneID)

        let expectedTeamRecordID = CloudKitSchema.teamRecordID(teamID, in: zoneID)

        // The explicit team reference cascades a delete; the CloudKit `parent`
        // must use `.none` but point at the same team record so the share
        // hierarchy resolves.
        let teamRef = record[CloudKitSchema.Key.team] as? CKRecord.Reference
        #expect(teamRef?.recordID == expectedTeamRecordID)
        #expect(record.parent?.recordID == expectedTeamRecordID)
        #expect(record.recordType == CloudKitSchema.gameRecordType)
    }

    // MARK: - Record identity

    @Test func recordIDsAreStableAndDistinctPerModel() {
        let id = UUID()
        let teamRID = CloudKitSchema.teamRecordID(id, in: zoneID)
        let gameRID = CloudKitSchema.gameRecordID(id, in: zoneID)

        // Deterministic from the model id (so re-publishing overwrites in place)…
        #expect(teamRID == CloudKitSchema.teamRecordID(id, in: zoneID))
        // …and namespaced so a team and a game that happened to share a UUID
        // never collide on one record.
        #expect(teamRID != gameRID)
        #expect(teamRID.recordName == "team-\(id.uuidString)")
        #expect(gameRID.recordName == "game-\(id.uuidString)")
    }

    // MARK: - Role mapping

    @Test func rolesMapToCloudKitPermissions() {
        #expect(SharingRole.follower.cloudKitPermission == .readOnly)
        #expect(SharingRole.coTracker.cloudKitPermission == .readWrite)
        #expect(SharingRole.follower.label == "View only")
        #expect(SharingRole.coTracker.label == "Can edit")
    }
}
