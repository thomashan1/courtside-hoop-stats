import Foundation

#if DEBUG
/// Deterministic demo content for UI-test screenshots (App Store listing,
/// README, and merge-gate verification). Only compiled in Debug and only loaded
/// when the app is launched with the `-uiTestSeedDemo` argument — see
/// `AppStore.init()`. Never touches the user's real persisted data.
enum DemoData {
    /// A believable youth-basketball roster.
    static func makeTeam() -> Team {
        // Last-name initial only — real-ish roster kept privacy-safe for the
        // public repo / App Store screenshots. Ordered alphabetically (the demo
        // presents a Name-sorted roster); game scripts below index into THIS order.
        Team(
            name: "Swish Warriors",
            players: [
                Player(name: "Adrian Y.", number: "19"),   // 0
                Player(name: "Austin W.", number: "8"),     // 1
                Player(name: "Bradley C.", number: "1"),    // 2
                Player(name: "Brendon C.", number: "3"),    // 3
                Player(name: "Jake L.", number: "7"),       // 4
                Player(name: "Kaleb K.", number: "24"),     // 5
                Player(name: "Lucas Z.", number: "30"),     // 6
                Player(name: "Mason C.", number: "5"),      // 7
                Player(name: "Nicholas H.", number: "77"),  // 8
                Player(name: "Wesley C.", number: "88"),    // 9
            ],
            homeJersey: .blue
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

    /// A fixed reference date so screenshots are reproducible — kept in the
    /// **current season**, since game rows drop the year in-season and a stale
    /// date would visibly age the App Store listing. Roll it forward when it
    /// falls behind the calendar year.
    ///
    /// Built from calendar components rather than an epoch constant so it lands
    /// at a plausible **10:00 AM tip-off in whatever timezone the screenshots
    /// are captured in**. The previous raw timestamp rendered as *"4:40 AM"* on
    /// every row — a detail nobody notices in one row and nobody misses in six.
    private static let refDate: Date = {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 8
        components.hour = 10
        components.minute = 0
        return Calendar.current.date(from: components)
            ?? Date(timeIntervalSince1970: 1_783_510_800)
    }()

    /// `refDate` shifted by whole days and hours, so each game gets its own
    /// believable tip-off time instead of all six sharing one.
    private static func gameDate(daysFromRef days: Int, hour: Double = 0) -> Date {
        refDate.addingTimeInterval(Double(days) * 86_400 + hour * 3_600)
    }

    // MARK: - Sharing (screenshots only)

    /// The demo team is presented as **shared with two people**, so the owner-side
    /// sharing markers (#93) actually appear in screenshots: the "Shared with 2
    /// followers" subtitle on Games, the followers button, and the "Shared" tag
    /// in Settings ▸ Teams. Without this the seed looks unshared and none of
    /// that UI is reachable.
    static func makeParticipants() -> [SharedParticipant] {
        [
            SharedParticipant(id: "demo-owner", name: "You", contact: "",
                              isOwner: true, hasAccepted: true),
            SharedParticipant(id: "demo-1", name: "Grandma Chen",
                              contact: "gchen@example.com",
                              isOwner: false, hasAccepted: true),
            SharedParticipant(id: "demo-2", name: "Coach Ramirez",
                              contact: "coach.ramirez@example.com",
                              isOwner: false, hasAccepted: false),
        ]
    }

    // MARK: - Random test game (easter egg: long-press "+" on the Games list)

    private static let opponents = [
        "Lakeside Lightning", "Northgate Falcons", "Summit Storm", "Valley Vipers",
        "Harbor Sharks", "Central Cyclones", "Pine Ridge Panthers", "Bayview Bobcats",
    ]
    private static let gyms = [
        "Riverside Community Gym", "Northgate High", "Summit Rec Center",
        "Central Arena", "Valley Fieldhouse", "Bayview Middle School",
    ]

    /// A finished game for `team` with random-but-realistic quarter-by-quarter
    /// scoring, for exercising the UI. DEBUG only.
    static func randomGame(team: Team) -> Game {
        let players = team.players.isEmpty
            ? [Player(name: "Test Player", number: "0")] : team.players
        var events: [GameEvent] = []
        var periodEnds: [Int: PeriodEndScore] = [:]
        var ourTotal = 0
        var oppTotal = 0
        let base = Date()

        for quarter in 1...4 {
            // A handful of our scoring plays per quarter.
            for _ in 0..<Int.random(in: 3...7) {
                let player = players.randomElement()!
                // Weight toward 2-pointers, with some 3s and free throws.
                let type = [EventType.twoPoint, .twoPoint, .twoPoint,
                            .threePoint, .ftMade, .ftMissed].randomElement()!
                events.append(GameEvent(playerID: player.id, type: type, period: quarter,
                                        timestamp: base.addingTimeInterval(Double(events.count))))
                ourTotal += type.points
            }
            oppTotal += Int.random(in: 6...15)
            periodEnds[quarter] = PeriodEndScore(ourRunningTotal: ourTotal,
                                                 opponentRunningTotal: oppTotal)
        }

        var game = Game(opponent: opponents.randomElement()!)
        game.teamID = team.id
        game.date = Date().addingTimeInterval(-Double(Int.random(in: 0...21)) * 86_400)
        game.league = "Metro Youth League"
        game.location = gyms.randomElement()!
        game.isHome = Bool.random()
        game.periodFormat = .quarters
        game.events = events
        game.periodEndScores = periodEnds
        game.isComplete = true
        game.hasStarted = true
        return game
    }

    /// Games list: every state the list can show, so a screenshot exercises the
    /// real range rather than one happy path.
    ///
    /// Covers all three sections (Playing Now / Coming Up / Final Scores), all
    /// three results (**win, loss, tie** — so each result badge appears), and
    /// all three period formats (**quarters, halves, pickup**). Deliberately
    /// stops at four finished games: a fifth pushes the Final Scores section
    /// past the bottom of the Games-list screenshot, which is the one place the
    /// variety is meant to be visible.
    static func makeGames(team: Team) -> [Game] {
        [finishedGame(team: team),
         lostGame(team: team),
         tiedHalvesGame(team: team),
         pickupGame(team: team),
         inProgressGame(team: team),
         scheduledGame()]
    }

    /// A team shared *with* the demo user, for the Following tab (#57).
    ///
    /// Uses the **same Swish Warriors roster** as every other screenshot, so the
    /// demo reads as one consistent team across the whole app — and, like the
    /// owner-side games, leans on **Nicholas (#77) hitting threes** as the
    /// standout. The narrative works: this is a grandparent following the team
    /// Jean is tracking.
    ///
    /// Carries its own game scripts rather than reusing `finishedGame` /
    /// `inProgressGame` so the two sides of the app don't show identical games.
    static func makeFollowedTeam() -> FollowedTeam {
        let team = makeTeam()
        let p = team.players   // index 8 = Nicholas H. (#77)

        // Live, partway through Q3. Quarter sums: 10, 9, then 7 so far = 26.
        var liveEvents: [GameEvent] = []
        for (index, type, period): (Int, EventType, Int) in [
            // Q1 = 10 — Nicholas opens with back-to-back threes.
            (8, .threePoint, 1), (8, .threePoint, 1), (2, .twoPoint, 1), (7, .twoPoint, 1),
            // Q2 = 9
            (8, .threePoint, 2), (4, .twoPoint, 2), (8, .ftMade, 2), (1, .threePoint, 2),
            // Q3 so far = 7
            (8, .threePoint, 3), (6, .twoPoint, 3), (8, .twoPoint, 3),
        ] {
            liveEvents.append(GameEvent(playerID: p[index].id, type: type, period: period))
        }
        let live = Game(
            date: gameDate(daysFromRef: 7, hour: 1),      // 11:00 AM
            opponent: "Harbor Sharks",
            league: "Metro Youth League",
            location: "Bayview Middle School",
            isHome: false,
            periodFormat: .quarters,
            events: liveEvents,
            periodEndScores: [1: PeriodEndScore(ourRunningTotal: 10, opponentRunningTotal: 8),
                              2: PeriodEndScore(ourRunningTotal: 19, opponentRunningTotal: 17)],
            isComplete: false,
            hasStarted: true
        )

        // The week before: a 28–24 win, Nicholas with five threes for 18.
        var pastEvents: [GameEvent] = []
        for (index, type, period): (Int, EventType, Int) in [
            // Q1 = 8
            (8, .threePoint, 1), (8, .threePoint, 1), (2, .twoPoint, 1),
            // Q2 = 7
            (8, .threePoint, 2), (4, .twoPoint, 2), (1, .twoPoint, 2),
            // Q3 = 6
            (8, .threePoint, 3), (8, .ftMade, 3), (7, .twoPoint, 3),
            // Q4 = 7
            (8, .threePoint, 4), (6, .twoPoint, 4), (8, .ftMade, 4), (8, .ftMade, 4),
        ] {
            pastEvents.append(GameEvent(playerID: p[index].id, type: type, period: period))
        }
        let past = Game(
            date: refDate,
            opponent: "Valley Vipers",
            league: "Metro Youth League",
            location: "Valley Fieldhouse",
            isHome: true,
            periodFormat: .quarters,
            events: pastEvents,
            periodEndScores: [1: PeriodEndScore(ourRunningTotal: 8, opponentRunningTotal: 6),
                              2: PeriodEndScore(ourRunningTotal: 15, opponentRunningTotal: 13),
                              3: PeriodEndScore(ourRunningTotal: 21, opponentRunningTotal: 19),
                              4: PeriodEndScore(ourRunningTotal: 28, opponentRunningTotal: 24)],
            isComplete: true,
            hasStarted: true
        )

        // And one they lost, 22–27 — a follower's history shouldn't be all wins
        // any more than the owner's is.
        var lossEvents: [GameEvent] = []
        for (index, type, period): (Int, EventType, Int) in [
            // Q1 = 6
            (8, .threePoint, 1), (8, .threePoint, 1),
            // Q2 = 5
            (8, .threePoint, 2), (2, .twoPoint, 2),
            // Q3 = 6
            (8, .threePoint, 3), (4, .twoPoint, 3), (8, .ftMade, 3),
            // Q4 = 5
            (8, .threePoint, 4), (7, .twoPoint, 4),
        ] {
            lossEvents.append(GameEvent(playerID: p[index].id, type: type, period: period))
        }
        let loss = Game(
            date: gameDate(daysFromRef: -6, hour: 2),     // noon
            opponent: "Central Cyclones",
            league: "Metro Youth League",
            location: "Central Arena",
            isHome: false,
            periodFormat: .quarters,
            events: lossEvents,
            periodEndScores: [1: PeriodEndScore(ourRunningTotal: 6, opponentRunningTotal: 9),
                              2: PeriodEndScore(ourRunningTotal: 11, opponentRunningTotal: 15),
                              3: PeriodEndScore(ourRunningTotal: 17, opponentRunningTotal: 21),
                              4: PeriodEndScore(ourRunningTotal: 22, opponentRunningTotal: 27)],
            isComplete: true,
            hasStarted: true
        )

        return FollowedTeam(
            team: team,
            games: [live, past, loss],
            zoneName: "team-demo",
            ownerName: "_demoOwner_",
            sharedByName: "Jean",
            updatedAt: Date().addingTimeInterval(-12)
        )
    }

    /// A second followed team (#120) — a different tracker's team, so the
    /// switcher menu and "Shared by" line have more than one case to show.
    /// Reuses `makeSecondTeam()`'s roster; carries just one finished game,
    /// since this one exists to exercise "following more than one team," not
    /// to add more game-state coverage (`makeFollowedTeam()` already does).
    static func makeSecondFollowedTeam() -> FollowedTeam {
        let team = makeSecondTeam()
        let p = team.players

        var events: [GameEvent] = []
        for (index, type, period): (Int, EventType, Int) in [
            (0, .threePoint, 1), (1, .twoPoint, 1),
            (2, .twoPoint, 2), (0, .threePoint, 2),
            (3, .twoPoint, 3), (1, .ftMade, 3),
            (0, .threePoint, 4), (2, .twoPoint, 4),
        ] {
            events.append(GameEvent(playerID: p[index].id, type: type, period: period))
        }
        let game = Game(
            date: gameDate(daysFromRef: 6, hour: 3),
            opponent: "Northgate Falcons",
            league: "Metro Youth League",
            location: "Northgate High",
            isHome: true,
            periodFormat: .quarters,
            events: events,
            periodEndScores: [1: PeriodEndScore(ourRunningTotal: 5, opponentRunningTotal: 4),
                              2: PeriodEndScore(ourRunningTotal: 10, opponentRunningTotal: 9),
                              3: PeriodEndScore(ourRunningTotal: 15, opponentRunningTotal: 13),
                              4: PeriodEndScore(ourRunningTotal: 20, opponentRunningTotal: 17)],
            isComplete: true,
            hasStarted: true
        )

        return FollowedTeam(
            team: team,
            games: [game],
            zoneName: "team-demo-2",
            ownerName: "_demoOwner2_",
            sharedByName: "Mike",
            updatedAt: Date().addingTimeInterval(-600)
        )
    }

    // MARK: - Finished game (48–41 win) with a full four-quarter breakdown.

    private static func finishedGame(team: Team) -> Game {
        let p = team.players
        var events: [GameEvent] = []
        // (playerIndex, type, period). Nicholas (#77, index 8) is the standout —
        // six made 3s and a game-high 27. Our per-quarter deltas: 12, 12, 11, 13 = 48.
        let script: [(Int, EventType, Int)] = [
            // Q1 = 12
            (8, .threePoint, 1), (8, .threePoint, 1), (2, .twoPoint, 1),
            (7, .twoPoint, 1), (8, .ftMade, 1), (0, .ftMade, 1),
            // Q2 = 12
            (8, .threePoint, 2), (3, .twoPoint, 2), (4, .twoPoint, 2),
            (8, .twoPoint, 2), (1, .threePoint, 2),
            // Q3 = 11
            (8, .threePoint, 3), (7, .twoPoint, 3), (8, .twoPoint, 3),
            (6, .twoPoint, 3), (8, .ftMade, 3), (8, .ftMissed, 3), (2, .ftMade, 3),
            // Q4 = 13
            (8, .threePoint, 4), (8, .threePoint, 4), (5, .twoPoint, 4),
            (6, .twoPoint, 4), (8, .ftMade, 4), (8, .ftMade, 4), (8, .ftMade, 4),
            (4, .ftMissed, 4),
        ]
        for (idx, type, period) in script {
            events.append(GameEvent(playerID: p[idx].id, type: type, period: period,
                                    timestamp: refDate.addingTimeInterval(Double(period) * 600)))
        }
        // Opponent running totals per quarter: 8, 19, 30, 41 (final 41 < our 48).
        let periodEnds: [Int: PeriodEndScore] = [
            1: PeriodEndScore(ourRunningTotal: 12, opponentRunningTotal: 8),
            2: PeriodEndScore(ourRunningTotal: 24, opponentRunningTotal: 19),
            3: PeriodEndScore(ourRunningTotal: 35, opponentRunningTotal: 30),
            4: PeriodEndScore(ourRunningTotal: 48, opponentRunningTotal: 41),
        ]
        // Wesley (index 9) missed this game. He has no events, so benching him
        // costs no points — and it makes the demo realistic: a real roster
        // usually has an absentee. It's also what puts a **DNP** row in the
        // box-score PDF and the README screenshot (#55).
        return Game(
            date: refDate,
            opponent: "Lakeside Lightning",
            league: "Metro Youth League",
            location: "Riverside Community Gym",
            locationAddress: "455 Riverside Dr, Springfield",
            isHome: true,
            periodFormat: .quarters,
            events: events,
            periodEndScores: periodEnds,
            notes: "Great defensive third quarter. Watch #8 on the press next time.",
            benchedPlayerIDs: [p[9].id],
            isComplete: true,
            hasStarted: true
        )
    }

    // MARK: - Loss (38–44), so the LOSS / "L" badge appears somewhere.

    private static func lostGame(team: Team) -> Game {
        let p = team.players
        // Our per-quarter deltas: 9, 11, 8, 10 = 38. Nicholas still leads with
        // 19 — losing the game is the point, not losing the player narrative.
        let script: [(Int, EventType, Int)] = [
            // Q1 = 9
            (8, .threePoint, 1), (2, .twoPoint, 1), (7, .twoPoint, 1),
            (8, .ftMade, 1), (8, .ftMade, 1), (3, .ftMissed, 1),
            // Q2 = 11
            (8, .threePoint, 2), (4, .twoPoint, 2), (6, .twoPoint, 2),
            (1, .twoPoint, 2), (8, .ftMade, 2), (0, .ftMade, 2),
            // Q3 = 8
            (8, .threePoint, 3), (3, .twoPoint, 3), (7, .twoPoint, 3),
            (8, .ftMade, 3), (8, .ftMissed, 3),
            // Q4 = 10
            (8, .threePoint, 4), (8, .threePoint, 4), (5, .twoPoint, 4), (2, .twoPoint, 4),
        ]
        return Game(
            date: gameDate(daysFromRef: -3, hour: 3),     // 1:00 PM
            opponent: "Central Cyclones",
            league: "Metro Youth League",
            location: "Central Arena",
            isHome: false,
            periodFormat: .quarters,
            events: events(from: script, roster: p),
            // Opponent running totals: 12, 22, 34, 44 (final 44 > our 38).
            periodEndScores: [
                1: PeriodEndScore(ourRunningTotal: 9, opponentRunningTotal: 12),
                2: PeriodEndScore(ourRunningTotal: 20, opponentRunningTotal: 22),
                3: PeriodEndScore(ourRunningTotal: 28, opponentRunningTotal: 34),
                4: PeriodEndScore(ourRunningTotal: 38, opponentRunningTotal: 44),
            ],
            notes: "Cold from the line in the third. Rebounding cost us this one.",
            isComplete: true,
            hasStarted: true
        )
    }

    // MARK: - Tie (30–30) played in halves — covers the TIE badge *and* the
    // two-period linescore in one game.

    private static func tiedHalvesGame(team: Team) -> Game {
        let p = team.players
        // H1 = 16, H2 = 14 → 30.
        //
        // Spread deliberately uneven: a couple of players with two baskets, a
        // couple with none. Giving everyone exactly one bucket balances neatly
        // but produces a box score of identical "2 / 1 / 0 / 0-0" rows, which
        // reads as generated data rather than a game.
        let script: [(Int, EventType, Int)] = [
            // H1 = 16
            (8, .threePoint, 1), (8, .threePoint, 1), (2, .twoPoint, 1),
            (4, .twoPoint, 1), (4, .twoPoint, 1), (7, .twoPoint, 1),
            (8, .ftMade, 1), (8, .ftMade, 1),
            // H2 = 14
            (8, .threePoint, 2), (2, .twoPoint, 2), (6, .twoPoint, 2), (6, .twoPoint, 2),
            (5, .twoPoint, 2), (8, .ftMade, 2), (8, .ftMissed, 2), (8, .ftMade, 2),
            (2, .ftMade, 2),
        ]
        return Game(
            date: gameDate(daysFromRef: -7, hour: -1),    // 9:00 AM
            opponent: "Pine Ridge Panthers",
            league: "Metro Youth League",
            location: "Valley Fieldhouse",
            isHome: true,
            periodFormat: .halves,
            events: events(from: script, roster: p),
            periodEndScores: [
                1: PeriodEndScore(ourRunningTotal: 16, opponentRunningTotal: 15),
                2: PeriodEndScore(ourRunningTotal: 30, opponentRunningTotal: 30),
            ],
            isComplete: true,
            hasStarted: true
        )
    }

    // MARK: - Pickup game (one running period, #35) — no quarter breaks, and
    // the linescore collapses to a single row.

    private static func pickupGame(team: Team) -> Game {
        let p = team.players
        // One period, 24 points. No league or location: pickup games are the
        // case where every optional field really is left blank.
        let script: [(Int, EventType, Int)] = [
            (8, .threePoint, 1), (8, .threePoint, 1), (8, .threePoint, 1),
            (2, .twoPoint, 1), (4, .twoPoint, 1), (7, .twoPoint, 1),
            (6, .twoPoint, 1), (5, .twoPoint, 1), (1, .twoPoint, 1),
            (8, .ftMade, 1), (8, .ftMade, 1), (0, .ftMade, 1), (3, .ftMissed, 1),
        ]
        return Game(
            date: gameDate(daysFromRef: -10, hour: 8),    // 6:00 PM pickup
            opponent: "Bayview Bobcats",
            isHome: false,
            periodFormat: .pickup,
            events: events(from: script, roster: p),
            periodEndScores: [1: PeriodEndScore(ourRunningTotal: 24, opponentRunningTotal: 19)],
            isComplete: true,
            hasStarted: true
        )
    }

    /// Shared script→events expansion. The timestamp only has to be monotonic
    /// within a game for the Score Log to read in order.
    private static func events(from script: [(Int, EventType, Int)],
                               roster: [Player]) -> [GameEvent] {
        script.enumerated().map { offset, entry in
            let (index, type, period) = entry
            return GameEvent(playerID: roster[index].id, type: type, period: period,
                             timestamp: refDate.addingTimeInterval(Double(offset) * 60))
        }
    }

    // MARK: - In-progress game (partway through Q2).

    private static func inProgressGame(team: Team) -> Game {
        let p = team.players
        // Nicholas (index 8) opens with a 3; running total 7 at the Q1 break.
        let events: [GameEvent] = [
            GameEvent(playerID: p[8].id, type: .threePoint, period: 1),
            GameEvent(playerID: p[2].id, type: .twoPoint, period: 1),
            GameEvent(playerID: p[8].id, type: .twoPoint, period: 1),
            GameEvent(playerID: p[4].id, type: .twoPoint, period: 2),
        ]
        return Game(
            date: gameDate(daysFromRef: 7, hour: 1),      // 11:00 AM
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
            date: gameDate(daysFromRef: 10, hour: 2.5),   // 12:30 PM
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
