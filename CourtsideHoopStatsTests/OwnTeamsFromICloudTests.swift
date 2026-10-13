import Testing
import Foundation
@testable import CourtsideHoopStats

/// A second device on the same Apple Account shows the owner's teams
/// read-only from their iCloud backup (#229 stage 1).
@MainActor
struct OwnTeamsFromICloudTests {

    final class FakeBackup: BackupService {
        var isAvailable = true
        var teams: [Team] = []
        var games: [Game] = []

        func backUp(teams: [Team], games: [Game], prunable: Set<UUID>) async throws -> BackupSnapshot {
            BackupSnapshot(backedUpAt: Date(), teamCount: teams.count, gameCount: games.count)
        }

        func fetchBackup() async throws -> (teams: [Team], games: [Game], snapshot: BackupSnapshot) {
            (teams, games, BackupSnapshot(backedUpAt: Date(), teamCount: teams.count, gameCount: games.count))
        }
    }

    private func backupWithOneSeason() -> FakeBackup {
        let backup = FakeBackup()
        let team = Team(name: "Hyde 6th graders", players: [Player(name: "Nicholas H", number: "77")])
        var game = Game(opponent: "Graham Bears")
        game.teamID = team.id
        // A blank default team an older build backed up: nothing to show.
        let blank = Team(name: "My Test Team", players: [])
        backup.teams = [team, blank]
        backup.games = [game]
        return backup
    }

    @Test func aBlankDeviceShowsItsOwnTeamsReadOnly() async throws {
        let store = AppStore(inMemory: true)
        store.backupService = backupWithOneSeason()

        try await store.refreshICloudTeams()

        #expect(store.iCloudTeams.map(\.team.name) == ["Hyde 6th graders"])
        #expect(store.iCloudTeams.first?.games.map(\.opponent) == ["Graham Bears"])
        #expect(store.iCloudTeams.first?.isOwnFromICloud == true)
        #expect(store.isViewOnly, "Games and Roster hide, like a pure follower's")
    }

    /// The phone that *makes* the backup must not see its own teams twice.
    @Test func aDeviceWithDataShowsNothingFromICloud() async throws {
        let store = AppStore(inMemory: true)
        store.backupService = backupWithOneSeason()
        store.addPlayer(name: "Jake", number: "7")

        try await store.refreshICloudTeams()

        #expect(store.iCloudTeams.isEmpty)
        #expect(!store.isViewOnly)
    }

    /// Adding data on the second device turns the view off, rather than
    /// leaving a stale read-only copy beside the new team.
    @Test func addingDataClearsTheICloudView() async throws {
        let store = AppStore(inMemory: true)
        store.backupService = backupWithOneSeason()
        try await store.refreshICloudTeams()
        #expect(!store.iCloudTeams.isEmpty)

        store.addPlayer(name: "Jake", number: "7")
        try await store.refreshICloudTeams()
        #expect(store.iCloudTeams.isEmpty)
    }
}
