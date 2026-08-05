import SwiftUI
import UIKit
import CloudKit

/// SwiftUI wrapper around `UICloudSharingController` — the system invite sheet
/// (#57).
///
/// This is Apple's own sharing UI, the same one Notes and Shared Albums use, so
/// invitees are added by the email address or phone number on their Apple
/// Account and the whole invite/accept flow is handled by iOS.
///
/// Permissions are deliberately limited to **read-only**: co-tracker
/// (`.readWrite`) support isn't built yet, and offering an edit permission the
/// app can't honor would let a participant make changes that silently never
/// sync back. Widen this when co-trackers ship.
struct CloudSharingSheet: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer
    var title: String?
    var onSaved: () -> Void = {}
    var onStopped: () -> Void = {}
    var onError: (Error) -> Void = { _ in }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.availablePermissions = [.allowReadOnly, .allowPrivate]
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(title: title, onSaved: onSaved, onStopped: onStopped, onError: onError)
    }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        private let title: String?
        private let onSaved: () -> Void
        private let onStopped: () -> Void
        private let onError: (Error) -> Void

        init(title: String?,
             onSaved: @escaping () -> Void,
             onStopped: @escaping () -> Void,
             onError: @escaping (Error) -> Void) {
            self.title = title
            self.onSaved = onSaved
            self.onStopped = onStopped
            self.onError = onError
        }

        /// Shown on the invite that lands in Messages/Mail.
        func itemTitle(for controller: UICloudSharingController) -> String? { title }

        /// The app icon, so the invite shows Courtside's basketball mark rather
        /// than the generic document placeholder.
        ///
        /// Read from the bundle's own icon at runtime instead of a duplicated
        /// asset, so it can never drift out of sync when the icon is redrawn.
        func itemThumbnailData(for controller: UICloudSharingController) -> Data? {
            Coordinator.appIconData
        }

        private static let appIconData: Data? = {
            guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
                  let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
                  let files = primary["CFBundleIconFiles"] as? [String],
                  // Last entry is the largest variant the bundle carries.
                  let name = files.last,
                  let icon = UIImage(named: name) else { return nil }
            return icon.pngData()
        }()

        func cloudSharingControllerDidSaveShare(_ controller: UICloudSharingController) {
            onSaved()
        }

        func cloudSharingControllerDidStopSharing(_ controller: UICloudSharingController) {
            onStopped()
        }

        func cloudSharingController(_ controller: UICloudSharingController,
                                    failedToSaveShareWithError error: Error) {
            onError(error)
        }
    }
}
