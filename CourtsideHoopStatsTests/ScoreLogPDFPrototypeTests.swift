import XCTest
import PDFKit
import UIKit
@testable import CourtsideHoopStats

/// Prototype harness for the multi-page box score (#182).
///
/// Renders every candidate layout of the Score Log pages, asserts the page count
/// and the **media box of every page** through PDFKit rather than by eye, and —
/// when `CAPTURE_DIR` is set — writes each PDF plus a PNG of every page so the
/// options can actually be looked at.
///
/// Run with:
/// `TEST_RUNNER_CAPTURE_DIR=<dir> xcodebuild test -only-testing:CourtsideHoopStatsTests/ScoreLogPDFPrototypeTests …`
final class ScoreLogPDFPrototypeTests: XCTestCase {

    // MARK: - Fixtures

    @MainActor
    private func sample() throws -> (team: Team, game: Game) {
        var team = DemoData.makeTeam()
        let game = try XCTUnwrap(DemoData.makeGames(team: team).first { $0.lifecycle == .complete })
        team.players.append(Player(name: "Jordan Blake", number: "12"))
        return (team, game)
    }

    /// The demo log lengthened `factor`× by replaying it, so the multi-page
    /// cases are exercised with real-shaped data (same mix of baskets, free
    /// throws, rebounds and assists) rather than filler.
    ///
    /// Scores are left alone: this fixture exists to measure **pagination**, and
    /// page 1 is not what's under test.
    private func lengthened(_ game: Game, factor: Int) -> Game {
        var inflated = game
        var events: [GameEvent] = []
        for pass in 0..<factor {
            for event in game.events {
                var copy = event
                copy.id = UUID()
                copy.timestamp = event.timestamp.addingTimeInterval(Double(pass))
                events.append(copy)
            }
        }
        inflated.events = events.sorted {
            $0.period == $1.period ? $0.timestamp < $1.timestamp : $0.period < $1.period
        }
        return inflated
    }

    // MARK: - Capture

    private var captureDirectory: URL? {
        // xcodebuild passes environment through under a few different prefixes
        // depending on how the tests are hosted; try them all rather than
        // silently capturing nothing.
        let environment = ProcessInfo.processInfo.environment
        let keys = ["CAPTURE_DIR", "TEST_RUNNER_CAPTURE_DIR", "SIMCTL_CHILD_CAPTURE_DIR"]
        guard let path = keys.lazy.compactMap({ environment[$0] }).first(where: { !$0.isEmpty })
        else { return nil }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Renders, verifies the geometry of every page, and captures the result.
    /// Returns the page count and the PDF's size in bytes.
    @MainActor
    @discardableResult
    private func check(_ team: Team, _ game: Game,
                       log: ScoreLogPrintOption,
                       named name: String,
                       expectedPages: Int? = nil,
                       file: StaticString = #filePath,
                       line: UInt = #line) throws -> (pages: Int, bytes: Int) {
        let url = try XCTUnwrap(
            GameSummaryPDF.render(game: game, teamName: team.name,
                                  roster: team.players, log: log),
            "render returned nil", file: file, line: line
        )
        let data = try Data(contentsOf: url)
        let pdf = try XCTUnwrap(PDFDocument(data: data), file: file, line: line)

        if let expectedPages {
            XCTAssertEqual(pdf.pageCount, expectedPages, "\(name): page count",
                           file: file, line: line)
        }

        // Every page is Letter width; page 1 may grow (a long note or roster
        // does that today), log pages must be exactly 792 — the paginator
        // guarantees the rows fit, so a tall log page would mean it didn't.
        for index in 0..<pdf.pageCount {
            let bounds = try XCTUnwrap(pdf.page(at: index)).bounds(for: .mediaBox)
            XCTAssertEqual(bounds.width, 612, accuracy: 1,
                           "\(name): page \(index + 1) width", file: file, line: line)
            if index == 0 {
                XCTAssertGreaterThanOrEqual(bounds.height, 791,
                                            "\(name): page 1 height", file: file, line: line)
            } else {
                XCTAssertEqual(bounds.height, 792, accuracy: 1,
                               "\(name): log page \(index + 1) height must be exactly Letter",
                               file: file, line: line)
            }
        }

        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "com.adobe.pdf")
        attachment.name = "\(name).pdf"
        attachment.lifetime = .keepAlways
        add(attachment)

        if let directory = captureDirectory {
            try data.write(to: directory.appendingPathComponent("\(name).pdf"))
            for index in 0..<pdf.pageCount {
                guard let page = pdf.page(at: index) else { continue }
                let bounds = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2
                let image = page.thumbnail(of: CGSize(width: bounds.width * scale,
                                                      height: bounds.height * scale),
                                           for: .mediaBox)
                if let png = image.pngData() {
                    try png.write(to: directory.appendingPathComponent(
                        String(format: "%@-page%d.png", name, index + 1)))
                }
            }
        }

        print("CAPTURE \(name): \(pdf.pageCount) pages, \(data.count) bytes")
        return (pdf.pageCount, data.count)
    }

    // MARK: - Page 1 is untouched

    /// The whole premise: turning the log on must not alter page 1.
    @MainActor
    func testPageOneIsIdenticalWithAndWithoutTheLog() throws {
        let (team, game) = try sample()

        // Read each render's bytes *before* the next one: both land on the same
        // temp filename (it's derived from the matchup and date), so reading
        // them afterwards would compare the second file with itself.
        let plain = try Data(contentsOf: try XCTUnwrap(
            GameSummaryPDF.render(game: game, teamName: team.name,
                                  roster: team.players, log: .off)))
        let withLog = try Data(contentsOf: try XCTUnwrap(
            GameSummaryPDF.render(game: game, teamName: team.name,
                                  roster: team.players, log: .twoColumn)))
        let a = try XCTUnwrap(PDFDocument(data: plain))
        let b = try XCTUnwrap(PDFDocument(data: withLog))

        XCTAssertEqual(a.pageCount, 1, "the log must default to off")
        XCTAssertGreaterThan(b.pageCount, 1)

        let first = try XCTUnwrap(a.page(at: 0))
        let second = try XCTUnwrap(b.page(at: 0))
        XCTAssertEqual(first.bounds(for: .mediaBox), second.bounds(for: .mediaBox))
        // The footer carries a "generated at" clock, so compare with times
        // stripped rather than risking a failure on a minute boundary.
        func stable(_ page: PDFPage) -> String {
            (page.string ?? "").replacingOccurrences(of: "\\d{1,2}:\\d{2}",
                                                    with: "", options: .regularExpression)
        }
        XCTAssertEqual(stable(first), stable(second),
                       "page 1's text content changed when the log was added")
    }

    /// A page 1 grown past Letter by a long note must not drag the log pages
    /// with it — they carry their own media box.
    @MainActor
    func testATallPageOneLeavesTheLogPagesAtLetter() throws {
        let (team, game) = try sample()
        var wordy = game
        wordy.notes = String(repeating:
            "Ended four minutes early after the coach picked up two technicals. ", count: 4)

        let url = try XCTUnwrap(GameSummaryPDF.render(game: wordy, teamName: team.name,
                                                      roster: team.players, log: .twoColumn))
        let pdf = try XCTUnwrap(PDFDocument(data: Data(contentsOf: url)))
        XCTAssertGreaterThan(try XCTUnwrap(pdf.page(at: 0)).bounds(for: .mediaBox).height, 792)
        for index in 1..<pdf.pageCount {
            XCTAssertEqual(try XCTUnwrap(pdf.page(at: index)).bounds(for: .mediaBox).height,
                           792, accuracy: 1)
        }
    }

    // MARK: - Pagination rules

    @MainActor
    func testEveryEventReachesThePage() throws {
        let (_, game) = try sample()
        let rows = ScoreLogPaginator.rows(for: game)
        for option in [ScoreLogPrintOption.oneColumn, .twoColumn, .threeColumn] {
            let pages = ScoreLogPaginator.paginate(rows: rows, columns: option.columns,
                                                   columnHeight: GameSummaryPDF.logColumnHeight)
            let printed = pages.flatMap { $0 }.flatMap { $0 }
            let events = printed.filter { if case .event = $0 { return true } else { return false } }
            XCTAssertEqual(events.count, game.events.count,
                           "\(option): \(game.events.count - events.count) events dropped")
            let ids = Set(events.map(\.id))
            XCTAssertEqual(ids.count, events.count, "\(option): an event was printed twice")
        }
    }

    /// No column may overflow its height — that's the guarantee that lets the
    /// page be a fixed 792 instead of growing.
    @MainActor
    func testNoColumnOverflows() throws {
        let (_, game) = try sample()
        let long = lengthened(game, factor: 4)
        for option in [ScoreLogPrintOption.oneColumn, .twoColumn, .threeColumn] {
            let pages = ScoreLogPaginator.paginate(rows: ScoreLogPaginator.rows(for: long),
                                                   columns: option.columns,
                                                   columnHeight: GameSummaryPDF.logColumnHeight)
            for (pageIndex, page) in pages.enumerated() {
                XCTAssertLessThanOrEqual(page.count, option.columns)
                for column in page {
                    let height = column.reduce(0) { $0 + $1.height }
                    XCTAssertLessThanOrEqual(height, GameSummaryPDF.logColumnHeight,
                                             "\(option) page \(pageIndex + 2) column overflowed")
                }
            }
        }
    }

    /// A period header must never be the last thing in a column, and a column
    /// that continues a period must reprint its header.
    @MainActor
    func testNoOrphanedPeriodHeaderAndContinuationsAreLabelled() throws {
        let (_, game) = try sample()
        let long = lengthened(game, factor: 4)
        for option in [ScoreLogPrintOption.oneColumn, .twoColumn, .threeColumn] {
            let pages = ScoreLogPaginator.paginate(rows: ScoreLogPaginator.rows(for: long),
                                                   columns: option.columns,
                                                   columnHeight: GameSummaryPDF.logColumnHeight)
            for page in pages {
                for column in page {
                    // Every column opens with a period header, original or
                    // continued: no column is a list of plays with no period.
                    XCTAssertTrue(column.first?.isHeader ?? false,
                                  "\(option): a column began without a period header")
                    // A header is never the last thing in a column.
                    for (index, row) in column.enumerated() where row.isHeader {
                        XCTAssertLessThan(index, column.count - 1,
                                          "\(option): orphaned period header at index \(index)")
                    }
                }
            }
        }
    }

    // MARK: - The options, rendered

    /// Renders every candidate for the demo game (36 events) and the two
    /// lengthened logs, and prints the page counts that the proposal turns on.
    @MainActor
    func testRendersEveryCandidateLayout() throws {
        let (team, game) = try sample()
        let heavy = lengthened(game, factor: 2)     // ~72 events: a real rebound-heavy game
        let long = lengthened(game, factor: 4)      // ~144 events: the 3-page case

        var summary: [String] = []
        func note(_ label: String, _ events: Int, _ result: (pages: Int, bytes: Int)) {
            let padded = label.padding(toLength: max(label.count, 26), withPad: " ", startingAt: 0)
            summary.append(String(format: "%@  %3d events → %d pages, %5.1f KB",
                                  padded, events, result.pages, Double(result.bytes) / 1024))
        }

        note("off (today)", game.events.count,
             try check(team, game, log: .off, named: "00-today-one-page", expectedPages: 1))

        for (option, slug) in [(ScoreLogPrintOption.oneColumn, "1col"),
                               (.twoColumn, "2col"),
                               (.threeColumn, "3col")] {
            note("demo · \(slug)", game.events.count,
                 try check(team, game, log: option, named: "10-demo-\(slug)"))
            note("rebound-heavy · \(slug)", heavy.events.count,
                 try check(team, heavy, log: option, named: "20-heavy-\(slug)"))
            note("long log · \(slug)", long.events.count,
                 try check(team, long, log: option, named: "30-long-\(slug)"))
        }

        print("\n==== PAGE COUNTS ====\n" + summary.joined(separator: "\n") + "\n=====================\n")

        if let directory = captureDirectory {
            try (summary.joined(separator: "\n") + "\n")
                .write(to: directory.appendingPathComponent("page-counts.txt"),
                       atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Content

    @MainActor
    func testTheLogPagesCarryThePlaysAndTheirFurniture() throws {
        let (team, game) = try sample()
        let url = try XCTUnwrap(GameSummaryPDF.render(game: game, teamName: team.name,
                                                      roster: team.players, log: .twoColumn))
        let pdf = try XCTUnwrap(PDFDocument(data: Data(contentsOf: url)))
        let logText = try XCTUnwrap(pdf.page(at: 1)).string ?? ""

        XCTAssertTrue(logText.contains("Score Log"), "log pages need a title")
        XCTAssertTrue(logText.contains("Q1"), "period headers missing")
        XCTAssertTrue(logText.contains("3PT"), "action labels missing")
        XCTAssertTrue(logText.contains("REB"), "rebounds missing from the log")
        XCTAssertTrue(logText.contains("ast."), "assists missing from the log")
        XCTAssertTrue(logText.contains("Page 2 of \(pdf.pageCount)"), "page numbering missing")
        XCTAssertTrue(logText.contains(team.name), "log page doesn't say whose game it is")

        // **Every** page carries the App Store link, not just page 1: a log
        // page gets forwarded or printed on its own, and a footer that looks
        // tappable but isn't is worse than no link at all.
        for index in 0..<pdf.pageCount {
            let links = try XCTUnwrap(pdf.page(at: index)).annotations
                .filter { $0.type == "Link" }
            XCTAssertEqual(links.count, 1,
                           "page \(index + 1) should carry exactly one App Store link")
        }

        // And every page says which build made it, for the same reason.
        XCTAssertTrue(logText.contains("v\(BuildInfo.version)"),
                      "log page doesn't say which build produced it")
    }

    /// The running total on the printed log has to be the same number the screen
    /// shows, and the last one has to be the final score.
    @MainActor
    func testRunningTotalsMatchTheFinalScore() throws {
        let (_, game) = try sample()
        let rows = ScoreLogPaginator.rows(for: game)
        let totals: [Int] = rows.compactMap {
            if case let .event(event, total) = $0, event.type.points > 0 { return total }
            return nil
        }
        XCTAssertEqual(totals.last, game.ourScore, "the log's last running total is the final score")
        XCTAssertEqual(totals, totals.sorted(), "running totals must never go backwards")
    }
}
