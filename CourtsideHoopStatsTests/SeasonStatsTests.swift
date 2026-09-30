import Testing
import Foundation
@testable import CourtsideHoopStats

/// Season averages across games (#211).
struct SeasonStatsTests {

    private func roster() -> [Player] {
        [Player(name: "Nicholas H.", number: "77"),
         Player(name: "Bradley C.", number: "1"),
         Player(name: "Wesley C.", number: "88")]
    }

    /// Two finished games, one still in progress.
    private func games(_ roster: [Player]) -> [Game] {
        let nick = roster[0].id, brad = roster[1].id, wes = roster[2].id

        var first = Game(opponent: "Lakeside")
        first.events = [
            GameEvent(playerID: nick, type: .threePoint, period: 1),
            GameEvent(playerID: nick, type: .twoPoint, period: 1),
            GameEvent(playerID: brad, type: .twoPoint, period: 1),
            GameEvent(playerID: nick, type: .ftMade, period: 2),
            GameEvent(playerID: nick, type: .ftMissed, period: 2),
        ]
        first.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 7, opponentRunningTotal: 4)]
        first.isComplete = true
        // Wesley wasn't there.
        first.benchedPlayerIDs = [wes]

        var second = Game(opponent: "Central")
        second.events = [
            GameEvent(playerID: nick, type: .twoPoint, period: 1),
            GameEvent(playerID: brad, type: .threePoint, period: 1),
            GameEvent(playerID: brad, type: .twoPoint, period: 1),
        ]
        second.periodEndScores = [1: PeriodEndScore(ourRunningTotal: 7, opponentRunningTotal: 9)]
        second.isComplete = true

        // Not finished: must not drag the averages down mid-way through.
        var live = Game(opponent: "Summit")
        live.events = [GameEvent(playerID: brad, type: .twoPoint, period: 1)]
        live.hasStarted = true

        return [first, second, live]
    }

    @Test func averagesComeFromCompletedGamesOnly() throws {
        let players = roster()
        let season = SeasonStats.season(for: players, in: games(players))

        let nick = try #require(season.first { $0.player.number == "77" })
        #expect(nick.gamesPlayed == 2)
        // 3 + 2 + 1 = 6, then 2 → 8 points over two games.
        #expect(nick.points == 8)
        #expect(nick.pointsPerGame == 4)

        let brad = try #require(season.first { $0.player.number == "1" })
        #expect(brad.gamesPlayed == 2)
        #expect(brad.points == 7, "the unfinished game's basket must not count")
    }

    @Test func aBenchedGameIsNotCountedAgainstTheAverage() throws {
        let players = roster()
        let season = SeasonStats.season(for: players, in: games(players))

        // Wesley was benched for the first game and recorded nothing in the
        // second, so he played one — not two, which would halve every average
        // he has.
        let wesley = season.first { $0.player.number == "88" }
        #expect(wesley?.gamesPlayed == 1)
    }

    /// A player added **mid-season** counts as having played the games before
    /// they joined, because nothing records when they joined: a past game's
    /// `benchedPlayerIDs` can't name someone who wasn't on the team yet, and
    /// `stats(for:)` includes every player who wasn't benched — a zero row
    /// meaning "there, didn't score".
    ///
    /// Asserted so the limitation is deliberate rather than discovered. The
    /// alternative — counting only games where they recorded something —
    /// understates the games of any kid who plays defence and doesn't score,
    /// inflating their average, which is the worse error to make about a
    /// child. Fixing it properly needs a join date on `Player`, which is a
    /// schema change (#211).
    @Test func aPlayerAddedMidSeasonCountsEarlierGamesUntilTheyAreBenched() {
        let players = roster() + [Player(name: "New Kid", number: "5")]
        let season = SeasonStats.season(for: players, in: games(players))

        let newcomer = season.first { $0.player.number == "5" }
        #expect(newcomer?.gamesPlayed == 2, "both finished games, though they played neither")
        #expect(newcomer?.points == 0)
    }

    @Test func theSeasonIsSortedByScoring() throws {
        let players = roster()
        let season = SeasonStats.season(for: players, in: games(players))
        let scoring = season.map(\.pointsPerGame)
        #expect(scoring == scoring.sorted(by: >))
    }

    @Test func freeThrowPercentIsASeasonRateAndAbsentWithoutAttempts() throws {
        let players = roster()
        let season = SeasonStats.season(for: players, in: games(players))

        let nick = try #require(season.first { $0.player.number == "77" })
        #expect(nick.ftAttempts == 2)
        #expect(nick.freeThrowPercent == 50)

        let brad = try #require(season.first { $0.player.number == "1" })
        #expect(brad.freeThrowPercent == nil, "never went to the line — not 0%")
    }

    /// The column rule: a stat nobody recorded is left out rather than averaged
    /// to a number that looks like a fact about the player.
    @Test func anUnrecordedStatHasNoColumn() throws {
        let players = roster()
        var season = SeasonStats.season(for: players, in: games(players))

        #expect(SeasonStats.hasAny(\.rebounds, in: season) == false,
                "no rebounds were recorded, so REB shouldn't be drawn")
        #expect(SeasonStats.hasAny(\.assists, in: season) == false)
        #expect(SeasonStats.hasAny(\.ftAttempts, in: season), "free throws were")

        season[0].rebounds = 1
        #expect(SeasonStats.hasAny(\.rebounds, in: season),
                "one recorded rebound anywhere is enough to earn the column")
    }

    @Test func aSeasonWithNoFinishedGamesIsEmpty() {
        var scheduled = Game(opponent: "Summit")
        scheduled.hasStarted = false
        #expect(SeasonStats.season(for: roster(), in: [scheduled]).isEmpty)
    }
}

/// The team's own record (#213).
struct TeamRecordTests {

    private func game(_ ours: Int, _ theirs: Int, complete: Bool = true) -> Game {
        var game = Game(opponent: "Someone")
        let scorer = UUID()
        for _ in 0..<(ours / 2) {
            game.events.append(GameEvent(playerID: scorer, type: .twoPoint, period: 1))
        }
        game.periodEndScores = [1: PeriodEndScore(ourRunningTotal: ours,
                                                  opponentRunningTotal: theirs)]
        game.isComplete = complete
        game.hasStarted = true
        return game
    }

    @Test func countsWinsLossesAndTiesFromCompletedGamesOnly() {
        let record = TeamRecord.record(from: [
            game(20, 10),        // win
            game(10, 20),        // loss
            game(14, 14),        // tie
            game(40, 0, complete: false),   // still being played
        ])

        #expect(record.wins == 1)
        #expect(record.losses == 1)
        #expect(record.ties == 1)
        #expect(record.gamesPlayed == 3, "the live game has no result yet")
    }

    @Test func aTieCountsAsHalfAWin() {
        // 1-0-1 has to rank above 1-1-0, which only a half-weighted tie does.
        let withTie = TeamRecord.record(from: [game(20, 10), game(14, 14)])
        let withLoss = TeamRecord.record(from: [game(20, 10), game(10, 20)])
        #expect(withTie.winPercent == 0.75)
        #expect(withLoss.winPercent == 0.5)
        #expect(withTie.winPercent > withLoss.winPercent)
    }

    @Test func theTieIsOnlyShownWhenThereIsOne() {
        #expect(TeamRecord.record(from: [game(20, 10), game(10, 20)]).display == "1–1")
        #expect(TeamRecord.record(from: [game(20, 10), game(14, 14)]).display == "1–0–1")
    }

    @Test func pointsForAndAgainstArePerGame() {
        let record = TeamRecord.record(from: [game(20, 10), game(10, 20)])
        #expect(record.pointsFor == 30)
        #expect(record.pointsAgainst == 30)
        #expect(record.pointsForPerGame == 15)
        #expect(record.pointsAgainstPerGame == 15)
    }

    @Test func aSeasonWithNoFinishedGamesDividesByNothing() {
        let record = TeamRecord.record(from: [game(40, 0, complete: false)])
        #expect(record.gamesPlayed == 0)
        #expect(record.winPercent == 0)
        #expect(record.pointsForPerGame == 0, "and doesn't divide by zero")
    }
}
