import SwiftUI

/// Root tab container: games, roster, and app settings.
struct ContentView: View {
    private enum Tab: String, Hashable {
        case games, roster, following, settings
    }

    /// The tab the app was last on, so a relaunch (after iOS has closed the
    /// app) reopens where you left off rather than always on Games.
    private static let lastTabKey = "lastSelectedTab"

    @EnvironmentObject var store: AppStore
    @Environment(\.teamSharingService) private var sharing
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: Tab = .games

    var body: some View {
        Group {
            // A brand-new install says what it's for first, instead of
            // landing on Games with a blank placeholder team.
            if store.needsWelcome {
                WelcomeView()
            } else {
                tabs
            }
        }
        // Leaving the welcome lands on the tab that matches the choice.
        .onChange(of: store.tabRequest) { _, request in
            guard let request else { return }
            selectedTab = request == .follow ? .following : .games
            store.tabRequest = nil
        }
        // Apply the in-app Text Size as a Dynamic Type floor for the whole app.
        .dynamicTypeSize(AppTextSize.floor(for: store.textSizeIndex)...)
        // Jersey bubbles across Games, Roster and Live Scoring belong to the
        // active team. A follower's screens override this with the team they're
        // watching, which is someone else's.
        .environment(\.teamKitColor, store.team.kitColor)
        // Reopen on the last tab. Failing that: a pure follower has no
        // Games/Roster tabs, so start them on Following rather than a tab
        // that no longer exists (#115).
        //
        // Note this is deliberately *not* "start on the first tab". Following
        // is leftmost for anyone who has it (#189), but a tracker who also
        // follows should still land on their own games — leftmost and
        // default-selected are different questions.
        .onAppear {
            selectedTab = initialTab
        }
        // Sync while the app is open, so the other device's changes show up
        // without a relaunch. Cheap: a pull with nothing new is one request.
        .task(id: store.syncAcrossDevices) {
            guard store.syncAcrossDevices else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                if scenePhase == .active { await store.syncNow() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await store.syncNow() } }
        }
        .onChange(of: selectedTab) { _, tab in
            UserDefaults.standard.set(tab.rawValue, forKey: Self.lastTabKey)
        }
        .task {
            // Pull the owner's other devices first (#229), so anything
            // published to followers below is already the merged copy.
            await store.syncNow()
            await discoverFollowedTeams()
            // Silent at launch, like discovery: the cached copy still shows.
            try? await store.refreshICloudTeams()
            // A view-only device opened on Games before its teams loaded.
            if store.isViewOnly, selectedTab == .games { selectedTab = .following }
        }
        // CloudKit woke us: re-fetch, which posts any alerts worth posting.
        .onReceive(NotificationCenter.default.publisher(for: .sharedDataChanged)) { note in
            let completion = note.object as? (UIBackgroundFetchResult) -> Void
            Task {
                // Either the owner's other device changed something (#229) or
                // a followed team did; both checks are one request each.
                await store.syncNow()
                let refreshed = await refreshFollowedTeams()
                completion?(refreshed ? .newData : .noData)
            }
        }
        // A share invite just got accepted — jump straight to it rather than
        // leaving the person to notice a new tab appeared on its own (#116).
        .onChange(of: store.followedTeams.count) { old, new in
            if new > old { selectedTab = .following }
        }
        // The tap that opened the app is doing real network work; without
        // this the app just looks stuck until it finishes (#116).
        .overlay {
            if store.isAcceptingShare {
                ProgressView("Adding shared team…")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .alert("Couldn't Add Shared Team", isPresented: Binding(
            get: { store.shareAcceptanceError != nil },
            set: { if !$0 { store.shareAcceptanceError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.shareAcceptanceError ?? "")
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            // **First**, for anyone who has it (#189). The tab only exists
            // when you actually follow someone (#57) — a tracker running only
            // their own team never sees it — so putting it left costs nothing
            // for them, and it matches what a follower-only person already
            // sees, where Following is the first tab by default.
            //
            // The trade: someone who both owns and follows loses Games as
            // their leftmost tab. Worth it because the reason to open the app
            // as a follower is time-sensitive (a game happening now), while
            // the reason to open it as a tracker is deliberate.
            //
            // It also carries this person's own teams from iCloud on a device
            // with no data of its own (#229) — named for that when there's
            // nothing followed, since "Following" your own team reads wrong.
            //
            // And for someone who chose Follow a Team on the welcome screen,
            // before anything is shared with them: it's where they wait.
            if !store.viewedTeams.isEmpty || store.isViewOnly {
                FollowingView()
                    .tabItem {
                        if store.followedTeams.isEmpty && !store.iCloudTeams.isEmpty {
                            Label("My Teams", systemImage: "icloud")
                        } else {
                            Label("Following", systemImage: "binoculars")
                        }
                    }
                    .tag(Tab.following)
            }

            // Hidden for a pure follower (#115) — someone who only watches
            // others' teams and has never touched their own local, blank
            // default team. Reappears the moment they add a player or a game.
            if !store.isViewOnly {
                GamesListView()
                    .tabItem { Label("Games", systemImage: "list.clipboard") }
                    .tag(Tab.games)

                RosterView()
                    .tabItem { Label("Roster", systemImage: "person.3.fill") }
                    .tag(Tab.roster)
            }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }

    /// The remembered tab if it still exists; otherwise the old defaults. The
    /// screenshot harness always starts on the default so its runs don't
    /// depend on where the previous one ended.
    private var initialTab: Tab {
        let fallback: Tab = store.isViewOnly ? .following : .games
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedDemo") { return fallback }
        #endif
        guard let raw = UserDefaults.standard.string(forKey: Self.lastTabKey),
              let tab = Tab(rawValue: raw) else { return fallback }
        switch tab {
        case .following: return store.viewedTeams.isEmpty && !store.isViewOnly ? fallback : tab
        case .games, .roster: return store.isViewOnly ? fallback : tab
        case .settings: return tab
        }
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
            await store.applyFollowedTeams(teams)
        }

        guard !teams.isEmpty else { return }
        // Only once something is actually shared with you: a permission prompt
        // on first launch has no context, and gets declined.
        await FollowerNotifier.shared.requestAuthorizationIfNeeded()
        try? await sharing.subscribeToFollowedTeamChanges()
    }

    @discardableResult
    private func refreshFollowedTeams() async -> Bool {
        guard sharing.isAvailable,
              let teams = try? await sharing.fetchFollowedTeams(),
              !teams.isEmpty else { return false }
        await store.applyFollowedTeams(teams)
        return true
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
