import Foundation

/// What this build is and where its data goes (#111).
///
/// Builds reach the phones by two routes — a direct install from Xcode and
/// TestFlight — and they do **not** talk to the same CloudKit database. Two
/// devices on different routes can't see each other's shares, which looks
/// exactly like sharing being broken. The version number alone doesn't tell
/// you that, so this reports the environment too.
enum BuildInfo {
    /// How this copy of the app was installed.
    enum Channel {
        case xcode, testFlight, appStore

        var label: String {
            switch self {
            case .xcode:      return "Xcode"
            case .testFlight: return "TestFlight"
            case .appStore:   return "App Store"
            }
        }

        /// The CloudKit database this channel's signature grants access to.
        ///
        /// Chosen by the code signature, not by anything the app can set: a
        /// development-signed build gets Development, and any distribution
        /// build — TestFlight or App Store — gets Production.
        var cloudKitEnvironment: String {
            self == .xcode ? "Development" : "Production"
        }
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    /// TestFlight is distinguished by its **sandbox receipt** — the standard
    /// signal, since a TestFlight build is otherwise signed like an App Store
    /// one.
    static var channel: Channel {
        #if DEBUG
        return .xcode
        #else
        if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
            return .testFlight
        }
        return .appStore
        #endif
    }

    /// One line for the bottom of Settings, e.g.
    /// `Version 1.2 (19) · Xcode · Development iCloud`.
    static var summary: String {
        "Version \(version) (\(build)) · \(channel.label) · \(channel.cloudKitEnvironment) iCloud"
    }
}
