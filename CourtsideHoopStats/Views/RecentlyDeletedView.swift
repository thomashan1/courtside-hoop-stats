import SwiftUI

/// Games deleted in the last 30 days, on this device or synced from another
/// of the owner's devices, each one tap from coming back.
struct RecentlyDeletedView: View {
    @EnvironmentObject var store: AppStore
    @State private var pendingPurge: AppStore.DeletedGame?

    var body: some View {
        List {
            Section {
                ForEach(store.recentlyDeleted) { deleted in
                    HStack {
                        GameRowView(game: deleted.game, ourName: deleted.team?.name ?? store.team.name)
                        Button("Recover") { store.recoverDeletedGame(deleted.id) }
                            .buttonStyle(.bordered)
                            .tint(Color.teamAccent)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) { pendingPurge = deleted }
                    }
                }
            } footer: {
                Text("Games deleted on any of your devices stay here for \(AppStore.recentlyDeletedDays) days. Recovering one puts it back everywhere.")
            }
        }
        .readableWidth()
        .navigationTitle("Recently Deleted")
        .confirmationDialog("Delete this game for good?",
                            isPresented: Binding(get: { pendingPurge != nil },
                                                 set: { if !$0 { pendingPurge = nil } }),
                            titleVisibility: .visible) {
            Button("Delete for Good", role: .destructive) {
                if let game = pendingPurge { store.purgeDeletedGame(game.id) }
                pendingPurge = nil
            }
            Button("Cancel", role: .cancel) { pendingPurge = nil }
        } message: {
            Text("It can't be recovered after this.")
        }
    }
}
