import SwiftUI

/// Navigation target for a game row, chosen from its lifecycle.
enum GameRoute: Hashable {
    case detail(UUID)   // scheduled — review/edit, then start
    case live(UUID)     // in progress — score it
    case summary(UUID)  // complete — read/edit summary
}

struct GamesListView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingNewGame = false
    @State private var path: [GameRoute] = []
    /// Set by the New Game sheet's "Start Now" so we can navigate once it dismisses.
    @State private var pendingStartID: UUID?

    /// Pre-entered games not yet started, soonest first.
    private var scheduled: [Game] {
        store.games.filter { $0.lifecycle == .scheduled }.sorted { $0.date < $1.date }
    }
    /// In-progress and completed games, most recent first.
    private var played: [Game] {
        store.games.filter { $0.lifecycle != .scheduled }.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.games.isEmpty {
                    ContentUnavailableView {
                        Label("No Games Yet", systemImage: "basketball")
                    } description: {
                        Text("Tap ✚ to schedule or start your first game.")
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
                            .onDelete { delete(played, $0) }
                    } header: {
                        if !scheduled.isEmpty { Text("Games") }
                    }
                }
            }
            .navigationTitle("Games")
            .navigationDestination(for: GameRoute.self) { destination($0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewGame = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewGame) {
                NewGameSheet(onStartNow: { pendingStartID = $0 })
            }
            .onChange(of: showingNewGame) { _, presented in
                // Navigate into scoring only after the sheet has fully dismissed.
                if !presented, let id = pendingStartID {
                    pendingStartID = nil
                    path.append(.live(id))
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
}

// MARK: - Row

struct GameRowView: View {
    let game: Game
    let ourName: String

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("vs \(game.opponent)")
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(game.date, style: .date)
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

// MARK: - New game

struct NewGameSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// Called when the user taps "Start Now" (after the game is created).
    var onStartNow: (UUID) -> Void

    @State private var opponent = ""
    @State private var date = Date()
    @State private var league = ""
    @State private var location = ""
    @State private var isHome = true
    @State private var periodFormat: PeriodFormat = .quarters

    private var trimmedOpponent: String {
        opponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private var canSave: Bool { !trimmedOpponent.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    SuggestingTextField(title: "League / Tournament",
                                        text: $league, suggestions: store.knownLeagues)
                    LocationField(title: "Location / Gym",
                                  text: $location, priorValues: store.knownLocations)
                    Picker("Format", selection: $periodFormat) {
                        ForEach(PeriodFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                }

                Section("Matchup") {
                    TextField("Opponent", text: $opponent)
                        .textInputAutocapitalization(.words)
                    Toggle("Home game", isOn: $isHome)
                        .tint(.teamAccent)
                    LabeledContent("Jersey") {
                        JerseyIndicator(color: store.team.jersey(isHome: isHome))
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section {
                    Button {
                        start()
                    } label: {
                        Label("Start Now", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave)
                } footer: {
                    Text("**Save** to schedule this game for later, or **Start Now** to begin scoring immediately.")
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    private func makeGame(started: Bool) -> Game {
        var game = Game(
            date: date,
            opponent: trimmedOpponent,
            league: league.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            isHome: isHome,
            periodFormat: periodFormat
        )
        game.hasStarted = started
        return game
    }

    private func save() {
        store.addGame(makeGame(started: false))
        dismiss()
    }

    private func start() {
        let game = makeGame(started: true)
        store.addGame(game)
        onStartNow(game.id)
        dismiss()
    }
}

#Preview {
    GamesListView()
        .environmentObject(AppStore())
}
