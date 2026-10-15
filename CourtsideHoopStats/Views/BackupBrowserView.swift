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
    /// Deleted from the backup in the last 30 days — from any device, or by
    /// a bug, which is the case this is really for.
    @State private var deleted = DeletedFromBackup()
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
        } else if let backup, backup.games.isEmpty, backup.teams.isEmpty,
                  deleted.games.isEmpty, deleted.teams.isEmpty {
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
                if !deleted.games.isEmpty || !deletedTeamsAlone.isEmpty {
                    Section {
                        ForEach(deletedTeamsAlone) { team in
                            teamRow(for: team)
                        }
                        ForEach(deleted.games) { game in
                            row(for: game, deletedAt: deleted.deletedAt[game.id])
                        }
                    } header: {
                        Text("Deleted in the Last \(DeletedFromBackup.days) Days")
                    } footer: {
                        Text("Kept in iCloud for \(DeletedFromBackup.days) days after they're deleted on any of your devices.")
                    }
                }
            }
            .readableWidth()
        }
    }

    /// A game already on the phone is shown but not selectable — restoring it
    /// would do nothing, and an enabled control that does nothing is worse
    /// than a disabled one that explains itself.
    @ViewBuilder
    private func row(for game: Game, deletedAt: Date? = nil) -> some View {
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
                    Group {
                        if let deletedAt {
                            Text("\(teamName(for: game)) · deleted \(deletedAt.formatted(.relative(presentation: .named)))")
                        } else {
                            Text(game.date.gameDayShort)
                        }
                    }
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

    /// A deleted team whose games weren't deleted with it: a roster to bring
    /// back on its own.
    private var deletedTeamsAlone: [Team] {
        deleted.teams.filter { team in !deleted.games.contains { $0.teamID == team.id } }
    }

    private func teamName(for game: Game) -> String {
        (deleted.teams + (backup?.teams ?? []) + store.teams)
            .first { $0.id == game.teamID }?.name ?? "Game"
    }

    @ViewBuilder
    private func teamRow(for team: Team) -> some View {
        let isLocal = store.teams.contains { $0.id == team.id }
        Button {
            if selected.contains(team.id) { selected.remove(team.id) }
            else { selected.insert(team.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isLocal || selected.contains(team.id) ? "checkmark.circle.fill"
                                                                         : "circle")
                    .foregroundStyle(isLocal ? AnyShapeStyle(.tertiary)
                                             : AnyShapeStyle(Color.teamAccent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(team.name)
                        .foregroundStyle(isLocal ? .secondary : .primary)
                    Text("\(team.players.count) players")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isLocal {
                    Text("On this phone")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
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
            // Recently Deleted is extra: failing to read it mustn't hide the
            // backup itself.
            deleted = (try? await service.fetchRecentlyDeleted()) ?? DeletedFromBackup()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func restore() {
        guard let backup else { return }
        var games: [Game] = []
        for game in backup.games + deleted.games
            where selected.contains(game.id) && !games.contains(where: { $0.id == game.id }) {
            games.append(game)
        }
        // A picked game drags its team along when that team is missing, or it
        // lands with nothing to show it under.
        let neededTeamIDs = Set(games.compactMap(\.teamID)).union(selected)
        let localTeamIDs = Set(store.teams.map(\.id))
        var teams: [Team] = []
        for team in backup.teams + deleted.teams
            where neededTeamIDs.contains(team.id) && !localTeamIDs.contains(team.id)
                && !teams.contains(where: { $0.id == team.id }) {
            teams.append(team)
        }
        store.restore(teams: teams, games: games)
        dismiss()
    }
}
