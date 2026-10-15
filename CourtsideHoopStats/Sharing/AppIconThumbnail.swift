import Foundation
import UIKit

/// The app icon as PNG data, for the invite that lands in Messages/Mail (#57).
///
/// Read from the bundle's own icon at runtime rather than a duplicated asset,
/// so it can never drift out of sync when the icon is redrawn.
enum AppIconThumbnail {
    /// Also the welcome screen's logo.
    static let image: UIImage? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              let name = files.last else { return nil }
        return UIImage(named: name)
    }()

    static let pngData: Data? = {
        // The last icon file is the largest variant the bundle carries.
        image?.pngData()
    }()
}
