import XCTest
import PDFKit
@testable import CourtsideHoopStats

/// The season sheet (#215).
///
/// XCTest rather than Swift Testing, like the box-score suite: rendering needs
/// `@MainActor`, and the rendered PDF rides along as an attachment so a human
/// can look at the layout from the result bundle.
final class SeasonPDFTests: XCTestCase {

    @MainActor
    private func render() throws -> (document: PDFDocument, text: String) {
        let team = DemoData.makeTeam()
        let games = DemoData.makeGames(team: team)
        let url = try XCTUnwrap(SeasonPDF.render(teamName: team.name,
                                                 roster: team.players,
                                                 games: games))
        let data = try Data(contentsOf: url)

        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "92-season-summary.pdf"
        attachment.lifetime = .keepAlways
        add(attachment)

        let document = try XCTUnwrap(PDFDocument(data: data), "rendered bytes aren't a PDF")
        return (document, try XCTUnwrap(document.string))
    }

    @MainActor
    func testRendersOneLetterPage() throws {
        let (document, _) = try render()
        XCTAssertEqual(document.pageCount, 1, "a season is a sheet, not a document")

        let bounds = try XCTUnwrap(document.page(at: 0)).bounds(for: .mediaBox)
        XCTAssertEqual(bounds.width, 612, accuracy: 1)
        // It grows rather than clipping, exactly as the box score does.
        XCTAssertGreaterThanOrEqual(bounds.height, 792 - 1)
    }

    @MainActor
    func testCarriesTheRecordAndTheGamesBehindIt() throws {
        let team = DemoData.makeTeam()
        let games = DemoData.makeGames(team: team)
        let record = TeamRecord.record(from: games)
        let (_, text) = try render()

        XCTAssertTrue(text.contains(team.name), "the team isn't named")
        XCTAssertTrue(text.contains(record.display), "the record is missing")

        // Every finished game should appear by opponent — the results list is
        // the point of the sheet over the on-screen table.
        for game in games where game.lifecycle == .complete && !game.opponent.isEmpty {
            XCTAssertTrue(text.contains(game.opponent),
                          "\(game.opponent) is missing from the results")
        }
    }

    /// The sheet must say what it counted, or the record reads as the league's
    /// standing rather than as the games this app happens to hold (#213).
    @MainActor
    func testSaysWhatItCounted() throws {
        let (_, text) = try render()
        XCTAssertTrue(text.contains("recorded in Courtside Hoop Stats"),
                      "the sheet should say where its numbers come from")
    }

    /// Free throws get made/attempted *and* a percentage here — the phone only
    /// has room for the fraction.
    @MainActor
    func testFreeThrowsShowBothTheFractionAndThePercentage() throws {
        let (_, text) = try render()
        XCTAssertTrue(text.contains("%"), "the percentage is the PDF's job")
        XCTAssertTrue(text.contains("/"), "and the fraction gives it a denominator")
    }

    @MainActor
    func testFooterCarriesATappableAppStoreLink() throws {
        let (document, _) = try render()
        let page = try XCTUnwrap(document.page(at: 0))
        let links = page.annotations.filter { $0.type == "Link" }

        XCTAssertEqual(links.count, 1)
        XCTAssertEqual((links.first?.action as? PDFActionURL)?.url, GameSummaryPDF.appStoreURL)
    }

    func testFilenameIsDatedAndNamesTheTeam() {
        let date = DateComponents(calendar: .current, year: 2026, month: 9, day: 30).date!
        XCTAssertEqual(SeasonPDF.filename(teamName: "Swish Warriors", on: date),
                       "Swish-Warriors-season-2026-09-30.pdf")
        // A season sheet gets exported more than once; two undated ones in a
        // Files folder look identical.
        XCTAssertEqual(SeasonPDF.filename(teamName: "", on: date), "season-2026-09-30.pdf")
    }
}
