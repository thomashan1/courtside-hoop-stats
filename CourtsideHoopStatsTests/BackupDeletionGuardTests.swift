import Testing
import Foundation
import CloudKit
@testable import CourtsideHoopStats

/// A bug that empties the app must not empty iCloud with it.
struct BackupDeletionGuardTests {

    private func team(_ name: String, players: Int = 8) -> Team {
        Team(name: name, players: (0..<players).map { Player(name: "P\($0)", number: "\($0)") })
    }

    private func games(_ count: Int, for team: Team) -> [Game] {
        (0..<count).map { i in
            var game = Game(opponent: "Opponent \(i)")
            game.teamID = team.id
            return game
        }
    }

    private func allowed(teams: [Team] = [], games: [Game] = [],
                         allTeams: [Team], allGames: [Game]) -> Set<UUID> {
        BackupDeletionGuard.allowed(teams: teams, games: games,
                                    allTeams: allTeams, allGames: allGames)
    }

    /// Jean's case: one team, a season of games, and a bug wipes the lot.
    @Test func wipingTheOnlyTeamIsRefused() {
        let swish = team("Swish Warriors")
        let season = games(20, for: swish)
        #expect(allowed(teams: [swish], games: season,
                        allTeams: [swish], allGames: season).isEmpty)
    }

    @Test func wipingEveryGameIsRefused() {
        let swish = team("Swish Warriors")
        let season = games(20, for: swish)
        #expect(allowed(games: season, allTeams: [swish], allGames: season).isEmpty)
    }

    @Test func wipingSeveralTeamsIsRefused() {
        let teams = [team("A"), team("B"), team("C")]
        #expect(allowed(teams: Array(teams.prefix(2)), allTeams: teams, allGames: []).isEmpty)
    }

    /// Deleting a team in Settings takes its games with it — however many.
    @Test func deletingOneOfSeveralTeamsGoesThrough() {
        let old = team("Swish (2025)")
        let current = team("Swish Warriors")
        let oldGames = games(15, for: old)
        let all = oldGames + games(5, for: current)
        let result = allowed(teams: [old], games: oldGames, allTeams: [old, current], allGames: all)
        #expect(result == Set([old.id] + oldGames.map(\.id)))
    }

    @Test func deletingAGameGoesThrough() {
        let swish = team("Swish Warriors")
        let season = games(20, for: swish)
        #expect(allowed(games: [season[3]], allTeams: [swish], allGames: season) == [season[3].id])
    }

    /// A handful at once is still normal, even in a short season.
    @Test func aFewGamesAtOnceGoThrough() {
        let swish = team("Swish Warriors")
        let season = games(6, for: swish)
        let doomed = Array(season.prefix(5))
        #expect(allowed(games: doomed, allTeams: [swish], allGames: season) == Set(doomed.map(\.id)))
    }

    /// Older builds backed up a blank starter from every fresh install;
    /// clearing those is housekeeping, not a wipe.
    @Test func blankTeamsAlwaysGo() {
        let swish = team("Swish Warriors")
        let blanks = [team(Team.starterName, players: 0), team(Team.starterName, players: 0)]
        let result = allowed(teams: blanks, allTeams: [swish] + blanks, allGames: [])
        #expect(result == Set(blanks.map(\.id)))
    }

    /// Recently Deleted keeps the record whole, so a restore reads it back.
    @Test func aDeletedRecordIsCopiedWhole() {
        let swish = team("Swish Warriors")
        let backupZone = CKRecordZone.ID(zoneName: "backup", ownerName: CKCurrentUserDefaultName)
        let deletedZone = CKRecordZone.ID(zoneName: "backup-deleted", ownerName: CKCurrentUserDefaultName)
        let record = CloudKitSchema.backupRecord(for: swish, in: backupZone)

        let copy = CloudKitSchema.copy(of: record, in: deletedZone)
        #expect(copy.recordID.zoneID == deletedZone)
        #expect(copy.recordID.recordName == record.recordID.recordName)
        #expect(CloudKitSchema.backupID(from: copy.recordID) == swish.id)
        #expect(CloudKitSchema.backupTeam(from: copy) == swish)
    }
}
