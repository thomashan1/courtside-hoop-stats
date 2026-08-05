import SwiftUI

@main
struct CourtsideHoopStatsApp: App {
    @StateObject private var store = AppStore()
    /// Live CloudKit sharing (#57). Swapping this for `NoopSharingService()`
    /// hides every sharing affordance and returns the app to local-only.
    private let sharing = CloudKitSharingService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environment(\.teamSharingService, sharing)
        }
    }
}
