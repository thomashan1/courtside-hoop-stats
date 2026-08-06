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

                // Only meaningful once you're following someone — an owner
                // scoring their own game has nothing to be notified about.
                if !store.followedTeams.isEmpty {
                    Section {
                        Picker("Notify me", selection: $store.alertCadence) {
                            ForEach(FollowerAlertCadence.allCases) { cadence in
                                Text(cadence.label).tag(cadence)
                            }
                        }
                    } header: {
                        Text("Following Notifications")
                    } footer: {
                        Text(store.alertCadence.detail)
                    }
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
                TeamRow(team: team,
                        isActive: team.id == store.activeTeamID,
                        isShared: store.isShared(team.id),
                        onEdit: { editingTeam = TeamRef(id: team.id) },
                        onSelect: { store.setActiveTeam(team.id) })
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

/// One team in Settings: tap the row to make it active, tap ⓘ to edit it.
///
/// The two targets sit in the same row and do very different things, so the ⓘ
/// gets an explicit 44pt hit area. Without it the glyph is ~22pt, and a miss
/// doesn't do nothing — it falls through to the row and silently switches the
/// active team, re-pointing Games and Roster at another team with no feedback.
private struct TeamRow: View {
    let team: Team
    let isActive: Bool
    /// Whether this team is shared with followers. Read from the store rather
    /// than fetched, so a list of teams costs no network calls.
    let isShared: Bool
    let onEdit: () -> Void
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.teamAccent : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(team.name).foregroundStyle(.primary)

                // Sharing is invisible from here otherwise: you'd have to open
                // each team in turn to find out which ones other people can
                // see. That matters more than most settings, because the thing
                // being shared is a roster of children's names (#93).
                HStack(spacing: 6) {
                    Text("^[\(team.players.count) player](inflect: true)")
                    if isShared {
                        Label("Shared", systemImage: "person.2.fill")
                            .foregroundStyle(Color.teamAccent)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button(action: onEdit) {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.teamAccent)
                    .minimumTapTarget()
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Edit \(team.name)")
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        // A List infers the separator inset from the row's contents, and the
        // "Shared" tag moved that inference — the divider jumped inward to
        // start under the tag instead of under the team name. Pin it.
        .alignmentGuide(.listRowSeparatorLeading) { $0[.leading] }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

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
    @State private var teamColor: JerseyColor = .blue
    @State private var confirmingDelete = false
    @State private var sharingError: String?
    @State private var preparedShare: PreparedShare?
    @State private var isPreparingShare = false
    @State private var showingFollowers = false
    @State private var inviteURL: URL?
    @State private var didCopyLink = false

    private var team: Team? { store.teams.first { $0.id == teamID } }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// The kit worn away — the one that isn't worn at home.
    private var awayJerseyLabel: String {
        (jersey == .white ? teamColor : .white).label
    }

    var body: some View {
        Form {
            Section("Team Name") {
                TextField("Team name", text: $name)
                    .textInputAutocapitalization(.words)
            }

            Section {
                // Nearly every team is white plus one colour, so this asks for
                // the colour and which one is worn at home, rather than making
                // both jerseys free-form.
                Picker("Team colour", selection: $teamColor) {
                    ForEach(JerseyColor.teamColors) { color in
                        Label {
                            Text(color.label)
                        } icon: {
                            Circle()
                                .fill(color.swatch)
                                .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                        }
                        .tag(color)
                    }
                }

                Picker("Worn at home", selection: $jersey) {
                    Text("White").tag(JerseyColor.white)
                    Text(teamColor.label).tag(teamColor)
                }
                .pickerStyle(.segmented)
                // The home choice is White or *the team colour*, so changing
                // the colour has to carry the choice with it — otherwise the
                // selection points at a colour no longer on offer and the
                // segmented control shows nothing selected.
                .onChange(of: teamColor) { previous, current in
                    if jersey == previous { jersey = current }
                }
            } header: {
                Text("Jerseys")
            } footer: {
                Text("Away games wear the other one — \(awayJerseyLabel).")
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

                    // The system share sheet's own Copy Link hides the URL and
                    // dismisses on tap. Showing it here means you can read it,
                    // select part of it, or copy it and carry on — handy for
                    // sending the invite by a route the sheet doesn't offer.
                    if let inviteURL {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(inviteURL.absoluteString)
                                .font(.footnote.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(2)
                                .truncationMode(.middle)

                            Button {
                                UIPasteboard.general.url = inviteURL
                                withAnimation { didCopyLink = true }
                            } label: {
                                Label(didCopyLink ? "Copied" : "Copy Invite Link",
                                      systemImage: didCopyLink ? "checkmark" : "doc.on.doc")
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 2)
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
                teamColor = team.kitColor
            }
        }
        .task(id: team?.id) { await loadInviteLink() }
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
                await loadInviteLink()
            } catch {
                sharingError = error.localizedDescription
            }
        }
    }

    /// Fetch the invite link so it can be shown and copied without going
    /// through the system sheet. Silent on failure — an absent link just hides
    /// the row, and the sheet remains the primary way to invite.
    private func loadInviteLink() async {
        guard let team, sharing.isAvailable else { return }
        inviteURL = try? await sharing.shareURL(for: team)
        didCopyLink = false
    }

    private func save() {
        guard var team else { return }
        team.name = trimmedName
        team.homeJersey = jersey
        team.teamColor = teamColor
        store.updateTeam(team)
        dismiss()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppStore())
}
