import Foundation

/// Which of a backup run's deletions may actually go through.
///
/// The backup copies deletions — it has to, or a restore resurrects what was
/// deliberately removed — so a bug that empties the app on one device would
/// otherwise empty iCloud, and through sync every other device, seconds
/// later. Nobody deletes their whole season in one go, so a run that tries
/// to is treated as a bug, not a request: those deletions are dropped and
/// the records stay in iCloud for Restore. Whatever does get deleted is
/// still kept in the backup's Recently Deleted for 30 days.
enum BackupDeletionGuard {

    /// A run may remove a few games outright; beyond this, never more than
    /// half of them.
    static let gamesAlwaysAllowed = 5

    /// The ids among `teams` and `games` (what the run wants to delete) that
    /// are safe to delete, given everything currently in the backup.
    static func allowed(teams doomedTeams: [Team], games doomedGames: [Game],
                        allTeams: [Team], allGames: [Game]) -> Set<UUID> {
        // An empty team carries nothing: older builds backed up a blank
        // starter from every fresh install, and clearing those must not trip
        // the guard.
        let realTeams = allTeams.filter { !$0.players.isEmpty }
        let doomedReal = doomedTeams.filter { !$0.players.isEmpty }
        var allowed = Set(doomedTeams.filter { $0.players.isEmpty }.map(\.id))

        // One team at a time, and never the last one: the app itself can do
        // neither in a single change.
        if doomedReal.count == 1, realTeams.count > 1 {
            allowed.insert(doomedReal[0].id)
        }

        // A deleted team's games go with it. Any other games, only a few at
        // a time.
        let goesWithTeam: (Game) -> Bool = { $0.teamID.map(allowed.contains) ?? false }
        allowed.formUnion(doomedGames.filter(goesWithTeam).map(\.id))
        let others = doomedGames.filter { !goesWithTeam($0) }
        if others.count <= max(gamesAlwaysAllowed, allGames.count / 2) {
            allowed.formUnion(others.map(\.id))
        }
        return allowed
    }
}
