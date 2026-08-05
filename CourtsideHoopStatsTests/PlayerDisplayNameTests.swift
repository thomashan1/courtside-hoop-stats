import Testing
import Foundation
@testable import CourtsideHoopStats

/// Tests for the shortest-unambiguous-name logic used by the box-score PDF
/// (#55): first names by default, escalating only for players who'd collide.
struct PlayerDisplayNameTests {

    private func player(_ name: String, _ number: String = "0") -> Player {
        Player(name: name, number: number)
    }

    @Test func usesBareFirstNamesWhenNoneCollide() {
        let roster = [player("Ava Mitchell"), player("Jake Lawson"), player("Nicholas Han")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names[roster[0].id] == "Ava")
        #expect(names[roster[1].id] == "Jake")
        #expect(names[roster[2].id] == "Nicholas")
    }

    @Test func addsLastInitialOnlyForTheCollidingPlayers() {
        let roster = [player("Jake Lawson"), player("Jake Moore"), player("Ava Mitchell")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names[roster[0].id] == "Jake L.")
        #expect(names[roster[1].id] == "Jake M.")
        // Untouched — Ava never collided, so she keeps a bare first name.
        #expect(names[roster[2].id] == "Ava")
    }

    @Test func fallsBackToFullLastNameWhenInitialsAlsoCollide() {
        let roster = [player("Jake Moore"), player("Jake Mills")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names[roster[0].id] == "Jake Moore")
        #expect(names[roster[1].id] == "Jake Mills")
    }

    @Test func matchesFirstNamesCaseInsensitively() {
        let roster = [player("jake Lawson"), player("Jake Moore")]
        let names = PlayerDisplayName.map(for: roster)

        // Both are recognised as the same first name, so both get qualified.
        #expect(names[roster[0].id] == "jake L.")
        #expect(names[roster[1].id] == "Jake M.")
    }

    @Test func degradesGracefullyWhenAPlayerHasNoLastName() {
        // Nothing to qualify with — the jersey badge disambiguates visually.
        let roster = [player("Jake"), player("Jake Moore")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names[roster[0].id] == "Jake")
        #expect(names[roster[1].id] == "Jake Moore")
    }

    @Test func handlesMultiWordLastNames() {
        let roster = [player("Ava Van Dyke"), player("Ava Mitchell")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names[roster[0].id] == "Ava V.")
        #expect(names[roster[1].id] == "Ava M.")
    }

    @Test func handlesThreeWayCollision() {
        let roster = [player("Jake Lawson"), player("Jake Moore"), player("Jake Nash")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names[roster[0].id] == "Jake L.")
        #expect(names[roster[1].id] == "Jake M.")
        #expect(names[roster[2].id] == "Jake N.")
    }

    @Test func coversEveryPlayerExactlyOnce() {
        let roster = [player("Ava Mitchell"), player("Jake Lawson"), player("Jake Moore")]
        let names = PlayerDisplayName.map(for: roster)

        #expect(names.count == roster.count)
    }
}
