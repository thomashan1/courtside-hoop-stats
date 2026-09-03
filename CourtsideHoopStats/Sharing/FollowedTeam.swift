import Foundation

/// A team someone else shared with you, as a follower (#57).
///
/// A **read-only snapshot**, deliberately kept separate from `AppStore.teams`:
/// mixing followed teams into the owner's own collection would put them behind
/// every edit affordance in the app, and none of those edits could ever sync
/// back. Keeping them apart makes "you can look but not touch" a property of
/// the data, not something each view has to remember to enforce.
///
/// Cached locally so a follower opening the app in a dead-zone gym still sees
/// the last known score rather than an empty screen.
struct FollowedTeam: Identifiable, Codable {
    var team: Team
    var games: [Game]
    /// The CloudKit zone this came from — identifies the share across refreshes.
    var zoneName: String
    /// The record-zone owner (the person who shared it), needed because two
    /// people could share differently-named teams from identically-named zones.
    ///
    /// This is CloudKit's opaque `CKRecordZone.ID.ownerName`, not a display
    /// name — good for uniqueness only. See `Team.ownerDisplayName` for the
    /// human name.
    var ownerName: String
    /// When this snapshot was last fetched, for the honest "updated N ago" line.
    var updatedAt: Date

    var id: String { "\(ownerName)|\(zoneName)" }

    /// "Shared by Jean · Updated 5 minutes ago" — first name only, and only
    /// when the owner actually set one (`Team.ownerDisplayName`, #128);
    /// otherwise just the freshness line, so there's no half-blank
    /// "Shared by · Updated…".
    var subtitle: String {
        guard let name = team.ownerDisplayName, !name.isEmpty else { return updatedAt.updatedLabel }
        return "Shared by \(name) · \(updatedAt.updatedLabel)"
    }

    /// Games newest-first, matching how the owner's own list is ordered.
    var sortedGames: [Game] {
        games.sorted { $0.date > $1.date }
    }

    /// The game a follower most likely opened the app to see: one in progress,
    /// else the most recent.
    var featuredGame: Game? {
        sortedGames.first { $0.lifecycle == .inProgress } ?? sortedGames.first
    }
}
