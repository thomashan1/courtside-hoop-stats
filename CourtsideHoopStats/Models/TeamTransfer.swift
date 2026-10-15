import Foundation
import CoreTransferable
import UniformTypeIdentifiers

/// Versioned payload for exporting/importing a single team + its roster (#40).
///
/// Games are intentionally excluded from v1 — this is for seeding a roster onto
/// another device (AirDrop) and for backup. A full backup (teams + games) is a
/// natural follow-on. `format`/`version` let a future import reject unrelated
/// JSON and stay backward-compatible.
struct TeamExport: Codable {
    var format: String = TeamExport.marker
    var version: Int = 1
    var exportedAt: Date = Date()
    var team: Team

    static let marker = "courtside.team.export"

    /// A stable encoder/decoder pair so export and import always agree.
    static let coder = (encoder: JSONEncoder(), decoder: JSONDecoder())
}

/// Wraps a `Team` so it can be shared as a `.json` file via `ShareLink`
/// (AirDrop, Files, Messages, …). The suggested filename is the team name.
struct TeamPackage: Transferable {
    let team: Team

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { package in
            try TeamExport.coder.encoder.encode(TeamExport(team: package.team))
        }
        .suggestedFileName { package in
            let safe = package.team.name
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .filter { !$0.isEmpty }
                .joined(separator: "-")
            return "\(safe.isEmpty ? "team" : safe).json"
        }
    }
}

// MARK: - Everything (every team and game)

/// Every team and every game in one file: a copy of the whole season that
/// doesn't depend on iCloud. Import reads it back by **adding** what's
/// missing, like the iCloud restore — it never overwrites or deletes.
struct LibraryExport: Codable {
    var format: String = LibraryExport.marker
    var version: Int = 1
    var exportedAt: Date = Date()
    var teams: [Team]
    var games: [Game]

    static let marker = "courtside.library.export"

    /// Reads a library file leniently: a team or game this build can't
    /// decode is skipped rather than failing the file — the moment someone
    /// reaches for this is the moment they can least afford "couldn't read".
    /// `nil` when it isn't a library file at all.
    static func read(_ data: Data) -> (teams: [Team], games: [Game])? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              object["format"] as? String == marker else { return nil }
        func salvage<T: Decodable>(_ key: String, as type: [T].Type) -> [T] {
            guard let raw = object[key],
                  let elements = try? JSONSerialization.data(withJSONObject: raw) else { return [] }
            return AppStore.salvagingElements(type, from: elements,
                                              quarantinedAs: "chs.import.unreadable.v1")
        }
        return (salvage("teams", as: [Team].self), salvage("games", as: [Game].self))
    }
}

/// Shares `LibraryExport` as a dated `.json` file.
struct LibraryPackage: Transferable {
    let teams: [Team]
    let games: [Game]

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { package in
            let encoder = JSONEncoder()
            // Readable if someone ever has to open it by hand.
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try encoder.encode(LibraryExport(teams: package.teams, games: package.games))
        }
        .suggestedFileName { _ in
            "Courtside Backup \(Date().formatted(.iso8601.year().month().day())).json"
        }
    }
}
