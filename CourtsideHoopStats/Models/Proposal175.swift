import Foundation

#if DEBUG
/// **PROPOSAL SCAFFOLDING for issue #175 (shooting percentages).**
///
/// Not a feature. This exists so each candidate design can be *photographed*
/// at a real game's shot volume, which is the only way to judge the crowding
/// the issue is actually about. Everything here is DEBUG-only and driven by
/// launch arguments, so a normal build behaves exactly as before.
///
/// `-uiTestProposal175 A|B|C`
///   - **A** — misses are real `GameEvent`s (`.missedTwo` / `.missedThree`)
///     recorded from a restructured make/miss point pad. They appear in the
///     Score Log, are editable, carry a period.
///   - **B** — misses are a per-player *tally* on `Game`, recorded by arming a
///     miss mode over the player deck (one tap, no sheet). Never events, so the
///     Score Log is untouched.
///   - **C** — nothing is recorded live. Attempts are typed in once, after the
///     game, on a Shooting screen in the Game Summary.
///
/// `-uiTestProposal175Columns separate|combined`
///   How the stats table carries attempts: four columns (`2P 2PA 3P 3PA`) or
///   two combined ones (`2P` = `4/9`).
enum Proposal175 {
    enum Option: String { case a, b, c, d }
    /// How the stats table carries attempts.
    /// - `separate`: `2P 2PA 3P 3PA` — nine columns, every value narrow.
    /// - `combined`: `2P` = `4/9`, `3P` = `1/4` — seven columns, two of them
    ///   three times as wide.
    /// - `fg`: one `FG` column = `5/13` and a plain `3P` make count — seven
    ///   columns and only *one* wide one, because PTS already tells you the
    ///   makes.
    enum StatsColumns: String { case separate, combined, fg }

    /// Point-pad layout for Option A.
    /// - `columns`: made on the left, missed on the right.
    /// - `grouped`: the makes stay a 2x2 block and the misses sit below them,
    ///   away from `+2`, the way REB was separated in #174.
    enum PadLayout: String { case columns, grouped }

    private static func argument(after flag: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
        return args[i + 1].lowercased()
    }

    static let option: Option? = argument(after: "-uiTestProposal175")
        .flatMap(Option.init(rawValue:))

    static var isOn: Bool { option != nil }

    static let statsColumns: StatsColumns = argument(after: "-uiTestProposal175Columns")
        .flatMap(StatsColumns.init(rawValue:)) ?? .combined

    static let padLayout: PadLayout = argument(after: "-uiTestProposal175Pad")
        .flatMap(PadLayout.init(rawValue:)) ?? .columns

    /// Whether the stats table carries per-player attempts. Option D
    /// deliberately doesn't: it buys one team number, so the table is left
    /// exactly as it ships today.
    static var showsAttempts: Bool {
        option == .a || option == .b || option == .c
    }

    // MARK: - Realistic shot volume

    /// The demo win (48–41) re-scripted with missed field goals interleaved.
    ///
    /// Volume is the whole point. The shipped demo game is 26 scoring events
    /// plus 10 rebounds; this adds **33 misses** — 18 missed 2s and 15 missed
    /// 3s — for a 69-event game at 2P 10/28 (36%), 3P 7/22 (32%), FG 17/50
    /// (34%). Those are ordinary youth numbers, and they mean **misses
    /// outnumber makes** (33 vs 24 including free throws). Anything tamer
    /// flatters the design; the rebound demo shipped with 2 rebounds in it and
    /// hid the crowding entirely.
    ///
    /// Each tuple is (roster index, event, assisting roster index).
    private static let winScript: [[(Int, EventType, Int?)]] = [
        // Q1 — 12 points, 2 rebounds, 8 misses.
        [(8, .missedThree, nil), (3, .rebound, nil), (8, .threePoint, 2),
         (6, .missedTwo, nil), (2, .twoPoint, nil), (7, .missedTwo, nil),
         (8, .rebound, nil), (7, .twoPoint, nil), (2, .missedThree, nil),
         (4, .threePoint, nil), (3, .missedTwo, nil), (4, .missedThree, nil),
         (2, .ftMade, nil), (0, .missedTwo, nil), (1, .missedThree, nil),
         (0, .ftMade, nil)],
        // Q2 — 12 points, 3 rebounds, 8 misses.
        [(2, .missedThree, nil), (3, .rebound, nil), (8, .twoPoint, nil),
         (8, .missedThree, nil), (6, .rebound, nil), (2, .threePoint, 8),
         (6, .missedTwo, nil), (6, .twoPoint, nil), (8, .missedTwo, nil),
         (4, .missedThree, nil), (7, .rebound, nil), (3, .twoPoint, nil),
         (2, .missedTwo, nil), (3, .missedThree, nil), (1, .missedTwo, nil),
         (1, .threePoint, nil)],
        // Q3 — 11 points, 2 rebounds, 9 misses.
        [(8, .missedThree, nil), (8, .rebound, nil), (8, .threePoint, 7),
         (7, .missedTwo, nil), (7, .twoPoint, nil), (6, .missedTwo, nil),
         (3, .rebound, nil), (6, .twoPoint, nil), (8, .missedThree, nil),
         (5, .missedTwo, nil), (5, .twoPoint, nil), (2, .missedThree, nil),
         (2, .missedTwo, nil), (8, .ftMade, nil), (8, .ftMissed, nil),
         (4, .missedThree, nil), (3, .missedTwo, nil), (4, .ftMade, nil)],
        // Q4 — 13 points, 3 rebounds, 8 misses.
        [(8, .missedThree, nil), (3, .rebound, nil), (8, .threePoint, nil),
         (8, .ftMade, nil), (6, .missedTwo, nil), (2, .threePoint, nil),
         (7, .missedTwo, nil), (6, .rebound, nil), (7, .twoPoint, 6),
         (7, .ftMade, nil), (2, .missedTwo, nil), (6, .twoPoint, nil),
         (8, .missedTwo, nil), (1, .missedThree, nil), (0, .rebound, nil),
         (4, .missedTwo, nil), (4, .ftMade, nil), (7, .missedThree, nil),
         (5, .ftMissed, nil)],
    ]

    /// The in-progress demo game (partway through Q2) with misses interleaved
    /// at the same ratio — this is what the *live* Score Log looks like mid-game.
    private static let liveScript: [[(Int, EventType, Int?)]] = [
        // Q1 — 7 points, 6 rebounds, 7 misses.
        [(8, .missedThree, nil), (7, .rebound, nil), (8, .threePoint, nil),
         (3, .rebound, nil), (6, .missedTwo, nil), (2, .twoPoint, nil),
         (2, .missedThree, nil), (8, .rebound, nil), (8, .missedThree, nil),
         (6, .rebound, nil), (8, .twoPoint, nil), (3, .missedTwo, nil),
         (3, .rebound, nil), (0, .rebound, nil), (7, .missedTwo, nil),
         (4, .missedThree, nil)],
        // Q2 so far — 2 points, 3 rebounds, 4 misses.
        [(7, .rebound, nil), (2, .missedThree, nil), (6, .rebound, nil),
         (4, .twoPoint, nil), (6, .missedTwo, nil), (3, .rebound, nil),
         (8, .missedThree, nil), (7, .missedTwo, nil)],
    ]

    // MARK: - Applying it to the seeded demo

    /// Rewrites the two demo games that matter (the finished win and the live
    /// game) so they carry shot attempts, in whichever shape the option needs.
    static func apply(to games: [Game], roster: [Player]) -> [Game] {
        guard let option else { return games }
        return games.map { game in
            var updated = game
            switch game.opponent {
            case "Lakeside Lightning":
                updated.events = events(from: winScript, roster: roster, base: game.date)
            case "Northgate Falcons":
                updated.events = events(from: liveScript, roster: roster, base: game.date)
            default:
                return game
            }
            // B and C store the same attempts as counts instead of events, so
            // the numbers in every screenshot are identical and only the
            // *consequences* differ.
            if option == .b || option == .c { updated = tallied(updated) }
            // D keeps only the per-period team total: the same 50 attempts,
            // summarised. Q1 4/12, Q2 5/13, Q3 4/13, Q4 4/12 -> 17/50 (34%).
            if option == .d {
                updated = tallied(updated)
                updated.missedTwosTally = nil
                updated.missedThreesTally = nil
                updated.teamShotAttempts = teamAttempts(for: updated)
            }
            return updated
        }
    }

    private static func events(from script: [[(Int, EventType, Int?)]],
                               roster: [Player],
                               base: Date) -> [GameEvent] {
        var events: [GameEvent] = []
        for (periodIndex, period) in script.enumerated() {
            for (offset, entry) in period.enumerated() {
                let (index, type, assist) = entry
                guard index < roster.count else { continue }
                events.append(GameEvent(
                    playerID: roster[index].id,
                    type: type,
                    period: periodIndex + 1,
                    // Monotonic within the period: `EventLogView` sorts on it.
                    timestamp: base.addingTimeInterval(Double(periodIndex) * 3600
                                                       + Double(offset) * 30),
                    assistPlayerID: assist.flatMap { $0 < roster.count ? roster[$0].id : nil }
                ))
            }
        }
        return events
    }

    /// Moves every miss event into the per-player tally and drops it from the
    /// log — Option B's storage, and what Option C's post-game screen writes.
    /// Makes plus misses, per period, from the same script — so Option D's
    /// numbers agree with A's to the shot.
    private static func teamAttempts(for game: Game) -> [Int: Int] {
        var attempts: [Int: Int] = [:]
        let script = game.opponent == "Lakeside Lightning" ? winScript : liveScript
        for (index, period) in script.enumerated() {
            let count = period.filter { entry in
                [.twoPoint, .threePoint, .missedTwo, .missedThree].contains(entry.1)
            }.count
            attempts[index + 1] = count
        }
        return attempts
    }

    private static func tallied(_ game: Game) -> Game {
        var copy = game
        var twos: [UUID: Int] = [:]
        var threes: [UUID: Int] = [:]
        for event in game.events {
            switch event.type {
            case .missedTwo:   twos[event.playerID, default: 0] += 1
            case .missedThree: threes[event.playerID, default: 0] += 1
            default: break
            }
        }
        copy.events = game.events.filter {
            $0.type != .missedTwo && $0.type != .missedThree
        }
        copy.missedTwosTally = twos
        copy.missedThreesTally = threes
        return copy
    }
}
#endif
