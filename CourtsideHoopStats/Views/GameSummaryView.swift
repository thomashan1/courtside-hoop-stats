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
    /// The rendered box-score PDF backing the Share button (#55). Regenerated
    /// whenever the game is loaded or edited so it never shares stale scores.
    @State private var pdfURL: URL?
    /// Presents the PDF preview, from which it can be shared.
    @State private var showingPDF = false

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
        .navigationTitle(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Box score as a PDF (#55). Opens a preview — sharing happens from
            // there, so you see what's going out before it goes. The file is
            // rendered up front (it's one page, so this is cheap); the button is
            // omitted rather than disabled if rendering ever fails.
            if pdfURL != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingPDF = true
                    } label: {
                        Label("Box Score PDF", systemImage: "square.and.arrow.up")
                            .minimumTapTarget()
                    }
                }
            }
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
        .sheet(isPresented: $showingPDF) {
            if let pdfURL {
                GameSummaryPDFPreview(url: pdfURL, shareTitle: shareTitle)
            }
        }
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
            // Shared with a follower's read-only detail, so the two screens
            // can't drift.
            GameScoreCard(game: game, ourName: store.team.name)
        }
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

    private var statsSection: some View {
        Section("Player Stats") {
            // Shared table (#8) — the same component used in Live Scoring.
            // It's the horizontally-scrollable Grid version that also fixes #12.
            // Pass the whole roster: `stats(for:)` drops benched players itself,
            // but keeps any who actually scored so the points column still adds
            // up to the final score (#59).
            PlayerStatsTable(stats: game.stats(for: store.team.players),
                             didNotPlay: game.didNotPlay(from: store.team.players))
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
            LabeledContent("Date", value: game.date.gameDayAndTime)
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
        regeneratePDF()
    }

    /// Reload from the store after the edit sheet closes so score edits made in
    /// the scoring view are reflected here (#8).
    private func reloadGame() {
        if let loaded = store.game(id: gameID) {
            game = loaded
        }
        regeneratePDF()
    }

    /// Title shown on the preview screen and in the share sheet.
    private var shareTitle: String {
        GameSummaryPDF.title(for: game, teamName: store.team.name)
    }

    private func regeneratePDF() {
        // The full roster — the PDF lists benched players as DNP rows itself.
        pdfURL = GameSummaryPDF.render(game: game,
                                       teamName: store.team.name,
                                       roster: store.team.players)
    }
}
