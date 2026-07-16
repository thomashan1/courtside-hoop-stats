import SwiftUI

struct GamesListView: View {
    @EnvironmentObject var store: AppStore
    @State private var showingNewGame = false

    var body: some View {
        NavigationStack {
            List {
                if store.games.isEmpty {
                    ContentUnavailableView {
                        Label("No Games Yet", systemImage: "basketball")
                    } description: {
                        Text("Tap ✚ to start tracking your first game.")
                    }
                }

                ForEach(store.games) { game in
                    NavigationLink {
                        destination(for: game)
                    } label: {
                        GameRowView(game: game, ourName: store.team.name)
                    }
                }
                .onDelete { store.deleteGames(at: $0) }
            }
            .navigationTitle("Games")
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
                NewGameSheet()
            }
        }
    }

    /// In-progress games open the live scorer; completed games open the summary.
    @ViewBuilder
    private func destination(for game: Game) -> some View {
        if game.isComplete {
            GameSummaryView(gameID: game.id)
        } else {
            LiveScoringView(gameID: game.id)
        }
    }
}

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

            if game.isComplete {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(game.ourScore)–\(game.opponentScore)")
                        .font(.headline)
                        .monospacedDigit()
                    resultBadge
                }
            } else {
                Text("In Progress")
                    .font(.caption2).bold()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.grassGreen.opacity(0.25)))
                    .foregroundStyle(Color.grassGreen)
            }
        }
        .padding(.vertical, 2)
    }

    private var resultBadge: some View {
        let (text, color): (String, Color) = {
            switch game.result {
            case .win:  return ("W", .grassGreen)
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

struct NewGameSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    @State private var opponent = ""
    @State private var league = ""
    @State private var location = ""
    @State private var isHome = true
    @State private var periodFormat: PeriodFormat = .quarters

    private var trimmedOpponent: String {
        opponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Matchup") {
                    TextField("Opponent", text: $opponent)
                        .textInputAutocapitalization(.words)
                    Toggle("Home game", isOn: $isHome)
                }

                Section("Details (optional)") {
                    TextField("League / Tournament", text: $league)
                    TextField("Location / Gym", text: $location)
                }

                Section("Format") {
                    Picker("Periods", selection: $periodFormat) {
                        ForEach(PeriodFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") { start() }
                        .disabled(trimmedOpponent.isEmpty)
                }
            }
        }
    }

    private func start() {
        let game = Game(
            opponent: trimmedOpponent,
            league: league.trimmingCharacters(in: .whitespacesAndNewlines),
            location: location.trimmingCharacters(in: .whitespacesAndNewlines),
            isHome: isHome,
            periodFormat: periodFormat
        )
        store.addGame(game)
        dismiss()
    }
}

#Preview {
    GamesListView()
        .environmentObject(AppStore())
}
