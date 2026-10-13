import Testing
import Foundation
@testable import CourtsideHoopStats

/// Who belongs in a game: a player added after it, or a guest who wasn't
/// in it, mustn't show up as "played, scored 0" or count toward GP.
struct GameRosterTests {

    private let nick = Player(name: "Nicholas H.", number: "77")
    private let brad = Player(name: "Bradley C.", number: "1")
    private let greg = Player(name: "Greg", number: "1")

    private func finished(_ roster: [Player], events: [GameEvent] = []) -> Game {
        var game = Game(opponent: "Panthers")
        game.hasStarted = true
        game.events = events
        game.finish(roster: roster)
        return game
    }

    @Test func aPlayerAddedAfterTheGameIsNotInIt() {
        let game = finished([nick, brad], events: [GameEvent(playerID: nick.id, type: .twoPoint, period: 1)])
        let ids = game.stats(for: [nick, brad, greg]).map(\.player.id)
        #expect(ids.contains(brad.id), "a teammate who didn't score still played")
        #expect(!ids.contains(greg.id))
        #expect(game.didNotPlay(from: [nick, brad, greg]).isEmpty)
    }

    @Test func aGameFinishedBeforeThisListsTheWholeRoster() {
        var game = finished([nick])
        game.rosterPlayerIDs = nil
        #expect(game.stats(for: [nick, greg]).count == 2)
    }

    @Test func aGuestShowsOnlyInGamesWithAStat() {
        var guest = greg
        guest.isGuest = true
        var old = finished([nick])
        old.rosterPlayerIDs = nil
        #expect(!old.stats(for: [nick, guest]).map(\.player.id).contains(guest.id))
        #expect(old.didNotPlay(from: [nick, guest]).isEmpty, "a guest is never a DNP")

        let assisted = finished([nick, guest], events: [
            GameEvent(playerID: nick.id, type: .twoPoint, period: 1, assistPlayerID: guest.id),
        ])
        #expect(assisted.stats(for: [nick, guest]).first { $0.player.id == guest.id }?.assists == 1)
    }

    @Test func aGuestCountsOnlyTheirGamesInTheSeason() {
        var guest = greg
        guest.isGuest = true
        var games = (0..<5).map { _ in finished([nick]) }
        games.append(finished([nick, guest], events: [GameEvent(playerID: guest.id, type: .twoPoint, period: 1)]))
        let season = SeasonStats.season(for: [nick, guest], in: games)
        #expect(season.first { $0.player.id == guest.id }?.gamesPlayed == 1)
        #expect(season.first { $0.player.id == nick.id }?.gamesPlayed == 6)
    }

    @Test func aGuestStartsANewGameOnTheBench() {
        var guest = greg
        guest.isGuest = true
        var game = Game(opponent: "Surge")
        game.start(roster: [nick, guest])
        #expect(game.isStarted)
        #expect(game.benchedPlayerIDs == [guest.id])
    }

    @Test func aMergeKeepsTheFinishedRoster() {
        let mine = Game(opponent: "Surge")
        var theirs = mine
        theirs.finish(roster: [nick])
        #expect(mine.merged(with: theirs).rosterPlayerIDs == [nick.id])
    }

    @Test func aRosterSavedBeforeGuestsDecodes() throws {
        let data = try JSONEncoder().encode([nick])
        var objects = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        objects[0].removeValue(forKey: "isGuest")
        let decoded = try JSONDecoder().decode([Player].self,
                                               from: JSONSerialization.data(withJSONObject: objects))
        #expect(decoded.first?.guest == false)
    }
}
