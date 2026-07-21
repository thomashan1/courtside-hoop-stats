import SwiftUI

/// Navigation target for a game row, chosen from its lifecycle.
enum GameRoute: Hashable {
    case detail(UUID)   // scheduled — review/edit, then start
    case live(UUID)     // in progress — score it
    case summary(UUID)  // complete — read/edit summary
}

struct GamesListView: View {
    @EnvironmentObject var store: AppStore
    @State private var path: [GameRoute] = []
    /// A played game pending delete-confirmation (it has recorded scores).
    @State private var pendingDelete: Game?

    /// Pre-entered games not yet started, soonest first (active team only).
    private var scheduled: [Game] {
        store.activeTeamGames.filter { $0.lifecycle == .scheduled }.sorted { $0.date < $1.date }
    }
    /// In-progress and completed games, most recent first (active team only).
    private var played: [Game] {
        store.activeTeamGames.filter { $0.lifecycle != .scheduled }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.activeTeamGames.isEmpty {
                    ContentUnavailableView {
                        Label("No Games Yet", systemImage: "basketball")
                    } description: {
                        Text("Tap ✚ to start your first game.")
                    }
                }

                if !scheduled.isEmpty {
                    Section("Upcoming") {
                        ForEach(scheduled) { row($0) }
                            .onDelete { delete(scheduled, $0) }
                    }
                }

                if !played.isEmpty {
                    Section {
                        ForEach(played) { row($0) }
                            .onDelete { offsets in
                                // Played games have recorded scores — confirm.
                                if let i = offsets.first { pendingDelete = played[i] }
                            }
                    } header: {
                        if !scheduled.isEmpty { Text("Games") }
                    }
                }
            }
            // Show the active team name (multi-team) — the tab bar labels it "Games".
            .navigationTitle(store.team.name)
            .confirmationDialog("Delete this game?",
                                isPresented: Binding(get: { pendingDelete != nil },
                                                     set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete Game & Scores", role: .destructive) {
                    if let game = pendingDelete { store.deleteGame(id: game.id) }
                    pendingDelete = nil
                }
                Button("Cancel", role: .cancel) { pendingDelete = nil }
            } message: {
                if let game = pendingDelete {
                    let name = game.opponent.isEmpty ? "This game" : "“vs \(game.opponent)”"
                    Text("\(name) and its recorded scores will be deleted. This can't be undone.")
                }
            }
            .navigationDestination(for: GameRoute.self) { destination($0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // No setup required — create the game and jump straight into
                    // scoring. Opponent, date, location, etc. are filled in later
                    // from the in-game Details editor (#44).
                    Button {
                        startNewGame()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Game")
                    #if DEBUG
                    // Easter egg: long-press to drop in a random finished game
                    // with realistic stats, for exercising the UI.
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.7).onEnded { _ in
                            store.addGame(DemoData.randomGame(team: store.team))
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    )
                    #endif
                }
            }
        }
    }

    private func row(_ game: Game) -> some View {
        NavigationLink(value: route(for: game)) {
            GameRowView(game: game, ourName: store.team.name)
        }
    }

    private func route(for game: Game) -> GameRoute {
        switch game.lifecycle {
        case .scheduled:  return .detail(game.id)
        case .inProgress: return .live(game.id)
        case .complete:   return .summary(game.id)
        }
    }

    @ViewBuilder
    private func destination(_ route: GameRoute) -> some View {
        switch route {
        case .detail(let id):
            // Starting from the detail screen replaces the stack so backing out
            // of scoring returns to the list, not the (now-started) detail.
            GameDetailView(gameID: id) { path = [.live($0)] }
        case .live(let id):
            LiveScoringView(gameID: id)
        case .summary(let id):
            GameSummaryView(gameID: id)
        }
    }

    private func delete(_ list: [Game], _ offsets: IndexSet) {
        for index in offsets { store.deleteGame(id: list[index].id) }
    }

    /// Create a game with no required setup and jump straight into scoring.
    /// Defaults to the quarters format; opponent, date, location, and league are
    /// all optional and editable later from the in-game Details editor (#44).
    private func startNewGame() {
        var game = Game(opponent: "")
        game.hasStarted = true
        store.addGame(game)
        path.append(.live(game.id))
    }
}

// MARK: - Row

struct GameRowView: View {
    let game: Game
    let ourName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(game.opponent.isEmpty ? "New Game" : "vs \(game.opponent)")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(game.date.formatted(date: .abbreviated, time: .shortened))
                    if !game.location.isEmpty {
                        Text("·")
                        Text(game.location)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer()

            trailing
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var trailing: some View {
        switch game.lifecycle {
        case .complete:
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(game.ourScore)–\(game.opponentScore)")
                    .font(.headline)
                    .monospacedDigit()
                resultBadge
            }
        case .inProgress:
            badge("In Progress", color: .teamAccent)
        case .scheduled:
            badge("Scheduled", color: .secondary)
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2).bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.2)))
            .foregroundStyle(color)
    }

    private var resultBadge: some View {
        let (text, color): (String, Color) = {
            switch game.result {
            case .win:  return ("W", .teamAccent)
            case .loss: return ("L", .red)
            case .tie:  return ("T", .gray)
            }
        }()
        return Text(text)
            .font(.caption2).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Capsule().fill(color))
    }
}

#Preview {
    GamesListView()
        .environmentObject(AppStore())
}
