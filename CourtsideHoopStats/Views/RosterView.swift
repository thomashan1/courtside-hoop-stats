import SwiftUI

struct RosterView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingPlayer: Player?
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                // Roster is players-only. Team name/jersey and switching the
                // active team all live in Settings now.
                Section("Players") {
                    if store.team.players.isEmpty {
                        Text("No players yet. Tap ✚ to add your roster.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.team.players) { player in
                        Button {
                            editingPlayer = player
                        } label: {
                            HStack(spacing: 12) {
                                JerseyBadge(number: player.number, size: 36)
                                Text(player.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDelete { store.deletePlayers(at: $0) }
                }
            }
            // Show the active team name (multi-team) — the tab bar labels it "Roster".
            .navigationTitle(store.team.name)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if store.team.players.count > 1 {
                        Menu {
                            Button("Name") { store.sortPlayers(by: .name) }
                            Button("Number") { store.sortPlayers(by: .number) }
                        } label: {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                PlayerEditSheet(player: nil)
            }
            .sheet(item: $editingPlayer) { player in
                PlayerEditSheet(player: player)
            }
        }
    }
}

struct PlayerEditSheet: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// nil = adding a new player; non-nil = editing an existing one.
    let player: Player?

    @State private var name = ""
    @State private var number = ""

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                    .textInputAutocapitalization(.words)
                TextField("Jersey number", text: $number)
                    .keyboardType(.numbersAndPunctuation)

                // Delete lives here too, so you don't have to swipe the row.
                if let player {
                    Section {
                        Button(role: .destructive) {
                            store.deletePlayer(player.id)
                            dismiss()
                        } label: {
                            Label("Delete Player", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(player == nil ? "Add Player" : "Edit Player")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                if let player {
                    name = player.name
                    number = player.number
                }
            }
        }
    }

    private func save() {
        let cleanNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
        if var player {
            player.name = trimmedName
            player.number = cleanNumber
            store.updatePlayer(player)
        } else {
            store.addPlayer(name: trimmedName, number: cleanNumber)
        }
        dismiss()
    }
}

#Preview {
    RosterView()
        .environmentObject(AppStore())
}
