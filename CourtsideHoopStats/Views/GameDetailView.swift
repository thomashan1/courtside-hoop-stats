import SwiftUI

/// Detail screen for a scheduled (not-yet-started) game. Shows the matchup you
/// pre-entered read-only, with an Edit button (Cancel/Save sheet, like the
/// roster's player editor), a Start Game action, and a confirmed Delete.
struct GameDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let gameID: UUID
    /// Called when the user starts the game; the parent navigates into scoring.
    var onStart: (UUID) -> Void

    @State private var game: Game
    @State private var editing = false
    @State private var confirmingDelete = false

    init(gameID: UUID, onStart: @escaping (UUID) -> Void) {
        self.gameID = gameID
        self.onStart = onStart
        _game = State(initialValue: Game(opponent: ""))
    }

    var body: some View {
        Form {
            // One section, not three. "Details" held a single row (Format) for
            // a header, a card and a gap — about 140pt for one value — and the
            // split between "Details" and "Opponent" was arbitrary: every row
            // here describes the same game (#193).
            //
            // `Opponent` itself is gone: the navigation title already reads
            // "vs Riverside", so the row restated what was on screen.
            Section {
                LabeledContent("Date", value: game.date.gameDayAndTime)
                LabeledContent("Home / Away", value: game.isHome ? "Home" : "Away")
                LabeledContent("Jersey") {
                    JerseyIndicator(color: store.team.jersey(isHome: game.isHome))
                }
                LabeledContent("Format", value: game.periodFormat.displayName)
                if !game.league.isEmpty { LabeledContent("League", value: game.league) }
                if !game.location.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        LabeledContent("Location", value: game.location)
                        if !game.locationAddress.isEmpty {
                            Text(game.locationAddress).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Start Game gets a section to itself. #193 merged these two to
            // save the ~90pt gap between them, which was right when both were
            // ordinary rows — but a destructive action sitting flush against
            // the primary one reads as a pair of equals and is easy to hit by
            // mistake. Here the gap *is* the design, and this screen has room
            // to spend on it.
            Section {
                Button {
                    start()
                } label: {
                    // A Label wrapped directly in .frame(maxWidth: .infinity)
                    // silently drops its icon here — rebuilt as an explicit
                    // Image + Text, grouped tight and centered as a pair (#137).
                    HStack(spacing: 8) {
                        Image(systemName: "play.fill")
                            .accessibilityHidden(true)
                        Text("Start Game")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            // No card and no pill — plain red text under the Start Game card,
            // the way iOS puts a destructive action at the foot of a screen. A
            // tinted pill inside a white row was a container within a
            // container, and it still read as Start Game's equal. The tap
            // target is held at 44pt by the row's own height (#195).
            Section {
                Button(role: .destructive) {
                    confirmingDelete = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .accessibilityHidden(true)
                        Text("Delete Game")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .navigationTitle(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { editing = true }
            }
        }
        // Inline titles center between the leading and trailing toolbar
        // items, not the screen — the automatic back button mirrors the
        // Games list's title text, which is far wider than "Edit" and
        // pushes the centered title visibly left (#135). Trimming the back
        // button to just its chevron shrinks that width mismatch.
        .toolbarRole(.editor)
        .onAppear(perform: load)
        // A confirmation this screen didn't need while Delete was a small text
        // row. Sharing Start Game's shape and sitting directly under it, it's
        // now as easy to hit by accident, and there is no undo (#195).
        .confirmationDialog("Delete this game?",
                            isPresented: $confirmingDelete,
                            titleVisibility: .visible) {
            Button("Delete Game", role: .destructive, action: delete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This can't be undone.")
        }
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

                Section {
                    TextField("Scouting notes, observations…", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                } header: {
                    Text("Notes")
                } footer: {
                    // Say so where it's typed. Notes have always travelled to
                    // followers inside the published game blob; now that a
                    // follower's screen actually shows them, the person
                    // writing one should know who reads it — not find out
                    // from someone quoting it back.
                    Text("Followers of this team can read these.")
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
