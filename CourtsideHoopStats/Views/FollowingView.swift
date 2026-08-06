import SwiftUI

/// What a follower sees: a team shared with them, read-only (#57).
///
/// Shows **one team at a time**, titled like the Games tab, with a title menu to
/// switch when you follow more than one — most people follow exactly one, and
/// that case shouldn't look like managing a collection (#69).
///
/// Game rows reuse `GameRowView`, the same component the Games tab uses, so the
/// two lists can't drift apart in font, badge, or layout. Only the destination
/// differs: a follower opens a read-only summary, never an editor.
struct FollowingView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.teamSharingService) private var sharing

    @State private var selectedTeamID: String?
    @State private var isRefreshing = false
    @State private var refreshError: String?

    /// The team being viewed — the chosen one, or the first followed team.
    private var selected: FollowedTeam? {
        store.followedTeams.first { $0.id == selectedTeamID } ?? store.followedTeams.first
    }

    var body: some View {
        NavigationStack {
            Group {
                if let followed = selected {
                    gameList(for: followed)
                } else {
                    emptyState
                }
            }
            .navigationTitle(selected?.team.name ?? "Following")
            .toolbar {
                // Only a real choice when there's more than one team to pick.
                if store.followedTeams.count > 1 {
                    ToolbarTitleMenu {
                        ForEach(store.followedTeams) { followed in
                            Button {
                                selectedTeamID = followed.id
                            } label: {
                                Label(followed.team.name,
                                      systemImage: followed.id == selected?.id ? "checkmark" : "")
                            }
                        }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh")
                }
            }
            .alert("Couldn't Refresh", isPresented: Binding(
                get: { refreshError != nil },
                set: { if !$0 { refreshError = nil } }
            )) {
                Button("OK", role: .cancel) { refreshError = nil }
            } message: {
                Text(refreshError ?? "")
            }
            .task { await refresh() }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Not Following Anyone", systemImage: "binoculars")
        } description: {
            Text("When someone shares their team with you, it appears here so you can follow their games and stats.")
        }
    }

    private func gameList(for followed: FollowedTeam) -> some View {
        List {
            // Status sits at the top, where it's read before the scores rather
            // than discovered under them. Its own section, but with the
            // grouping chrome stripped out — a one-line note shouldn't get a
            // full section's worth of padding above and below it.
            Section {
                statusLine(for: followed)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .listSectionSpacing(.compact)

            // Same section titles as the Games tab.
            ForEach(gameGroups(for: followed), id: \.title) { group in
                Section(group.title) {
                    ForEach(group.games) { game in
                        NavigationLink {
                            // Identified rather than passed by value: the view
                            // re-reads from the store, so a refresh reaches a
                            // game already open.
                            FollowedGameView(followedID: followed.id, gameID: game.id)
                        } label: {
                            GameRowView(game: game, ourName: followed.team.name)
                        }
                    }
                }
            }

            if followed.games.isEmpty {
                Section {
                    Text("No games yet")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .refreshable { await refresh() }
    }

    /// Honest about staleness rather than implying "live", and italic so it
    /// reads as a note about the data rather than part of it.
    private func statusLine(for followed: FollowedTeam) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "eye")
            Text("View only · updated \(followed.updatedAt, format: .relative(presentation: .named))")
        }
        .font(.footnote.italic())
        .foregroundStyle(.secondary)
    }

    /// A team's games split exactly the way the Games tab splits them.
    private func gameGroups(for followed: FollowedTeam) -> [GameGroup] {
        let live = followed.games
            .filter { $0.lifecycle == .inProgress }.sorted { $0.date > $1.date }
        let upcoming = followed.games
            .filter { $0.lifecycle == .scheduled }.sorted { $0.date < $1.date }
        let finished = followed.games
            .filter { $0.lifecycle == .complete }.sorted { $0.date > $1.date }

        return [
            GameGroup(title: "Playing Now", games: live),
            GameGroup(title: "Coming Up", games: upcoming),
            GameGroup(title: "Final Scores", games: finished),
        ].filter { !$0.games.isEmpty }
    }
    private func refresh() async {
        guard sharing.isAvailable, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        do {
            await store.applyFollowedTeams(try await sharing.fetchFollowedTeams())
        } catch {
            // Keep showing the cached snapshot; only report if we have nothing.
            if store.followedTeams.isEmpty {
                refreshError = error.localizedDescription
            }
        }
    }
}

/// One titled group of a followed team's games.
private struct GameGroup {
    let title: String
    let games: [Game]
}

// MARK: - Read-only game detail

/// A followed game, showing everything the owner's Game Summary shows — the
/// same box score and the same play-by-play — minus every way to change it.
///
/// Reuses `GameScoreCard`, `PlayerStatsTable`, `PeriodBreakdownGrid`, and
/// `EventLogView` rather than reimplementing them, so a follower's numbers can
/// never drift from the owner's. `EventLogView` already has a display-only mode
/// (no tap-to-edit, no swipe-to-delete), and the game is passed as a constant
/// binding, so there's nothing for an edit to write back to.
private struct FollowedGameView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.teamSharingService) private var sharing
    let followedID: String
    let gameID: UUID

    /// How often a live game re-fetches while you're watching it. Long enough
    /// not to drain a phone sitting on the bleachers, short enough that the
    /// score doesn't feel stale. Until push notifications land, this is what
    /// makes watching a game hands-off.
    private let livePollInterval: Duration = .seconds(20)

    /// The most recent basket, shown as a banner. A push notification is
    /// suppressed by iOS while the app is foregrounded, so without this a
    /// follower staring at the game gets the least feedback of anyone.
    @State private var flash: ScoreFlash?
    /// Events already seen, so only genuinely new ones flash. Seeded on first
    /// appearance rather than empty — otherwise opening a game mid-way would
    /// announce a basket from ten minutes ago.
    @State private var seenEventIDs: Set<UUID>?

    private var followed: FollowedTeam? {
        store.followedTeams.first { $0.id == followedID }
    }
    private var game: Game? {
        followed?.games.first { $0.id == gameID }
    }
    private var roster: [Player] { followed?.team.players ?? [] }
    private var teamName: String { followed?.team.name ?? "" }
    private var stats: [PlayerStats] { game?.stats(for: roster) ?? [] }

    var body: some View {
        Group {
            if let game {
                content(for: game)
            } else {
                // The game vanished from the share — deleted by the owner, or
                // the team was unshared while this screen was open.
                ContentUnavailableView {
                    Label("Game Unavailable", systemImage: "questionmark.circle")
                } description: {
                    Text("This game is no longer being shared with you.")
                }
            }
        }
        .navigationTitle(game.map { $0.opponent.isEmpty ? "Game" : "vs. \($0.opponent)" } ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .scoreToast($flash)
        .refreshable { await refresh() }
        .onChange(of: game?.events.count) { _, _ in flashNewestScore() }
        .task(id: game?.lifecycle) {
            // Only poll a game actually in progress; a finished game can't
            // change, and polling it would be pure battery cost.
            guard game?.lifecycle == .inProgress else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: livePollInterval)
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    /// Banner the newest basket that wasn't there before.
    private func flashNewestScore() {
        guard let game else { return }
        let ids = Set(game.events.map(\.id))

        // First look at this game establishes the baseline silently.
        guard let seen = seenEventIDs else {
            seenEventIDs = ids
            return
        }
        seenEventIDs = ids

        guard let event = game.events.last(where: { !seen.contains($0.id) }),
              event.type.points > 0,
              let player = roster.first(where: { $0.id == event.playerID }) else { return }

        flash = ScoreFlash(id: event.id,
                           playerName: player.firstName,
                           jerseyNumber: player.number,
                           label: event.type.scoreLogLabel,
                           teamScore: game.ourScore,
                           opponentScore: game.opponentScore)
    }

    private func refresh() async {
        guard sharing.isAvailable else { return }
        guard let teams = try? await sharing.fetchFollowedTeams() else { return }
        // Don't wipe a good cache on a transient failure returning nothing.
        if !teams.isEmpty { await store.applyFollowedTeams(teams) }
    }

    private func content(for game: Game) -> some View {
        List {
            Section {
                // The same card the owner's Game Summary leads with, not Live
                // Scoring's navy banner: that banner is built for glancing at
                // across a gym while scoring, and a follower is neither.
                GameScoreCard(game: game, ourName: teamName)
            }

            // Nothing else on the screen for a game that hasn't tipped off, and
            // a blank page reads as a failure to load rather than as "not yet".
            if game.lifecycle == .scheduled {
                Section {
                    Text("Scores and stats appear here once the game starts.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            // Log first, newest at the top: a follower is watching for the next
            // basket, and shouldn't have to scroll past a box score to find it.
            if !game.events.isEmpty {
                Section("Score Log") {
                    EventLogView(game: .constant(game),
                                 players: roster,
                                 isEditable: false,
                                 newestFirst: true,
                                 persist: {})
                }
            }

            // A game that hasn't tipped off would otherwise get a full roster of
            // zeros, contradicting the card above it.
            if game.lifecycle != .scheduled, !stats.isEmpty {
                Section("Player Stats") {
                    PlayerStatsTable(stats: stats, didNotPlay: game.didNotPlay(from: roster))
                }
            }

            if !game.periodBreakdown().isEmpty {
                Section("By Period") {
                    PeriodBreakdownGrid(game: game, ourName: teamName)
                }
            }
        }
    }
}
