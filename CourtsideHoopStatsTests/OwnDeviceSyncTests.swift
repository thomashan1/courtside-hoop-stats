import Testing
import Foundation
@testable import CourtsideHoopStats

/// Two devices on one Apple Account, kept in step through the backup zone
/// (#229 stage 2). A fake iCloud stands between two in-memory stores, so the
/// merge rules run exactly as they would against CloudKit.
@MainActor
struct OwnDeviceSyncTests {

    /// An in-memory backup zone with a change log, so pulls can ask for
    /// "changes since" the way CloudKit's change tokens do.
    final class FakeCloud {
        var teams: [UUID: Team] = [:]
        var games: [UUID: Game] = [:]
        private(set) var log: [UUID] = []   // one entry per change, in order

        func service() -> Device { Device(cloud: self) }

        fileprivate func record(_ id: UUID) { log.append(id) }
    }

    final class Device: BackupService {
        let cloud: FakeCloud
        init(cloud: FakeCloud) { self.cloud = cloud }
        var isAvailable: Bool { true }

        func backUp(teams: [Team], games: [Game], prunable: Set<UUID>) async throws -> BackupSnapshot {
            Issue.record("a syncing device must never do a full backup")
            return .none
        }
        func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot) {
            (Array(cloud.teams.values), Array(cloud.games.values), .none)
        }
        func pushChanges(teams: [Team], games: [Game], deleting: Set<UUID>) async throws {
            for team in teams { cloud.teams[team.id] = team; cloud.record(team.id) }
            for game in games { cloud.games[game.id] = game; cloud.record(game.id) }
            for id in deleting {
                cloud.teams[id] = nil; cloud.games[id] = nil; cloud.record(id)
            }
        }
        func pullChanges(since token: Data?) async throws -> SyncPull {
            let from = token.flatMap { Int(String(decoding: $0, as: UTF8.self)) } ?? 0
            var pull = SyncPull()
            for id in Set(cloud.log.dropFirst(from)) {
                if let team = cloud.teams[id] { pull.teams.append(team) }
                else if let game = cloud.games[id] { pull.games.append(game) }
                else { pull.deletedIDs.insert(id) }
            }
            pull.token = Data(String(cloud.log.count).utf8)
            return pull
        }
    }

    private func device(on cloud: FakeCloud) -> AppStore {
        let store = AppStore(inMemory: true)
        store.backupService = cloud.service()
        return store
    }

    @Test func aGameAddedOnThePhoneAppearsOnTheIPad() async {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addPlayer(name: "Nicholas H", number: "77")
        phone.addGame(Game(opponent: "Graham Bears"))
        await phone.setSyncAcrossDevices(true)

        let iPad = device(on: cloud)
        await iPad.setSyncAcrossDevices(true)

        #expect(iPad.games.map(\.opponent) == ["Graham Bears"])
        #expect(iPad.teams.map(\.id) == phone.teams.map(\.id),
                "the iPad's blank default team gives way to the real one")
        #expect(iPad.team.players.map(\.name) == ["Nicholas H"])
    }

    @Test func anEditOnTheIPadReachesThePhone() async {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addGame(Game(opponent: "Graham Bears"))
        await phone.setSyncAcrossDevices(true)
        let iPad = device(on: cloud)
        await iPad.setSyncAcrossDevices(true)

        var game = iPad.games[0]
        game.notes = "Edited on the iPad"
        iPad.updateGame(game)
        await iPad.syncNow()
        await phone.syncNow()

        #expect(phone.games.first?.notes == "Edited on the iPad")
    }

    /// The phantom-game bug, across devices: a deletion must travel too.
    @Test func aDeletionOnOneDeviceRemovesTheGameOnTheOther() async {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addGame(Game(opponent: "Test game"))
        phone.addGame(Game(opponent: "Graham Bears"))
        await phone.setSyncAcrossDevices(true)
        let iPad = device(on: cloud)
        await iPad.setSyncAcrossDevices(true)
        #expect(iPad.games.count == 2)

        let test = try! #require(iPad.games.first { $0.opponent == "Test game" })
        iPad.deleteGame(id: test.id)
        await iPad.syncNow()
        await phone.syncNow()

        #expect(phone.games.map(\.opponent) == ["Graham Bears"])
    }

    /// An edit not yet pushed beats an incoming copy of the same game.
    @Test func anUnsentLocalEditWinsOverAnIncomingOne() async {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addGame(Game(opponent: "Graham Bears"))
        await phone.setSyncAcrossDevices(true)
        let iPad = device(on: cloud)
        await iPad.setSyncAcrossDevices(true)

        var onPad = iPad.games[0]
        onPad.notes = "iPad"
        iPad.updateGame(onPad)
        await iPad.syncNow()

        var onPhone = phone.games[0]
        onPhone.notes = "phone"
        phone.updateGame(onPhone)   // not yet synced when the pull arrives
        await phone.syncNow()

        #expect(phone.games[0].notes == "phone")
        await iPad.syncNow()
        #expect(iPad.games[0].notes == "phone", "and then it reaches the other device")
    }

    /// Off by default: nothing changes for a device that never turned it on.
    @Test func aDeviceWithSyncOffNeitherPullsNorPushes() async {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addGame(Game(opponent: "Graham Bears"))
        await phone.syncNow()

        #expect(cloud.log.isEmpty)
        #expect(!phone.syncAcrossDevices)
    }
}
