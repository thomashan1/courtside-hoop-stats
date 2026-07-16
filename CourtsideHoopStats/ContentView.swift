import SwiftUI

/// Root tab container: the games log and the roster.
struct ContentView: View {
    var body: some View {
        TabView {
            GamesListView()
                .tabItem { Label("Games", systemImage: "list.clipboard") }

            RosterView()
                .tabItem { Label("Roster", systemImage: "person.3.fill") }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
