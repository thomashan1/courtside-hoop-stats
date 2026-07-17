import Foundation
import Combine

/// Single source of truth for the app. Holds the roster and all games, and
/// auto-persists to UserDefaults (as JSON) on every mutation.
final class AppStore: ObservableObject {
    @Published var team: Team { didSet { save() } }
    @Published var games: [Game] { didSet { save() } }

    private let teamKey = "chs.team.v1"
    private let gamesKey = "chs.games.v1"

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        // `didSet` does not fire for values assigned inside init, so this
        // initial load does not trigger a redundant save.
        if let data = UserDefaults.standard.data(forKey: teamKey),
           let saved = try? JSONDecoder().decode(Team.self, from: data) {
            team = saved
        } else {
            team = .empty
        }

        if let data = UserDefaults.standard.data(forKey: gamesKey),
           let saved = try? JSONDecoder().decode([Game].self, from: data) {
            games = saved
        } else {
            games = []
        }
    }

    private func save() {
        if let data = try? encoder.encode(team) {
            UserDefaults.standard.set(data, forKey: teamKey)
        }
        if let data = try? encoder.encode(games) {
            UserDefaults.standard.set(data, forKey: gamesKey)
        }
    }

    // MARK: - Roster

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

    /// Insert a new game at the front so the list stays newest-first.
    func addGame(_ game: Game) {
        games.insert(game, at: 0)
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
}
