import Foundation

// MARK: - Team & Player

struct Team: Codable {
    var name: String
    var players: [Player]

    static let empty = Team(name: "My Team", players: [])
}

struct Player: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var number: String          // jersey number, stored as String (handles "0", "00")

    /// Up to two uppercased initials from the name, e.g. "Ava M." -> "AM".
    var initials: String {
        name.split(separator: " ")
            .compactMap(\.first)
            .prefix(2)
            .map { String($0).uppercased() }
            .joined()
    }
}

// MARK: - Events

enum EventType: String, Codable, CaseIterable {
    case twoPoint               // +2
    case threePoint             // +3
    case ftMade                 // +1
    case ftMissed               // +0, counts as FT attempt
    case foul                   // +0

    var points: Int {
        switch self {
        case .twoPoint:   return 2
        case .threePoint: return 3
        case .ftMade:     return 1
        case .ftMissed:   return 0
        case .foul:       return 0
        }
    }

    /// Compact label used on the action strip.
    var buttonLabel: String {
        switch self {
        case .twoPoint:   return "2 PT"
        case .threePoint: return "3 PT"
        case .ftMade:     return "FT ✓"
        case .ftMissed:   return "FT ✗"
        case .foul:       return "Foul"
        }
    }

    /// Descriptive label used in the event log.
    var logLabel: String {
        switch self {
        case .twoPoint:   return "2-Point"
        case .threePoint: return "3-Point"
        case .ftMade:     return "Free Throw"
        case .ftMissed:   return "FT Miss"
        case .foul:       return "Foul"
        }
    }
}

struct GameEvent: Identifiable, Codable {
    var id: UUID = UUID()
    var playerID: UUID
    var type: EventType
    var period: Int             // 1-based
    var timestamp: Date = Date()
}

// MARK: - Period format

enum PeriodFormat: String, Codable, CaseIterable {
    case quarters   // 4 periods, label "Q"
    case halves     // 2 periods, label "H"

    var periodCount: Int {
        switch self {
        case .quarters: return 4
        case .halves:   return 2
        }
    }

    var label: String {
        switch self {
        case .quarters: return "Q"
        case .halves:   return "H"
        }
    }

    var displayName: String {
        switch self {
        case .quarters: return "4 Quarters"
        case .halves:   return "2 Halves"
        }
    }

    /// Human label for a specific period, e.g. "Q1" or "H2".
    func periodLabel(_ period: Int) -> String { "\(label)\(period)" }
}

// MARK: - Scores

struct PeriodEndScore: Codable {
    var ourRunningTotal: Int        // cumulative (not delta)
    var opponentRunningTotal: Int   // cumulative (not delta)
}

// MARK: - Game

struct Game: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var opponent: String
    var league: String = ""
    var location: String = ""
    var isHome: Bool = true
    var periodFormat: PeriodFormat = .quarters
    var events: [GameEvent] = []
    var periodEndScores: [Int: PeriodEndScore] = [:]   // key = period number
    var notes: String = ""
    var isComplete: Bool = false

    // MARK: Derived (never stored)

    /// Our score, always auto-calculated from events.
    var ourScore: Int {
        events.reduce(0) { $0 + $1.type.points }
    }

    /// Opponent's final score = the highest recorded period running total.
    var opponentScore: Int {
        periodEndScores.keys.sorted().last
            .flatMap { periodEndScores[$0]?.opponentRunningTotal } ?? 0
    }

    /// The period currently being scored (1-based). Once every period has an
    /// end-score recorded the game is complete and this caps at the last period.
    var currentPeriod: Int {
        min(periodEndScores.count + 1, periodFormat.periodCount)
    }

    var isFinalPeriod: Bool {
        currentPeriod >= periodFormat.periodCount
    }

    enum Result { case win, loss, tie }

    var result: Result {
        if ourScore > opponentScore { return .win }
        if ourScore < opponentScore { return .loss }
        return .tie
    }

    /// Per-period score deltas. Our points are derived from events (so the
    /// breakdown always matches the event-sourced final score, even after an
    /// event is edited or deleted); the opponent side comes from the recorded
    /// cumulative running totals.
    func periodBreakdown() -> [(period: Int, our: Int, opponent: Int)] {
        var rows: [(Int, Int, Int)] = []
        var prevOpp = 0
        for period in 1...periodFormat.periodCount {
            guard let score = periodEndScores[period] else { break }
            let ourDelta = events
                .filter { $0.period == period }
                .reduce(0) { $0 + $1.type.points }
            rows.append((period, ourDelta, score.opponentRunningTotal - prevOpp))
            prevOpp = score.opponentRunningTotal
        }
        return rows
    }

    /// Aggregated stats per player, sorted by points descending.
    func stats(for players: [Player]) -> [PlayerStats] {
        var map: [UUID: PlayerStats] = [:]
        for player in players { map[player.id] = PlayerStats(player: player) }
        for event in events {
            guard var stats = map[event.playerID] else { continue }
            switch event.type {
            case .twoPoint:
                stats.twoPointers += 1
                stats.points += 2
            case .threePoint:
                stats.threePointers += 1
                stats.points += 3
            case .ftMade:
                stats.ftMade += 1
                stats.ftAttempts += 1
                stats.points += 1
            case .ftMissed:
                stats.ftAttempts += 1
            case .foul:
                stats.fouls += 1
            }
            map[event.playerID] = stats
        }
        return players.compactMap { map[$0.id] }.sorted { $0.points > $1.points }
    }
}

// MARK: - Derived player stats (never stored)

struct PlayerStats: Identifiable {
    let player: Player
    var points: Int = 0
    var twoPointers: Int = 0
    var threePointers: Int = 0
    var ftMade: Int = 0
    var ftAttempts: Int = 0
    var fouls: Int = 0

    var id: UUID { player.id }

    var freeThrowDisplay: String { "\(ftMade)/\(ftAttempts)" }
}
