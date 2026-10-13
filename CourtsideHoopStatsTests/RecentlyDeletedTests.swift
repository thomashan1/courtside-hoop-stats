import Testing
import Foundation
@testable import CourtsideHoopStats

/// Nothing leaves a device for good by accident: every removed game is kept
/// for 30 days and can be put back, however it went.
@MainActor
struct RecentlyDeletedTests {

    @Test func aDeletedGameCanBeRecovered() {
        let store = AppStore(inMemory: true)
        store.addGame(Game(opponent: "Graham Bears"))
        let id = store.games[0].id

        store.deleteGame(id: id)
        #expect(store.games.isEmpty)
        #expect(store.recentlyDeleted.map(\.id) == [id])

        store.recoverDeletedGame(id)
        #expect(store.games.map(\.id) == [id])
        #expect(store.recentlyDeleted.isEmpty)
    }

    /// Deleting a team takes its games; they come back with the team.
    @Test func gamesOfADeletedTeamComeBackWithTheirTeam() {
        let store = AppStore(inMemory: true)
        store.addTeam(name: "Old Season")
        let oldTeam = try! #require(store.teams.first { $0.name == "Old Season" })
        var game = Game(opponent: "Graham Bears")
        game.teamID = oldTeam.id
        store.addGame(game)

        store.deleteTeam(oldTeam.id)
        #expect(!store.teams.contains { $0.id == oldTeam.id })

        store.recoverDeletedGame(game.id)
        #expect(store.teams.contains { $0.id == oldTeam.id })
        #expect(store.games.first?.teamID == oldTeam.id)
    }

    /// A game deleted on another device is recoverable on this one, and
    /// recovering it brings it back everywhere.
    @Test func aGameDeletedOnAnotherDeviceIsRecoverableHere() async {
        let cloud = OwnDeviceSyncTests.FakeCloud()
        let phone = AppStore(inMemory: true)
        phone.backupService = cloud.service()
        phone.addGame(Game(opponent: "Graham Bears"))
        await phone.setSyncAcrossDevices(true)
        let iPad = AppStore(inMemory: true)
        iPad.backupService = cloud.service()
        await iPad.setSyncAcrossDevices(true)
        let id = phone.games[0].id

        iPad.deleteGame(id: id)
        await iPad.syncNow()
        await phone.syncNow()
        #expect(phone.games.isEmpty)
        #expect(phone.recentlyDeleted.map(\.id) == [id])

        phone.recoverDeletedGame(id)
        await phone.syncNow()
        await iPad.syncNow()
        #expect(iPad.games.map(\.id) == [id])
    }
}
