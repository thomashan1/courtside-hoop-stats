import Foundation
import CloudKit

/// The live CloudKit backing for team sharing (#57).
///
/// **One custom zone per shared team** (`team-<uuid>`), with the team as the
/// root record and its games as children. Sharing requires a custom zone —
/// records in the default zone can't be shared — and a zone per team keeps the
/// hierarchies isolated, so "stop sharing" is a single zone delete that can't
/// reach another team's data.
///
/// Publishing is **one-way**: the owner's local `UserDefaults`/JSON store stays
/// the source of truth and is mirrored up. Followers are read-only, so there is
/// no merge or conflict resolution to do — the reason this slice needs neither
/// Core Data nor SwiftData (see `docs/SHARING.md`).
final class CloudKitSharingService: TeamSharingService {
    static let defaultContainerIdentifier = "iCloud.com.thomashan.CourtsideHoopStats"

    private let container: CKContainer
    private var database: CKDatabase { container.privateCloudDatabase }

    init(containerIdentifier: String = CloudKitSharingService.defaultContainerIdentifier) {
        self.container = CKContainer(identifier: containerIdentifier)
    }

    var isAvailable: Bool { true }

    // MARK: - Sharing

    func prepareShare(for team: Team, games: [Game]) async throws -> PreparedShare {
        try await requireAccount()
        let zoneID = try await ensureZone(for: team)

        let teamRecord = try await upsertTeamRecord(team, in: zoneID)

        // Reuse the existing share if this team has already been shared —
        // creating a second one would orphan everyone already invited.
        if let existing = try await existingShare(on: teamRecord) {
            try await saveHierarchy(teamRecord: teamRecord, games: games,
                                    teamID: team.id, in: zoneID)
            // Refresh the presentation fields: the share sheet reads these off
            // the stored record, so a renamed team (or an icon added after the
            // share was first made) would otherwise show stale details forever.
            if applyPresentation(of: team, to: existing) {
                try await save([existing])
            }
            return PreparedShare(share: existing, container: container)
        }

        let share = CKShare(rootRecord: teamRecord)
        _ = applyPresentation(of: team, to: share)
        // Invite-only. A public "anyone with the link" share would put a
        // children's roster behind a forwardable URL; the owner can still
        // invite anyone they like by email or phone.
        share.publicPermission = .none

        // A new share and its root record must be saved in the same operation.
        try await saveHierarchy(teamRecord: teamRecord, alongside: [share],
                                games: games, teamID: team.id, in: zoneID)
        return PreparedShare(share: share, container: container)
    }

    func publish(team: Team, games: [Game]) async throws {
        try await requireAccount()
        let zoneID = zoneID(for: team)

        // Only publish a team that's actually shared — otherwise this would
        // silently recreate a zone the owner just stopped sharing.
        guard try await zoneExists(zoneID) else { throw SharingError.notShared }

        let teamRecord = try await upsertTeamRecord(team, in: zoneID)
        try await saveHierarchy(teamRecord: teamRecord, games: games,
                                teamID: team.id, in: zoneID)
    }

    func stopSharing(_ team: Team) async throws {
        try await requireAccount()
        // Deleting the zone removes the share, the team, and its games in one
        // shot. The owner's local copy is untouched.
        _ = try await database.modifyRecordZones(saving: [], deleting: [zoneID(for: team)])
    }

    /// Set the title and icon the system share sheet shows for this share.
    ///
    /// These live as system fields **on the share record**, not on the app
    /// side: `UICloudSharingController` reads them from the stored share, and
    /// its delegate is only consulted while a share is being created. Returns
    /// whether anything actually changed, so an unchanged share isn't re-saved.
    @discardableResult
    private func applyPresentation(of team: Team, to share: CKShare) -> Bool {
        var changed = false

        if share[CKShare.SystemFieldKey.title] as? String != team.name {
            share[CKShare.SystemFieldKey.title] = team.name as CKRecordValue
            changed = true
        }

        if let icon = AppIconThumbnail.pngData,
           share[CKShare.SystemFieldKey.thumbnailImageData] as? Data != icon {
            share[CKShare.SystemFieldKey.thumbnailImageData] = icon as CKRecordValue
            changed = true
        }

        return changed
    }

    // MARK: - Account

    private func requireAccount() async throws {
        let status = try await container.accountStatus()
        guard status == .available else { throw SharingError.iCloudAccountUnavailable }
    }

    // MARK: - Zones

    private func zoneID(for team: Team) -> CKRecordZone.ID {
        CKRecordZone.ID(zoneName: "team-\(team.id.uuidString)",
                        ownerName: CKCurrentUserDefaultName)
    }

    @discardableResult
    private func ensureZone(for team: Team) async throws -> CKRecordZone.ID {
        let id = zoneID(for: team)
        // Saving an existing zone is a no-op server-side, so this is idempotent
        // and cheaper than fetch-then-create.
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: id)], deleting: [])
        return id
    }

    private func zoneExists(_ id: CKRecordZone.ID) async throws -> Bool {
        do {
            _ = try await database.recordZone(for: id)
            return true
        } catch let error as CKError where error.code == .zoneNotFound {
            return false
        }
    }

    // MARK: - Records

    /// Fetch-or-create, then apply. Mutating the **server's** record preserves
    /// its system fields — above all the `share` reference, which a
    /// freshly-built replacement would drop and thereby un-share the team.
    private func upsertTeamRecord(_ team: Team, in zoneID: CKRecordZone.ID) async throws -> CKRecord {
        let id = CloudKitSchema.teamRecordID(team.id, in: zoneID)
        let record = try await existingRecord(id)
            ?? CKRecord(recordType: CloudKitSchema.teamRecordType, recordID: id)
        CloudKitSchema.apply(team, to: record)
        return record
    }

    private func gameRecords(for games: [Game], teamID: UUID, in zoneID: CKRecordZone.ID) -> [CKRecord] {
        games.map { CloudKitSchema.record(for: $0, teamID: teamID, in: zoneID) }
    }

    /// Save the team root (plus anything that must ride with it, like a new
    /// share), **then** its games.
    ///
    /// The order matters: a game carries a parent reference to its team, and
    /// CloudKit rejects a child whose parent isn't on the server yet with
    /// "Parent record … does not exist on the server". Saving games first is
    /// exactly that failure.
    private func saveHierarchy(teamRecord: CKRecord,
                               alongside extras: [CKRecord] = [],
                               games: [Game],
                               teamID: UUID,
                               in zoneID: CKRecordZone.ID) async throws {
        try await save([teamRecord] + extras)
        try await save(gameRecords(for: games, teamID: teamID, in: zoneID))
    }

    private func existingRecord(_ id: CKRecord.ID) async throws -> CKRecord? {
        do {
            return try await database.record(for: id)
        } catch let error as CKError where error.code == .unknownItem || error.code == .zoneNotFound {
            return nil
        }
    }

    private func existingShare(on record: CKRecord) async throws -> CKShare? {
        guard let reference = record.share else { return nil }
        return try await existingRecord(reference.recordID) as? CKShare
    }

    /// Save records and surface the first failure. `.allKeys` because the owner
    /// is the only writer, so the local copy always wins.
    private func save(_ records: [CKRecord]) async throws {
        guard !records.isEmpty else { return }
        let result = try await database.modifyRecords(saving: records,
                                                      deleting: [],
                                                      savePolicy: .allKeys,
                                                      atomically: true)
        for (_, outcome) in result.saveResults {
            if case .failure(let error) = outcome { throw error }
        }
    }
}
