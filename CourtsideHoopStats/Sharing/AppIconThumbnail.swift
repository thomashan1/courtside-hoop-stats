import Foundation
import UIKit

/// The app icon as PNG data, for the invite that lands in Messages/Mail (#57).
///
/// Read from the bundle's own icon at runtime rather than a duplicated asset,
/// so it can never drift out of sync when the icon is redrawn.
enum AppIconThumbnail {
    static let pngData: Data? = {
        guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
              let files = primary["CFBundleIconFiles"] as? [String],
              // Last entry is the largest variant the bundle carries.
              let name = files.last,
              let icon = UIImage(named: name) else { return nil }
        return icon.pngData()
    }()
}
