import SwiftUI

/// Read/edit view for a completed game: final score, period grid, per-player
/// stats, editable opponent totals, and free-text notes.
struct GameSummaryView: View {
    @EnvironmentObject var store: AppStore

    let gameID: UUID
    @State private var game: Game
    /// Presents the full scoring view to edit a finished game's events (#8).
    @State private var isEditingScores = false

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
                    isEditingScores = true
                } label: {
                    Label("Edit Scores", systemImage: "square.and.pencil")
                }
            }
        }
        .onAppear(perform: loadGameIfNeeded)
        // Re-open the same two-tap scoring screen so editing a finished game
        // "looks the same" as entering it live (#8). Reload on dismiss so the
        // summary reflects any edits.
        .fullScreenCover(isPresented: $isEditingScores, onDismiss: reloadGame) {
            NavigationStack {
                LiveScoringView(gameID: gameID)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { isEditingScores = false }
                        }
                    }
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

    // MARK: - Period-by-period grid (opponent totals editable)

    private var periodSection: some View {
        Section("By Period") {
            // Shared read-only grid (#8) — same component used in Live Scoring.
            PeriodBreakdownGrid(game: game, ourName: store.team.name)

            // Editable opponent running totals (fat-finger recovery).
            DisclosureGroup("Edit opponent totals") {
                ForEach(recordedPeriods, id: \.self) { period in
                    HStack {
                        Text(game.periodFormat.periodLabel(period))
                            .font(.subheadline)
                            .frame(width: 44, alignment: .leading)
                        Text("Opponent total")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("0", value: opponentBinding(for: period), format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 70)
                    }
                }
            }
        }
    }

    // MARK: - Player stats table

    private var statsSection: some View {
        Section("Player Stats") {
            // Shared table (#8) — the same component used in Live Scoring.
            // It's the horizontally-scrollable Grid version that also fixes #12.
            PlayerStatsTable(stats: game.stats(for: store.team.players))
        }
    }

    // MARK: - Event log (editable)

    private var eventLogSection: some View {
        Section("Score Log") {
            EventLogView(game: $game, players: store.team.players) {
                store.updateGame(game)
            }
        }
    }

    // MARK: - Notes

    private var notesSection: some View {
        Section("Notes") {
            TextField(
                "Scouting notes, observations…",
                text: Binding(get: { game.notes }, set: { game.notes = $0; persist() }),
                axis: .vertical
            )
            .lineLimit(3...10)
        }
    }

    // MARK: - Metadata

    private var detailsSection: some View {
        Section("Details") {
            LabeledContent("Date", value: game.date.formatted(date: .abbreviated, time: .omitted))
            LabeledContent("Home / Away", value: game.isHome ? "Home" : "Away")
            if !game.league.isEmpty { LabeledContent("League", value: game.league) }
            if !game.location.isEmpty { LabeledContent("Location", value: game.location) }
            LabeledContent("Format", value: game.periodFormat.displayName)
        }
    }

    // MARK: - Helpers

    private var recordedPeriods: [Int] {
        game.periodEndScores.keys.sorted()
    }

    private func opponentBinding(for period: Int) -> Binding<Int> {
        Binding(
            get: { game.periodEndScores[period]?.opponentRunningTotal ?? 0 },
            set: { newValue in
                if var score = game.periodEndScores[period] {
                    score.opponentRunningTotal = newValue
                    game.periodEndScores[period] = score
                    persist()
                }
            }
        )
    }

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

    private func persist() {
        store.updateGame(game)
    }
}
