import SwiftUI
import UniformTypeIdentifiers

/// App-level settings, including team management (#20).
struct SettingsView: View {
    @EnvironmentObject var store: AppStore

    @State private var showAddTeam = false
    @State private var newTeamName = ""
    @State private var editingTeam: TeamRef?

    // Team import (#40).
    @State private var showImporter = false
    @State private var importMessage: String?

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
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: [.json]) { result in
                handleImport(result)
            }
            .alert("Import Team", isPresented: Binding(
                get: { importMessage != nil },
                set: { if !$0 { importMessage = nil } }
            )) {
                Button("OK", role: .cancel) { importMessage = nil }
            } message: {
                Text(importMessage ?? "")
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

            // Import a team + roster from a shared/AirDrop'd .json file (#40).
            Button {
                showImporter = true
            } label: {
                Label("Import Team…", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Teams")
        } footer: {
            Text("Tap a team to make it active (checkmark) — Roster and the Games list follow it. Tap ⓘ to edit its name, jersey, export it, or delete it.")
        }
    }

    // MARK: - Import (#40)

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Files delivered by the picker are security-scoped.
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let export = try TeamExport.coder.decoder.decode(TeamExport.self, from: data)
                guard export.format == TeamExport.marker else {
                    importMessage = "That file isn't a Courtside team export."
                    return
                }
                let team = store.importTeam(from: export)
                importMessage = "Imported “\(team.name)” with ^[\(team.players.count) player](inflect: true). It's now the active team."
            } catch {
                importMessage = "Couldn't read that file. Make sure it's a Courtside team export (.json)."
            }
        case .failure:
            break   // user cancelled the picker
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
    @Environment(\.teamSharingService) private var sharing
    let teamID: UUID

    // Staged edits (Cancel/Save), matching every other record editor.
    @State private var name = ""
    @State private var jersey: JerseyColor = .white
    @State private var confirmingDelete = false
    @State private var sharingError: String?
    @State private var preparedShare: PreparedShare?
    @State private var isPreparingShare = false
    @State private var showingFollowers = false

    private var team: Team? { store.teams.first { $0.id == teamID } }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section("Team Name") {
                TextField("Team name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section {
                Picker("Home jersey", selection: $jersey) {
                    ForEach(JerseyColor.allCases) { color in
                        Text(color.label).tag(color)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Home Jersey")
            } footer: {
                Text("Away games use the other jersey — \(jersey.opposite.label).")
            }

            // Live CloudKit sharing (#57) leads: it's the primary way to get a
            // team to someone else. Export sits below as the offline/backup
            // fallback. Hidden until a real sharing backend is injected — the
            // Noop default reports `isAvailable == false`, so no half-built
            // button ships. See docs/SHARING.md.
            if let team, sharing.isAvailable {
                Section {
                    Button {
                        shareTeam(team)
                    } label: {
                        HStack {
                            Label("Share Team…", systemImage: "person.crop.circle.badge.plus")
                            if isPreparingShare {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isPreparingShare)

                    // Always offered, never gated on local state: "who did I
                    // share this with?" should be answerable at any time, and
                    // the sheet says plainly when nobody is following yet.
                    Button {
                        showingFollowers = true
                    } label: {
                        Label("See Who's Following", systemImage: "person.2")
                    }
                } header: {
                    Text("Share with Followers")
                } footer: {
                    Text("Invite family and friends by Apple Account to follow this team's games and stats. They'll need an iPhone signed into iCloud, and can view but not edit.\n\nUpdates arrive within seconds when you have signal. In a gym with no reception they'll catch up once you're back online.")
                }
            }

            if let team {
                Section {
                    ShareLink(item: TeamPackage(team: team),
                              preview: SharePreview("\(team.name) roster")) {
                        Label("Export Team…", systemImage: "square.and.arrow.up")
                    }
                } header: {
                    Text("Export a Backup")
                } footer: {
                    Text("Save or AirDrop this team and its roster as a file — a backup, or a copy someone else can import and edit as their own team. Import it from Settings ▸ Teams ▸ Import Team.")
                }
            }

            if store.teams.count > 1 {
                Section {
                    Button(role: .destructive) {
                        confirmingDelete = true
                    } label: {
                        Label("Delete Team", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
        }
        .navigationTitle(team?.name ?? "Team")
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
            if let team {
                name = team.name
                jersey = team.homeJersey ?? .white
            }
        }
        .confirmationDialog("Delete \(team?.name ?? "team")?",
                            isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete Team & Its Games", role: .destructive) {
                store.deleteTeam(teamID)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This deletes the team and all of its games. This can't be undone.")
        }
        .alert("Couldn't Share", isPresented: Binding(
            get: { sharingError != nil },
            set: { if !$0 { sharingError = nil } }
        )) {
            Button("OK", role: .cancel) { sharingError = nil }
        } message: {
            Text(sharingError ?? "")
        }
        .sheet(isPresented: $showingFollowers) {
            if let team { FollowersView(team: team) }
        }
        .sheet(item: $preparedShare) { prepared in
            CloudSharingSheet(share: prepared.share,
                              container: prepared.container,
                              title: team?.name,
                              onError: { sharingError = $0.localizedDescription })
                .ignoresSafeArea()
        }
    }

    /// Begin sharing this team (#57): mirror it to CloudKit, then hand the
    /// resulting share to the system invite sheet. Talking to iCloud can take a
    /// moment, so the button shows a spinner rather than appearing dead.
    private func shareTeam(_ team: Team) {
        let games = store.games.filter { ($0.teamID ?? team.id) == team.id }
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do {
                preparedShare = try await sharing.prepareShare(for: team, games: games)
                // From here on, edits to this team publish to its followers.
                store.markShared(team.id)
            } catch {
                sharingError = error.localizedDescription
            }
        }
    }

    private func save() {
        guard var team else { return }
        team.name = trimmedName
        team.homeJersey = jersey
        store.updateTeam(team)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
