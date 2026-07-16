import SwiftUI

/// Root tab container.
///
/// Phase 1 of the staged-code reintroduction: only the Roster tab is wired up
/// while its design pass is verified on device. The Games tab (and the live
/// scoring / summary screens behind it) lands in the next phase.
struct ContentView: View {
    var body: some View {
        TabView {
            RosterView()
                .tabItem { Label("Roster", systemImage: "person.3.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
