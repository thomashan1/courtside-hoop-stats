import SwiftUI
import UIKit
import CloudKit

extension Notification.Name {
    /// Posted when the user taps a share invitation and iOS hands the app its
    /// metadata. Carries the `CKShare.Metadata` as its object.
    static let cloudKitShareAccepted = Notification.Name("chs.cloudKitShareAccepted")
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
}
