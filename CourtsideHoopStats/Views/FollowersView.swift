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
    let team: Team

    @State private var participants: [SharedParticipant] = []
    @State private var isLoading = true
    @State private var loadError: String?

    /// Everyone except you.
    private var followers: [SharedParticipant] {
        participants.filter { !$0.isOwner }
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Checking…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadError {
                    ContentUnavailableView {
                        Label("Couldn't Load Followers", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(loadError)
                    }
                } else if followers.isEmpty {
                    ContentUnavailableView {
                        Label("No Followers Yet", systemImage: "person.2")
                    } description: {
                        Text("Share this team from Settings ▸ Teams to let family and friends follow its games.")
                    }
                } else {
                    List {
                        Section {
                            ForEach(followers) { person in
                                row(for: person)
                            }
                        } footer: {
                            Text("Followers can see this team's games and stats, but can't change anything.")
                        }
                    }
                }
            }
            .navigationTitle("Followers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await load() }
        }
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
        } catch {
            loadError = error.localizedDescription
        }
    }
}

/// Compact "N following" pill for the live-scoring screen. Shows nothing at all
/// when the team isn't shared, so it never costs space in the common case.
struct FollowersBadge: View {
    let team: Team
    @Environment(\.teamSharingService) private var sharing
    @State private var count: Int?
    @State private var showingFollowers = false

    var body: some View {
        Button {
            showingFollowers = true
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
        .sheet(isPresented: $showingFollowers) {
            FollowersView(team: team)
        }
        .task {
            // Best-effort: a failure just leaves the eye without a number,
            // which is still a truthful "this team is shared".
            count = (try? await sharing.participants(for: team))?
                .filter { !$0.isOwner }.count
        }
    }
}
