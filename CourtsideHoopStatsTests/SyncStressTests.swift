import Testing
import Foundation
@testable import CourtsideHoopStats

/// Random multi-device histories against the fake iCloud (#229).
///
/// Three devices take thousands of random actions — score, delete a tap,
/// edit notes, add or delete a game, finish a game, sync — in random order.
/// Afterwards every device must hold exactly the same games, and no tap may
/// have vanished unless someone deleted it. Seeded, so a failure replays.
@MainActor
struct SyncStressTests {

    /// SplitMix64: small, fast, and the same sequence on every run.
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    typealias Cloud = OwnDeviceSyncTests.FakeCloud

    @Test(arguments: [1, 2, 3, 4, 5, 6, 7, 8] as [UInt64])
    func randomHistoriesConvergeWithoutLosingTaps(seed: UInt64) async {
        var rng = Seeded(state: seed)
        let cloud = Cloud()

        let first = AppStore(inMemory: true)
        first.backupService = cloud.service()
        first.addPlayer(name: "Nicholas H", number: "77")
        await first.setSyncAcrossDevices(true)
        var devices = [first]
        for _ in 0..<2 {
            let device = AppStore(inMemory: true)
            device.backupService = cloud.service()
            await device.setSyncAcrossDevices(true)
            devices.append(device)
        }
        let player = first.team.players[0].id

        // What the history did, to judge the end state against.
        var created: Set<UUID> = []          // every tap ever recorded
        var tapDeleted: Set<UUID> = []       // taps someone deleted
        var gameOf: [UUID: UUID] = [:]       // tap -> its game
        var gamesDeleted: Set<UUID> = []     // games someone deleted

        for _ in 0..<1500 {
            let device = devices[Int.random(in: 0..<devices.count, using: &rng)]
            let games = device.games
            switch Int.random(in: 0..<100, using: &rng) {
            case 0..<35 where !games.isEmpty:                    // score
                var game = games.randomElement(using: &rng)!
                let type: EventType = [.twoPoint, .threePoint, .ftMade, .rebound]
                    .randomElement(using: &rng)!
                let event = GameEvent(playerID: player, type: type,
                                      period: Int.random(in: 1...4, using: &rng))
                game.events.append(event)
                device.updateGame(game)
                created.insert(event.id)
                gameOf[event.id] = game.id
            case 35..<42:                                         // delete a tap
                guard var game = games.filter({ !$0.events.isEmpty }).randomElement(using: &rng)
                else { continue }
                let id = game.events.randomElement(using: &rng)!.id
                game.removeEvent(id: id)
                device.updateGame(game)
                tapDeleted.insert(id)
            case 42..<50 where !games.isEmpty:                    // edit notes
                var game = games.randomElement(using: &rng)!
                game.notes = "note \(Int.random(in: 0..<1000, using: &rng))"
                device.updateGame(game)
            case 50..<56:                                         // new game
                var game = Game(opponent: "Opp \(Int.random(in: 0..<100, using: &rng))")
                game.hasStarted = true
                device.addGame(game)
            case 56..<58 where !games.isEmpty:                    // delete a game
                let id = games.randomElement(using: &rng)!.id
                device.deleteGame(id: id)
                gamesDeleted.insert(id)
            case 58..<60 where !games.isEmpty:                    // finish a game
                var game = games.randomElement(using: &rng)!
                game.isComplete = true
                device.updateGame(game)
            default:                                              // sync
                await device.syncNow()
            }
        }

        // Let everything settle.
        for _ in 0..<4 {
            for device in devices { await device.syncNow() }
        }

        // 1. Every device holds the same games, with the same taps.
        let reference = Dictionary(uniqueKeysWithValues:
            devices[0].games.map { ($0.id, Set($0.events.map(\.id))) })
        for device in devices.dropFirst() {
            let mine = Dictionary(uniqueKeysWithValues:
                device.games.map { ($0.id, Set($0.events.map(\.id))) })
            #expect(mine == reference, "devices disagree (seed \(seed))")
        }

        // 2. A game nobody deleted is still there.
        let surviving = Set(reference.keys)
        for (_, gameID) in gameOf where !gamesDeleted.contains(gameID) {
            #expect(surviving.contains(gameID), "a game nobody deleted is gone (seed \(seed))")
        }

        // 3. A tap nobody deleted, in a game nobody deleted, is still there.
        for tap in created where !tapDeleted.contains(tap) {
            let gameID = gameOf[tap]!
            guard !gamesDeleted.contains(gameID) else { continue }
            #expect(reference[gameID]?.contains(tap) == true,
                    "a tap nobody deleted vanished (seed \(seed))")
        }

        // 4. A deleted tap stays deleted in any game nobody deleted.
        for tap in tapDeleted {
            let gameID = gameOf[tap]!
            guard !gamesDeleted.contains(gameID) else { continue }
            #expect(reference[gameID]?.contains(tap) != true,
                    "a deleted tap came back (seed \(seed))")
        }

    }
}
