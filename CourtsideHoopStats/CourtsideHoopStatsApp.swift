import SwiftUI
import CloudKit

@main
struct CourtsideHoopStatsApp: App {
    /// Installs the scene delegate that catches share invitations (#57);
    /// a SwiftUI-lifecycle app has nowhere else to receive them.
    @UIApplicationDelegateAdaptor(ShareAcceptingAppDelegate.self) private var appDelegate

    @StateObject private var store: AppStore
    /// Live CloudKit sharing (#57). Swapping this for `NoopSharingService()`
    /// hides every sharing affordance and returns the app to local-only.
    private let sharing: CloudKitSharingService

    /// Wired up here rather than in a `.task` so the store can publish from the
    /// very first launch tick — a task-based hand-off races `ContentView`'s own
    /// startup work, which silently skipped the first sync.
    init() {
        let service = CloudKitSharingService()
        let appStore = AppStore()
        appStore.sharingService = service
        sharing = service
        _store = StateObject(wrappedValue: appStore)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.teamSharingService, sharing)
                // Lets the store push edits to followers. Set here rather than
                // in AppStore.init so tests and previews stay offline.
                .task { store.sharingService = sharing }
                .onReceive(NotificationCenter.default.publisher(for: .cloudKitShareAccepted)) { note in
                    guard let metadata = note.object as? CKShare.Metadata else { return }
                    Task { await accept(metadata) }
                }
        }
    }

    /// Accept an invitation, then pull the shared team straight away so it
    /// shows up without the follower having to hunt for a refresh button.
    private func accept(_ metadata: CKShare.Metadata) async {
        do {
            try await sharing.acceptShare(metadata)
            store.followedTeams = try await sharing.fetchFollowedTeams()
        } catch {
            // Nothing actionable for the user mid-launch; the Following tab's
            // own refresh reports errors where they can be seen.
        }
    }
}
