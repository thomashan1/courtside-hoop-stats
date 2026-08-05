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
            // than discovered under them.
            Section {
                statusLine(for: followed)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Same section titles as the Games tab.
            ForEach(gameGroups(for: followed), id: \.title) { group in
                Section(group.title) {
                    ForEach(group.games) { game in
                        NavigationLink {
                            FollowedGameView(game: game,
                                             roster: followed.team.players,
                                             teamName: followed.team.name)
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
            store.followedTeams = try await sharing.fetchFollowedTeams()
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
/// Reuses `PlayerStatsTable`, `PeriodBreakdownGrid`, and `EventLogView` rather
/// than reimplementing them, so a follower's numbers can never drift from the
/// owner's. `EventLogView` already has a display-only mode (no tap-to-edit, no
/// swipe-to-delete), and the game is passed as a constant binding, so there's
/// nothing for an edit to write back to.
private struct FollowedGameView: View {
    let game: Game
    let roster: [Player]
    let teamName: String

    private var stats: [PlayerStats] { game.stats(for: roster) }

    var body: some View {
        List {
            Section {
                ScoreboardView(ourName: teamName,
                               ourScore: game.ourScore,
                               opponentName: game.opponent.isEmpty ? "Opponent" : game.opponent,
                               opponentScore: game.opponentScore,
                               periodLabel: periodLabel)
                    .listRowInsets(EdgeInsets())
            }

            if !game.periodBreakdown().isEmpty {
                Section("By Period") {
                    PeriodBreakdownGrid(game: game, ourName: teamName)
                }
            }

            if !stats.isEmpty {
                Section("Player Stats") {
                    PlayerStatsTable(stats: stats)
                }
            }

            if !game.events.isEmpty {
                Section("Score Log") {
                    EventLogView(game: .constant(game),
                                 players: roster,
                                 isEditable: false,
                                 persist: {})
                }
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game" : "vs. \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var periodLabel: String {
        switch game.lifecycle {
        case .complete:   return "Final"
        case .scheduled:  return "Scheduled"
        case .inProgress: return game.periodFormat.periodLabel(game.currentPeriod)
        }
    }
}
