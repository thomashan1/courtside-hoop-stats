import SwiftUI

struct RosterView: View {
    @EnvironmentObject var store: AppStore
    @State private var editingPlayer: Player?
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                Section("Team") {
                    TextField("Team name", text: Binding(
                        get: { store.team.name },
                        set: { store.renameTeam($0) }
                    ))
                    .textInputAutocapitalization(.words)
                }

                Section {
                    HStack(spacing: 16) {
                        Button {
                            store.textSizeIndex = max(0, store.textSizeIndex - 1)
                        } label: {
                            Image(systemName: "textformat.size.smaller")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.textSizeIndex == 0)

                        Text("Aa")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)

                        Button {
                            store.textSizeIndex = min(AppTextSize.maxIndex, store.textSizeIndex + 1)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.textSizeIndex == AppTextSize.maxIndex)
                    }
                } header: {
                    Text("Text Size")
                } footer: {
                    Text("Makes text throughout the app larger. Also follows your device's text size if that's set higher.")
                }

                Section {
                    Picker("Home jersey", selection: homeJerseyBinding) {
                        ForEach(JerseyColor.allCases) { color in
                            Text(color.label).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Home Jersey")
                } footer: {
                    Text("Away games use the other jersey — \(homeJerseyBinding.wrappedValue.opposite.label).")
                }

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
                    .onMove { store.movePlayers(from: $0, to: $1) }
                }
            }
            .navigationTitle("Roster")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !store.team.players.isEmpty { EditButton() }
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

    private var homeJerseyBinding: Binding<JerseyColor> {
        Binding(
            get: { store.team.homeJersey ?? .white },
            set: { store.team.homeJersey = $0 }
        )
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
