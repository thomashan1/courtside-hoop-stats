import SwiftUI

/// Read/edit view for a completed game: final score, period grid, per-player
/// stats, editable opponent totals, and free-text notes.
struct GameSummaryView: View {
    @EnvironmentObject var store: AppStore

    let gameID: UUID
    @State private var game: Game

    init(gameID: UUID) {
        self.gameID = gameID
        _game = State(initialValue: Game(opponent: ""))
    }

    var body: some View {
        List {
            finalScoreSection
            periodSection
            statsSection
            notesSection
            detailsSection
        }
        .navigationTitle("vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadGameIfNeeded)
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
            Text(name).font(.subheadline).bold().lineLimit(1)
            Text("\(score)")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? Color.grassGreen : .primary)
        }
        .frame(maxWidth: .infinity)
    }

    private var resultBadge: some View {
        let (text, color): (String, Color) = {
            switch game.result {
            case .win:  return ("WIN", .grassGreen)
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
            HStack {
                Text("").frame(width: 44, alignment: .leading)
                Text(store.team.name).font(.caption).bold().frame(maxWidth: .infinity)
                Text(game.opponent).font(.caption).bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            ForEach(game.periodBreakdown(), id: \.period) { row in
                HStack {
                    Text(game.periodFormat.periodLabel(row.period))
                        .font(.subheadline).bold()
                        .frame(width: 44, alignment: .leading)
                    Text("\(row.our)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                    Text("\(row.opponent)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
            }

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
            HStack {
                Text("Player").font(.caption).bold().frame(maxWidth: .infinity, alignment: .leading)
                Group {
                    Text("PTS")
                    Text("2P")
                    Text("3P")
                    Text("FT")
                    Text("F")
                }
                .font(.caption).bold()
                .frame(width: 42)
            }
            .foregroundStyle(.secondary)

            ForEach(game.stats(for: store.team.players)) { stat in
                HStack {
                    HStack(spacing: 8) {
                        JerseyBadge(number: stat.player.number, size: 26)
                        Text(stat.player.name).font(.subheadline).lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Group {
                        Text("\(stat.points)").bold()
                        Text("\(stat.twoPointers)")
                        Text("\(stat.threePointers)")
                        Text(stat.freeThrowDisplay)
                        Text("\(stat.fouls)")
                    }
                    .font(.caption)
                    .monospacedDigit()
                    .frame(width: 42)
                }
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

    private func persist() {
        store.updateGame(game)
    }
}
