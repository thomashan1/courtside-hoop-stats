import SwiftUI

/// What a follower sees: a team shared with them, read-only (#57).
///
/// Shows **one team at a time**, titled like the Games tab, with a toolbar menu
/// to switch when you follow more than one — most people follow exactly one,
/// and that case shouldn't look like managing a collection (#69). A plain
/// `Menu` in a `ToolbarItem`, not `ToolbarTitleMenu`: the latter never opened
/// when tapped (#121), for reasons that didn't isolate to anything in this
/// file's own code.
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
    /// Set while confirming an unfollow (#123); presenting the dialog.
    @State private var pendingUnfollow: FollowedTeam?
    @State private var isUnfollowing = false
    @State private var unfollowError: String?

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
            // Freshness (and who shared it, #120) belongs in chrome, not
            // content: it's always visible, system-styled, and costs no room
            // above the scores. Mail and Podcasts show last-updated the same
            // way.
            .navigationSubtitle(selected?.subtitle ?? "")
            // The team being watched, not the active one — a follower's jersey
            // bubbles belong to someone else's team.
            .environment(\.teamKitColor, selected?.team.kitColor ?? .blue)
            .toolbar {
                // Only a real choice when there's more than one team to pick.
                // A plain toolbar `Menu` (#121) rather than `ToolbarTitleMenu`:
                // the latter never actually opened when tapped — confirmed with
                // hardcoded content, no subtitle, no sibling toolbar item, and
                // unconditionally rendered, so the fix is a menu we control and
                // can verify opens, not a further attempt at the built-in one.
                if store.followedTeams.count > 1 {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            // A `Picker`, not a hand-built `ForEach` of
                            // `Button`s with a conditional checkmark: passing
                            // `systemImage: ""` for the unselected rows
                            // doesn't reserve icon space the way an actual
                            // (even hidden) icon would, so those rows' text
                            // started further left than the checked one —
                            // visibly misaligned. A native `Picker` inside a
                            // `Menu` renders its own consistent checkmark
                            // column, the same way Files' "Sort By" menu does.
                            Picker("Team", selection: Binding(
                                get: { selected?.id ?? "" },
                                set: { selectedTeamID = $0 }
                            )) {
                                ForEach(store.followedTeams) { followed in
                                    Text(followed.team.name).tag(followed.id)
                                }
                            }
                        } label: {
                            Image(systemName: "person.2.fill")
                                .minimumTapTarget()
                        }
                        .accessibilityLabel("Switch Team")
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
                                .minimumTapTarget()
                        }
                    }
                    .disabled(isRefreshing)
                    .accessibilityLabel("Refresh")
                }
                // Only once there's a team to act on — matches every other
                // toolbar item here in reading `selected`, not `store` directly.
                if let selected {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(role: .destructive) {
                                pendingUnfollow = selected
                            } label: {
                                Label("Unfollow \(selected.team.name)",
                                      systemImage: "binoculars.fill")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .minimumTapTarget()
                        }
                        .accessibilityLabel("More")
                    }
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
            .confirmationDialog(
                "Unfollow \"\(pendingUnfollow?.team.name ?? "")\"?",
                isPresented: Binding(get: { pendingUnfollow != nil },
                                     set: { if !$0 { pendingUnfollow = nil } }),
                titleVisibility: .visible
            ) {
                Button("Unfollow", role: .destructive) {
                    if let team = pendingUnfollow {
                        Task { await unfollow(team) }
                    }
                    pendingUnfollow = nil
                }
                Button("Cancel", role: .cancel) { pendingUnfollow = nil }
            } message: {
                Text("You'll stop seeing their games and stats. They can invite you again anytime.")
            }
            .alert("Couldn't Unfollow", isPresented: Binding(
                get: { unfollowError != nil },
                set: { if !$0 { unfollowError = nil } }
            )) {
                Button("OK", role: .cancel) { unfollowError = nil }
            } message: {
                Text(unfollowError ?? "")
            }
            .disabled(isUnfollowing)
            .task { await refresh() }
        }
    }

    /// Removes just this device's acceptance (#123) — the owner's copy and
    /// any other follower are untouched. Local state only updates on success,
    /// so a failed unfollow leaves the team right where it was.
    private func unfollow(_ team: FollowedTeam) async {
        isUnfollowing = true
        defer { isUnfollowing = false }
        do {
            try await sharing.unfollow(team)
            store.removeFollowedTeam(id: team.id)
            if selectedTeamID == team.id { selectedTeamID = nil }
        } catch {
            unfollowError = error.localizedDescription
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
            // TEMPORARY (#128): the nav subtitle truncates this to one line,
            // too short for a full field dump — shown here instead, where it
            // can wrap. Remove once the real cause is confirmed.
            if let name = followed.sharedByName, name.hasPrefix("[debug:") {
                Section {
                    Text(name)
                        .font(.footnote.monospaced())
                        .textSelection(.enabled)
                }
            }

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

            // Below the fold, where iOS puts explanatory non-actionable text —
            // and mirroring the wording the owner sees in FollowersView. No
            // persistent badge: Apple's own shared Notes and albums convey
            // read-only by simply having no edit affordances, which this
            // screen already does.
            Section {} footer: {
                Text("You can see this team's games and stats, but can't change them.")
            }
        }
        .refreshable { await refresh() }
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

    /// The rendered box score (#91). Regenerated whenever the game changes, so
    /// a follower never shares a score that's already moved on.
    @State private var pdfURL: URL?
    @State private var showingPDF = false

    /// How often a live game re-fetches while you're watching it. Long enough
    /// not to drain a phone sitting on the bleachers, short enough that the
    /// score doesn't feel stale. Until push notifications land, this is what
    /// makes watching a game hands-off.
    private let livePollInterval: Duration = .seconds(20)

    /// The most recent basket, shown as a banner. A push notification is
    /// suppressed by iOS while the app is foregrounded, so without this a
    /// follower staring at the game gets the least feedback of anyone.
    @State private var flash: ScoreFlash?
    /// Drives the live dot's pulse in the team-colour banner.
    @State private var livePulse = false
    /// Scales with the label beside it — a fixed 9pt dot next to accessibility-
    /// sized LIVE text reads as a speck.
    @ScaledMetric(relativeTo: .caption2) private var liveDotSize: CGFloat = 9
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        // Only while it's live: watching a game in progress, how far behind the
        // score might be is the most useful thing on screen. A final can't go
        // stale, so there the same line would be noise.
        .navigationSubtitle(game?.lifecycle == .inProgress
                            ? (followed?.updatedAt.updatedLabel ?? "") : "")
        .environment(\.teamKitColor, followed?.team.kitColor ?? .blue)
        .navigationBarTitleDisplayMode(.inline)
        .scoreToast($flash)
        .toolbar {
            // A follower has as much reason to send the box score to family as
            // the tracker does. Finished games only, matching the owner: the
            // page is a box score — it stamps FINAL and a win/loss result, so
            // rendering a game still in progress would state an outcome that
            // hasn't happened.
            if let game, game.lifecycle == .complete, pdfURL != nil {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingPDF = true
                    } label: {
                        Label("Box Score PDF", systemImage: "square.and.arrow.up")
                            .minimumTapTarget()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPDF) {
            if let pdfURL, let game {
                GameSummaryPDFPreview(url: pdfURL,
                                      shareTitle: GameSummaryPDF.title(for: game,
                                                                       teamName: teamName))
            }
        }
        .onChange(of: game?.events.count) { _, _ in regeneratePDF() }
        .onChange(of: game?.lifecycle) { _, _ in regeneratePDF() }
        .task { regeneratePDF() }
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

    /// Renders from the followed team's own roster — never `store.team`, which
    /// is a different team entirely.
    private func regeneratePDF() {
        guard let game, game.lifecycle == .complete else {
            pdfURL = nil
            return
        }
        pdfURL = GameSummaryPDF.render(game: game, teamName: teamName, roster: roster,
                                       kit: followed?.team.kitColor ?? .blue)
    }

    private func refresh() async {
        guard sharing.isAvailable else { return }
        guard let teams = try? await sharing.fetchFollowedTeams() else { return }
        // Don't wipe a good cache on a transient failure returning nothing.
        if !teams.isEmpty { await store.applyFollowedTeams(teams) }
    }

    /// The "live now" marker, in the shape everything else uses: a green dot
    /// and the word LIVE.
    ///
    /// Two things stop the convention breaking on a team's own colour. The dot
    /// carries a ring, so it still reads as a dot when the band behind it is
    /// **green** — one of the nine kit colours, where a bare green dot would
    /// vanish. And the pair sits on a wash of the band's foreground colour,
    /// which separates the badge from any kit without needing a colour of its
    /// own.
    private var liveBadge: some View {
        let kit = followed?.team.kitColor ?? .blue
        return HStack(spacing: 5) {
            Circle()
                .fill(Color(.systemGreen))
                .overlay(Circle().strokeBorder(kit.onSwatch.opacity(0.7), lineWidth: 1))
                .frame(width: liveDotSize, height: liveDotSize)
                // Pulsing opacity rather than scale: a dot that changes size
                // nudges the text beside it.
                .opacity(livePulse ? 0.35 : 1)
                .animation(reduceMotion ? nil
                           : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                           value: livePulse)
            Text("LIVE")
                .font(.caption2.weight(.heavy))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(kit.onSwatch.opacity(0.16)))
        .onAppear { livePulse = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Live now")
    }

    private func content(for game: Game) -> some View {
        List {
            Section {
                GameHeaderCard(game: game, ourName: teamName,
                               kit: followed?.team.kitColor ?? .blue) {
                    Label {
                        Text("Following").font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "binoculars.fill").font(.caption)
                    }
                } trailing: {
                    if game.lifecycle == .inProgress { liveBadge }
                }
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
                Section {
                    EventLogView(game: .constant(game),
                                 players: roster,
                                 isEditable: false,
                                 newestFirst: true,
                                 persist: {})
                } header: {
                    // Says which way the log runs. It's the opposite of the
                    // scoring screen, where the log is oldest-first and scrolls
                    // to follow the game — and a log you can't tell the
                    // direction of reads as one in the wrong order.
                    HStack {
                        Text("Score Log")
                        Spacer()
                        Text("Most recent on top")
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
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
