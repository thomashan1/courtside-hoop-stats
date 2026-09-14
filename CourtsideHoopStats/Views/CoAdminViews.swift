import SwiftUI

// MARK: - PROTOTYPE (#169) — co-admin screens
//
// Design prototype for review, not a shipping feature. Nothing here talks to
// CloudKit: the co-admin persona is seeded by the screenshot harness
// (`-uiTestCoAdminSelf`), and the invite role chooser stops at the system share
// sheet, which is where the real work would begin.

/// Pick what an invitee is allowed to do, *before* handing off to the system
/// share sheet (#169).
///
/// The system sheet already has a permission picker — "View only" / "Can make
/// changes" — so this screen looks like a duplicate until you read what it
/// says. CloudKit's wording is about records; ours is about the app. "Can make
/// changes" is true of a co-admin and still leaves the owner expecting the
/// wrong thing, because the one change a co-admin *can't* make is the one this
/// app is for: scoring a game while it's being played. That sentence has
/// nowhere to live inside Apple's sheet, so it lives here, and the sheet is
/// then pinned to the single permission that was chosen.
struct InviteRoleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let teamName: String
    /// Called with the chosen role once the owner taps Next; the caller
    /// prepares the share and presents the system sheet.
    let onChoose: (SharingRole) -> Void

    @State private var role: SharingRole = .follower

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SharingRole.allCases) { option in
                        Button {
                            role = option
                        } label: {
                            roleRow(option)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("What can they do?")
                } footer: {
                    Text("You can change this later, or remove someone entirely, from this team's people list.")
                }

                if role == .coTracker {
                    Section {
                        Label {
                            Text("Scoring stays with you. A co-admin watching a game in progress sees the score update, but can't record a basket.")
                        } icon: {
                            Image(systemName: "hand.raised.fill")
                                .foregroundStyle(Color.teamAccent)
                        }
                        .font(.footnote)
                    }
                }
            }
            .navigationTitle("Invite to \(teamName)")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.teamAccent)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    // "Next", not "Invite": the actual inviting happens in the
                    // system sheet that follows, and a button that promises to
                    // send something and instead opens another sheet reads as
                    // a misfire.
                    Button("Next") {
                        let chosen = role
                        dismiss()
                        onChoose(chosen)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func roleRow(_ option: SharingRole) -> some View {
        RoleChoiceRow(option: option, isSelected: role == option)
    }
}

/// One selectable role, shared by the invite sheet and the change-role sheet so
/// the wording and the hit target can't diverge between them.
struct RoleChoiceRow: View {
    let option: SharingRole
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                .font(.title3)
                .foregroundStyle(isSelected ? Color.teamAccent : .secondary)
                .minimumTapTarget()

            VStack(alignment: .leading, spacing: 3) {
                Label(option.label, systemImage: option.systemImage)
                    .font(.headline)
                Text(option.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("role-\(option.rawValue)")
    }
}

/// Change what one person already on the team may do, or remove them (#169).
///
/// A record editor, so it follows the house pattern rather than inventing one:
/// staged in local `@State`, Cancel discards, Save commits, and the destructive
/// action is a red button at the bottom of the sheet (UI_GUIDELINES 1 and 2).
/// Promoting a follower and demoting a co-admin are the same screen — the
/// alternative was two menu items that each need their own confirmation.
struct ChangeRoleSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: SharedParticipant
    let onSave: (SharingRole) -> Void
    let onRemove: () -> Void

    /// Seeded from `person` on appear rather than in an `init`, which silently
    /// rendered with neither option selected.
    @State private var role: SharingRole = .follower
    @State private var confirmingRemove = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(SharingRole.allCases) { option in
                        Button { role = option } label: {
                            RoleChoiceRow(option: option, isSelected: role == option)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("What can they do?")
                } footer: {
                    if role == .follower, person.role == .coTracker {
                        Text("Save to take away their editing. Games and roster changes they already made stay — they just can't make new ones.")
                    } else if role == .coTracker, person.role == .follower {
                        Text("Save to let them edit. Scoring a live game stays yours either way.")
                    }
                }

                Section {
                    Button("Remove from Team", role: .destructive) { confirmingRemove = true }
                        .foregroundStyle(.red)
                } footer: {
                    Text("They lose access to this team entirely. You keep everything.")
                }
            }
            .navigationTitle(person.name)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Color.teamAccent)
            .onAppear { role = person.role }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let chosen = role
                        dismiss()
                        onSave(chosen)
                    }
                    .fontWeight(.semibold)
                    .disabled(role == person.role)
                }
            }
            .confirmationDialog("Remove \(person.name)?",
                                isPresented: $confirmingRemove,
                                titleVisibility: .visible) {
                Button("Remove", role: .destructive) {
                    dismiss()
                    onRemove()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("They'll lose access to this team's games, stats and roster.")
            }
        }
    }
}

// MARK: - The one thing a co-admin can't do

/// What a co-admin sees when they open a game that is being scored right now
/// (#169).
///
/// Deliberately **not** the Live Scoring screen with its point pad greyed out.
/// A disabled control still invites the tap, and the tracker's own screen is
/// built around a deck of players you press — rendering it inert would be a
/// screen whose entire purpose is unavailable. This is the follower's view of
/// a live game instead, which is exactly what a co-admin is for the duration
/// of one: someone watching the score arrive.
///
/// The line at the top names the person scoring and says when the co-admin's
/// own editing comes back, so "can't touch this" reads as a handover rather
/// than as a permissions failure.
struct CoAdminLiveGameView: View {
    @EnvironmentObject var store: AppStore
    let gameID: UUID

    private var game: Game? { store.game(id: gameID) }
    private var roster: [Player] { store.team.players }
    private var ownerName: String { store.coAdminOwnerName ?? "the owner" }

    var body: some View {
        Group {
            if let game {
                content(for: game)
            } else {
                ContentUnavailableView("Game Unavailable", systemImage: "questionmark.circle")
            }
        }
        .navigationTitle(game.map { $0.opponent.isEmpty ? "Game" : "vs \($0.opponent)" } ?? "Game")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarRole(.editor)
    }

    private func content(for game: Game) -> some View {
        List {
            Section {
                GameHeaderCard(game: game, ourName: store.team.name,
                               kit: store.team.jersey(isHome: game.isHome)) {
                    Label {
                        Text("Co-admin").font(.subheadline.weight(.semibold))
                    } icon: {
                        Image(systemName: "pencil.and.list.clipboard").font(.caption)
                    }
                } trailing: {
                    StatusBadge(text: "In Progress", color: .teamAccent, compact: true)
                }
            }

            Section {
                Label {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(ownerName) is scoring this game")
                            .font(.subheadline.weight(.semibold))
                        Text("The score updates here as it's recorded. You can edit this game — the score log, the details, the box score — once it's final.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: "figure.basketball")
                        .foregroundStyle(Color.teamAccent)
                }
            }

            if !game.events.isEmpty {
                Section {
                    EventLogView(game: .constant(game),
                                 players: roster,
                                 isEditable: false,
                                 newestFirst: true,
                                 persist: {})
                } header: {
                    HStack {
                        Text("Score Log")
                        Spacer()
                        Text("Most recent on top")
                            .font(.caption2)
                            .textCase(nil)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            let stats = game.stats(for: roster)
            if !stats.isEmpty {
                Section("Player Stats") {
                    PlayerStatsTable(stats: stats, didNotPlay: game.didNotPlay(from: roster))
                }
            }
        }
    }
}
