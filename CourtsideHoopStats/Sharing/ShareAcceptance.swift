import SwiftUI
import UIKit
import CloudKit

extension Notification.Name {
    /// Posted when CloudKit wakes the app because shared data changed.
    static let sharedDataChanged = Notification.Name("chs.sharedDataChanged")
}

/// Invitations waiting to be accepted.
///
/// Held rather than broadcast: an invite that launches the app arrives before
/// any view is listening, and a notification posted then is simply lost —
/// the app opened and did nothing. Whoever reads `pending` gets what's
/// already waiting as well as what comes next.
@MainActor
final class Mailbox<Item>: ObservableObject {
    @Published private(set) var pending: [Item] = []

    func post(_ item: Item) { pending.append(item) }

    /// Everything waiting, emptying the box so nothing is handled twice.
    func take() -> [Item] {
        defer { pending = [] }
        return pending
    }
}

@MainActor
enum ShareInbox {
    static let shared = Mailbox<CKShare.Metadata>()
}

/// Receives share invitations (#57).
///
/// A SwiftUI-lifecycle app has nowhere to catch them, so the app installs
/// this scene delegate. The metadata goes to `ShareInbox` rather than being
/// handled here, because accepting needs the sharing service and the store —
/// neither of which a scene delegate should reach into.
final class ShareAcceptingSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    /// An invite that *launches* the app comes here, not to
    /// `userDidAcceptCloudKitShareWith` — which only fires for an app that's
    /// already running. Missing this left a new follower, who almost always
    /// taps the link with the app closed, with an app that opened and did
    /// nothing.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        if let metadata = connectionOptions.cloudKitShareMetadata {
            MainActor.assumeIsolated { ShareInbox.shared.post(metadata) }
        }
    }

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        MainActor.assumeIsolated { ShareInbox.shared.post(metadata) }
    }
}

/// Points every scene at `ShareAcceptingSceneDelegate`.
final class ShareAcceptingAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     configurationForConnecting session: UISceneSession,
                     options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = ShareAcceptingSceneDelegate.self
        return configuration
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // Registers with APNs so CloudKit can reach this device. Harmless
        // without notification permission — the silent wake still arrives, so
        // a follower who declined alerts still gets fresh data.
        application.registerForRemoteNotifications()
        return true
    }

    /// CloudKit woke us because the shared database changed.
    ///
    /// The payload never carries a score — it only says "something changed" —
    /// so the work is to re-fetch and let the app decide what's worth
    /// announcing. The completion handler must be called, and reasonably
    /// promptly, or iOS throttles future background wakes.
    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completion: @escaping (UIBackgroundFetchResult) -> Void) {
        guard CKNotification(fromRemoteNotificationDictionary: userInfo) != nil else {
            completion(.noData)
            return
        }
        NotificationCenter.default.post(name: .sharedDataChanged, object: completion)
    }
}
