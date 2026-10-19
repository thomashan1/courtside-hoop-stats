import Foundation

/// A team's games split by tournament.
///
/// The tournament is the game's **League** field — Jean already types it on
/// every game, so the same team carries on from one tournament to the next
/// without a new team or re-sharing it with followers. Grouping on an existing
/// field means no schema change: every shipped build reads and writes it, and
/// followers already receive it.
struct TournamentGroup: Identifiable, Equatable {
    /// The name as most recently typed, or nil for games left blank.
    let name: String?
    /// Newest first.
    let games: [Game]

    var id: String { name.map(Tournaments.key) ?? "" }
    var title: String { name ?? Tournaments.otherTitle }
}

enum Tournaments {
    static let otherTitle = "Other Games"

    /// Two spellings that differ only in case or stray spaces are the same
    /// tournament: "NJB Fall 15U" and "njb fall 15u " shouldn't split a season.
    static func key(_ league: String) -> String {
        league.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Newest tournament first, by its most recent game. Games with no
    /// league are grouped last, as Other Games.
    static func groups(_ games: [Game]) -> [TournamentGroup] {
        let newestFirst = games.sorted { $0.date > $1.date }
        var order: [String] = []
        var byKey: [String: [Game]] = [:]
        for game in newestFirst {
            let key = key(game.league)
            if byKey[key] == nil { order.append(key) }
            byKey[key, default: []].append(game)
        }
        let groups = order.map { key -> TournamentGroup in
            let games = byKey[key] ?? []
            let name = key.isEmpty ? nil
                : games[0].league.trimmingCharacters(in: .whitespacesAndNewlines)
            return TournamentGroup(name: name, games: games)
        }
        let named: [TournamentGroup] = groups.filter { $0.name != nil }
        let blank: [TournamentGroup] = groups.filter { $0.name == nil }
        return named + blank
    }

    /// Worth showing as tournaments — even one, so it's named and followers
    /// see where the next one will go. Only a season with no league at all
    /// stays a plain list.
    static func named(_ groups: [TournamentGroup]) -> Bool {
        groups.contains { $0.name != nil }
    }
}
