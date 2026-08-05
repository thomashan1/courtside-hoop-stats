import XCTest
import PDFKit
@testable import CourtsideHoopStats

/// Regression tests for the box-score PDF export (#55).
///
/// XCTest rather than Swift Testing (used by the pure-model tests) because
/// rendering needs `@MainActor` and the failing cases are easiest to review as
/// attachments — the test bundles the rendered PDF so a human can eyeball the
/// layout from the result bundle.
final class GameSummaryPDFTests: XCTestCase {

    /// The demo team and its finished game, with a duplicate first name and two
    /// benched non-scorers so both the disambiguation and DNP paths are live.
    ///
    /// `DemoData` is deliberately left untouched — it feeds the README and App
    /// Store screenshots.
    @MainActor
    private func sample() throws -> (team: Team, game: Game) {
        var team = DemoData.makeTeam()
        var game = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.lifecycle == .complete })

        let lucas = try XCTUnwrap(team.players.firstIndex { $0.name.hasPrefix("Lucas") })
        team.players[lucas].name = "Jake Zimmer"   // collides with "Jake L."

        // Only ever bench players with no events: benching a scorer makes the
        // TEAM row disagree with the final score (#59).
        team.players.append(Player(name: "Jordan Blake", number: "12"))
        game.benchedPlayerIDs = team.players
            .filter { $0.name.hasPrefix("Wesley") || $0.name.hasPrefix("Jordan") }
            .map(\.id)

        return (team, game)
    }

    @MainActor
    private func render(_ team: Team, _ game: Game) throws -> PDFDocument {
        let url = try XCTUnwrap(
            GameSummaryPDF.render(game: game, teamName: team.name, roster: team.players),
            "PDF render returned nil"
        )
        let data = try Data(contentsOf: url)

        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "90-box-score-sample.pdf"
        attachment.lifetime = .keepAlways
        add(attachment)

        return try XCTUnwrap(PDFDocument(data: data), "rendered bytes aren't a valid PDF")
    }

    @MainActor
    func testRendersASingleLetterPage() throws {
        let (team, game) = try sample()
        let pdf = try render(team, game)

        XCTAssertEqual(pdf.pageCount, 1)

        // A 12-player roster must still land on exactly one US Letter page.
        // Guards two regressions at once: content overflowing the page (it grows
        // rather than clipping, so this catches creeping padding), and the
        // earlier bug where a bad scale transform cropped the title off the top.
        let bounds = try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 612, accuracy: 1)
        XCTAssertEqual(bounds.height, 792, accuracy: 1)
    }

    @MainActor
    func testIncludesTheHeadlineNumbersAndDNPRows() throws {
        let (team, game) = try sample()
        let text = try XCTUnwrap(render(team, game).string)

        XCTAssertTrue(text.contains(team.name), "team name missing")
        XCTAssertTrue(text.contains(game.opponent), "opponent missing")
        XCTAssertTrue(text.contains("\(game.ourScore)"), "our score missing")
        XCTAssertTrue(text.contains("WIN"), "result badge missing")

        // Benched players appear as DNP rows, with the abbreviation explained.
        XCTAssertTrue(text.contains("DNP"), "DNP rows missing")
        XCTAssertTrue(text.contains("did not play"), "DNP footnote missing")
        XCTAssertTrue(text.contains("Wesley"), "benched player missing from DNP rows")
    }

    /// The whole point of the TEAM row: it has to agree with the scoreboard.
    @MainActor
    func testTeamTotalReconcilesWithTheFinalScore() throws {
        let (team, game) = try sample()
        // The whole roster — `stats(for:)` does the benching itself (#59).
        let tableTotal = game.stats(for: team.players).reduce(0) { $0 + $1.points }

        XCTAssertEqual(tableTotal, game.ourScore,
                       "player rows must sum to the final score")
    }

    /// Regression for the seam between the DNP rows and #59: a benched player
    /// who scored is kept in the stats table, so they must not *also* be listed
    /// as a DNP.
    @MainActor
    func testABenchedScorerIsListedOnceAndStillReconciles() throws {
        var (team, game) = try sample()

        // Bench the game's top scorer, on top of the existing bench-warmers.
        let topScorer = try XCTUnwrap(game.stats(for: team.players).first)
        game.benchedPlayerIDs.append(topScorer.player.id)
        XCTAssertGreaterThan(topScorer.points, 0, "fixture should have a scorer")

        let text = try XCTUnwrap(render(team, game).string)
        let name = try XCTUnwrap(PlayerDisplayName.map(for: team.players)[topScorer.player.id])

        // Appears exactly once — as a stats row, not also as a DNP.
        let occurrences = text.components(separatedBy: name).count - 1
        XCTAssertEqual(occurrences, 1, "benched scorer should be listed exactly once")

        // And the column still adds up.
        let tableTotal = game.stats(for: team.players).reduce(0) { $0 + $1.points }
        XCTAssertEqual(tableTotal, game.ourScore)
    }

    /// The footer credit must be a real PDF link annotation, not just text that
    /// looks like one — `ImageRenderer` alone would produce the latter.
    @MainActor
    func testFooterCarriesATappableAppStoreLink() throws {
        let (team, game) = try sample()
        let pdf = try render(team, game)
        let page = try XCTUnwrap(pdf.page(at: 0))

        let links = page.annotations.filter { $0.type == "Link" }
        XCTAssertEqual(links.count, 1, "expected exactly one link annotation")

        let link = try XCTUnwrap(links.first)
        XCTAssertEqual((link.action as? PDFActionURL)?.url, GameSummaryPDF.appStoreURL)

        // It has to sit over the footer, near the bottom of the page.
        let pageHeight = page.bounds(for: .mediaBox).height
        XCTAssertLessThan(link.bounds.maxY, pageHeight * 0.2,
                          "link should be in the footer, not floating mid-page")
        XCTAssertGreaterThan(link.bounds.width, 40)
        XCTAssertGreaterThan(link.bounds.height, 10)
    }

    @MainActor
    func testDisambiguatesDuplicateFirstNames() throws {
        let (team, game) = try sample()
        let text = try XCTUnwrap(render(team, game).string)

        // Two Jakes on the roster, so both are qualified by last initial.
        XCTAssertTrue(text.contains("Jake Z."), "duplicate first name not disambiguated")
        XCTAssertTrue(text.contains("Jake L."), "duplicate first name not disambiguated")
    }

    func testFilenameNamesBothTeams() {
        var game = Game(opponent: "Lakeside Lightning")
        game.date = DateComponents(calendar: .current, year: 2026, month: 8, day: 2).date!

        XCTAssertEqual(GameSummaryPDF.filename(for: game, teamName: "Swish Warriors"),
                       "Swish-Warriors-vs-Lakeside-Lightning-2026-08-02.pdf")

        // An opponent is optional in the New Game form (#44).
        var unnamed = Game(opponent: "")
        unnamed.date = game.date
        XCTAssertEqual(GameSummaryPDF.filename(for: unnamed, teamName: "Swish Warriors"),
                       "Swish-Warriors-2026-08-02.pdf")

        // Punctuation must not leak into the filename.
        var punctuated = Game(opponent: "St. Mary's / Under-12")
        punctuated.date = game.date
        XCTAssertEqual(GameSummaryPDF.filename(for: punctuated, teamName: "Swish Warriors"),
                       "Swish-Warriors-vs-St-Mary-s-Under-12-2026-08-02.pdf")

        // Neither name set — still a usable filename.
        XCTAssertEqual(GameSummaryPDF.filename(for: unnamed, teamName: ""),
                       "game-2026-08-02.pdf")
    }

    func testTitleNamesBothTeams() {
        let game = Game(opponent: "Lakeside Lightning")
        XCTAssertEqual(GameSummaryPDF.title(for: game, teamName: "Swish Warriors"),
                       "Swish Warriors vs Lakeside Lightning")

        // Falls back to our team alone when the opponent wasn't recorded.
        XCTAssertEqual(GameSummaryPDF.title(for: Game(opponent: ""), teamName: "Swish Warriors"),
                       "Swish Warriors")
    }
}
