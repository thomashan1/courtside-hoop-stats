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
            self == .xcode ? "CloudKit Dev" : "CloudKit Prod"
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

    /// When this binary was linked — which for a directly-installed build is
    /// when it was built and pushed to the phone.
    ///
    /// Read from the executable rather than baked in at compile time, so it
    /// needs no build phase and can't drift from the binary it describes.
    static var builtAt: Date? {
        guard let path = Bundle.main.executablePath,
              let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        else { return nil }
        return attributes[.modificationDate] as? Date
    }

    /// One line for the bottom of Settings.
    ///
    /// Which identifier is shown depends on how the app got here, because they
    /// answer different questions:
    ///
    /// - **Xcode** → the **build time**. `CURRENT_PROJECT_VERSION` is a static
    ///   number in the project file; nothing increments it, so every direct
    ///   install reports the same build and it can't tell today's from
    ///   yesterday's. The link time changes with every build.
    /// - **TestFlight / App Store** → the **build number**. Xcode Cloud assigns
    ///   its own sequence, and that number is how a build is identified in App
    ///   Store Connect.
    static var summary: String {
        let tail = "\(channel.label) · \(channel.cloudKitEnvironment)"
        switch channel {
        case .xcode:
            let stamp = builtAt.map {
                $0.formatted(.dateTime.month(.abbreviated).day().hour().minute())
            } ?? "build \(build)"
            return "Version \(version) · \(tail) · built \(stamp)"
        case .testFlight, .appStore:
            return "Version \(version) (\(build)) · \(tail)"
        }
    }
}

extension BuildInfo {
    /// The same facts, spelled out for VoiceOver — the on-screen line separates
    /// them with interpuncts, which read poorly.
    ///
    /// Derived from `summary` rather than written out again: the two had
    /// drifted the moment the build time was added, and the version line is
    /// exactly the thing that must not lie.
    static var accessibilitySummary: String {
        summary
            .replacingOccurrences(of: " · ", with: ", ")
            .replacingOccurrences(of: "Version ", with: "App version ")
    }
}
