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
    @State private var showEndPeriod = false
    /// Presented from the inert "Final" divider when re-editing a finished game,
    /// so opponent totals can still be corrected after the game ends (#23).
    @State private var showOpponentTotals = false
    /// Presents the List-based score-log editor (reorder + delete, #9).
    @State private var showLogEditor = false
    /// Presents the game-details editor (location, notes, matchup) so details
    /// can be fixed mid-game — the same Cancel/Save sheet used elsewhere.
    @State private var showDetails = false
    /// Whether the at-a-glance stats/period panel is expanded (#8). Collapsed by
    /// default so it never gets in the way of fast two-tap entry.
    @State private var showStats = false
    /// Whether the "Not playing" bench strip is expanded. Collapsed by default so
    /// it takes almost no space.
    @State private var showBench = false
    /// The player whose point pad is open (tap a card to score, #33).
    @State private var scoringPlayer: Player?

    // Sizes that scale with Dynamic Type so the screen stays usable at large
    // accessibility text sizes (player cards widen, action buttons wrap/grow).
    @ScaledMetric private var cardMinWidth: CGFloat = 100

    init(gameID: UUID) {
        self.gameID = gameID
        // Placeholder; the real game is loaded from the store in `.onAppear`.
        _game = State(initialValue: Game(opponent: ""))
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: cardMinWidth), spacing: 12)]
    }

    /// Players at the game — shown in the grid. Benched players are hidden.
    private var activePlayers: [Player] {
        store.team.players.filter { !game.benchedPlayerIDs.contains($0.id) }
    }
    /// Players sat out, shown as compact chips you can tap to bring back.
    private var benchedPlayers: [Player] {
        store.team.players.filter { game.benchedPlayerIDs.contains($0.id) }
    }

    private func bench(_ id: UUID) {
        guard !game.benchedPlayerIDs.contains(id) else { return }
        game.benchedPlayerIDs.append(id)
        store.updateGame(game)
    }

    private func unbench(_ id: UUID) {
        game.benchedPlayerIDs.removeAll { $0 == id }
        store.updateGame(game)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Compact control row folded into the (dark) scoreboard, replacing
            // the system nav bar — back, undo/redo, and details all live here.
            scoreboardTopBar

            ScoreboardView(
                ourName: store.team.name,
                ourScore: game.ourScore,
                opponentName: game.opponent,
                opponentScore: game.opponentScore,
                periodLabel: game.periodFormat.periodLabel(game.currentPeriod)
            )

            // Pinned Score Log header — stays put while the entries scroll.
            scoreLogHeader
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 6)

            // …the log entries scroll…
            ScrollViewReader { proxy in
                ScrollView {
                    eventLog
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .id("scoreLogEnd")
                    statsPanel
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
                // Keep the newest event (bottom of the log) in view as you score.
                .onChange(of: game.events.count) { _, _ in
                    withAnimation(.snappy(duration: 0.2)) {
                        proxy.scrollTo("scoreLogEnd", anchor: .bottom)
                    }
                }
                .onAppear { proxy.scrollTo("scoreLogEnd", anchor: .bottom) }
            }

            // …and the player cards sit at the bottom, in the thumb zone right
            // above the action bar. The deck has its own elevated surface so it
            // reads as a distinct control area, separate from the Score Log.
            VStack(alignment: .leading, spacing: 8) {
                benchStrip
                // Cue the tap-to-score flow until the first point is scored.
                if game.events.isEmpty && !store.team.players.isEmpty {
                    Text("Tap a player to score")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                playerGrid
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 2)
            .background(
                UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22)
                    .fill(Color(.systemBackground))
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
                    .shadow(color: .black.opacity(0.18), radius: 10, y: -3)
            )
        }
        .background(Color(.systemGroupedBackground))
        // Hidden system nav bar — the scoreboard's own top row carries the
        // controls, reclaiming the bar's height (long-press a card to score).
        .toolbar(.hidden, for: .navigationBar)
        // Hide the tab bar while scoring: more room, and no accidental
        // navigation away from a live game.
        .toolbar(.hidden, for: .tabBar)
        .onAppear(perform: loadGameIfNeeded)
        .sheet(isPresented: $showDetails) {
            // Format can't change once a game is under way (would rescramble
            // recorded periods).
            EditGameSheet(game: game, allowsFormatChange: false) { updated in
                game = updated
                store.updateGame(game)
            }
        }
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
        .sheet(isPresented: $showLogEditor) {
            ScoreLogEditor(game: $game, players: store.team.players) {
                store.updateGame(game)
            }
        }
        .sheet(item: $scoringPlayer) { player in
            ScorePadSheet(
                player: player,
                onScore: { recordScore($0, for: player.id) },
                onBench: { bench(player.id) }
            )
        }
    }

    // MARK: - Scoreboard top bar (replaces the system nav bar)

    private var scoreboardTopBar: some View {
        HStack(spacing: 22) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.backward").fontWeight(.semibold)
            }
            .accessibilityLabel("Back")
            Spacer()
            Button { showDetails = true } label: { Image(systemName: "info.circle") }
                .accessibilityLabel("Details")
        }
        .font(.title3)
        .tint(.white)
        .foregroundStyle(.white)
        .padding(.horizontal)
        .padding(.top, 6)
        .padding(.bottom, 2)
        .background(Color.scoreboardBackground.ignoresSafeArea(edges: .top))
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
                    ForEach(activePlayers) { player in
                        PlayerCard(player: player) { scoringPlayer = player }
                    }
                }
            }
        }
    }

    // MARK: - Bench (players not at this game)

    @ViewBuilder
    private var benchStrip: some View {
        if !benchedPlayers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                // Collapsed control is a distinct capsule so it reads as its own
                // element, not part of the Score Log below it.
                Button {
                    withAnimation(.snappy(duration: 0.2)) { showBench.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.slash")
                            .font(.caption)
                        Text("Not playing (\(benchedPlayers.count))")
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                            .rotationEffect(.degrees(showBench ? 180 : 0))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)

                if showBench {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(benchedPlayers) { player in
                                Button {
                                    unbench(player.id)
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(benchLabel(player))
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Image(systemName: "plus.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(Color.teamAccent)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Capsule().fill(Color.teamAccent.opacity(0.12)))
                                    // Applied outside the background so the
                                    // capsule keeps its size and only the hit
                                    // area grows to the 44pt minimum (#56).
                                    .minimumTapTarget()
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func benchLabel(_ player: Player) -> String {
        let number = player.number.isEmpty ? "" : "#\(player.number)"
        return [player.firstName, number].filter { !$0.isEmpty }.joined(separator: " ")
    }

    // MARK: - Event log

    /// Pinned above the scrolling log so the title + Edit/Reorder stay in view.
    private var scoreLogHeader: some View {
        HStack {
            Text("Score Log")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            if !game.events.isEmpty {
                Button {
                    showLogEditor = true
                } label: {
                    Label("Edit / Reorder", systemImage: "arrow.up.arrow.down")
                        .font(.subheadline)
                }
                .tint(.teamAccent)
            }
        }
    }

    private var eventLog: some View {
        VStack(alignment: .leading, spacing: 10) {
            EventLogView(game: $game, players: store.team.players,
                         pinsPeriodHeaders: true) {
                store.updateGame(game)
            }

            // The "end this period" control sits at the bottom, after the current
            // period's (newest) events — the natural place to finish a period.
            endPeriodDivider
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The current quarter/half boundary, shown at the bottom of the Score Log
    /// (after the newest events). Tapping it records the opponent's total and
    /// advances (or finishes).
    /// When re-editing a finished game the divider is inert ("Final") so editing
    /// events never forces a re-finish and `isComplete` is preserved (#8).
    /// Label for the end-of-period control: "Finish Game" for a pickup game (no
    /// periods), otherwise "End Q3" / "End Q4 & Finish".
    private var endPeriodLabel: String {
        if game.periodFormat == .pickup { return "Finish Game" }
        let label = game.periodFormat.periodLabel(game.currentPeriod)
        return game.isFinalPeriod ? "End \(label) & Finish" : "End \(label)"
    }

    @ViewBuilder
    private var endPeriodDivider: some View {
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
                    Label(endPeriodLabel, systemImage: "flag.checkered")
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
                // Only players at the game — benched players are excluded.
                PlayerStatsTable(stats: game.stats(for: activePlayers))
            }
            .padding(.top, 12)
        } label: {
            Label("Stats", systemImage: "chart.bar.xaxis")
                .font(.headline)
                .foregroundStyle(.primary)
        }
        .tint(.teamAccent)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Record a scoring event for a player directly (from the card's long-press
    /// menu). A haptic confirms the tap landed on the right player.
    private func recordScore(_ type: EventType, for playerID: UUID) {
        let event = GameEvent(playerID: playerID, type: type, period: game.currentPeriod)
        game.events.append(event)
        store.updateGame(game)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    /// Single tap opens the big point pad for this player (#33, Jean's feedback).
    let onTap: () -> Void

    /// Compact identity for accessibility, e.g. "Ava #4".
    private var idLabel: String {
        let number = player.number.isEmpty ? "" : "#\(player.number)"
        return [player.firstName, number].filter { !$0.isEmpty }.joined(separator: " ")
    }

    var body: some View {
        // Single row: bigger jersey bubble (easy to see/tap) + first name.
        Button(action: onTap) {
            HStack(spacing: 8) {
                JerseyBadge(number: player.number, size: 36)
                Text(player.firstName)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(Color.teamAccent.opacity(0.10))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(idLabel)
    }
}

// MARK: - Score pad (tap a player → big point buttons, #33)

/// A big, high-contrast point pad for one player. Tapping a point button
/// records it and dismisses; benching is a secondary action here.
struct ScorePadSheet: View {
    @Environment(\.dismiss) private var dismiss
    let player: Player
    let onScore: (EventType) -> Void
    let onBench: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                JerseyBadge(number: player.number, size: 40)
                Text(player.firstName)
                    .font(.title2).bold()
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.top, 8)

            Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                GridRow {
                    padButton("+2", .twoPoint)
                    padButton("+3", .threePoint)
                }
                GridRow {
                    padButton("FT ✓", .ftMade)
                    padButton("FT ✗", .ftMissed)
                }
            }

            Button(role: .destructive) {
                onBench()
                dismiss()
            } label: {
                Label("Not playing", systemImage: "person.slash")
            }
            .padding(.top, 2)
        }
        .padding()
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.visible)
    }

    private func padButton(_ label: String, _ type: EventType) -> some View {
        Button {
            onScore(type)
            dismiss()
        } label: {
            Text(label)
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 88)
                .background(RoundedRectangle(cornerRadius: 18).fill(Color.teamAccent))
                .foregroundStyle(.white)
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
