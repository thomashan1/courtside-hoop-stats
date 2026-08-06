import SwiftUI
import UIKit
import CloudKit

extension Notification.Name {
    /// Posted when the user taps a share invitation and iOS hands the app its
    /// metadata. Carries the `CKShare.Metadata` as its object.
    static let cloudKitShareAccepted = Notification.Name("chs.cloudKitShareAccepted")
    /// Posted when CloudKit wakes the app because shared data changed.
    static let sharedDataChanged = Notification.Name("chs.sharedDataChanged")
}

/// Receives share invitations (#57).
///
/// A SwiftUI-lifecycle app has nowhere to catch
/// `userDidAcceptCloudKitShareWith`, so the app installs this scene delegate to
/// get it. The metadata is re-broadcast as a notification rather than handled
/// here, because accepting needs the sharing service and the store — neither of
/// which a scene delegate should reach into.
final class ShareAcceptingSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func windowScene(_ windowScene: UIWindowScene,
                     userDidAcceptCloudKitShareWith metadata: CKShare.Metadata) {
        NotificationCenter.default.post(name: .cloudKitShareAccepted, object: metadata)
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
