import Testing
import Foundation
@testable import CourtsideHoopStats

/// The REB column only appears once someone has a rebound (#187).
///
/// Rebounds are hard to catch while scoring a live game, so "no rebounds
/// recorded" is the common case. These pin the predicate the tables branch on,
/// since the views themselves aren't unit-testable.
struct EmptyReboundColumnTests {

    private func game(_ types: [EventType]) -> (Game, [Player]) {
        let player = Player(name: "Nicholas H.", number: "77")
        var game = Game(opponent: "Hawks")
        game.events = types.map { GameEvent(playerID: player.id, type: $0, period: 1) }
        return (game, [player])
    }

    private func showsRebounds(_ types: [EventType]) -> Bool {
        let (g, roster) = game(types)
        return g.stats(for: roster).contains { $0.rebounds > 0 }
    }

    @Test func aGameWithNoReboundsHidesTheColumn() {
        #expect(!showsRebounds([.twoPoint, .threePoint, .ftMade, .ftMissed]))
    }

    @Test func oneReboundIsEnoughToShowIt() {
        #expect(showsRebounds([.twoPoint, .rebound]))
    }

    /// The live case: the column has to appear the moment the first rebound is
    /// tapped, not at the end of the game.
    @Test func theColumnAppearsAsSoonAsOneIsRecorded() {
        #expect(!showsRebounds([.twoPoint]))
        #expect(showsRebounds([.twoPoint, .rebound]))
    }

    /// An empty game shouldn't show it either — nothing has been recorded at
    /// all, so there's nothing to report.
    @Test func anEmptyGameHidesTheColumn() {
        #expect(!showsRebounds([]))
    }

    /// The demo fixture still has rebounds, so the screenshots keep exercising
    /// the visible case. If this fails, the demo seed lost its rebounds and
    /// every capture is quietly testing the hidden path instead.
    @Test func theDemoGameStillShowsTheColumn() {
        let team = DemoData.makeTeam()
        let finished = DemoData.makeGames(team: team).first { $0.isComplete }!
        #expect(finished.stats(for: team.players).contains { $0.rebounds > 0 })
    }
}
