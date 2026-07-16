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

    init(gameID: UUID) {
        self.gameID = gameID
        // Placeholder; the real game is loaded from the store in `.onAppear`.
        _game = State(initialValue: Game(opponent: ""))
    }

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 12)]

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
                LazyVGrid(columns: columns, spacing: 12) {
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
            Text("Event Log")
                .font(.headline)
                .foregroundStyle(.primary)

            EventLogView(game: $game, players: store.team.players) {
                store.updateGame(game)
            }
        }
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
                .tint(.grassGreen)
            }

            HStack(spacing: 8) {
                actionButton(.twoPoint)
                actionButton(.threePoint)
                actionButton(.ftMade)
                actionButton(.ftMissed)
                actionButton(.foul)
            }

            Button {
                showEndPeriod = true
            } label: {
                Text(game.isFinalPeriod
                     ? "End \(game.periodFormat.periodLabel(game.currentPeriod)) & Finish Game"
                     : "End \(game.periodFormat.periodLabel(game.currentPeriod))")
                    .font(.subheadline).bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.grassGreen.opacity(0.20)))
                    .foregroundStyle(Color.grassGreen)
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
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(enabled ? Color.grassGreen : Color(.tertiarySystemFill))
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
        store.updateGame(game)
        // Clear selection after each event so a new event requires an explicit
        // player tap — reduces mis-attributed entries courtside.
        selectedPlayerID = nil
    }

    private func undo() {
        guard !game.events.isEmpty else { return }
        game.events.removeLast()
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

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                JerseyBadge(number: player.number, size: 42)
                Text(player.name)
                    .font(.caption).bold()
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Text("\(points)")
                    .font(.title3).bold()
                    .monospacedDigit()
                    .foregroundStyle(Color.grassGreen)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.grassGreen.opacity(0.18)
                                     : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.grassGreen : .clear, lineWidth: 2.5)
                    )
            )
        }
        .buttonStyle(.plain)
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
