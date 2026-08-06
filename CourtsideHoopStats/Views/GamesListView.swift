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
    /// Presents the New Game form (#44 — every field optional; Start or Save).
    @State private var showingNewGame = false
    /// Presents the followers list for the active team.
    @State private var showFollowers = false
    /// How many people follow the active team, once we've asked CloudKit.
    /// `nil` means "not asked yet, or the ask failed" — the marker still shows,
    /// just without a number.
    @State private var followerCount: Int?

    @Environment(\.teamSharingService) private var sharing

    /// This tab is the *owner's* view. When the team is also shared, that has
    /// to be visible here — otherwise the Games tab and the Following tab look
    /// alike, and the only cue that you're the one whose taps change the score
    /// is which tab you happen to be on (#93).
    ///
    /// Mirrors the Following tab, which puts "Updated Just Now" in the same
    /// slot: same position, opposite meaning.
    /// Pluralised by hand: `.navigationSubtitle` takes a plain `String`, so
    /// `^[…](inflect:)` markup is passed straight through and rendered
    /// literally rather than resolved.
    private var sharedSubtitle: String {
        guard store.isShared(store.team.id) else { return "" }
        guard let followerCount, followerCount > 0 else { return "Shared" }
        return followerCount == 1 ? "Shared with 1 follower"
                                  : "Shared with \(followerCount) followers"
    }

    /// Games being scored right now. Listed first — a game in progress is the
    /// only thing you'd open the app mid-game to reach.
    private var live: [Game] {
        store.activeTeamGames.filter { $0.lifecycle == .inProgress }.sorted { $0.date > $1.date }
    }
    /// Pre-entered games not yet started, soonest first (active team only).
    private var scheduled: [Game] {
        store.activeTeamGames.filter { $0.lifecycle == .scheduled }.sorted { $0.date < $1.date }
    }
    /// Finished games, most recent first (active team only).
    private var finished: [Game] {
        store.activeTeamGames.filter { $0.lifecycle == .complete }.sorted { $0.date > $1.date }
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

                // Live first: mid-game, this is the row you're reaching for.
                if !live.isEmpty {
                    Section("Playing Now") {
                        ForEach(live) { row($0) }
                            .onDelete { offsets in
                                // Has a score already — confirm before losing it.
                                if let i = offsets.first { pendingDelete = live[i] }
                            }
                    }
                }

                if !scheduled.isEmpty {
                    Section("Coming Up") {
                        ForEach(scheduled) { row($0) }
                            .onDelete { delete(scheduled, $0) }
                    }
                }

                if !finished.isEmpty {
                    Section("Final Scores") {
                        ForEach(finished) { row($0) }
                            .onDelete { offsets in
                                // Played games have recorded scores — confirm.
                                if let i = offsets.first { pendingDelete = finished[i] }
                            }
                    }
                }
            }
            // Show the active team name (multi-team) — the tab bar labels it "Games".
            .navigationTitle(store.team.name)
            .navigationSubtitle(sharedSubtitle)
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
            .sheet(isPresented: $showingNewGame) {
                NewGameSheet(onStartNow: { path.append(.live($0)) })
            }
            // Declared out here rather than inside the toolbar: a sheet inherits
            // the environment of wherever it's declared, and that has bitten
            // this app before (a followers sheet opened from the navy
            // scoreboard bar inherited its forced white text).
            .sheet(isPresented: $showFollowers) {
                FollowersView(team: store.team)
            }
            .toolbar {
                if store.isShared(store.team.id) {
                    ToolbarItem(placement: .topBarTrailing) {
                        // "Who can see this?" — the same question the live
                        // scoring screen answers, asked from the tab you're on
                        // between games.
                        Button {
                            showFollowers = true
                        } label: {
                            Image(systemName: "person.2.fill")
                                .minimumTapTarget()
                        }
                        .accessibilityLabel(sharedSubtitle.isEmpty ? "Followers" : sharedSubtitle)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Open the New Game form — every field is optional. "Start
                    // Game" begins scoring immediately; "Save" schedules it for
                    // later (#44).
                    Button {
                        showingNewGame = true
                    } label: {
                        Image(systemName: "plus")
                            .minimumTapTarget()
                    }
                    .accessibilityLabel("New Game")
                }
            }
            // Best-effort. A failure leaves the subtitle reading "Shared"
            // without a count, which is still true.
            .task(id: store.activeTeamID) {
                guard store.isShared(store.team.id) else {
                    followerCount = nil
                    return
                }
                followerCount = (try? await sharing.participants(for: store.team))?
                    .filter { !$0.isOwner }.count
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

// MARK: - New Game form (#44)

/// Create a game: fill in as much or as little as you want — **every field is
/// optional**. "Start Game" begins scoring immediately; "Save" schedules it for
/// later. Anything left blank is editable mid-game from the Details editor.
struct NewGameSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// Called after the game is created via "Start Game", to navigate into it.
    var onStartNow: (UUID) -> Void

    @State private var opponent = ""
    @State private var date = Date()
    @State private var league = ""
    @State private var location = ""
    @State private var locationAddress = ""
    @State private var isHome = true
    @State private var periodFormat: PeriodFormat = .quarters

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    LabeledContent("Date & Time") {
                        GameDatePicker(selection: $date)
                    }
                    SuggestingTextField(title: "League / Tournament",
                                        text: $league, suggestions: store.knownLeagues)
                    LocationField(title: "Location / Gym",
                                  text: $location, address: $locationAddress,
                                  priorValues: store.knownLocations)
                    Picker("Format", selection: $periodFormat) {
                        ForEach(PeriodFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    Toggle("Home game", isOn: $isHome)
                        .tint(.teamAccent)
                    LabeledContent("Jersey") {
                        JerseyIndicator(color: store.team.jersey(isHome: isHome))
                    }
                }

                Section("Opponent") {
                    TextField("Opponent (optional)", text: $opponent)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    Button {
                        start()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Game", systemImage: "play.fill")
                                .labelStyle(.titleAndIcon)
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } footer: {
                    Text("Nothing here is required. **Start Game** begins scoring now; **Save** schedules it for later. You can edit any of this mid-game from Details.")
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
                }
            }
        }
    }

    private func makeGame(started: Bool) -> Game {
        let cleanLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        var game = Game(
            date: date,
            opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines),
            league: league.trimmingCharacters(in: .whitespacesAndNewlines),
            location: cleanLocation,
            locationAddress: cleanLocation.isEmpty ? "" : locationAddress,
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
                    // When these compete for width the gym name gives way, not
                    // the tip-off time — "which day, what time" is the question
                    // this row exists to answer.
                    Text(game.date.gameDayCompact)
                        .layoutPriority(1)
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
        StatusBadge(text: text, color: color, compact: true)
    }

    private var resultBadge: some View {
        let (text, color): (String, Color) = {
            switch game.result {
            case .win:  return ("W", .teamAccent)
            case .loss: return ("L", .red)
            case .tie:  return ("T", .secondary)
            }
        }()
        return StatusBadge(text: text, color: color, compact: true)
    }
}

#Preview {
    GamesListView()
        .environmentObject(AppStore())
}
