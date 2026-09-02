import Testing
import Foundation
import CloudKit
@testable import CourtsideHoopStats

/// Tests for how `AppStore` drives sharing — the layer between the pure alert
/// logic and CloudKit itself (#57).
///
/// This is where the bugs actually landed in practice: a team shared from an
/// earlier build never publishing, share discovery living somewhere it could
/// never run, a transient fetch failure wiping a follower's cached games. None
/// of those are visible in `CloudKitSchema` or `FollowerAlertBuilder`, which is
/// why they got through.
///
/// `TeamSharingService` exists as a seam precisely so this can be exercised
/// without an iCloud account or the network.
@MainActor
struct SharingOrchestrationTests {

    // MARK: - Test double

    final class FakeSharingService: TeamSharingService {
        var isAvailable = true
        /// Teams the "server" considers shared.
        var sharedTeamIDs: Set<UUID> = []
        /// Recorded publishes, so tests can assert what was pushed and when.
        private(set) var published: [(team: Team, games: [Game])] = []
        var fetchResult: [FollowedTeam] = []
        var publishError: Error?

        func prepareShare(for team: Team, games: [Game]) async throws -> PreparedShare {
            throw SharingError.unavailable   // not exercised here
        }

        func publish(team: Team, games: [Game]) async throws {
            if let publishError { throw publishError }
            published.append((team, games))
        }

        func stopSharing(_ team: Team) async throws {
            sharedTeamIDs.remove(team.id)
        }

        func acceptShare(_ metadata: CKShare.Metadata) async throws {}
        func fetchFollowedTeams() async throws -> [FollowedTeam] { fetchResult }
        func unfollow(_ team: FollowedTeam) async throws {
            fetchResult.removeAll { $0.id == team.id }
        }
        func participants(for team: Team) async throws -> [SharedParticipant] { [] }
        func shareURL(for team: Team) async throws -> URL? { nil }
        func subscribeToFollowedTeamChanges() async throws {}
        func isSharing(_ team: Team) async throws -> Bool {
            sharedTeamIDs.contains(team.id)
        }
    }

    private func makeStore(_ service: FakeSharingService) -> AppStore {
        let store = AppStore(inMemory: true)
        store.sharingService = service
        return store
    }

    private func followed(_ name: String = "Swish Warriors",
                          games: [Game] = [],
                          id: String = "owner|zone") -> FollowedTeam {
        FollowedTeam(team: Team(name: name, players: []),
                     games: games,
                     zoneName: String(id.split(separator: "|").last ?? "zone"),
                     ownerName: String(id.split(separator: "|").first ?? "owner"),
                     updatedAt: Date())
    }

    private func liveGame(opponent: String = "Hawks") -> Game {
        var game = Game(opponent: opponent)
        game.hasStarted = true
        return game
    }

    // MARK: - syncSharedState

    /// The bug that made publish-on-edit look broken: a team shared before the
    /// app tracked shared state isn't in `sharedTeamIDs`, so nothing ever
    /// published and its followers sat on a stale copy.
    @Test func syncAdoptsATeamCloudKitSaysIsShared() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        service.sharedTeamIDs = [store.team.id]

        #expect(!store.isShared(store.team.id))
        await store.syncSharedState()
        #expect(store.isShared(store.team.id))
    }

    /// Adoption must also push, or followers stay stale until the next edit.
    @Test func syncPublishesWhatItAdopts() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        service.sharedTeamIDs = [store.team.id]
        store.addGame(liveGame())

        await store.syncSharedState()
        #expect(service.published.contains { $0.team.id == store.team.id })
    }

    /// Sharing stopped elsewhere shouldn't leave this device publishing into a
    /// zone the owner deleted.
    @Test func syncDropsATeamNoLongerShared() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        store.markShared(store.team.id)
        service.sharedTeamIDs = []

        await store.syncSharedState()
        #expect(!store.isShared(store.team.id))
    }

    @Test func syncDoesNothingWithoutAService() async {
        let store = AppStore(inMemory: true)
        store.markShared(store.team.id)
        await store.syncSharedState()   // no service injected
        #expect(store.isShared(store.team.id))
    }

    // MARK: - applyFollowedTeams

    /// Accepting a share must not announce a season's worth of history.
    @Test func firstSnapshotIsSilent() async {
        let service = FakeSharingService()
        let store = makeStore(service)

        await store.applyFollowedTeams([followed(games: [liveGame()])])
        #expect(store.followedTeams.count == 1)
        // Nothing to assert on the notifier directly, but the alert builder is
        // the thing that decides — and it returns nothing without a previous
        // snapshot. Guarded here so a refactor can't quietly change it.
        #expect(FollowerAlertBuilder.alerts(previous: nil,
                                            current: store.followedTeams[0],
                                            cadence: .periodEnd).isEmpty)
    }

    @Test func applyReplacesTheSnapshot() async {
        let service = FakeSharingService()
        let store = makeStore(service)

        await store.applyFollowedTeams([followed(games: [])])
        await store.applyFollowedTeams([followed(games: [liveGame(), liveGame()])])

        #expect(store.followedTeams.count == 1)
        #expect(store.followedTeams[0].games.count == 2)
    }

    /// Cadence `.off` must reach the store, not just the UI — a follower who
    /// turned notifications off should get none even as data flows.
    @Test func cadenceOffStillUpdatesTheData() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        store.alertCadence = .off

        await store.applyFollowedTeams([followed(games: [liveGame()])])
        #expect(store.followedTeams[0].games.count == 1)
    }

    // MARK: - Publishing

    @Test func publishingSkipsTeamsThatArentShared() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        service.sharedTeamIDs = []

        await store.syncSharedState()
        #expect(service.published.isEmpty)
    }

    /// A publish failure must not mark the team unshared — the next edit should
    /// try again rather than silently stopping forever.
    @Test func aFailedPublishKeepsTheTeamShared() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        service.sharedTeamIDs = [store.team.id]
        service.publishError = SharingError.iCloudAccountUnavailable

        await store.syncSharedState()
        #expect(store.isShared(store.team.id))
    }

    /// Only the shared team's own games go up — a second team's games must not
    /// leak into someone else's share.
    @Test func publishCarriesOnlyThatTeamsGames() async {
        let service = FakeSharingService()
        let store = makeStore(service)

        store.addTeam(name: "Other Team")
        let otherID = store.activeTeamID
        store.addGame({ var g = liveGame(opponent: "Other"); g.teamID = otherID; return g }())

        let sharedID = store.teams[0].id
        store.setActiveTeam(sharedID)
        store.addGame({ var g = liveGame(opponent: "Ours"); g.teamID = sharedID; return g }())

        service.sharedTeamIDs = [sharedID]
        await store.syncSharedState()

        let push = service.published.first { $0.team.id == sharedID }
        #expect(push != nil)
        #expect(push?.games.allSatisfy { $0.teamID == sharedID } == true)
        #expect(push?.games.contains { $0.opponent == "Other" } == false)
    }

    // MARK: - Unsharing

    /// The reported bug: a team unshared from the system share sheet kept its
    /// "Shared" tag, because the sheet's `onStopped` callback was never wired
    /// up and nothing cleared local state.
    @Test func markNotSharedClearsTheSharedFlag() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        store.markShared(store.team.id)
        #expect(store.isShared(store.team.id))

        store.markNotShared(store.team.id)
        #expect(!store.isShared(store.team.id))
    }

    /// …and a later sync must not resurrect it, or the tag comes back on the
    /// next launch.
    @Test func syncDoesNotResurrectAnUnsharedTeam() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        store.markShared(store.team.id)
        service.sharedTeamIDs = []      // the server agrees it's no longer shared

        store.markNotShared(store.team.id)
        await store.syncSharedState()
        #expect(!store.isShared(store.team.id))
    }

    /// An unshared team must also stop publishing — otherwise edits keep
    /// uploading to a zone nobody can read.
    @Test func anUnsharedTeamStopsPublishing() async {
        let service = FakeSharingService()
        let store = makeStore(service)
        store.markShared(store.team.id)
        store.markNotShared(store.team.id)
        service.sharedTeamIDs = []

        await store.syncSharedState()
        #expect(service.published.isEmpty)
    }
}
