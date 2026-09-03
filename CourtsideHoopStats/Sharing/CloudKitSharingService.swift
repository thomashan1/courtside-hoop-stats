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

    // MARK: - Follower side

    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        try await requireAccount()
        _ = try await container.accept(metadata)
    }

    func fetchFollowedTeams() async throws -> [FollowedTeam] {
        try await requireAccount()
        let database = container.sharedCloudDatabase

        // Each accepted share arrives as its own zone in the shared database.
        let zones = try await database.allRecordZones()
        var followed: [FollowedTeam] = []

        for zone in zones {
            // Zone *changes* rather than a query: a query would need the record
            // type indexed as queryable in the CloudKit schema, while change
            // fetching works on any zone as-is.
            let changes = try await database.recordZoneChanges(inZoneWith: zone.zoneID, since: nil)

            var team: Team?
            var teamRecord: CKRecord?
            var games: [Game] = []
            for (_, result) in changes.modificationResultsByID {
                guard let record = try? result.get().record else { continue }
                if let decoded = CloudKitSchema.team(from: record) {
                    team = decoded
                    teamRecord = record
                } else if let decoded = CloudKitSchema.game(from: record) {
                    games.append(decoded)
                }
            }

            // A zone with no team record is one we can't render — skip it
            // rather than surfacing a nameless placeholder.
            guard let team else { continue }
            let sharedByName = await ownerFirstName(of: teamRecord, in: database)
            followed.append(FollowedTeam(team: team,
                                         games: games,
                                         zoneName: zone.zoneID.zoneName,
                                         ownerName: zone.zoneID.ownerName,
                                         sharedByName: sharedByName,
                                         updatedAt: Date()))
        }

        return followed.sorted { $0.team.name < $1.team.name }
    }

    /// Remove just this participant's acceptance of `team`'s share (#123).
    ///
    /// Deletes the zone from the **shared** database — the follower's own
    /// view of it — rather than `stopSharing`'s delete against the **owner's
    /// private** database. The owner's copy and every other follower are
    /// untouched; only this device stops seeing it.
    func unfollow(_ team: FollowedTeam) async throws {
        try await requireAccount()
        let zoneID = CKRecordZone.ID(zoneName: team.zoneName, ownerName: team.ownerName)
        _ = try await container.sharedCloudDatabase.modifyRecordZones(saving: [], deleting: [zoneID])
    }

    /// The owner's first name for a followed team's "Shared by Jean" line
    /// (#120), read off the `CKShare` referenced by its team record.
    ///
    /// Best-effort: `try?` throughout, because a name that can't be resolved
    /// should fall back to no "Shared by" line (`FollowedTeam.subtitle`
    /// already handles `nil`), not fail the whole fetch over one zone.
    private func ownerFirstName(of teamRecord: CKRecord?, in database: CKDatabase) async -> String? {
        guard let reference = teamRecord?.share,
              let share = try? await database.record(for: reference.recordID) as? CKShare
        else { return nil }
        // `.owner`, not filtering `.participants` for `role == .owner`: it's
        // CKShare's own documented accessor for exactly this, and cheaper
        // insurance against `.participants` ever coming back in an order or
        // shape filtering doesn't expect.
        return share.owner.userIdentity.nameComponents?.givenName
    }

    func isSharing(_ team: Team) async throws -> Bool {
        try await requireAccount()
        return try await share(for: team) != nil
    }

    /// Subscription id is fixed: CloudKit keeps one subscription per id, so
    /// re-saving simply overwrites rather than accumulating duplicates every
    /// launch.
    private static let followedChangesSubscriptionID = "shared-teams-changed"

    func subscribeToFollowedTeamChanges() async throws {
        try await requireAccount()

        let subscription = CKDatabaseSubscription(
            subscriptionID: Self.followedChangesSubscriptionID)

        // Silent: CloudKit's push can't carry a score, so it only wakes the app.
        // The app then fetches and posts its own notification with real content
        // — see FollowerNotifier.
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info

        do {
            _ = try await container.sharedCloudDatabase
                .modifySubscriptions(saving: [subscription], deleting: [])
        } catch let error as CKError where error.code == .serverRejectedRequest {
            // Already registered — the common case on every launch after the
            // first, and not worth surfacing.
            return
        }
    }

    func shareURL(for team: Team) async throws -> URL? {
        try await requireAccount()
        return try await share(for: team)?.url
    }

    /// The team's share, if it has one. Nil when the zone, the record, or the
    /// share is missing — all of which mean "not shared".
    private func share(for team: Team) async throws -> CKShare? {
        let zoneID = zoneID(for: team)
        guard try await zoneExists(zoneID) else { return nil }
        let teamRecordID = CloudKitSchema.teamRecordID(team.id, in: zoneID)
        guard let record = try await existingRecord(teamRecordID) else { return nil }
        return try await existingShare(on: record)
    }

    func participants(for team: Team) async throws -> [SharedParticipant] {
        try await requireAccount()
        guard let share = try await share(for: team) else { return [] }

        return share.participants.enumerated().map { index, participant in
            let identity = participant.userIdentity
            let contact = identity.lookupInfo?.emailAddress
                ?? identity.lookupInfo?.phoneNumber
                ?? ""

            // iCloud withholds name components until an invite is accepted, so
            // fall back to whatever contact the invite went to rather than
            // showing a blank row.
            let formatted = identity.nameComponents.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
            } ?? ""
            let name = formatted.isEmpty ? (contact.isEmpty ? "Invited person" : contact)
                                         : formatted

            // Identity has to be stable across refreshes or SwiftUI re-creates
            // every row; the position is the last resort when CloudKit gives us
            // neither a user record nor a contact.
            let id = identity.userRecordID?.recordName
                ?? (contact.isEmpty ? "participant-\(index)" : contact)

            return SharedParticipant(
                id: id,
                name: name,
                // Don't repeat the contact underneath when it *is* the name.
                contact: formatted.isEmpty ? "" : contact,
                isOwner: participant.role == .owner,
                hasAccepted: participant.acceptanceStatus == .accepted
            )
        }
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
        try await deleteGamesNoLongerPresent(games, in: zoneID)
    }

    /// Remove game records the owner has since deleted locally.
    ///
    /// Publishing only ever *saved*, so a deleted game stayed in the zone and
    /// kept coming back to followers on every fetch — the follower's copy was
    /// append-only whatever the owner did.
    private func deleteGamesNoLongerPresent(_ games: [Game],
                                            in zoneID: CKRecordZone.ID) async throws {
        let keep = Set(games.map { CloudKitSchema.gameRecordID($0.id, in: zoneID) })
        let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: nil)

        let stale = changes.modificationResultsByID.compactMap { id, result -> CKRecord.ID? in
            guard let record = try? result.get().record,
                  record.recordType == CloudKitSchema.gameRecordType,
                  !keep.contains(id) else { return nil }
            return id
        }

        guard !stale.isEmpty else { return }
        _ = try await database.modifyRecords(saving: [], deleting: stale)
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
