import SwiftUI

/// Who a team you own is shared with (#57).
///
/// Reachable from the team's detail *and* from the live-scoring screen, because
/// "who can see this?" is a question that comes up mid-game — and leaving a game
/// in progress to go dig through Settings is exactly what this app shouldn't
/// make you do.
struct FollowersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.teamSharingService) private var sharing
    @EnvironmentObject private var store: AppStore
    let team: Team

    @State private var participants: [SharedParticipant] = []
    @State private var isLoading = true
    @State private var loadError: String?

    // Everything sharing-related for this team lives here, the way a shared
    // album keeps its people, its invite and its "Stop Sharing" on one screen.
    @State private var preparedShare: PreparedShare?
    @State private var isPreparingShare = false
    @State private var inviteURL: URL?
    @State private var didCopyLink = false
    @State private var confirmingStop = false
    @State private var actionError: String?

    /// Everyone except you.
    private var followers: [SharedParticipant] {
        participants.filter { !$0.isOwner }
    }

    var body: some View {
        NavigationStack {
            List {
                peopleSection
                inviteSection
                if store.isShared(team.id) { stopSharingSection }
            }
            .overlay {
                if isLoading && participants.isEmpty {
                    ProgressView("Checking…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            }
            // The team name, the way a shared album is titled by the album.
            // "Followers" was both the title and the first section header.
            .navigationTitle(team.name)
            .navigationBarTitleDisplayMode(.inline)
            // A sheet inherits the environment of whatever presented it, and
            // one entry point is the scoreboard bar — which forces white text
            // for the navy banner. Inheriting that renders this unreadable in
            // light mode, so the sheet states its own colours rather than
            // depending on where it was opened from.
            .foregroundStyle(.primary)
            .tint(Color.teamAccent)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
            .sheet(item: $preparedShare) { prepared in
                CloudSharingSheet(share: prepared.share,
                                  container: prepared.container,
                                  title: team.name,
                                  onSaved: { Task { await load() } },
                                  onStopped: { stoppedSharing() },
                                  onError: { actionError = $0.localizedDescription })
                    .ignoresSafeArea()
            }
            .confirmationDialog("Stop sharing this team?",
                                isPresented: $confirmingStop,
                                titleVisibility: .visible) {
                Button("Stop Sharing", role: .destructive) { Task { await stopSharing() } }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Followers will lose access to \(team.name)'s games and stats. Your own copy is untouched.")
            }
            .alert("Sharing", isPresented: Binding(
                get: { actionError != nil },
                set: { if !$0 { actionError = nil } }
            )) {
                Button("OK", role: .cancel) { actionError = nil }
            } message: {
                Text(actionError ?? "")
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var peopleSection: some View {
        Section {
            if let loadError {
                Label(loadError, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .font(.footnote)
            } else if followers.isEmpty && !isLoading {
                Text("Nobody yet. Invite family and friends to follow this team's games.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(followers) { person in
                    row(for: person)
                }
            }

            // The one way in, whether this is the first invite or the fifth.
            // Previously "Share Team…" and "See Who's Following" sat next to
            // each other in Settings doing overlapping jobs.
            Button {
                addPeople()
            } label: {
                HStack {
                    Label(store.isShared(team.id) ? "Add People…" : "Invite People…",
                          systemImage: "person.crop.circle.badge.plus")
                    if isPreparingShare {
                        Spacer()
                        ProgressView()
                    }
                }
            }
            .disabled(isPreparingShare)
        } header: {
            Text("Followers")
        } footer: {
            Text("Followers can see this team's games and stats, but can't change anything.")
        }
    }

    /// The invite link, readable and selectable. The system sheet's own Copy
    /// Link hides the URL and dismisses on tap; showing it here means you can
    /// read it, copy it, and carry on.
    @ViewBuilder
    private var inviteSection: some View {
        if let inviteURL {
            Section {
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
            } header: {
                Text("Invite Link")
            } footer: {
                Text("Only people you invite by Apple Account can open this — it isn't a public link.")
            }
        }
    }

    private var stopSharingSection: some View {
        Section {
            // Explicitly red. This view forces `.foregroundStyle(.primary)` on
            // its content (see the note on the navigation title), which
            // overrides what `role: .destructive` would colour it — leaving the
            // most destructive control on the screen looking like a plain row.
            Button("Stop Sharing", role: .destructive) { confirmingStop = true }
                .foregroundStyle(.red)
        } footer: {
            Text("Removes everyone's access. You keep the team, its roster and every game.")
        }
    }

    // MARK: - Actions

    /// Mirror the team to CloudKit if needed, then hand the share to the system
    /// invite sheet — the same flow whether it's the first invite or a later one.
    private func addPeople() {
        let games = store.games.filter { ($0.teamID ?? team.id) == team.id }
        isPreparingShare = true
        Task {
            defer { isPreparingShare = false }
            do {
                preparedShare = try await sharing.prepareShare(for: team, games: games)
                store.markShared(team.id)
                inviteURL = try? await sharing.shareURL(for: team)
            } catch {
                actionError = error.localizedDescription
            }
        }
    }

    private func stopSharing() async {
        do {
            try await sharing.stopSharing(team)
            stoppedSharing()
        } catch {
            actionError = error.localizedDescription
        }
    }

    /// Shared by both routes out of sharing — our own button and the system
    /// sheet's "Stop Sharing". The sheet's callback used not to be wired up at
    /// all, which is why a team unshared from there kept its "Shared" tag.
    private func stoppedSharing() {
        store.markNotShared(team.id)
        participants = []
        inviteURL = nil
        didCopyLink = false
    }

    private func row(for person: SharedParticipant) -> some View {
        HStack(spacing: 12) {
            Image(systemName: person.hasAccepted ? "person.crop.circle.fill" : "person.crop.circle.badge.clock")
                .font(.title2)
                .foregroundStyle(person.hasAccepted ? Color.teamAccent : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                if !person.contact.isEmpty {
                    Text(person.contact)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(person.statusLabel)
                .font(.caption.weight(.semibold))
                .foregroundStyle(person.hasAccepted ? Color.teamAccent : .secondary)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            participants = try await sharing.participants(for: team)
            loadError = nil
            inviteURL = try? await sharing.shareURL(for: team)
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Compact "N following" pill for the live-scoring screen. Shows nothing at all
/// when the team isn't shared, so it never costs space in the common case.
struct FollowersBadge: View {
    let team: Team
    /// Presenting is the caller's job. A sheet inherits the environment of
    /// wherever it's declared, and this badge sits inside the scoreboard bar,
    /// which forces white text and tint for the navy banner — a sheet declared
    /// here inherits both and is unreadable in light mode.
    let onTap: () -> Void

    @Environment(\.teamSharingService) private var sharing
    @State private var count: Int?

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "eye.fill")
                    .font(.caption2)
                if let count, count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.white.opacity(0.18)))
            .minimumTapTarget()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\($0) following" } ?? "Followers")
        .task {
            // Best-effort: a failure just leaves the eye without a number,
            // which is still a truthful "this team is shared".
            count = (try? await sharing.participants(for: team))?
                .filter { !$0.isOwner }.count
        }
    }
}
