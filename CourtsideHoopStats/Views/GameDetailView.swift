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
            Section("Details") {
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

            Section("Opponent") {
                LabeledContent("Opponent", value: game.opponent)
                LabeledContent("Home / Away", value: game.isHome ? "Home" : "Away")
                LabeledContent("Jersey") {
                    JerseyIndicator(color: store.team.jersey(isHome: game.isHome))
                }
                LabeledContent("Date", value: game.date.gameDayAndTime)
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
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let game: Game
    /// Whether the period format can be changed. False once a game has started,
    /// so editing details never rescrambles recorded periods.
    var allowsFormatChange: Bool = true
    var onSave: (Game) -> Void

    @State private var opponent: String
    @State private var date: Date
    @State private var league: String
    @State private var location: String
    @State private var locationAddress: String
    @State private var isHome: Bool
    @State private var periodFormat: PeriodFormat
    @State private var notes: String
    /// Confirming "Move Back to Scheduled" (#133).
    @State private var confirmingRevert = false

    init(game: Game, allowsFormatChange: Bool = true, onSave: @escaping (Game) -> Void) {
        self.game = game
        self.allowsFormatChange = allowsFormatChange
        self.onSave = onSave
        _opponent = State(initialValue: game.opponent)
        _date = State(initialValue: game.date)
        _league = State(initialValue: game.league)
        _location = State(initialValue: game.location)
        _locationAddress = State(initialValue: game.locationAddress)
        _isHome = State(initialValue: game.isHome)
        _periodFormat = State(initialValue: game.periodFormat)
        _notes = State(initialValue: game.notes)
    }

    private var trimmedOpponent: String {
        opponent.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                    if allowsFormatChange {
                        Picker("Format", selection: $periodFormat) {
                            ForEach(PeriodFormat.allCases, id: \.self) { format in
                                Text(format.displayName).tag(format)
                            }
                        }
                    }
                }

                Section("Opponent") {
                    TextField("Opponent", text: $opponent)
                        .textInputAutocapitalization(.words)
                    Toggle("Home game", isOn: $isHome)
                        .tint(.teamAccent)
                    LabeledContent("Jersey") {
                        JerseyIndicator(color: store.team.jersey(isHome: isHome))
                    }
                }

                Section("Notes") {
                    TextField("Scouting notes, observations…", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }

                // Only the "oops, tapped Start Game by mistake" case (#133):
                // once anything's actually been recorded, reverting would
                // silently orphan those events rather than undo a mistake, so
                // this is deliberately narrower than "un-start any game".
                if game.lifecycle == .inProgress && game.events.isEmpty {
                    Section {
                        Button(role: .destructive) {
                            confirmingRevert = true
                        } label: {
                            Label("Move Back to Scheduled", systemImage: "arrow.uturn.backward")
                        }
                    } footer: {
                        Text("Undoes starting this game. Only offered before anything's been scored.")
                    }
                }
            }
            .navigationTitle("Edit Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // Opponent is optional — a game can start with no setup and
                    // have its details filled in (or left blank) later (#44).
                    Button("Save") { save() }
                }
            }
            .confirmationDialog("Move back to Scheduled?",
                                isPresented: $confirmingRevert, titleVisibility: .visible) {
                Button("Move Back", role: .destructive) { revert() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This undoes starting the game. Nothing's been scored yet, so there's nothing to lose.")
            }
        }
    }

    private func save() {
        var updated = game
        updated.opponent = trimmedOpponent
        updated.date = date
        updated.league = league.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.location = location.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.locationAddress = updated.location.isEmpty ? "" : locationAddress
        updated.isHome = isHome
        if allowsFormatChange { updated.periodFormat = periodFormat }
        updated.notes = notes
        onSave(updated)
        dismiss()
    }

    /// Clears `hasStarted` and hands the reverted game to `onSave` — the
    /// caller (`LiveScoringView`) is what notices `lifecycle == .scheduled`
    /// on the result and navigates back to the Games list, since this sheet
    /// doesn't own that navigation itself.
    private func revert() {
        var updated = game
        updated.hasStarted = false
        onSave(updated)
        dismiss()
    }
}
