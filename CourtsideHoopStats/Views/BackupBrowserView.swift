import SwiftUI

/// Browse what's in iCloud and pick what to bring back (#177 follow-on).
///
/// Grouped by team, because a game only means something next to the team it
/// belongs to — and picking a game whose team isn't on this phone has to bring
/// the team with it or the game arrives orphaned, invisible in every list.
struct BackupBrowserView: View {
    @EnvironmentObject var store: AppStore
    @Environment(\.dismiss) private var dismiss

    /// Everything in the backup, once loaded.
    @State private var backup: (teams: [Team], games: [Game])?
    @State private var selected: Set<UUID> = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Restore from iCloud")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Restore\(selected.isEmpty ? "" : " (\(selected.count))")") {
                            restore()
                        }
                        .disabled(selected.isEmpty)
                    }
                }
                .task { await load() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("Reading iCloud…")
        } else if let error {
            ContentUnavailableView("Couldn't read iCloud", systemImage: "exclamationmark.icloud",
                                   description: Text(error))
        } else if let backup, backup.games.isEmpty, backup.teams.isEmpty {
            ContentUnavailableView("Nothing in iCloud yet", systemImage: "icloud",
                                   description: Text("Backups happen automatically once you've recorded a game."))
        } else if let backup {
            List {
                ForEach(backup.teams) { team in
                    Section {
                        let teamGames = backup.games.filter { ($0.teamID ?? team.id) == team.id }
                        if teamGames.isEmpty {
                            Text("No games").foregroundStyle(.secondary)
                        }
                        ForEach(teamGames) { game in
                            row(for: game)
                        }
                    } header: {
                        HStack {
                            Text(team.name)
                            if !store.teams.contains(where: { $0.id == team.id }) {
                                Text("not on this phone")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    /// A game already on the phone is shown but not selectable — restoring it
    /// would do nothing, and an enabled control that does nothing is worse
    /// than a disabled one that explains itself.
    @ViewBuilder
    private func row(for game: Game) -> some View {
        let isLocal = store.games.contains { $0.id == game.id }
        Button {
            if selected.contains(game.id) { selected.remove(game.id) }
            else { selected.insert(game.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isLocal ? "checkmark.circle.fill"
                                          : selected.contains(game.id) ? "checkmark.circle.fill"
                                                                       : "circle")
                    .foregroundStyle(isLocal ? AnyShapeStyle(.tertiary)
                                             : AnyShapeStyle(Color.teamAccent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.opponent.isEmpty ? "Game" : "vs \(game.opponent)")
                        .foregroundStyle(isLocal ? .secondary : .primary)
                    Text(game.date.gameDayShort)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLocal {
                    Text("On this phone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if game.isComplete {
                    Text("\(game.ourScore)–\(game.opponentScore)")
                        .font(.subheadline).monospacedDigit()
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isLocal)
    }

    private func load() async {
        guard let service = store.backupService else {
            isLoading = false
            return
        }
        do {
            let fetched = try await service.fetchBackup()
            backup = (fetched.teams, fetched.games)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func restore() {
        guard let backup else { return }
        let games = backup.games.filter { selected.contains($0.id) }
        // A picked game drags its team along when that team is missing, or it
        // lands with nothing to show it under.
        let neededTeamIDs = Set(games.compactMap(\.teamID))
        let localTeamIDs = Set(store.teams.map(\.id))
        let teams = backup.teams.filter {
            neededTeamIDs.contains($0.id) && !localTeamIDs.contains($0.id)
        }
        store.restore(teams: teams, games: games)
        dismiss()
    }
}
