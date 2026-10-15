import SwiftUI

/// How to follow a team, and a way to check whether it's already happened.
///
/// Shown on an empty Following tab and from Settings → Follow a Team. The
/// invite link is the real way in; this is for when it didn't take. A parent
/// was invited by a phone number that wasn't on their Apple Account, tapped
/// the link, and the app opened and did nothing — with no screen anywhere
/// saying what an invite needs.
struct FollowHelpView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.teamSharingService) private var sharing

    @State private var isChecking = false
    @State private var result: String?

    var body: some View {
        ContentUnavailableView {
            Label("Not Following a Team Yet", systemImage: "binoculars")
        } description: {
            Text("Ask the team's scorekeeper to invite you with the phone number or email of your Apple Account. You'll find it in the Settings app, under your name. Then tap the link they send you.")
        } actions: {
            Button {
                Task { await check() }
            } label: {
                if isChecking {
                    ProgressView()
                } else {
                    Text("Check for Invites")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isChecking)

            if let result {
                Text(result)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        // A readable line on iPad, rather than one sentence across 13 inches.
        .frame(maxWidth: 560)
    }

    /// Asks iCloud for teams already shared with this account. Finding one
    /// adds the Following tab's team, and the app switches to it.
    private func check() async {
        isChecking = true
        defer { isChecking = false }
        result = nil
        guard sharing.isAvailable else {
            result = "Sign in to iCloud in the Settings app to follow a team."
            return
        }
        do {
            let teams = try await sharing.fetchFollowedTeams()
            if teams.isEmpty {
                result = "No invites yet. Once you've tapped the link from your scorekeeper, try again."
            } else {
                await store.applyFollowedTeams(teams)
            }
        } catch SharingError.iCloudAccountUnavailable {
            result = "Sign in to iCloud in the Settings app to follow a team."
        } catch {
            result = "Couldn't reach iCloud. Check your connection and try again."
        }
    }
}
