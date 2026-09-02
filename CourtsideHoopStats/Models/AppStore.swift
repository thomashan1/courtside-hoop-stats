import Foundation
import Combine

/// How the roster can be sorted (#27).
enum PlayerSort {
    case name, number
}

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
    /// Teams shared *with* this user, read-only (#57). Cached so a follower in
    /// a gym with no signal still sees the last known score. Kept out of
    /// `teams` so they can never be edited — see `FollowedTeam`.
    @Published var followedTeams: [FollowedTeam] { didSet { save() } }
    /// How often a follower wants to be notified about games (#57).
    @Published var alertCadence: FollowerAlertCadence { didSet { save() } }
    /// Teams this user has shared *out* (#57). Tracked locally so an edit knows
    /// whether it needs publishing without asking CloudKit on every keystroke.
    @Published var sharedTeamIDs: Set<UUID> { didSet { save() } }

    private let teamsKey = "chs.teams.v1"        // multi-team blob
    private let gamesKey = "chs.games.v1"
    private let textSizeKey = "chs.textSizeIndex.v1"
    private let followedKey = "chs.followedTeams.v1"
    private let sharedKey = "chs.sharedTeams.v1"
    private let cadenceKey = "chs.alertCadence.v1"

    /// Backend for publishing local edits to followers. Injected at app launch;
    /// nil in tests and previews, which disables publishing entirely.
    var sharingService: (any TeamSharingService)?
    private var publishTask: Task<Void, Never>?
    /// How long to wait after the last edit before pushing. Live scoring writes
    /// on every basket, so publishing per-mutation would hammer CloudKit; this
    /// coalesces a flurry of taps into one upload.
    private let publishDebounce: Duration = .seconds(3)

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    /// When true, mutations are not persisted. Set for UI-test screenshot runs
    /// so seeded demo content never overwrites real data.
    private let ephemeral: Bool

    /// - Parameter inMemory: skips loading and saving entirely. Used by unit
    ///   tests so they exercise the real logic without reading or writing the
    ///   app's stored data.
    init(inMemory: Bool = false) {
        if inMemory {
            let team = Team(name: "Test Team", players: [])
            teams = [team]
            activeTeamID = team.id
            games = []
            textSizeIndex = 0
            followedTeams = []
            sharedTeamIDs = []
            alertCadence = .periodEnd
            ephemeral = true
            return
        }

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-uiTestSeedDemo") {
            let demoTeam = DemoData.makeTeam()
            teams = [demoTeam, DemoData.makeSecondTeam()]
            activeTeamID = demoTeam.id
            games = DemoData.makeGames(team: demoTeam).map {
                var g = $0; g.teamID = demoTeam.id; return g
            }
            // `-uiTestTextSizeIndex N` seeds the in-app Text Size so a UI test
            // can exercise accessibility sizes. The OS-level
            // `-UIPreferredContentSizeCategoryName` argument does not reach a
            // SwiftUI app whose root applies its own `.dynamicTypeSize` floor,
            // and this is the control a user would actually reach for anyway.
            // `UserDefaults` picks up `-key value` launch arguments directly, so
            // the value arrives already parsed; 0 when absent.
            textSizeIndex = UserDefaults.standard.integer(forKey: "uiTestTextSizeIndex")
            followedTeams = [DemoData.makeFollowedTeam()]
            // The demo team is presented as shared, so the owner-side sharing
            // markers (#93) appear in screenshots rather than the unshared
            // default. Paired with `DemoSharingService`, which supplies the
            // follower list they read from.
            sharedTeamIDs = [demoTeam.id]
            alertCadence = .periodEnd
            ephemeral = true
            return
        }
        #endif
        ephemeral = false

        // Returns 0 (the default step) when unset. Set before the team branch so
        // all stored properties are initialized before `persistTeams()` runs.
        textSizeIndex = UserDefaults.standard.integer(forKey: textSizeKey)

        if let data = UserDefaults.standard.data(forKey: followedKey),
           let saved = try? decoder.decode([FollowedTeam].self, from: data) {
            followedTeams = saved
        } else {
            followedTeams = []
        }

        if let data = UserDefaults.standard.data(forKey: sharedKey),
           let saved = try? decoder.decode(Set<UUID>.self, from: data) {
            sharedTeamIDs = saved
        } else {
            sharedTeamIDs = []
        }

        // Period ends by default: frequent enough to follow a game, rare enough
        // not to get muted.
        alertCadence = UserDefaults.standard.string(forKey: cadenceKey)
            .flatMap(FollowerAlertCadence.init(rawValue:)) ?? .periodEnd

        // Teams: load the saved collection, else start with one empty team.
        if let data = UserDefaults.standard.data(forKey: teamsKey),
           let saved = try? decoder.decode(TeamsState.self, from: data),
           !saved.teams.isEmpty {
            teams = saved.teams
            activeTeamID = saved.teams.contains(where: { $0.id == saved.activeTeamID })
                ? saved.activeTeamID : saved.teams[0].id
        } else {
            let first = Team(name: "My Test Team", players: [])
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
        if let data = try? encoder.encode(followedTeams) {
            UserDefaults.standard.set(data, forKey: followedKey)
        }
        if let data = try? encoder.encode(sharedTeamIDs) {
            UserDefaults.standard.set(data, forKey: sharedKey)
        }
        UserDefaults.standard.set(alertCadence.rawValue, forKey: cadenceKey)
        schedulePublish()
    }

    // MARK: - Publishing to followers (#57)

    /// Note that a team is now shared, so later edits get published.
    func markShared(_ teamID: UUID) {
        sharedTeamIDs.insert(teamID)
    }

    /// Replace the followed snapshot, notifying about whatever changed.
    ///
    /// Every refresh path funnels through here — the tab, the game screen, a
    /// push, launch — so alerting can't be forgotten at one call site and the
    /// comparison always has the snapshot the follower actually last saw.
    @MainActor
    func applyFollowedTeams(_ fetched: [FollowedTeam]) async {
        let previous = followedTeams
        followedTeams = fetched

        guard alertCadence != .off else { return }
        var alerts: [FollowerAlert] = []
        for team in fetched {
            alerts += FollowerAlertBuilder.alerts(
                previous: previous.first { $0.id == team.id },
                current: team,
                cadence: alertCadence
            )
        }
        await FollowerNotifier.shared.post(alerts)
    }

    /// Ask CloudKit which of my teams are actually shared, and publish those.
    ///
    /// Local state can't be trusted on its own: a team shared from an earlier
    /// build (or another device) isn't in `sharedTeamIDs`, so it would silently
    /// never publish — its followers would sit on whatever was uploaded the day
    /// it was shared. Publishing on discovery also pushes everything recorded
    /// while the app didn't realise it was sharing.
    @MainActor
    func syncSharedState() async {
        guard let service = sharingService, service.isAvailable else { return }

        for team in teams {
            guard let shared = try? await service.isSharing(team) else { continue }
            let knownShared = sharedTeamIDs.contains(team.id)

            if shared {
                if !knownShared { sharedTeamIDs.insert(team.id) }
                // Catch followers up on anything recorded while we weren't
                // publishing, whether or not the flag was already set.
                let teamGames = games.filter { ($0.teamID ?? team.id) == team.id }
                try? await service.publish(team: team, games: teamGames)
            } else if knownShared {
                sharedTeamIDs.remove(team.id)
            }
        }
    }

    func markNotShared(_ teamID: UUID) {
        sharedTeamIDs.remove(teamID)
    }

    func isShared(_ teamID: UUID) -> Bool {
        sharedTeamIDs.contains(teamID)
    }

    /// Push shared teams to CloudKit a beat after the last edit.
    ///
    /// Debounced rather than immediate: scoring a game writes on every basket,
    /// and publishing per-tap would upload the whole game dozens of times in a
    /// quarter. Each new edit cancels the pending upload and restarts the timer,
    /// so a burst of taps costs one upload.
    private func schedulePublish() {
        guard let service = sharingService, !sharedTeamIDs.isEmpty else { return }

        publishTask?.cancel()
        publishTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: self?.publishDebounce ?? .seconds(3))
            guard !Task.isCancelled, let self else { return }
            await self.publishSharedTeams(using: service)
        }
    }

    @MainActor
    private func publishSharedTeams(using service: any TeamSharingService) async {
        for id in sharedTeamIDs {
            guard let team = teams.first(where: { $0.id == id }) else { continue }
            let teamGames = games.filter { ($0.teamID ?? id) == id }
            do {
                try await service.publish(team: team, games: teamGames)
            } catch SharingError.notShared {
                // The share is gone (owner stopped sharing, or it was removed on
                // another device). Stop trying, rather than recreating a zone
                // the user deliberately deleted.
                markNotShared(id)
            } catch {
                // Offline or a transient CloudKit failure. The next edit
                // reschedules, and a full publish is sent then — nothing to
                // reconcile, because we always upload current state.
            }
        }
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

    /// Set while a tapped share invite is being accepted (#116) — lets the app
    /// show a progress overlay instead of appearing to hang after the tap.
    @Published var isAcceptingShare = false
    /// Set when accepting a tapped share invite fails (#116); shown as an
    /// alert, then cleared. `nil` means nothing to show.
    @Published var shareAcceptanceError: String?

    /// True for someone who only follows other people's teams (#115): the
    /// only local team is still the untouched default (no players, no
    /// games), and at least one team is actually followed. `teams` itself is
    /// never empty — a fresh install auto-creates one blank team — so
    /// emptiness has to be read off its contents rather than the array.
    ///
    /// Gated on `teams.count == 1`, not "every team is empty", so there's
    /// always a way out: adding or importing a second team (#118) flips this
    /// false immediately, before that team has any players, which is what
    /// un-hides Roster so they can actually add players to it.
    var isPureFollower: Bool {
        !followedTeams.isEmpty && games.isEmpty && teams.count == 1 && (teams.first?.players.isEmpty ?? true)
    }

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

    /// Add an imported team + roster as a NEW team (#40). IDs are regenerated so
    /// it can never collide with existing data, and a duplicate name is
    /// disambiguated. Non-destructive — nothing existing is touched. Returns the
    /// team as it was actually inserted; it becomes the active team.
    @discardableResult
    func importTeam(from export: TeamExport) -> Team {
        var team = export.team
        team.id = UUID()
        team.players = team.players.map { var p = $0; p.id = UUID(); return p }

        var name = team.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { name = "Imported Team" }
        if teams.contains(where: { $0.name == name }) { name += " (Imported)" }
        team.name = name

        teams.append(team)
        activeTeamID = team.id
        return team
    }

    /// Replace a team wholesale (used by the Settings team editor for live
    /// name/jersey edits, #27-followup). No-op if the id isn't found.
    func updateTeam(_ team: Team) {
        guard let i = teams.firstIndex(where: { $0.id == team.id }) else { return }
        teams[i] = team
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

    func deletePlayer(_ id: UUID) {
        team.players.removeAll { $0.id == id }
    }

    /// Sort the active team's roster in place (persisted, so it applies to the
    /// live-scoring grid too). Replaces manual drag-reorder (#27).
    func sortPlayers(by sort: PlayerSort) {
        switch sort {
        case .name:
            team.players.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .number:
            // Numeric where possible ("2" before "10"); non-numeric go last,
            // ties broken by name.
            team.players.sort { a, b in
                let na = Int(a.number) ?? Int.max
                let nb = Int(b.number) ?? Int.max
                if na != nb { return na < nb }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        }
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
