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

// MARK: - Wire compatibility with already-shipped builds (#174)

/// A `Game` reaches a follower as one JSON blob, and an older build's
/// `GameEvent` decoder **throws** on an `EventType` it has never heard of —
/// failing the whole game, so `game(from:)` returns nil, the caller skips it,
/// and the game silently disappears from that follower's list.
///
/// `CloudKitSchema.payload(for:)` therefore keeps `events` to the types every
/// shipped build knows and parks newer ones under a top-level key that an old
/// `Game.init(from:)` never reads. These tests are the proof, because the
/// claim is about binaries that can no longer be changed.
struct CloudKitWireCompatibilityTests {

    /// Exactly what `EventType` contained in the last release before
    /// `laterEvents` existed (v1.6). Frozen — if a change makes this test fail,
    /// the change is what's wrong.
    private let typesV16CanDecode: Set<String> = [
        "twoPoint", "threePoint", "ftMade", "ftMissed", "foul",
    ]

    private func gameWithRebounds() -> Game {
        let scorer = UUID(), boarder = UUID()
        var game = Game(opponent: "Lakeside")
        let t = Date()
        game.events = [
            GameEvent(playerID: scorer, type: .threePoint, period: 1, timestamp: t),
            GameEvent(playerID: boarder, type: .rebound, period: 1, timestamp: t + 1),
            GameEvent(playerID: scorer, type: .twoPoint, period: 1, timestamp: t + 2),
            GameEvent(playerID: boarder, type: .rebound, period: 2, timestamp: t + 3),
        ]
        return game
    }

    /// The load-bearing one: nothing an old build can't decode reaches `events`.
    @Test func theWirePayloadNeverPutsANewEventTypeInEvents() throws {
        let data = try #require(CloudKitSchema.payload(for: gameWithRebounds()))
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])
        let events = try #require(object["events"] as? [[String: Any]])

        #expect(events.count == 2, "the two rebounds must not be in events")
        for event in events {
            let raw = try #require(event["type"] as? String)
            #expect(typesV16CanDecode.contains(raw),
                    "\(raw) would make v1.6 drop this game entirely")
        }
        #expect(object["laterEvents"] != nil, "the rebounds have to go somewhere")
    }

    /// An old build ignores unknown top-level keys, so it must still see a
    /// complete game — and, because rebounds are worth 0, the right score.
    @Test func anOlderBuildStillDecodesTheGameWithTheCorrectScore() throws {
        let game = gameWithRebounds()
        let data = try #require(CloudKitSchema.payload(for: game))

        // Decoded **with** `laterEvents` still present, which is the whole
        // question: an old build receives the key and has to ignore it.
        // Stripping it first would prove nothing — it would pass even if a
        // decoder rejected unknown keys.
        let decoded = try JSONDecoder().decode(Game.self, from: data)

        #expect(decoded.opponent == game.opponent)
        #expect(decoded.ourScore == game.ourScore,
                "rebounds score 0, so an old follower's total is still right")
        #expect(decoded.events.count == 2)
    }

    /// A current build gets everything back.
    @Test func aCurrentBuildRoundTripsEveryEvent() throws {
        let game = gameWithRebounds()
        let published = try #require(CloudKitSchema.payload(for: game))
        let restored = try #require(CloudKitSchema.game(fromPayload: published))

        #expect(restored.events.count == game.events.count)
        #expect(restored.events.filter { $0.type == .rebound }.count == 2)
        #expect(restored.ourScore == game.ourScore)
        #expect(restored.events.map(\.id) == game.events.map(\.id),
                "restored in timestamp order, matching what was published")
    }

    /// The case most likely to look like a vanished game: every event is one
    /// the old build can't read, so `events` goes out empty. It must still
    /// arrive as a real game with an empty log, not as nothing at all.
    @Test func aGameOfNothingButReboundsStillArrives() throws {
        var game = Game(opponent: "Bayview")
        let boarder = UUID()
        game.events = [
            GameEvent(playerID: boarder, type: .rebound, period: 1),
            GameEvent(playerID: boarder, type: .rebound, period: 1),
        ]

        let data = try #require(CloudKitSchema.payload(for: game))
        let decoded = try JSONDecoder().decode(Game.self, from: data)

        #expect(decoded.opponent == "Bayview")
        #expect(decoded.events.isEmpty)
        #expect(decoded.ourScore == 0)

        let restored = try #require(CloudKitSchema.game(fromPayload: data))
        #expect(restored.events.count == 2)
    }

    /// A game with nothing new in it must encode byte-for-byte as before, so
    /// this machinery costs existing games nothing.
    @Test func aGameWithNoNewerEventsIsUnchangedOnTheWire() throws {
        var game = Game(opponent: "Central")
        game.events = [GameEvent(playerID: UUID(), type: .twoPoint, period: 1)]

        let data = try #require(CloudKitSchema.payload(for: game))
        let json = try JSONSerialization.jsonObject(with: data)
        let object = try #require(json as? [String: Any])

        // Compared as parsed JSON, not bytes: key order in a serialized
        // dictionary isn't contractual, and it's the content that has to be
        // untouched.
        let plain = try JSONEncoder().encode(game)
        let plainJSON = try JSONSerialization.jsonObject(with: plain)
        let plainObject = try #require(plainJSON as? [String: Any])

        #expect(object["laterEvents"] == nil, "no sidecar key when it isn't needed")
        #expect(NSDictionary(dictionary: object) == NSDictionary(dictionary: plainObject))
    }
}
