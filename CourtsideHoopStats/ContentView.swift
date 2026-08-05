import SwiftUI

/// Root tab container: games, roster, and app settings.
struct ContentView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.teamSharingService) private var sharing

    var body: some View {
        TabView {
            GamesListView()
                .tabItem { Label("Games", systemImage: "list.clipboard") }

            RosterView()
                .tabItem { Label("Roster", systemImage: "person.3.fill") }

            // Only for people actually following someone (#57) — a tracker
            // running their own team should never see an empty extra tab.
            if !store.followedTeams.isEmpty {
                FollowingView()
                    .tabItem { Label("Following", systemImage: "binoculars") }
            }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        // Apply the in-app Text Size as a Dynamic Type floor for the whole app.
        .dynamicTypeSize(AppTextSize.floor(for: store.textSizeIndex)...)
        .task { await discoverFollowedTeams() }
    }

    /// Look for teams shared with this user at launch (#57).
    ///
    /// This has to live *above* the Following tab, not inside it: the tab only
    /// appears once `followedTeams` is non-empty, so a fetch that ran only from
    /// inside it could never populate it in the first place. Without this, a
    /// follower who reinstalled the app — or whose accept notification was
    /// missed — would have no way to see shares they'd already accepted.
    private func discoverFollowedTeams() async {
        guard sharing.isAvailable else { return }

        // Reconcile which of my own teams are shared before looking at what
        // others have shared with me — this is what makes an owner's edits
        // publish again after sharing from an older build or another device.
        await store.syncSharedState()
        // Silent: at launch there's no sensible place to report a failure, and
        // the cached snapshot still shows. The Following tab's own refresh
        // surfaces errors where the user can act on them.
        guard let teams = try? await sharing.fetchFollowedTeams() else { return }
        // Don't clobber a good cache with an empty result — a transient auth or
        // network hiccup shouldn't make someone's followed teams vanish.
        if !teams.isEmpty || store.followedTeams.isEmpty {
            store.followedTeams = teams
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
