import SwiftUI

/// Detail / edit screen for a scheduled (not-yet-started) game. Review or edit
/// the matchup you pre-entered, then start scoring — or delete it. Edits persist
/// immediately, matching the rest of the app.
struct GameDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    let gameID: UUID
    /// Called when the user starts the game; the parent navigates into scoring.
    var onStart: (UUID) -> Void

    @State private var game: Game

    init(gameID: UUID, onStart: @escaping (UUID) -> Void) {
        self.gameID = gameID
        self.onStart = onStart
        _game = State(initialValue: Game(opponent: ""))
    }

    var body: some View {
        Form {
            Section("Matchup") {
                TextField("Opponent", text: field(\.opponent))
                    .textInputAutocapitalization(.words)
                Toggle("Home game", isOn: field(\.isHome))
                    .tint(.teamAccent)
                DatePicker("Date", selection: field(\.date), displayedComponents: .date)
            }

            Section("Details (optional)") {
                TextField("League / Tournament", text: field(\.league))
                TextField("Location / Gym", text: field(\.location))
            }

            Section("Format") {
                Picker("Periods", selection: field(\.periodFormat)) {
                    ForEach(PeriodFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
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
        .onAppear(perform: load)
    }

    /// A binding that writes straight through to the persisted game.
    private func field<T>(_ keyPath: WritableKeyPath<Game, T>) -> Binding<T> {
        Binding(
            get: { game[keyPath: keyPath] },
            set: { game[keyPath: keyPath] = $0; store.updateGame(game) }
        )
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
