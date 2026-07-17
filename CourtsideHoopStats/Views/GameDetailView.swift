import SwiftUI

/// Detail screen for a scheduled (not-yet-started) game. Shows the matchup you
/// pre-entered read-only, with an Edit button (Cancel/Save sheet, like the
/// roster's player editor), a Start Game action, and Delete.
struct GameDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let gameID: UUID
    /// Called when the user starts the game; the parent navigates into scoring.
    var onStart: (UUID) -> Void

    @State private var game: Game
    @State private var editing = false

    init(gameID: UUID, onStart: @escaping (UUID) -> Void) {
        self.gameID = gameID
        self.onStart = onStart
        _game = State(initialValue: Game(opponent: ""))
    }

    var body: some View {
        Form {
            Section("Matchup") {
                LabeledContent("Opponent", value: game.opponent)
                LabeledContent("Home / Away", value: game.isHome ? "Home" : "Away")
                LabeledContent("Date", value: game.date.formatted(date: .abbreviated, time: .omitted))
            }

            if !game.league.isEmpty || !game.location.isEmpty {
                Section("Details") {
                    if !game.league.isEmpty { LabeledContent("League", value: game.league) }
                    if !game.location.isEmpty { LabeledContent("Location", value: game.location) }
                }
            }

            Section("Format") {
                LabeledContent("Periods", value: game.periodFormat.displayName)
            }

            Section {
                Button {
                    start()
                } label: {
                    Label("Start Game", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            Section {
                Button(role: .destructive) {
                    delete()
                } label: {
                    Label("Delete Game", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        .onAppear(perform: load)
        .sheet(isPresented: $editing) {
            EditGameSheet(game: game) { updated in
                store.updateGame(updated)
                game = updated
            }
        }
    }

    private func load() {
        if game.id != gameID, let loaded = store.game(id: gameID) {
            game = loaded
        }
    }

    private func start() {
        game.hasStarted = true
        store.updateGame(game)
        onStart(gameID)
    }

    private func delete() {
        store.deleteGame(id: gameID)
        dismiss()
    }
}

// MARK: - Edit sheet (Cancel / Save, mirroring the roster's player editor)

struct EditGameSheet: View {
    @Environment(\.dismiss) private var dismiss

    let game: Game
    var onSave: (Game) -> Void

    @State private var opponent: String
    @State private var date: Date
    @State private var league: String
    @State private var location: String
    @State private var isHome: Bool
    @State private var periodFormat: PeriodFormat

    init(game: Game, onSave: @escaping (Game) -> Void) {
        self.game = game
        self.onSave = onSave
        _opponent = State(initialValue: game.opponent)
        _date = State(initialValue: game.date)
        _league = State(initialValue: game.league)
        _location = State(initialValue: game.location)
        _isHome = State(initialValue: game.isHome)
        _periodFormat = State(initialValue: game.periodFormat)
    }

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
                        .tint(.teamAccent)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
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
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedOpponent.isEmpty)
                }
            }
        }
    }

    private func save() {
        var updated = game
        updated.opponent = trimmedOpponent
        updated.date = date
        updated.league = league.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.isHome = isHome
        updated.periodFormat = periodFormat
        onSave(updated)
        dismiss()
    }
}
