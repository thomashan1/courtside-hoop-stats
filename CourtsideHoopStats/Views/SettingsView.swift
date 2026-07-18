import SwiftUI

/// App-level settings, including team management (#20).
struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var showAddTeam = false
    @State private var newTeamName = ""
    @State private var renamingTeam: Team?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                teamsSection

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

                    if store.textSizeIndex != 0 {
                        Button("Reset to Default") {
                            store.textSizeIndex = 0
                        }
                    }
                } header: {
                    Text("Text Size")
                } footer: {
                    Text("Makes text throughout the app larger. Also follows your device's text size if that's set higher.")
                }
            }
            .navigationTitle("Settings")
            .alert("New Team", isPresented: $showAddTeam) {
                TextField("Team name", text: $newTeamName)
                Button("Cancel", role: .cancel) {}
                Button("Add") { store.addTeam(name: newTeamName) }
            } message: {
                Text("Create another team to track separately. It becomes the active team.")
            }
            .alert("Rename Team", isPresented: renameAlertPresented) {
                TextField("Team name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingTeam = nil }
                Button("Save") {
                    if let team = renamingTeam { store.renameTeam(id: team.id, to: renameText) }
                    renamingTeam = nil
                }
            }
        }
    }

    // MARK: - Teams

    private var teamsSection: some View {
        Section {
            ForEach(store.teams) { team in
                Button {
                    store.setActiveTeam(team.id)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: team.id == store.activeTeamID ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(team.id == store.activeTeamID ? Color.teamAccent : .secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(team.name).foregroundStyle(.primary)
                            Text("^[\(team.players.count) player](inflect: true)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .swipeActions(edge: .trailing) {
                    if store.teams.count > 1 {
                        Button(role: .destructive) {
                            store.deleteTeam(team.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
                    Button {
                        renamingTeam = team
                        renameText = team.name
                    } label: { Label("Rename", systemImage: "pencil") }
                    .tint(.blue)
                }
            }

            Button {
                newTeamName = ""
                showAddTeam = true
            } label: {
                Label("Add Team", systemImage: "plus")
            }
        } header: {
            Text("Teams")
        } footer: {
            Text("The active team (checkmark) is what Roster and the Games list show. Deleting a team also deletes its games.")
        }
    }

    private var renameAlertPresented: Binding<Bool> {
        Binding(get: { renamingTeam != nil }, set: { if !$0 { renamingTeam = nil } })
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
