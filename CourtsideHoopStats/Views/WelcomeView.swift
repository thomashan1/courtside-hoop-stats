import SwiftUI

/// The first screen of a brand-new install: keep score, or follow a team.
///
/// It replaces landing on Games with a blank "My Test Team". A parent who
/// installed the app only to follow their child's team got a scorekeeping
/// app with a placeholder team and no word anywhere on how following works.
/// Shown only while `AppStore.needsWelcome` — never to someone with data of
/// their own, a followed team, or teams coming back from iCloud.
///
/// Settings → Welcome Screen opens it again (`onClose` set), where each
/// choice takes you to the matching tab rather than starting over.
struct WelcomeView: View {
    @EnvironmentObject var store: AppStore
    /// Set when opened again from Settings; closes the sheet.
    var onClose: (() -> Void)? = nil
    @State private var namingTeam = false
    @State private var showingFollowHelp = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(spacing: 12) {
                        logo
                        Text("Welcome to Courtside")
                            .font(.largeTitle.bold())
                            .multilineTextAlignment(.center)
                        Text("What brings you here?")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 48)

                    VStack(spacing: 12) {
                        choice(title: "Keep Score",
                               detail: "Track your team's games and stats courtside.",
                               systemImage: "list.clipboard", action: keepScore)
                        choice(title: "Follow a Team",
                               detail: "Watch the games and stats of a team someone else keeps score for.",
                               systemImage: "binoculars", action: follow)
                    }
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationDestination(isPresented: $namingTeam) { NameTeamStep(onDone: onClose) }
            .navigationDestination(isPresented: $showingFollowHelp) {
                FollowHelpView()
                    .navigationTitle("Follow a Team")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close", systemImage: "xmark", action: onClose)
                    }
                }
            }
        }
    }

    /// The app's own icon, so the first thing a new user sees is the thing
    /// they just tapped on the home screen.
    @ViewBuilder
    private var logo: some View {
        if let icon = AppIconThumbnail.image {
            Image(uiImage: icon)
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
                .accessibilityHidden(true)
        }
    }

    private func keepScore() {
        // Only a device with nothing on it has a team left to name.
        if store.hasNoDataOfItsOwn {
            namingTeam = true
        } else {
            store.welcomeChoice = .keepScore
            store.tabRequest = .keepScore
            onClose?()
        }
    }

    private func follow() {
        if store.hasNoDataOfItsOwn || !store.followedTeams.isEmpty {
            store.welcomeChoice = store.hasNoDataOfItsOwn ? .follow : store.welcomeChoice
            store.tabRequest = .follow
            onClose?()
        } else {
            // A scorekeeper keeps their tabs; the help is the way in.
            showingFollowHelp = true
        }
    }

    private func choice(title: String, detail: String, systemImage: String,
                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(Color.teamAccent)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16))
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        // The name is the choice; the line under it is the explanation.
        .accessibilityLabel(title)
        .accessibilityHint(detail)
    }
}

/// Keep Score's one question: the team's name. Players come next, on Roster.
private struct NameTeamStep: View {
    @EnvironmentObject var store: AppStore
    var onDone: (() -> Void)?
    @State private var name = ""
    @FocusState private var focused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        Form {
            Section {
                TextField("Team Name", text: $name)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(start)
            } footer: {
                Text("Add your players next, on the Roster tab. You can add more teams later in Settings.")
            }
        }
        .readableWidth()
        .navigationTitle("Name Your Team")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Start", action: start)
                    .disabled(trimmed.isEmpty)
            }
        }
        .onAppear { focused = true }
    }

    private func start() {
        guard !trimmed.isEmpty else { return }
        store.startKeepingScore(teamName: trimmed)
        store.tabRequest = .keepScore
        onDone?()
    }
}
