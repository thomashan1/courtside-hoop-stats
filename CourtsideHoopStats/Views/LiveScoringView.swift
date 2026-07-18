import SwiftUI

/// The core courtside screen. Two-tap interaction: tap a player card to select,
/// then tap an action to record an event. Score is auto-calculated from events.
///
/// Design pass: content (player grid, event log) uses adaptive system surfaces
/// so it stays legible in a bright gym; the scoreboard banner is the one
/// intentionally-dark element, and Liquid Glass is confined to the floating
/// action bar (chrome).
struct LiveScoringView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let gameID: UUID

    /// Local working copy of the game; persisted via `store.updateGame` on
    /// every mutation (per the architecture in REQUIREMENTS.md).
    @State private var game: Game
    @State private var selectedPlayerID: UUID?
    @State private var showEndPeriod = false
    /// Presented from the inert "Final" divider when re-editing a finished game,
    /// so opponent totals can still be corrected after the game ends (#23).
    @State private var showOpponentTotals = false
    /// Whether the at-a-glance stats/period panel is expanded (#8). Collapsed by
    /// default so it never gets in the way of fast two-tap entry.
    @State private var showStats = false
    /// Events removed by Undo, so they can be re-applied by Redo. Cleared when a
    /// new event is recorded.
    @State private var redoStack: [GameEvent] = []

    // Sizes that scale with Dynamic Type so the screen stays usable at large
    // accessibility text sizes (player cards widen, action buttons wrap/grow).
    @ScaledMetric private var cardMinWidth: CGFloat = 96
    @ScaledMetric private var actionMinWidth: CGFloat = 72
    @ScaledMetric private var actionMinHeight: CGFloat = 48

    init(gameID: UUID) {
        self.gameID = gameID
        // Placeholder; the real game is loaded from the store in `.onAppear`.
        _game = State(initialValue: Game(opponent: ""))
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardMinWidth), spacing: 12)]
    }

    var body: some View {
        VStack(spacing: 0) {
            ScoreboardView(
                ourName: store.team.name,
                ourScore: game.ourScore,
                opponentName: game.opponent,
                opponentScore: game.opponentScore,
                periodLabel: game.periodFormat.periodLabel(game.currentPeriod)
            )

            ScrollView {
                playerGrid
                    .padding()
                eventLog
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                statsPanel
                    .padding(.horizontal)
                    .padding(.bottom, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { actionBar }
        .onAppear(perform: loadGameIfNeeded)
        .sheet(isPresented: $showEndPeriod) {
            EndPeriodSheet(
                periodLabel: game.periodFormat.periodLabel(game.currentPeriod),
                ourScore: game.ourScore,
                previousOpponentTotal: previousOpponentTotal,
                isFinalPeriod: game.isFinalPeriod,
                onConfirm: endPeriod(opponentTotal:)
            )
        }
        .sheet(isPresented: $showOpponentTotals) {
            OpponentTotalsSheet(game: $game) { store.updateGame(game) }
        }
    }

    // MARK: - Player grid

    private var playerGrid: some View {
        Group {
            if store.team.players.isEmpty {
                ContentUnavailableView(
                    "No Players",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Add players on the Roster tab before scoring.")
                )
                .padding(.top, 40)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(store.team.players) { player in
                        PlayerCard(
                            player: player,
                            points: pointsByPlayer[player.id, default: 0],
                            isSelected: selectedPlayerID == player.id
                        ) {
                            toggleSelection(player.id)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Event log

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Score Log")
                .font(.headline)
                .foregroundStyle(.primary)

            endPeriodDivider

            EventLogView(game: $game, players: store.team.players) {
                store.updateGame(game)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The current quarter/half boundary, shown at the top of the Score Log.
    /// Tapping it records the opponent's total and advances (or finishes).
    /// When re-editing a finished game the divider is inert ("Final") so editing
    /// events never forces a re-finish and `isComplete` is preserved (#8).
    @ViewBuilder
    private var endPeriodDivider: some View {
        let label = game.periodFormat.periodLabel(game.currentPeriod)
        if game.isComplete {
            // Inert as a period control (editing never re-finishes, #8), but
            // tappable to correct opponent totals after the game ends (#23).
            Button {
                showOpponentTotals = true
            } label: {
                HStack(spacing: 10) {
                    dividerLine
                    Label("Final · Edit opponent totals", systemImage: "flag.checkered")
                        .font(.subheadline).bold()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                    dividerLine
                }
            }
            .buttonStyle(.plain)
        } else {
            Button {
                showEndPeriod = true
            } label: {
                HStack(spacing: 10) {
                    dividerLine
                    Label(game.isFinalPeriod ? "End \(label) & Finish" : "End \(label)",
                          systemImage: "flag.checkered")
                        .font(.subheadline).bold()
                        .foregroundStyle(Color.teamAccent)
                        .fixedSize()
                    dividerLine
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.teamAccent.opacity(0.35))
            .frame(height: 1)
    }

    // MARK: - Stats & periods panel (at-a-glance, collapsible — #8)

    /// The player-stats table and by-period grid from the Summary, surfaced here
    /// via shared components so you can review them while scoring or editing.
    /// Collapsed by default to keep two-tap entry unobstructed.
    private var statsPanel: some View {
        DisclosureGroup(isExpanded: $showStats) {
            VStack(alignment: .leading, spacing: 18) {
                if !game.periodBreakdown().isEmpty {
                    PeriodBreakdownGrid(game: game, ourName: store.team.name)
                }
                PlayerStatsTable(stats: game.stats(for: store.team.players))
            }
            .padding(.top, 12)
        } label: {
            Label("Player Stats & Periods", systemImage: "chart.bar.xaxis")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(.teamAccent)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Action bar (floating Liquid Glass chrome, pinned to bottom)

    private var actionBar: some View {
        VStack(spacing: 10) {
            HStack {
                if let player = selectedPlayer {
                    HStack(spacing: 8) {
                        JerseyBadge(number: player.number, size: 26)
                        Text(player.name).font(.subheadline).bold()
                    }
                    .foregroundStyle(.primary)
                } else {
                    Text("Select a player")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                        .font(.subheadline)
                }
                .disabled(game.events.isEmpty)
                .tint(.teamAccent)

                Button {
                    redo()
                } label: {
                    Label("Redo", systemImage: "arrow.uturn.forward")
                        .font(.subheadline)
                }
                .disabled(redoStack.isEmpty)
                .tint(.teamAccent)
            }

            // Wrapping grid so the actions reflow (rather than cram/clip) at
            // large accessibility text sizes.
            LazyVGrid(columns: [GridItem(.adaptive(minimum: actionMinWidth), spacing: 8)], spacing: 8) {
                actionButton(.twoPoint)
                actionButton(.threePoint)
                actionButton(.ftMade)
                actionButton(.ftMissed)
            }
        }
        .padding()
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .padding(.horizontal)
        .padding(.bottom, 4)
    }

    private func actionButton(_ type: EventType) -> some View {
        let enabled = selectedPlayerID != nil
        return Button {
            record(type)
        } label: {
            Text(type.buttonLabel)
                .font(.subheadline).bold()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: actionMinHeight)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(enabled ? Color.teamAccent : Color(.tertiarySystemFill))
                )
                .foregroundStyle(enabled ? .white : Color.secondary)
        }
        .disabled(!enabled)
    }

    // MARK: - Derived helpers

    private var pointsByPlayer: [UUID: Int] {
        var totals: [UUID: Int] = [:]
        for event in game.events {
            totals[event.playerID, default: 0] += event.type.points
        }
        return totals
    }

    private var selectedPlayer: Player? {
        guard let id = selectedPlayerID else { return nil }
        return player(for: id)
    }

    private func player(for id: UUID) -> Player? {
        store.team.players.first { $0.id == id }
    }

    /// The opponent running total recorded at the previous period end (0 if none),
    /// used to pre-fill the end-period sheet since totals are cumulative.
    private var previousOpponentTotal: Int {
        let prior = game.currentPeriod - 1
        guard prior >= 1 else { return 0 }
        return game.periodEndScores[prior]?.opponentRunningTotal ?? 0
    }

    // MARK: - Actions

    private func loadGameIfNeeded() {
        if game.id != gameID, let loaded = store.game(id: gameID) {
            game = loaded
        }
    }

    private func toggleSelection(_ id: UUID) {
        selectedPlayerID = (selectedPlayerID == id) ? nil : id
    }

    private func record(_ type: EventType) {
        guard let playerID = selectedPlayerID else { return }
        let event = GameEvent(playerID: playerID, type: type, period: game.currentPeriod)
        game.events.append(event)
        redoStack.removeAll()   // a new event invalidates the redo history
        store.updateGame(game)
        // Clear selection after each event so a new event requires an explicit
        // player tap — reduces mis-attributed entries courtside.
        selectedPlayerID = nil
    }

    private func undo() {
        guard let last = game.events.last else { return }
        redoStack.append(last)
        game.events.removeLast()
        store.updateGame(game)
    }

    private func redo() {
        guard let event = redoStack.popLast() else { return }
        game.events.append(event)
        store.updateGame(game)
    }

    private func endPeriod(opponentTotal: Int) {
        let period = game.currentPeriod
        game.periodEndScores[period] = PeriodEndScore(
            ourRunningTotal: game.ourScore,
            opponentRunningTotal: opponentTotal
        )
        if period >= game.periodFormat.periodCount {
            game.isComplete = true
        }
        store.updateGame(game)

        // When the game is finished, pop back to the games list; the row will
        // now route to the summary screen.
        if game.isComplete {
            dismiss()
        }
    }
}

// MARK: - Player card

private struct PlayerCard: View {
    let player: Player
    let points: Int
    let isSelected: Bool
    let onTap: () -> Void

    /// Compact identity: first name + jersey number, e.g. "Ava #4".
    private var idLabel: String {
        let number = player.number.isEmpty ? "" : "#\(player.number)"
        return [player.firstName, number].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                Text(idLabel)
                    .font(.subheadline).bold()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(.primary)
                Text("\(points) pts")
                    .font(.caption).bold()
                    .monospacedDigit()
                    .foregroundStyle(Color.teamAccent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.teamAccent.opacity(0.18)
                                     : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.teamAccent : .clear, lineWidth: 2.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Opponent totals editor (post-game correction, #23)

/// Edits the opponent's cumulative running total per recorded period. Reached
/// from the "Final" divider when re-editing a finished game — the single place
/// opponent scores are corrected now that the Summary is read-only.
struct OpponentTotalsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var game: Game
    var persist: () -> Void

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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(recordedPeriods, id: \.self) { period in
                        HStack {
                            Text(game.periodFormat.periodLabel(period))
                                .font(.subheadline).bold()
                                .frame(width: 44, alignment: .leading)
                            Text("Opponent running total")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                            TextField("0", value: opponentBinding(for: period), format: .number)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 70)
                        }
                    }
                } footer: {
                    Text("Cumulative opponent score at the end of each period (their scoreboard total, not just that period's points).")
                }
            }
            .navigationTitle("Opponent Totals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - End period sheet

struct EndPeriodSheet: View {
    @Environment(\.dismiss) private var dismiss

    let periodLabel: String
    let ourScore: Int
    let previousOpponentTotal: Int
    let isFinalPeriod: Bool
    let onConfirm: (Int) -> Void

    @State private var opponentTotalText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Our score (auto)") {
                        Text("\(ourScore)").bold().monospacedDigit()
                    }
                    TextField("Opponent running total", text: $opponentTotalText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("End of \(periodLabel)")
                } footer: {
                    Text("Enter the opponent's cumulative score so far (their total on the scoreboard, not just this period).")
                }
            }
            .navigationTitle(isFinalPeriod ? "Finish Game" : "End \(periodLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isFinalPeriod ? "Finish" : "Next Period") {
                        onConfirm(Int(opponentTotalText) ?? previousOpponentTotal)
                        dismiss()
                    }
                }
            }
            .onAppear {
                opponentTotalText = previousOpponentTotal > 0 ? "\(previousOpponentTotal)" : ""
            }
        }
    }
}
