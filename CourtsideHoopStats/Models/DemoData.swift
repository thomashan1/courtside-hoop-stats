import Foundation

#if DEBUG
/// Deterministic demo content for UI-test screenshots (App Store listing,
/// README, and merge-gate verification). Only compiled in Debug and only loaded
/// when the app is launched with the `-uiTestSeedDemo` argument — see
/// `AppStore.init()`. Never touches the user's real persisted data.
enum DemoData {
    /// A believable youth-basketball roster.
    static func makeTeam() -> Team {
        Team(
            name: "Riverside Hawks",
            players: [
                Player(name: "Ava Chen", number: "4"),
                Player(name: "Maya Patel", number: "7"),
                Player(name: "Zoe Williams", number: "10"),
                Player(name: "Sofia Garcia", number: "12"),
                Player(name: "Lily Nguyen", number: "15"),
                Player(name: "Emma Johnson", number: "21"),
                Player(name: "Chloe Kim", number: "23"),
                Player(name: "Grace Lee", number: "34"),
            ],
            homeJersey: .white
        )
    }

    /// A second team, so multi-team UI (Settings, the Roster switcher) has
    /// something to show in screenshots (#20).
    static func makeSecondTeam() -> Team {
        Team(
            name: "Eastside Eagles",
            players: [
                Player(name: "Nora Diaz", number: "3"),
                Player(name: "Priya Shah", number: "8"),
                Player(name: "Ruby Tan", number: "11"),
                Player(name: "Isla Moore", number: "24"),
            ],
            homeJersey: .blue
        )
    }

    /// A fixed reference date so screenshots are reproducible.
    private static let refDate = Date(timeIntervalSince1970: 1_752_000_000) // 2025-07-08

    /// Games list: one finished game (rich stats, the #8 edit target), one game
    /// in progress, and one scheduled.
    static func makeGames(team: Team) -> [Game] {
        [finishedGame(team: team),
         inProgressGame(team: team),
         scheduledGame()]
    }

    // MARK: - Finished game (45–41 win) with a full four-quarter breakdown.

    private static func finishedGame(team: Team) -> Game {
        let p = team.players
        var events: [GameEvent] = []
        // (playerIndex, type, period) — our per-quarter deltas: 10, 12, 11, 12 = 45.
        let script: [(Int, EventType, Int)] = [
            // Q1 = 10
            (0, .twoPoint, 1), (2, .threePoint, 1), (1, .twoPoint, 1),
            (3, .twoPoint, 1), (0, .ftMade, 1),
            // Q2 = 12
            (2, .twoPoint, 2), (4, .threePoint, 2), (0, .twoPoint, 2),
            (1, .ftMade, 2), (1, .ftMissed, 2), (5, .twoPoint, 2), (2, .ftMade, 2),
            // Q3 = 11
            (0, .threePoint, 3), (6, .twoPoint, 3), (2, .twoPoint, 3),
            (3, .twoPoint, 3), (0, .ftMade, 3), (4, .ftMissed, 3),
            // Q4 = 12
            (1, .threePoint, 4), (0, .twoPoint, 4), (2, .twoPoint, 4),
            (7, .twoPoint, 4), (5, .ftMade, 4), (5, .ftMade, 4), (6, .ftMissed, 4),
        ]
        for (idx, type, period) in script {
            events.append(GameEvent(playerID: p[idx].id, type: type, period: period,
                                    timestamp: refDate.addingTimeInterval(Double(period) * 600)))
        }
        // Opponent running totals per quarter: 8, 19, 30, 41 (final 41 < our 45).
        let periodEnds: [Int: PeriodEndScore] = [
            1: PeriodEndScore(ourRunningTotal: 10, opponentRunningTotal: 8),
            2: PeriodEndScore(ourRunningTotal: 22, opponentRunningTotal: 19),
            3: PeriodEndScore(ourRunningTotal: 33, opponentRunningTotal: 30),
            4: PeriodEndScore(ourRunningTotal: 45, opponentRunningTotal: 41),
        ]
        return Game(
            date: refDate,
            opponent: "Lakeside Lightning",
            league: "Metro Youth League",
            location: "Riverside Community Gym",
            isHome: true,
            periodFormat: .quarters,
            events: events,
            periodEndScores: periodEnds,
            notes: "Great defensive third quarter. Watch #12 on the press next time.",
            isComplete: true,
            hasStarted: true
        )
    }

    // MARK: - In-progress game (partway through Q2).

    private static func inProgressGame(team: Team) -> Game {
        let p = team.players
        let events: [GameEvent] = [
            GameEvent(playerID: p[0].id, type: .twoPoint, period: 1),
            GameEvent(playerID: p[2].id, type: .threePoint, period: 1),
            GameEvent(playerID: p[1].id, type: .twoPoint, period: 1),
            GameEvent(playerID: p[3].id, type: .twoPoint, period: 2),
        ]
        return Game(
            date: refDate.addingTimeInterval(7 * 86_400),
            opponent: "Northgate Falcons",
            league: "Metro Youth League",
            location: "Northgate High",
            isHome: false,
            periodFormat: .quarters,
            events: events,
            periodEndScores: [1: PeriodEndScore(ourRunningTotal: 7, opponentRunningTotal: 9)],
            isComplete: false,
            hasStarted: true
        )
    }

    // MARK: - Scheduled game (not started).

    private static func scheduledGame() -> Game {
        Game(
            date: refDate.addingTimeInterval(10 * 86_400),
            opponent: "Summit Storm",
            league: "Metro Youth League",
            location: "Summit Rec Center",
            isHome: true,
            periodFormat: .quarters,
            isComplete: false,
            hasStarted: false
        )
    }
}
#endif
