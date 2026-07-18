import Foundation
import Combine

/// The persisted multi-team container (new-format blob, #20).
struct TeamsState: Codable {
    var teams: [Team]
    var activeTeamID: UUID
}

/// Single source of truth for the app. Holds every team, the active team, and
/// all games, and auto-persists to UserDefaults (as JSON) on every mutation.
///
/// Multi-team (#20): most people coach one team, so the common case stays
/// simple — `team` is the active team and every existing view reads it as
/// before. Extra teams are managed in Settings; the Games list and Roster are
/// scoped to the active team.
final class AppStore: ObservableObject {
    @Published var teams: [Team] { didSet { save() } }
    @Published var activeTeamID: UUID { didSet { save() } }
    @Published var games: [Game] { didSet { save() } }
    /// In-app text-size step (index into `AppTextSize.steps`); applied app-wide
    /// as a Dynamic Type floor. 0 = default.
    @Published var textSizeIndex: Int { didSet { save() } }

    private let teamsKey = "chs.teams.v1"        // multi-team blob
    private let gamesKey = "chs.games.v1"
    private let textSizeKey = "chs.textSizeIndex.v1"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// When true, mutations are not persisted. Set for UI-test screenshot runs
    /// so seeded demo content never overwrites real data.
    private let ephemeral: Bool

    init() {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedDemo") {
            let demoTeam = DemoData.makeTeam()
            teams = [demoTeam, DemoData.makeSecondTeam()]
            activeTeamID = demoTeam.id
            games = DemoData.makeGames(team: demoTeam).map {
                var g = $0; g.teamID = demoTeam.id; return g
            }
            textSizeIndex = 0
            ephemeral = true
            return
        }
        #endif
        ephemeral = false

        // Returns 0 (the default step) when unset. Set before the team branch so
        // all stored properties are initialized before `persistTeams()` runs.
        textSizeIndex = UserDefaults.standard.integer(forKey: textSizeKey)

        // Teams: load the saved collection, else start with one empty team.
        if let data = UserDefaults.standard.data(forKey: teamsKey),
           let saved = try? decoder.decode(TeamsState.self, from: data),
           !saved.teams.isEmpty {
            teams = saved.teams
            activeTeamID = saved.teams.contains(where: { $0.id == saved.activeTeamID })
                ? saved.activeTeamID : saved.teams[0].id
        } else {
            let first = Team(name: "My Team", players: [])
            teams = [first]
            activeTeamID = first.id
        }

        if let data = UserDefaults.standard.data(forKey: gamesKey),
           let saved = try? decoder.decode([Game].self, from: data) {
            games = saved
        } else {
            games = []
        }
    }

    // MARK: - Persistence

    private func save() {
        if ephemeral { return }
        persistTeams()
        persistGames()
        UserDefaults.standard.set(textSizeIndex, forKey: textSizeKey)
    }

    private func persistTeams() {
        let state = TeamsState(teams: teams, activeTeamID: activeTeamID)
        if let data = try? encoder.encode(state) {
            UserDefaults.standard.set(data, forKey: teamsKey)
        }
    }

    private func persistGames() {
        if let data = try? encoder.encode(games) {
            UserDefaults.standard.set(data, forKey: gamesKey)
        }
    }

    // MARK: - Active team

    /// The active team — what Roster shows and new games default to. Existing
    /// views read/write this exactly as they did the old single `team`.
    var team: Team {
        get { teams.first { $0.id == activeTeamID } ?? teams.first ?? .empty }
        set {
            if let i = teams.firstIndex(where: { $0.id == newValue.id }) {
                teams[i] = newValue
            } else if let i = teams.firstIndex(where: { $0.id == activeTeamID }) {
                teams[i] = newValue
            }
        }
    }

    // MARK: - Teams

    func addTeam(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let team = Team(name: trimmed.isEmpty ? "New Team" : trimmed, players: [])
        teams.append(team)
        activeTeamID = team.id   // switch to the team you just made
    }

    func setActiveTeam(_ id: UUID) {
        guard teams.contains(where: { $0.id == id }) else { return }
        activeTeamID = id
    }

    /// Rename a specific team (any team, not just the active one).
    func renameTeam(id: UUID, to name: String) {
        guard let i = teams.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { teams[i].name = trimmed }
    }

    /// Delete a team and its games. No-op on the last remaining team so there's
    /// always an active team.
    func deleteTeam(_ id: UUID) {
        guard teams.count > 1 else { return }
        games.removeAll { $0.teamID == id }
        teams.removeAll { $0.id == id }
        if activeTeamID == id { activeTeamID = teams[0].id }
    }

    // MARK: - Roster (operates on the active team)

    func renameTeam(_ name: String) {
        team.name = name
    }

    func addPlayer(name: String, number: String) {
        team.players.append(Player(name: name, number: number))
    }

    func updatePlayer(_ player: Player) {
        guard let index = team.players.firstIndex(where: { $0.id == player.id }) else { return }
        team.players[index] = player
    }

    func deletePlayers(at offsets: IndexSet) {
        team.players.remove(atOffsets: offsets)
    }

    func movePlayers(from source: IndexSet, to destination: Int) {
        team.players.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Games

    /// All games belonging to the active team, in stored (newest-first) order.
    var activeTeamGames: [Game] {
        games.filter { ($0.teamID ?? activeTeamID) == activeTeamID }
    }

    /// Insert a new game at the front so the list stays newest-first. Stamps the
    /// active team's id if the caller didn't set one.
    func addGame(_ game: Game) {
        var g = game
        if g.teamID == nil { g.teamID = activeTeamID }
        games.insert(g, at: 0)
    }

    func updateGame(_ game: Game) {
        guard let index = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[index] = game
    }

    func deleteGames(at offsets: IndexSet) {
        games.remove(atOffsets: offsets)
    }

    func deleteGame(id: UUID) {
        games.removeAll { $0.id == id }
    }

    func game(id: UUID) -> Game? {
        games.first { $0.id == id }
    }

    // MARK: - Autocomplete sources (scoped to the active team)

    /// Distinct, non-empty prior values for a game text field, most-recent first.
    private func knownValues(_ keyPath: KeyPath<Game, String>) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for game in activeTeamGames {
            let value = game[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
            let key = value.lowercased()
            if !value.isEmpty, !seen.contains(key) {
                seen.insert(key)
                result.append(value)
            }
        }
        return result
    }

    var knownLeagues: [String] { knownValues(\.league) }
    var knownLocations: [String] { knownValues(\.location) }
}
