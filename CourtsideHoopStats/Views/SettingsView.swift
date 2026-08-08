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

    /// A team swiped for deletion, pending confirmation.
    @State private var pendingTeamDelete: Team?

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
                                .minimumTapTarget()
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.textSizeIndex == 0)
                        .accessibilityLabel("Smaller text")

                        Text("Aa")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)

                        Button {
                            store.textSizeIndex = min(AppTextSize.maxIndex, store.textSizeIndex + 1)
                        } label: {
                            Image(systemName: "textformat.size.larger")
                                .minimumTapTarget()
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.textSizeIndex == AppTextSize.maxIndex)
                        .accessibilityLabel("Larger text")
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

                // Which build this is, and — the part that actually causes
                // confusion — which CloudKit database it talks to. Two phones
                // on different routes can't see each other's shares (#111).
                // A plain row, not `Section { EmptyView() } footer:` — an
                // empty section renders nothing at all, footer included.
                Section {
                    Text(BuildInfo.summary)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .textSelection(.enabled)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .accessibilityLabel(BuildInfo.accessibilitySummary)
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
            .modifier(DeleteTeamConfirmation(team: $pendingTeamDelete) { id in
                store.deleteTeam(id)
            })
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
                    // Red by tint, **not** by `role: .destructive`.
                    //
                    // A destructive role makes SwiftUI animate the row away as
                    // soon as it's tapped, on the assumption the data is about
                    // to lose it. Behind a confirmation it isn't: the next
                    // update reports the row back and UIKit traps with
                    // "number of items after the update (4) … before (3) …
                    // 0 inserted, 0 deleted". The delete goes through the
                    // dialog, so the swipe must leave the row alone.
                    Button {
                        pendingTeamDelete = team
                    } label: { Label("Delete", systemImage: "trash") }
                    .tint(.red)
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

/// Confirmation for deleting a team, which takes its roster and every game it
/// played with it (UI_GUIDELINES §2).
///
/// A separate modifier rather than another `.confirmationDialog` inline: this
/// view's body is already at the type-checker's time limit, and adding one more
/// builder to the chain tips it over.
private struct DeleteTeamConfirmation: ViewModifier {
    @Binding var team: Team?
    let onDelete: (UUID) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "Delete this team?",
            isPresented: Binding(get: { team != nil },
                                 set: { if !$0 { team = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete Team & Its Games", role: .destructive) {
                guard let id = team?.id else { return }
                team = nil
                onDelete(id)
            }
            Button("Cancel", role: .cancel) { team = nil }
        } message: {
            if let team {
                Text("“\(team.name)”, its roster and every game it played will be deleted. This can't be undone.")
            }
        }
    }
}

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
                HStack(spacing: 8) {
                    Text("^[\(team.players.count) player](inflect: true)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if isShared {
                        StatusBadge(text: "Shared", color: .teamAccent,
                                    compact: true, systemImage: "person.2.fill")
                    }
                }
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
    @State private var showingFollowers = false

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

                // Both kits, drawn, with the home one marked. The old control
                // was a segmented "Worn at home: White | Maroon" — abstract
                // enough that it wasn't clear what it changed, and it never
                // showed the colour you'd just picked.
                HomeJerseyPicker(kit: teamColor, home: $jersey)
                    // The home choice is White or *the team colour*, so changing
                    // the colour has to carry the choice with it — otherwise the
                    // selection points at a colour no longer on offer and
                    // neither kit reads as selected.
                    .onChange(of: teamColor) { previous, current in
                        if jersey == previous { jersey = current }
                    }
            } header: {
                Text("Jerseys")
            } footer: {
                Text("Tap whichever your team wears at home. Away games wear the other one — \(awayJerseyLabel).")
            }

            // Live CloudKit sharing (#57) leads: it's the primary way to get a
            // team to someone else. Export sits below as the offline/backup
            // fallback. Hidden until a real sharing backend is injected — the
            // Noop default reports `isAvailable == false`, so no half-built
            // button ships. See docs/SHARING.md.
            if let team, sharing.isAvailable {
                Section {
                    // One row, not two. "Share Team…" and "See Who's Following"
                    // sat side by side doing overlapping jobs — and once a team
                    // was shared, the first one's job *was* "add more people",
                    // which its wording didn't say.
                    //
                    // A shared album works this way: one People screen that
                    // lists who's on it, invites more, and stops sharing. That
                    // screen is `FollowersView`; this is the way in.
                    Button {
                        showingFollowers = true
                    } label: {
                        HStack {
                            Label(store.isShared(team.id) ? "Followers" : "Share Team…",
                                  systemImage: store.isShared(team.id)
                                      ? "person.2.fill" : "person.crop.circle.badge.plus")
                            Spacer()
                            if store.isShared(team.id) {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
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
        .sheet(isPresented: $showingFollowers) {
            if let team { FollowersView(team: team) }
        }
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


/// The two kits a team owns, drawn side by side, with the home one selected.
///
/// Replaces a segmented "Worn at home: White | Maroon". That control asked the
/// right question but showed nothing: no jersey, no colour, and — the actual
/// complaint — no feedback that picking a team colour had changed anything.
private struct HomeJerseyPicker: View {
    let kit: JerseyColor
    @Binding var home: JerseyColor

    var body: some View {
        HStack(spacing: 12) {
            tile(.white)
            tile(kit)
        }
        .padding(.vertical, 4)
    }

    private func tile(_ colour: JerseyColor) -> some View {
        let isHome = home == colour
        return Button {
            home = colour
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(colour.swatch)
                    // White needs an outline or it's an invisible disc on a
                    // white row.
                    .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 0.5))
                    .frame(width: 44, height: 44)

                Text(colour.label)
                    .font(.caption)
                    .foregroundStyle(.primary)

                Text(isHome ? "HOME" : "AWAY")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isHome ? Color.teamAccent : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isHome ? Color.teamAccent.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isHome ? Color.teamAccent : Color(.separator),
                                  lineWidth: isHome ? 2 : 0.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(colour.label) jersey")
        .accessibilityValue(isHome ? "Home" : "Away")
        .accessibilityAddTraits(isHome ? [.isButton, .isSelected] : .isButton)
    }
}
