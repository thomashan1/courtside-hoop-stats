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

        /// Put a record in iCloud as an earlier backup would have.
        func seed(_ team: Team) { teams[team.id] = team; record(team.id) }
        func seed(_ game: Game) { games[game.id] = game; record(game.id) }

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

    // MARK: - It just works: both devices scoring, deletions, stale copies

    private func pairWithOneGame() async -> (AppStore, AppStore, UUID, UUID) {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addPlayer(name: "Nicholas H", number: "77")
        var game = Game(opponent: "Graham Bears")
        game.hasStarted = true
        phone.addGame(game)
        await phone.setSyncAcrossDevices(true)
        let iPad = device(on: cloud)
        await iPad.setSyncAcrossDevices(true)
        return (phone, iPad, phone.games[0].id, phone.team.players[0].id)
    }

    private func score(_ store: AppStore, _ gameID: UUID, _ player: UUID, _ type: EventType) -> UUID {
        var game = store.game(id: gameID)!
        let event = GameEvent(playerID: player, type: type, period: 1)
        game.events.append(event)
        store.updateGame(game)
        return event.id
    }

    /// Both devices score the same game before either syncs: every tap
    /// survives on both.
    @Test func bothDevicesScoringAtOnceKeepEveryTap() async {
        let (phone, iPad, gameID, nick) = await pairWithOneGame()
        let a = score(phone, gameID, nick, .threePoint)
        let b = score(iPad, gameID, nick, .twoPoint)

        await phone.syncNow()
        await iPad.syncNow()
        await phone.syncNow()

        for store in [phone, iPad] {
            let ids = Set(store.game(id: gameID)!.events.map(\.id))
            #expect(ids == [a, b])
            #expect(store.game(id: gameID)!.ourScore == 5)
        }
    }

    /// A tap deleted on one device stays deleted, even while the other
    /// device is adding taps to the same game.
    @Test func aDeletedTapStaysDeleted() async {
        let (phone, iPad, gameID, nick) = await pairWithOneGame()
        let mistake = score(phone, gameID, nick, .threePoint)
        await phone.syncNow()
        await iPad.syncNow()

        var onPad = iPad.game(id: gameID)!
        onPad.removeEvent(id: mistake)
        iPad.updateGame(onPad)
        let later = score(phone, gameID, nick, .twoPoint)

        await iPad.syncNow()
        await phone.syncNow()
        await iPad.syncNow()

        for store in [phone, iPad] {
            #expect(store.game(id: gameID)!.events.map(\.id) == [later])
        }
    }

    /// A screen saving a copy of the game from before another device's taps
    /// arrived must not drop them.
    @Test func savingAnOlderCopyKeepsNewerTaps() {
        let store = AppStore(inMemory: true)
        store.addPlayer(name: "Nicholas H", number: "77")
        store.addGame(Game(opponent: "Graham Bears"))
        let gameID = store.games[0].id
        let staleCopy = store.game(id: gameID)!

        let arrived = score(store, gameID, store.team.players[0].id, .threePoint)
        var edited = staleCopy
        edited.notes = "Edited from an open sheet"
        store.updateGame(edited)

        let saved = store.game(id: gameID)!
        #expect(saved.events.map(\.id) == [arrived])
        #expect(saved.notes == "Edited from an open sheet")
    }

    /// Finishing a game on one device finishes it on the other, even if that
    /// one recorded a late tap.
    @Test func finishedOnEitherDeviceMeansFinished() async {
        let (phone, iPad, gameID, nick) = await pairWithOneGame()
        var onPhone = phone.game(id: gameID)!
        onPhone.periodEndScores[4] = PeriodEndScore(ourRunningTotal: 0, opponentRunningTotal: 30)
        onPhone.isComplete = true
        phone.updateGame(onPhone)
        _ = score(iPad, gameID, nick, .ftMade)

        await phone.syncNow()
        await iPad.syncNow()
        await phone.syncNow()

        for store in [phone, iPad] {
            let game = store.game(id: gameID)!
            #expect(game.isComplete)
            #expect(game.events.count == 1)
            #expect(game.periodEndScores[4]?.opponentRunningTotal == 30)
        }
    }

    /// The first sync on a device with real games: its old backup may still
    /// hold a tap deleted before deletions were remembered. It stays deleted.
    @Test func aStaleBackupCantResurrectATapOnTheFirstSync() async {
        let cloud = FakeCloud()
        let phone = device(on: cloud)
        phone.addPlayer(name: "Nicholas H", number: "77")
        var game = Game(opponent: "Graham Bears")
        let kept = GameEvent(playerID: phone.team.players[0].id, type: .twoPoint, period: 1)
        let deleted = GameEvent(playerID: phone.team.players[0].id, type: .threePoint, period: 1)
        game.events = [kept, deleted]
        cloud.seed(game)                        // the old backup, from before the delete
        game.events = [kept]                    // deleted with no record of it
        phone.addGame(game)

        await phone.setSyncAcrossDevices(true)

        #expect(phone.games[0].events.map(\.id) == [kept.id])
        #expect(cloud.games[game.id]?.events.map(\.id) == [kept.id], "and the backup is corrected")
    }

    /// Older builds backed up a fresh install's blank default team; a first
    /// pull mustn't bring it onto a real device.
    @Test func aBlankTeamFromAnOldBackupStaysOut() async {
        let cloud = FakeCloud()
        let blank = Team(name: "My Test Team", players: [])
        cloud.seed(blank)
        let phone = device(on: cloud)
        phone.addPlayer(name: "Nicholas H", number: "77")
        await phone.setSyncAcrossDevices(true)

        #expect(!phone.teams.contains { $0.id == blank.id })
    }
}

/// Games saved before deletions were remembered must still load.
struct RemovedEventIDsMigrationTests {
    @Test func aGameWithoutTheKeyDecodes() throws {
        var game = Game(opponent: "Graham Bears")
        game.removedEventIDs = [UUID()]
        let data = try JSONEncoder().encode(game)
        var object = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        object["removedEventIDs"] = nil
        let stripped = try JSONSerialization.data(withJSONObject: object)

        let decoded = try JSONDecoder().decode(Game.self, from: stripped)
        #expect(decoded.opponent == "Graham Bears")
        #expect(decoded.removedEventIDs.isEmpty)
    }
}
