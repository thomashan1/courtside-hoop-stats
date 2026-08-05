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
