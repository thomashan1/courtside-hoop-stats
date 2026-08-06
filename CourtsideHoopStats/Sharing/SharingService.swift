import Foundation
import SwiftUI
import CloudKit

// MARK: - Roles

/// A participant's permission level on a shared team (#57), mapping directly
/// onto `CKShare` permissions: a **follower** is read-only, a **co-tracker** is
/// read-write. Followers ship first; co-trackers are a later slice
/// (see `docs/SHARING.md`).
enum SharingRole: String, Codable, CaseIterable, Identifiable {
    case follower       // read-only
    case coTracker      // read-write

    var id: String { rawValue }

    /// Wording shown next to a person in the invite sheet — mirrors the mockups.
    var label: String {
        switch self {
        case .follower:  return "View only"
        case .coTracker: return "Can edit"
        }
    }

    var cloudKitPermission: CKShare.ParticipantPermission {
        switch self {
        case .follower:  return .readOnly
        case .coTracker: return .readWrite
        }
    }
}

// MARK: - Service seam

/// Someone a team is shared with (#57), flattened out of `CKShare.Participant`
/// so views don't touch CloudKit types.
struct SharedParticipant: Identifiable {
    let id: String
    /// Best available name — falls back to the email/phone when iCloud gives
    /// us no name components, which is common before an invite is accepted.
    let name: String
    /// Email or phone the invite went to; empty when unknown.
    let contact: String
    let isOwner: Bool
    /// False while an invite is still outstanding.
    let hasAccepted: Bool

    var statusLabel: String {
        if isOwner { return "Owner" }
        return hasAccepted ? "Following" : "Invited"
    }
}

/// A prepared `CKShare` plus its container — the two things the system share
/// sheet (`UICloudSharingController`) needs. Produced by the service; the UI
/// only presents it, so views never construct CloudKit types themselves.
struct PreparedShare: Identifiable {
    let share: CKShare
    let container: CKContainer

    var id: String { share.recordID.recordName }
}

enum SharingError: LocalizedError {
    case unavailable
    case iCloudAccountUnavailable
    case notShared

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Sharing isn't available in this build yet."
        case .iCloudAccountUnavailable:
            return "Sign in to iCloud in Settings to share a team."
        case .notShared:
            return "This team isn't shared."
        }
    }
}

/// The boundary between the app and CloudKit sharing (#57).
///
/// The app talks only to this protocol. `NoopSharingService` is the default, so
/// the whole app builds and runs exactly as the single-device build today;
/// `CloudKitSharingService` (PR 2, once the CloudKit capability is enabled)
/// drops in behind the same seam. Keeping every CloudKit call here means the
/// SwiftUI views never `import CloudKit` and stay unit-testable.
protocol TeamSharingService {
    /// `false` for the Noop default, so the UI hides "Share Team" until a real
    /// service is injected — no dead button reaches a shipping build.
    var isAvailable: Bool { get }

    /// Ensure the team + its games exist in the shared CloudKit zone and return
    /// a share to present. Creates the `CKShare` on first call for a team,
    /// reuses it afterwards.
    func prepareShare(for team: Team, games: [Game]) async throws -> PreparedShare

    /// Push the latest local state of an already-shared team to CloudKit — call
    /// after any local edit to a shared team so followers see it.
    func publish(team: Team, games: [Game]) async throws

    /// Stop sharing a team (delete its `CKShare`). The local copy is untouched.
    func stopSharing(_ team: Team) async throws

    // MARK: Follower side

    /// Accept an invitation the user tapped. Called with the metadata iOS hands
    /// the app when someone opens a share link.
    func acceptShare(_ metadata: CKShare.Metadata) async throws

    /// Every team currently shared *with* this user, as read-only snapshots.
    func fetchFollowedTeams() async throws -> [FollowedTeam]

    /// Ask CloudKit to notify this device when anything in the shared database
    /// changes, so a follower doesn't have to open the app to find out.
    /// Idempotent — safe to call on every launch.
    func subscribeToFollowedTeamChanges() async throws

    /// Who a team you own is shared with. Empty when it isn't shared.
    func participants(for team: Team) async throws -> [SharedParticipant]

    /// The invitation link for a shared team, or nil when it isn't shared.
    /// Same URL the system share sheet sends — useful for handing it over by
    /// any route the sheet doesn't offer.
    func shareURL(for team: Team) async throws -> URL?

    /// Whether this team currently has a share in CloudKit.
    ///
    /// The authority is CloudKit, not local state: a team can have been shared
    /// from an earlier version of the app, on another device, or before the app
    /// started tracking it — and a team that only *looks* unshared silently
    /// stops publishing to its followers.
    func isSharing(_ team: Team) async throws -> Bool
}

/// Default service: sharing is not wired up. Everything reports unavailable and
/// throws, so the app behaves exactly as the local, single-device build.
struct NoopSharingService: TeamSharingService {
    var isAvailable: Bool { false }

    func prepareShare(for team: Team, games: [Game]) async throws -> PreparedShare {
        throw SharingError.unavailable
    }
    func publish(team: Team, games: [Game]) async throws {
        throw SharingError.unavailable
    }
    func stopSharing(_ team: Team) async throws {
        throw SharingError.unavailable
    }
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        throw SharingError.unavailable
    }
    func fetchFollowedTeams() async throws -> [FollowedTeam] { [] }
    func participants(for team: Team) async throws -> [SharedParticipant] { [] }
    func isSharing(_ team: Team) async throws -> Bool { false }
    func shareURL(for team: Team) async throws -> URL? { nil }
    func subscribeToFollowedTeamChanges() async throws {}
}

// MARK: - Environment injection

private struct TeamSharingServiceKey: EnvironmentKey {
    static let defaultValue: any TeamSharingService = NoopSharingService()
}

extension EnvironmentValues {
    /// The active sharing backend. Defaults to `NoopSharingService`; the app
    /// root injects the live `CloudKitSharingService` once sharing ships.
    var teamSharingService: any TeamSharingService {
        get { self[TeamSharingServiceKey.self] }
        set { self[TeamSharingServiceKey.self] = newValue }
    }
}

#if DEBUG
/// Stand-in sharing service for the screenshot harness (`-uiTestSeedDemo`).
///
/// The demo team is presented as shared, so the owner-side markers (#93) need
/// something to report: a real count for the "Shared with 2 followers" subtitle
/// and a populated Followers list. `NoopSharingService` returns nothing, which
/// renders every one of those screens in its empty state.
///
/// Read-only and offline — it never touches CloudKit, and publishing is a no-op
/// so a screenshot run can't try to push demo rosters anywhere.
struct DemoSharingService: TeamSharingService {
    /// Only this team reports as shared. `isSharing` returning `true` for
    /// everything made `syncSharedState()` adopt *every* demo team, so the
    /// second team picked up a "Shared" tag it was never given.
    let sharedTeamID: UUID

    var isAvailable: Bool { true }

    func prepareShare(for team: Team, games: [Game]) async throws -> PreparedShare {
        throw SharingError.unavailable
    }
    func publish(team: Team, games: [Game]) async throws {}
    func stopSharing(_ team: Team) async throws {}
    func acceptShare(_ metadata: CKShare.Metadata) async throws {}
    func fetchFollowedTeams() async throws -> [FollowedTeam] { [DemoData.makeFollowedTeam()] }
    func isSharing(_ team: Team) async throws -> Bool { team.id == sharedTeamID }
    func participants(for team: Team) async throws -> [SharedParticipant] {
        team.id == sharedTeamID ? DemoData.makeParticipants() : []
    }
    func shareURL(for team: Team) async throws -> URL? {
        team.id == sharedTeamID ? URL(string: "https://www.icloud.com/share/demo") : nil
    }
    func subscribeToFollowedTeamChanges() async throws {}
}
#endif
