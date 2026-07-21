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
