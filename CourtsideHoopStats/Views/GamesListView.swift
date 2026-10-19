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
    /// The tournament being renamed, and the name being typed.
    @State private var renaming: TournamentGroup?
    @State private var newTournamentName = ""

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

    /// Final scores by tournament, once any game has a league. A team that
    /// never fills one in keeps a plain Final Scores list.
    private var finishedByTournament: [TournamentGroup]? {
        let groups = Tournaments.groups(finished)
        return Tournaments.named(groups) ? groups : nil
    }

    // MARK: - Layout (#232)

    @Environment(\.horizontalSizeClass) private var sizeClass
    /// iPad: the game open beside the list.
    @State private var selection: GameRoute?
    /// iPad: a game being scored. Live Scoring takes the whole screen there
    /// too — it's the one screen that needs every point of it.
    @State private var scoringGameID: UUID?
    @State private var columns: NavigationSplitViewVisibility = .all

    private var isSplit: Bool { sizeClass == .regular }

    var body: some View {
        if isSplit {
            // iPad: the list beside the game it opened.
            NavigationSplitView(columnVisibility: $columns) {
                gameList(List(selection: $selection) { listContent })
                    .navigationSplitViewColumnWidth(min: 300, ideal: 360, max: 440)
            } detail: {
                NavigationStack { detailColumn }
                    // A fresh stack per game, so nothing pushed inside one
                    // game's detail is left showing under the next.
                    .id(selection)
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: selection) { _, route in
                // A game in progress opens straight into scoring.
                if case .live(let id) = route {
                    selection = nil
                    scoringGameID = id
                }
            }
            // The open game moved on — started, finished, or deleted from
            // another device — so the detail follows it.
            .onChange(of: store.games) { _, _ in followSelection() }
            .onChange(of: store.activeTeamID) { _, _ in selection = openingSelection }
            // Open on a game rather than an empty pane, as Notes and Mail do.
            // Never the live one: that would throw you straight into scoring.
            .onAppear { if selection == nil { selection = openingSelection } }
            .fullScreenCover(item: Binding(
                get: { scoringGameID.map(ScoringGame.init) },
                set: {
                    if $0 == nil { lastScoredID = scoringGameID }
                    scoringGameID = $0?.id
                }
            ), onDismiss: afterScoring) { game in
                // Live Scoring's own Back button dismisses this cover.
                NavigationStack { LiveScoringView(gameID: game.id) }
            }
        } else {
            NavigationStack(path: $path) {
                gameList(List { listContent })
                    .navigationDestination(for: GameRoute.self) { destination($0) }
            }
        }
    }

    @ViewBuilder
    private var listContent: some View {
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

        if let groups = finishedByTournament {
            ForEach(groups) { group in
                Section {
                    ForEach(group.games) { row($0) }
                        .onDelete { offsets in
                            if let i = offsets.first { pendingDelete = group.games[i] }
                        }
                } header: {
                    tournamentHeader(group)
                }
            }
        } else if !finished.isEmpty {
            Section("Final Scores") {
                ForEach(finished) { row($0) }
                    .onDelete { offsets in
                        // Played games have recorded scores — confirm.
                        if let i = offsets.first { pendingDelete = finished[i] }
                    }
            }
        }
    }

    /// The tournament's name, and a way to fix it on all its games at once —
    /// a misspelling splits a season in two, and Other Games are the ones
    /// with no league typed.
    private func tournamentHeader(_ group: TournamentGroup) -> some View {
        HStack {
            Text(group.title)
            Spacer()
            Menu {
                Button(group.name == nil ? "Name Tournament…" : "Rename Tournament…",
                       systemImage: "pencil") {
                    newTournamentName = group.name ?? ""
                    renaming = group
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .minimumTapTarget()
            }
            .accessibilityLabel("\(group.title) options")
        }
    }

    private func gameList(_ list: some View) -> some View {
        list
            .alert(renaming?.name == nil ? "Name Tournament" : "Rename Tournament",
                   isPresented: Binding(get: { renaming != nil },
                                        set: { if !$0 { renaming = nil } })) {
                TextField("Tournament", text: $newTournamentName)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let group = renaming {
                        store.renameTournament(group.name ?? "", to: newTournamentName)
                    }
                    renaming = nil
                }
                .disabled(newTournamentName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Changes the League on every game in it, including any coming up. Use another tournament's name to merge the two.")
            }
            .readableWidth()
            // Show the active team name (multi-team) — the tab bar labels it "Games".
            // Sections here hold one or two rows each — Playing Now and
            // Coming Up are usually a single game — so the default
            // inset-grouped gaps cost ~90pt to separate almost nothing (#193).
            .listSectionSpacing(.compact)
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
            .sheet(isPresented: $showingNewGame) {
                NewGameSheet(onStartNow: startScoring)
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

    /// The right-hand side on iPad.
    @ViewBuilder
    private var detailColumn: some View {
        switch selection {
        case .detail(let id):
            GameDetailView(gameID: id) { startScoring($0) }
        case .summary(let id):
            GameSummaryView(gameID: id)
        case .live, nil:
            ContentUnavailableView {
                Label("No Game Selected", systemImage: "basketball")
            } description: {
                Text(store.activeTeamGames.isEmpty
                     ? "Tap ✚ to start your first game."
                     : "Pick a game to see its score and stats.")
            }
        }
    }

    /// The most recent finished game, else the next scheduled one.
    private var openingSelection: GameRoute? {
        (finished.first ?? scheduled.first).map(route(for:))
    }

    /// Start scoring a game: full screen on iPad, pushed on iPhone.
    private func startScoring(_ id: UUID) {
        if isSplit {
            selection = nil
            scoringGameID = id
        } else {
            path = [.live(id)]
        }
    }

    /// Back from scoring on iPad: a game that finished opens its summary.
    private func afterScoring() {
        guard let id = lastScoredID,
              let game = store.games.first(where: { $0.id == id }) else { return }
        if game.lifecycle != .inProgress { selection = route(for: game) }
    }

    /// The last game scored, kept past the cover's dismissal so
    /// `afterScoring` can still find it.
    @State private var lastScoredID: UUID?

    private func followSelection() {
        let id: UUID? = switch selection {
        case .detail(let id), .summary(let id), .live(let id): id
        case nil: nil
        }
        guard let id else { return }
        guard let game = store.games.first(where: { $0.id == id }),
              game.teamID == store.team.id else {
            selection = nil
            return
        }
        // Started on another device: don't throw this one into scoring.
        let current = route(for: game)
        if case .live = current { selection = nil }
        else if current != selection { selection = current }
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

/// A game being scored on iPad, as a cover's item.
private struct ScoringGame: Identifiable {
    let id: UUID
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
                    HomeAwayToggle(isHome: $isHome,
                                   teamName: store.team.name,
                                   opponent: opponent)
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
                        // A Label wrapped in the old Spacer/Spacer HStack
                        // shifted the text right of true center by the
                        // icon's width — grouped tight and centered as a
                        // pair instead (#137).
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .accessibilityHidden(true)
                            Text("Start Game")
                        }
                        .frame(maxWidth: .infinity)
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
        if started { game.start(roster: store.team.players) } else { game.hasStarted = false }
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
                    // Location is deliberately absent. At this width it
                    // truncated to "Bayview Middl…" / "Riverside Comm…", which
                    // identifies no gym — and the date is what distinguishes
                    // one game from another in this list anyway. It's in full
                    // on the detail and summary screens (#193).
                    
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
