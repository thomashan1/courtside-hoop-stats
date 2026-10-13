import CloudKit

extension CKDatabase {
    /// Every record currently in `zoneID`, following `moreComing` until the
    /// zone is exhausted.
    ///
    /// `recordZoneChanges(inZoneWith:since:)` returns **one batch**, not the
    /// zone. Reading only that batch meant a record past it was invisible:
    /// the owner's publish never saw a deleted game to remove it, so
    /// followers kept a phantom game the owner had deleted, and a restore
    /// could come back short.
    func allRecordZoneChanges(
        in zoneID: CKRecordZone.ID
    ) async throws -> [CKRecord.ID: Result<RecordZoneChange.Modification, any Error>] {
        var results: [CKRecord.ID: Result<RecordZoneChange.Modification, any Error>] = [:]
        var token: CKServerChangeToken?
        repeat {
            let page = try await recordZoneChanges(inZoneWith: zoneID, since: token)
            results.merge(page.modificationResultsByID) { _, newer in newer }
            for deletion in page.deletions { results[deletion.recordID] = nil }
            // A page that says more is coming but hands back the same token
            // would loop forever; stop rather than spin.
            if page.moreComing, page.changeToken == token { break }
            token = page.changeToken
            if !page.moreComing { break }
        } while true
        return results
    }

    /// Delete `ids`, surfacing the first per-record failure.
    ///
    /// `modifyRecords` only throws when the whole request fails; a single
    /// record that couldn't be deleted comes back inside the result, and
    /// discarding that is how a delete could fail while Sync Now reported
    /// success. A record that's already gone counts as deleted.
    func deleteRecords(_ ids: [CKRecord.ID]) async throws {
        for start in stride(from: 0, to: ids.count, by: 200) {
            let batch = Array(ids[start..<min(start + 200, ids.count)])
            let result = try await modifyRecords(saving: [], deleting: batch)
            for (_, outcome) in result.deleteResults {
                if case .failure(let error) = outcome {
                    if let ckError = error as? CKError, ckError.code == .unknownItem { continue }
                    throw error
                }
            }
        }
    }
}
