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
                // No section header: the tab says Roster and the title says the
                // team name. A third label for one list earned nothing but
                // ~30pt (#193).
                Section {
                    if store.team.players.isEmpty {
                        Text("No players yet. Tap ✚ to add your roster.")
                            .foregroundStyle(.secondary)
                    }

                    ForEach(store.team.players) { player in
                        Button {
                            editingPlayer = player
                        } label: {
                            HStack(spacing: 12) {
                                // 28, not 36: the badge was setting the row
                                // height, and a roster of 12 didn't fit a
                                // screen for a name and a number (#193).
                                //
                                // No `minHeight: 44` here — that was the first
                                // attempt and it made rows *taller*, because
                                // the content is shorter than 44 so the floor
                                // added height and the list's own insets
                                // stacked on top. 28 + default insets already
                                // clears 44.
                                JerseyBadge(number: player.number, size: 28)
                                Text(player.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        // Without this the Button tints its whole label, so the
                        // names rendered accent-blue and read as links despite
                        // being explicitly `.primary` (#193).
                        .buttonStyle(.plain)
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
                                .minimumTapTarget()
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .minimumTapTarget()
                    }
                    .accessibilityLabel("Add Player")
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
                TextField("Jersey Number", text: $number)
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
