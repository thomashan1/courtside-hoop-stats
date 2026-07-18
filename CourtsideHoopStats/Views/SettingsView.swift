import SwiftUI

/// App-level settings, including team management (#20).
struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var showAddTeam = false
    @State private var newTeamName = ""
    @State private var editingTeam: TeamRef?

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
            .sheet(item: $editingTeam) { ref in
                NavigationStack { TeamDetailView(teamID: ref.id) }
            }
        }
    }

    // MARK: - Teams

    private var teamsSection: some View {
        Section {
            ForEach(store.teams) { team in
                HStack(spacing: 12) {
                    Image(systemName: team.id == store.activeTeamID ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(team.id == store.activeTeamID ? Color.teamAccent : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(team.name).foregroundStyle(.primary)
                        Text("^[\(team.players.count) player](inflect: true)")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    // Edit name / jersey / delete — separate from selecting active.
                    Button {
                        editingTeam = TeamRef(id: team.id)
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(Color.teamAccent)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Edit \(team.name)")
                }
                .contentShape(Rectangle())
                .onTapGesture { store.setActiveTeam(team.id) }   // tap = make active
                .swipeActions(edge: .trailing) {
                    if store.teams.count > 1 {
                        Button(role: .destructive) {
                            store.deleteTeam(team.id)
                        } label: { Label("Delete", systemImage: "trash") }
                    }
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
            Text("Tap a team to make it active (checkmark) — Roster and the Games list follow it. Tap ⓘ to edit its name, jersey, or delete it.")
        }
    }
}

/// Identifiable wrapper so a team id can drive a `.sheet(item:)`.
private struct TeamRef: Identifiable { let id: UUID }

// MARK: - Team detail (all team editing lives here, #27-followup)

/// Edit a single team's name and home jersey, make it active, or delete it.
/// Consolidates every team-level edit into Settings so Roster is players-only.
struct TeamDetailView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss
    let teamID: UUID

    private var team: Team? { store.teams.first { $0.id == teamID } }

    var body: some View {
        Form {
            if let team {
                Section("Team Name") {
                    TextField("Team name", text: Binding(
                        get: { team.name },
                        set: { var t = team; t.name = $0; store.updateTeam(t) }
                    ))
                    .textInputAutocapitalization(.words)
                }

                Section {
                    Picker("Home jersey", selection: Binding(
                        get: { team.homeJersey ?? .white },
                        set: { var t = team; t.homeJersey = $0; store.updateTeam(t) }
                    )) {
                        ForEach(JerseyColor.allCases) { color in
                            Text(color.label).tag(color)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Home Jersey")
                } footer: {
                    Text("Away games use the other jersey — \((team.homeJersey ?? .white).opposite.label).")
                }

                if store.teams.count > 1 {
                    Section {
                        Button(role: .destructive) {
                            store.deleteTeam(teamID)
                            dismiss()
                        } label: {
                            Label("Delete Team", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                    } footer: {
                        Text("Deletes this team and all of its games.")
                    }
                }
            }
        }
        .navigationTitle(team?.name ?? "Team")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
