import SwiftUI

/// Read/edit view for a completed game: final score, period grid, per-player
/// stats, editable opponent totals, and free-text notes.
struct GameSummaryView: View {
    @EnvironmentObject var store: AppStore

    let gameID: UUID
    @State private var game: Game
    /// Presents the full scoring view to edit a finished game's events (#8).
    @State private var isEditingScores = false
    @State private var showDetails = false

    /// Final-score digits scale with Dynamic Type (capped so they can't overflow
    /// the row), matching the live scoreboard's behavior (issue #12).
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 36

    init(gameID: UUID) {
        self.gameID = gameID
        _game = State(initialValue: Game(opponent: ""))
    }

    var body: some View {
        List {
            finalScoreSection
            periodSection
            statsSection
            eventLogSection
            notesSection
            detailsSection
        }
        .navigationTitle("vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showDetails = true
                } label: {
                    Label("Details", systemImage: "info.circle")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isEditingScores = true
                } label: {
                    Label("Edit Scores", systemImage: "square.and.pencil")
                }
            }
        }
        .onAppear(perform: loadGameIfNeeded)
        .sheet(isPresented: $showDetails) {
            // Details + notes editor (Cancel/Save). Format is locked — the game
            // is played, so its periods are fixed.
            EditGameSheet(game: game, allowsFormatChange: false) { updated in
                store.updateGame(updated)
                game = updated
            }
        }
        // Re-open the same two-tap scoring screen so editing a finished game
        // "looks the same" as entering it live (#8). Reload on dismiss so the
        // summary reflects any edits.
        .fullScreenCover(isPresented: $isEditingScores, onDismiss: reloadGame) {
            // Live Scoring provides its own Back button (its scoreboard top bar),
            // which dismisses this cover.
            NavigationStack {
                LiveScoringView(gameID: gameID)
            }
        }
    }

    // MARK: - Final score

    private var finalScoreSection: some View {
        Section {
            HStack {
                scoreColumn(name: store.team.name, score: game.ourScore, highlight: true)
                VStack {
                    resultBadge
                    Text("Final").font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                scoreColumn(name: game.opponent, score: game.opponentScore, highlight: false)
            }
            .padding(.vertical, 8)
        }
    }

    private func scoreColumn(name: String, score: Int, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.subheadline).bold().lineLimit(1).minimumScaleFactor(0.6)
            Text("\(score)")
                .font(.system(size: min(scoreSize, 64), weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(highlight ? Color.teamAccent : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultBadge: some View {
        let (text, color): (String, Color) = {
            switch game.result {
            case .win:  return ("WIN", .teamAccent)
            case .loss: return ("LOSS", .red)
            case .tie:  return ("TIE", .gray)
            }
        }()
        return Text(text)
            .font(.caption).bold()
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(color))
    }

    // MARK: - Period-by-period grid (read-only)

    private var periodSection: some View {
        Section("By Period") {
            // Shared read-only grid (#8) — same component used in Live Scoring.
            // Editing opponent totals lives behind "Edit Scores" now (#23).
            PeriodBreakdownGrid(game: game, ourName: store.team.name)
        }
    }

    // MARK: - Player stats table

    /// Players who were at the game (benched players excluded from stats).
    private var playingPlayers: [Player] {
        store.team.players.filter { !game.benchedPlayerIDs.contains($0.id) }
    }

    private var statsSection: some View {
        Section("Player Stats") {
            // Shared table (#8) — the same component used in Live Scoring.
            // It's the horizontally-scrollable Grid version that also fixes #12.
            PlayerStatsTable(stats: game.stats(for: playingPlayers))
        }
    }

    // MARK: - Event log (read-only — edit via "Edit Scores", #23)

    private var eventLogSection: some View {
        Section("Score Log") {
            EventLogView(game: $game, players: store.team.players, isEditable: false) {
                store.updateGame(game)
            }
        }
    }

    // MARK: - Notes (read-only — edit via the Details button, #23/consistency)

    @ViewBuilder
    private var notesSection: some View {
        if !game.notes.isEmpty {
            Section("Notes") {
                Text(game.notes)
            }
        }
    }

    // MARK: - Metadata

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Date", value: game.date.formatted(date: .abbreviated, time: .shortened))
            LabeledContent("Home / Away", value: game.isHome ? "Home" : "Away")
            if !game.league.isEmpty { LabeledContent("League", value: game.league) }
            if !game.location.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    LabeledContent("Location", value: game.location)
                    if !game.locationAddress.isEmpty {
                        Text(game.locationAddress).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            LabeledContent("Format", value: game.periodFormat.displayName)
        }
    }

    // MARK: - Helpers

    private func loadGameIfNeeded() {
        if game.id != gameID, let loaded = store.game(id: gameID) {
            game = loaded
        }
    }

    /// Reload from the store after the edit sheet closes so score edits made in
    /// the scoring view are reflected here (#8).
    private func reloadGame() {
        if let loaded = store.game(id: gameID) {
            game = loaded
        }
    }
}
