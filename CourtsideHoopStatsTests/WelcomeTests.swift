import Testing
import Foundation
@testable import CourtsideHoopStats

/// Who sees the welcome screen, and what each choice leaves behind.
@MainActor
struct WelcomeTests {

    /// A store as a brand-new install has it: the blank starter team only.
    private func freshStore() -> AppStore {
        let store = AppStore(inMemory: true)
        let starter = Team(name: Team.starterName, players: [])
        store.teams = [starter]
        store.activeTeamID = starter.id
        return store
    }

    @Test func aBrandNewInstallIsWelcomed() {
        #expect(freshStore().needsWelcome)
    }

    /// Jean, and anyone else who has started keeping score.
    @Test func aDeviceWithItsOwnDataIsNot() {
        let players = freshStore()
        players.addPlayer(name: "Jake", number: "7")
        #expect(!players.needsWelcome)

        let named = freshStore()
        named.updateTeam(Team(id: named.activeTeamID, name: "Swish Warriors", players: []))
        #expect(!named.needsWelcome)
    }

    @Test func someoneAlreadyFollowingIsNot() async {
        let store = freshStore()
        await store.applyFollowedTeams([DemoData.makeFollowedTeam()])
        #expect(!store.needsWelcome)
    }

    /// Follow a Team: the Following tab, with nothing in it yet, and no
    /// Games or Roster for a team they don't keep.
    @Test func followingWaitsOnTheFollowingTab() {
        let store = freshStore()
        store.welcomeChoice = .follow
        #expect(!store.needsWelcome)
        #expect(store.isViewOnly)

        // Adding a team of their own later brings Games and Roster back.
        store.addTeam(name: "Hyde 6th graders")
        #expect(!store.isViewOnly)
    }

    /// Keep Score: the starter becomes their team, under its real name.
    @Test func keepingScoreNamesTheStarterTeam() {
        let store = freshStore()
        let starterID = store.activeTeamID
        store.startKeepingScore(teamName: "  Swish Warriors ")
        #expect(store.teams.map(\.name) == ["Swish Warriors"])
        #expect(store.activeTeamID == starterID)
        #expect(!store.needsWelcome)
        #expect(!store.isViewOnly)
    }
}
