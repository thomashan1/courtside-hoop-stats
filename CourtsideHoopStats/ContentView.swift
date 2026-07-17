import SwiftUI

/// Root tab container: the games log and the roster.
struct ContentView: View {
    @EnvironmentObject var store: AppStore

    var body: some View {
        TabView {
            GamesListView()
                .tabItem { Label("Games", systemImage: "list.clipboard") }

            RosterView()
                .tabItem { Label("Roster", systemImage: "person.3.fill") }
        }
        // Apply the in-app Text Size as a Dynamic Type floor for the whole app.
        .dynamicTypeSize(AppTextSize.floor(for: store.textSizeIndex)...)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppStore())
}
