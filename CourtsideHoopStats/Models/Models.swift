import Foundation

// MARK: - Team & Player

/// Which jersey the team wears. Optional on `Team` for backward compatibility;
/// falls back to a home-white / away-blue convention.
enum JerseyColor: String, Codable, CaseIterable, Identifiable {
    case white, blue

    var id: String { rawValue }
    var label: String {
        switch self {
        case .white: return "White"
        case .blue:  return "Blue"
        }
    }

    /// The team's other jersey — the two are worn opposite at home vs away.
    var opposite: JerseyColor { self == .white ? .blue : .white }
}

struct Team: Identifiable, Codable {
    /// Stable identity so games and the active-team selection can reference it.
    /// Optional-decoded for backward compatibility: team JSON saved before
    /// multi-team support has no id and gets a fresh one on load.
    var id: UUID = UUID()
    var name: String
    var players: [Player]
    /// The jersey worn at home; away games use its opposite. Optional for
    /// backward compatibility (defaults to white — see `jersey(isHome:)`).
    var homeJersey: JerseyColor? = nil

    static let empty = Team(name: "My Team", players: [])

    /// The jersey to wear for a game: the home jersey at home, its opposite away.
    func jersey(isHome: Bool) -> JerseyColor {
        let home = homeJersey ?? .white
        return isHome ? home : home.opposite
    }
}

struct Player: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var number: String          // jersey number, stored as String (handles "0", "00")

    /// First name only, e.g. "Ava M." -> "Ava".
    var firstName: String {
        String(name.split(separator: " ").first ?? "")
    }
}

// MARK: - Events

enum EventType: String, Codable, CaseIterable {
    case twoPoint               // +2
    case threePoint             // +3
    case ftMade                 // +1
    case ftMissed               // +0, counts as FT attempt
    case foul                   // +0 — retained for decoding old games; not tracked in the UI

    /// Event types users can record/choose. `foul` is intentionally excluded
    /// (kept only so previously-saved foul events still decode).
    static let selectable: [EventType] = [.twoPoint, .threePoint, .ftMade, .ftMissed]

    var points: Int {
        switch self {
        case .twoPoint:   return 2
        case .threePoint: return 3
        case .ftMade:     return 1
        case .ftMissed:   return 0
        case .foul:       return 0
        }
    }

    /// Descriptive label used in the event editor.
    var logLabel: String {
        switch self {
        case .twoPoint:   return "2-Point"
        case .threePoint: return "3-Point"
        case .ftMade:     return "Free Throw"
        case .ftMissed:   return "FT Miss"
        case .foul:       return "Foul"
        }
    }

    /// Single concise label for a Score Log row (combines action + points).
    var scoreLogLabel: String {
        switch self {
        case .twoPoint:   return "+2 points"
        case .threePoint: return "+3 points"
        case .ftMade:     return "FT +1 point"
        case .ftMissed:   return "FT miss"
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

/// One row in the reorderable score log (#9): a scoring event, or a period-end
/// boundary marker that ends the given period. Both are draggable; an event's
/// period is derived from how many markers precede it (see
/// `Game.applyingReorderedLog(_:)`).
enum ScoreLogItem: Identifiable, Hashable {
    case event(GameEvent)
    case periodEnd(period: Int)

    var id: String {
        switch self {
        case .event(let event):   return "e-\(event.id.uuidString)"
        case .periodEnd(let period): return "m-\(period)"
        }
    }

    static func == (lhs: ScoreLogItem, rhs: ScoreLogItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Period format

enum PeriodFormat: String, Codable, CaseIterable {
    case quarters   // 4 periods, label "Q"
    case halves     // 2 periods, label "H"
    case pickup     // 1 running period, no breaks (casual games, #35)

    var periodCount: Int {
        switch self {
        case .quarters: return 4
        case .halves:   return 2
        case .pickup:   return 1
        }
    }

    var label: String {
        switch self {
        case .quarters: return "Q"
        case .halves:   return "H"
        case .pickup:   return ""
        }
    }

    var displayName: String {
        switch self {
        case .quarters: return "4 Quarters"
        case .halves:   return "2 Halves"
        case .pickup:   return "Pickup (no periods)"
        }
    }

    /// Human label for a specific period, e.g. "Q1" or "H2"; "Game" for pickup.
    func periodLabel(_ period: Int) -> String {
        self == .pickup ? "Game" : "\(label)\(period)"
    }
}

// MARK: - Scores

struct PeriodEndScore: Codable {
    var ourRunningTotal: Int        // cumulative (not delta)
    var opponentRunningTotal: Int   // cumulative (not delta)
}

// MARK: - Game

struct Game: Identifiable, Codable {
    var id: UUID = UUID()
    /// Which team played this game. Optional for backward compatibility: games
    /// saved before multi-team support decode as `nil` and are stamped with the
    /// migrated team's id on load (#20).
    var teamID: UUID? = nil
    var date: Date = Date()
    var opponent: String
    var league: String = ""
    var location: String = ""
    /// The street address of the picked location (from MapKit), kept as a
    /// smaller-font FYI under the location. Empty for manually-typed gyms.
    var locationAddress: String = ""
    var isHome: Bool = true
    var periodFormat: PeriodFormat = .quarters
    var events: [GameEvent] = []
    var periodEndScores: [Int: PeriodEndScore] = [:]   // key = period number
    var notes: String = ""
    /// Roster players sat out of this game (not at the game). Hidden from the
    /// live-scoring grid to save space; their existing events are untouched.
    var benchedPlayerIDs: [UUID] = []
    var isComplete: Bool = false
    /// Whether scoring has begun. Optional for backward compatibility: games
    /// saved before scheduling existed decode as `nil` and are treated as
    /// started (see `isStarted`). New games set this explicitly (Save = false,
    /// Start = true).
    var hasStarted: Bool? = false

    // MARK: Derived (never stored)

    /// A game predating the scheduling feature (nil) counts as already started.
    var isStarted: Bool { hasStarted ?? true }

    enum Lifecycle { case scheduled, inProgress, complete }

    /// Which stage the game is in, driving list routing and badges.
    var lifecycle: Lifecycle {
        if isComplete { return .complete }
        return isStarted ? .inProgress : .scheduled
    }

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

    /// Cumulative score at the **end of each period** — a running linescore
    /// (Q1 total, Q2 total, …), where the last row equals the final score. Our
    /// side is derived from events; the opponent side is the recorded running
    /// total (already cumulative).
    func periodBreakdownCumulative() -> [(period: Int, our: Int, opponent: Int)] {
        var rows: [(Int, Int, Int)] = []
        var ourTotal = 0
        for period in 1...periodFormat.periodCount {
            guard let score = periodEndScores[period] else { break }
            ourTotal += events
                .filter { $0.period == period }
                .reduce(0) { $0 + $1.type.points }
            rows.append((period, ourTotal, score.opponentRunningTotal))
        }
        return rows
    }

    // MARK: - Reorderable score log (#9)

    /// The score log as one ordered, chronological sequence (oldest first) of
    /// scoring events and period-end boundary markers. Events keep their array
    /// order; a marker for period `p` is placed right after that period's events
    /// once the period has been ended (has a `periodEndScores` entry).
    func orderedLog() -> [ScoreLogItem] {
        let maxPeriod = max(periodEndScores.keys.max() ?? 0,
                            events.map(\.period).max() ?? 0)
        guard maxPeriod > 0 else { return events.map { .event($0) } }
        var items: [ScoreLogItem] = []
        for p in 1...maxPeriod {
            for event in events where event.period == p { items.append(.event(event)) }
            if periodEndScores[p] != nil { items.append(.periodEnd(period: p)) }
        }
        return items
    }

    /// Rebuild the game from a reordered score log (#9). Each event's period is
    /// **derived** from how many period-end markers precede it, so dragging an
    /// event or a period boundary reassigns periods across quarters/halves.
    /// Opponent running totals ride with their marker; our running totals are
    /// recomputed from the new event order. Periods are clamped to the format's
    /// period count so a stray drag can't invent an extra period.
    func applyingReorderedLog(_ items: [ScoreLogItem]) -> Game {
        var copy = self
        let cap = periodFormat.periodCount
        var newEvents: [GameEvent] = []
        var newScores: [Int: PeriodEndScore] = [:]
        var currentPeriod = 1
        var ourRunning = 0
        var markerCount = 0

        for item in items {
            switch item {
            case .event(let event):
                var moved = event
                moved.period = min(currentPeriod, cap)
                ourRunning += moved.type.points
                newEvents.append(moved)
            case .periodEnd(let oldPeriod):
                guard markerCount < cap else { break }   // can't exceed the format
                markerCount += 1
                let opponent = periodEndScores[oldPeriod]?.opponentRunningTotal
                    ?? newScores[markerCount - 1]?.opponentRunningTotal ?? 0
                newScores[markerCount] = PeriodEndScore(ourRunningTotal: ourRunning,
                                                        opponentRunningTotal: opponent)
                currentPeriod = min(currentPeriod + 1, cap)
            }
        }
        copy.events = newEvents
        copy.periodEndScores = newScores
        return copy
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

    /// Made/attempts, with a whole-percent FT% when there's at least one
    /// attempt (e.g. "5/6 (83%)"). No percentage for 0 attempts — just "0/0".
    var freeThrowDisplay: String {
        guard ftAttempts > 0 else { return "\(ftMade)/\(ftAttempts)" }
        let percent = Int((Double(ftMade) / Double(ftAttempts) * 100).rounded())
        return "\(ftMade)/\(ftAttempts) (\(percent)%)"
    }
}
