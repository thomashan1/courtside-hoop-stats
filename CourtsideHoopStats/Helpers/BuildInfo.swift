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

    /// A short time stamp, e.g. `Aug 7, 8:15 PM`.
    private static var builtStamp: String? {
        builtAt.map {
            $0.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        }
    }

    /// One line for the bottom of Settings, short enough to stay on one line
    /// at ordinary text sizes:
    ///
    ///     v1.2 · CloudKit Dev · Xcode Aug 7, 8:15 PM
    ///     v1.2 · CloudKit Prod · TestFlight (76)
    ///
    /// Which identifier trails the channel depends on how the app got here,
    /// because they answer different questions. A directly-installed build
    /// shows **when it was built** — `CURRENT_PROJECT_VERSION` is a static
    /// number in the project file that nothing increments, so it can't tell one
    /// direct install from another. A distribution build shows its **build
    /// number**, which is how Xcode Cloud and App Store Connect identify it.
    static var summary: String {
        switch channel {
        case .xcode:
            let stamp = builtStamp.map { " \($0)" } ?? ""
            return "v\(version) · \(channel.cloudKitEnvironment) · Xcode\(stamp)"
        case .testFlight:
            return "v\(version) · \(channel.cloudKitEnvironment) · TestFlight (\(build))"
        case .appStore:
            // No CloudKit label on the shipping build. It's the answer to a
            // question only a tester asks, and there's nothing to disambiguate
            // — an App Store build is always Production. To a parent on the
            // sideline it's jargon in the one line that should just say which
            // version they have.
            return "v\(version) (\(build))"
        }
    }
}

extension BuildInfo {
    /// The same facts spelled out for VoiceOver.
    ///
    /// Built from the fields rather than rewritten from `summary`: the compact
    /// line starts "v1.2", which a screen reader says as "vee one point two",
    /// and the interpuncts read as nothing at all. Derived by string
    /// replacement they also drifted the moment the format changed.
    static var accessibilitySummary: String {
        let trailing: String
        switch channel {
        case .xcode:
            trailing = builtAt.map {
                "built by Xcode \($0.formatted(.dateTime.month(.wide).day().hour().minute()))"
            } ?? "built by Xcode"
        case .testFlight:
            trailing = "installed from TestFlight, build \(build)"
        case .appStore:
            return "App version \(version), build \(build)"
        }
        return "App version \(version), \(channel.cloudKitEnvironment), \(trailing)"
    }
}
