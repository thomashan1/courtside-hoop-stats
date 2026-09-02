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
    /// name — good for uniqueness only. See `sharedByName` for the human name.
    var ownerName: String
    /// The owner's first name, for "Shared by Jean" (#120). Optional and
    /// separate from `ownerName`: iCloud only supplies name components once an
    /// invite is accepted, and older cached snapshots decode this as `nil`.
    var sharedByName: String? = nil
    /// When this snapshot was last fetched, for the honest "updated N ago" line.
    var updatedAt: Date

    var id: String { "\(ownerName)|\(zoneName)" }

    /// "Shared by Jean · Updated 5 minutes ago" — first name only, and only
    /// when CloudKit actually gave one; otherwise just the freshness line, so
    /// there's no half-blank "Shared by · Updated…" while an invite is
    /// mid-flight or a name never resolved.
    var subtitle: String {
        guard let sharedByName, !sharedByName.isEmpty else { return updatedAt.updatedLabel }
        return "Shared by \(sharedByName) · \(updatedAt.updatedLabel)"
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
