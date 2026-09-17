import SwiftUI
import PDFKit

/// PDF export of a finished game's box score (#55) — a clean, printable recap
/// to drop in the parents' group chat.
///
/// This is a **print-specific layout**, not a capture of `GameSummaryView`. The
/// on-screen summary is a `List` whose stat table scrolls horizontally, neither
/// of which renders sensibly to a fixed page. What it *does* share is the
/// source of truth: every number comes from the same model methods the screen
/// uses (`Game.stats(for:)`, `Game.periodBreakdownCumulative()`), so the two
/// can't drift in the numbers that matter — only in styling.

// MARK: - Page geometry

/// Shared by page 1 (`GameSummaryPrintout`) and the Score Log pages
/// (`ScoreLogPrintoutPage`), so every sheet in the document has the same
/// trim and margin. Internal rather than file-private for that reason.
enum PrintPage {
    /// US Letter at 72dpi. Letter rather than A4 because the audience is a US
    /// youth league; it also prints acceptably on A4 with default scaling.
    static let size = CGSize(width: 612, height: 792)
    /// 32 originally. Trimmed to make room for the Notes line: with a
    /// twelve-player roster the page is completely full, and the note
    /// overran US Letter (827pt of 792) until the stack's spacing came down
    /// and this with it. 28pt is still a normal printable margin.
    static let margin: CGFloat = 28
    static var contentWidth: CGFloat { size.width - margin * 2 }
    static var contentHeight: CGFloat { size.height - margin * 2 }
}

// MARK: - The printable page

/// The box-score page. Deliberately styled for paper: always-light colors, a
/// fixed Dynamic Type size, and hairline rules instead of the app's grouped
/// -List chrome.
struct GameSummaryPrintout: View {
    let game: Game
    let teamName: String
    /// The full team roster. The page splits it itself so the stats rows and
    /// the DNP rows can't disagree about who was there.
    let roster: [Player]

    /// Pass the whole roster: `stats(for:)` drops benched players itself, but
    /// keeps any who actually recorded something, so the points column still
    /// adds up to the final score (#59).
    private var stats: [PlayerStats] { game.stats(for: roster) }

    /// Players benched for this game *and* absent from the stats table. Listed
    /// NBA-style as "DNP" rows rather than rows of zeroes, which would wrongly
    /// read as "played, didn't score".
    ///
    /// A benched player who has events still appears above (#59) — they were
    /// evidently there — so they must not also be listed as a DNP.
    private var didNotPlay: [Player] { game.didNotPlay(from: roster) }

    /// First names, widened to "Jake M." only where two players would collide.
    /// Computed across the whole roster so a benched Jake still disambiguates
    /// the Jake who played.
    private var displayNames: [UUID: String] {
        PlayerDisplayName.map(for: roster)
    }

    private var resultText: String {
        switch game.result {
        case .win:  return "WIN"
        case .loss: return "LOSS"
        case .tie:  return "TIE"
        }
    }

    private var resultColor: Color {
        switch game.result {
        case .win:  return .teamAccent
        case .loss: return .red
        case .tie:  return .gray
        }
    }

    /// Date · League · Location, skipping whatever wasn't filled in (every
    /// field in the New Game form is optional).
    private var subtitle: String {
        [game.date.formatted(date: .complete, time: .shortened),
         game.league,
         game.location]
            .filter { !$0.isEmpty }
            .joined(separator: "  ·  ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            scoreBand
            periodTable
            statsTable
            notesBlock
            Spacer(minLength: 0)
            footer
        }
        .padding(PrintPage.margin)
        // `minHeight` rather than a fixed height: a normal game lands on exactly
        // one Letter page (the Spacer absorbing the slack), while an unusually
        // long roster grows the page instead of being clipped or shrunk.
        .frame(width: PrintPage.size.width)
        .frame(minHeight: PrintPage.size.height, alignment: .topLeading)
        .background(Color.white)
        // Paper is white regardless of the device appearance, and print output
        // must not depend on the reader's Dynamic Type setting.
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(game.opponent.isEmpty ? teamName : "\(teamName)  vs  \(game.opponent)")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(.black)
            if !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Final score

    private var scoreBand: some View {
        HStack(alignment: .center, spacing: 0) {
            scoreColumn(teamName, game.ourScore, highlight: true)
            VStack(spacing: 4) {
                Text(resultText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(resultColor))
                Text("FINAL")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            scoreColumn(game.opponent.isEmpty ? "Opponent" : game.opponent,
                        game.opponentScore, highlight: false)
        }
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.teamAccent.opacity(0.07))
        )
    }

    private func scoreColumn(_ name: String, _ score: Int, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(score)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? Color.teamAccent : .black)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: By-period linescore

    private var periodTable: some View {
        let rows = game.periodBreakdownCumulative()
        return VStack(alignment: .leading, spacing: 6) {
            sectionTitle("By Period (running score)")
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("").frame(width: Self.nameColumnWidth, alignment: .leading)
                    ForEach(rows, id: \.period) { row in
                        Text(game.periodFormat.periodLabel(row.period))
                            .frame(maxWidth: .infinity)
                    }
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.bottom, 6)

                linescoreRow(teamName, rows.map(\.our), bold: true)
                Divider()
                linescoreRow(game.opponent.isEmpty ? "Opponent" : game.opponent,
                             rows.map(\.opponent), bold: false)
            }
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
        }
    }

    private func linescoreRow(_ name: String, _ values: [Int], bold: Bool) -> some View {
        HStack(spacing: 0) {
            Text(name)
                .font(.system(size: 11, weight: bold ? .bold : .regular))
                .foregroundStyle(bold ? Color.teamAccent : .black)
                .lineLimit(1)
                // Team names run long ("Lakeside Lightning"); shrink rather
                // than truncate, since a clipped name looks like a bug.
                .minimumScaleFactor(0.7)
                .frame(width: Self.nameColumnWidth, alignment: .leading)
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                Text("\(value)")
                    .font(.system(size: 12, weight: bold ? .semibold : .regular))
                    .monospacedDigit()
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    // MARK: Player stats

    private var statsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Player Stats")
            VStack(spacing: 0) {
                // The name column is fixed at the same 132 the by-period table
                // above uses, so both tables' left edges line up — and the
                // stat columns then split the rest evenly instead of being
                // squeezed against the right margin by a name column that
                // had claimed every spare point (#148 follow-up).
                HStack(spacing: 0) {
                    Text("Player").frame(width: Self.nameColumnWidth, alignment: .leading)
                    Text("PTS").frame(maxWidth: .infinity)
                    Text("2P").frame(maxWidth: .infinity)
                    Text("3P").frame(maxWidth: .infinity)
                    Text("AST").frame(maxWidth: .infinity)
                    Text("REB").frame(maxWidth: .infinity)
                    // Last, matching the on-screen table.
                    Text("FT").frame(maxWidth: .infinity)
                }
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.black.opacity(0.04))

                let names = displayNames
                ForEach(Array(stats.enumerated()), id: \.element.id) { index, stat in
                    HStack(spacing: 0) {
                        HStack(spacing: 7) {
                            JerseyBadge(number: stat.player.number, size: 20)
                            Text(names[stat.player.id] ?? stat.player.firstName)
                                .font(.system(size: 12))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(width: Self.nameColumnWidth, alignment: .leading)
                        statCell("\(stat.points)", bold: true, isNothing: stat.points == 0)
                        statCell("\(stat.twoPointers)", isNothing: stat.twoPointers == 0)
                        statCell("\(stat.threePointers)", isNothing: stat.threePointers == 0)
                        statCell("\(stat.assists)", isNothing: stat.assists == 0)
                        statCell("\(stat.rebounds)", isNothing: stat.rebounds == 0)
                        statCell(stat.freeThrowDisplayWithPercent, isNothing: stat.ftAttempts == 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.black.opacity(0.02))
                }

                Divider()
                totalsRow

                // DNP rows sit below the team totals — they contribute nothing
                // to them, so listing them above would imply otherwise.
                if !didNotPlay.isEmpty {
                    Divider()
                    ForEach(didNotPlay) { player in
                        HStack(spacing: 0) {
                            HStack(spacing: 7) {
                                JerseyBadge(number: player.number, size: 20)
                                    .opacity(0.45)
                                Text(names[player.id] ?? player.firstName)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(width: Self.nameColumnWidth, alignment: .leading)
                            Text("DNP")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .tracking(0.5)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                    }
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))

            // Only worth explaining when the abbreviation actually appears.
            if !didNotPlay.isEmpty {
                Text("DNP — did not play")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var totalsRow: some View {
        let ftMade = stats.reduce(0) { $0 + $1.ftMade }
        let ftAtt = stats.reduce(0) { $0 + $1.ftAttempts }
        let ftText = ftAtt > 0
            ? "\(ftMade)/\(ftAtt) (\(Int((Double(ftMade) / Double(ftAtt) * 100).rounded()))%)"
            : "\(ftMade)/\(ftAtt)"
        return HStack(spacing: 0) {
            Text("TEAM")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: Self.nameColumnWidth, alignment: .leading)
            statCell("\(stats.reduce(0) { $0 + $1.points })", bold: true)
            statCell("\(stats.reduce(0) { $0 + $1.twoPointers })", bold: true)
            statCell("\(stats.reduce(0) { $0 + $1.threePointers })", bold: true)
            statCell("\(stats.reduce(0) { $0 + $1.assists })", bold: true)
            statCell("\(stats.reduce(0) { $0 + $1.rebounds })", bold: true)
            statCell(ftText, bold: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.teamAccent.opacity(0.07))
    }

    /// Width of both tables' left-hand name column, so the by-period
    /// linescore and the stats table share one left edge.
    private static let nameColumnWidth: CGFloat = 132

    /// `isNothing` fades a stat the player didn't record, matching the
    /// on-screen table. Grey rather than absent: this is a box score people
    /// print and hand around, and a blank cell reads as an omission.
    private func statCell(_ text: String, bold: Bool = false,
                          isNothing: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 12, weight: bold ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(isNothing ? Color(white: 0.62) : .black)
            .frame(maxWidth: .infinity)
    }

    // MARK: Chrome

    /// The tracker's note, under the box score.
    ///
    /// Sits below the numbers and above the `Spacer` that absorbs the page's
    /// slack, so on a normal game it lands in the whitespace that was empty
    /// anyway. Capped at four lines: this page is a one-pager by design, and
    /// a long note should lose its tail rather than push the footer — and the
    /// App Store link anchored to it — onto a second sheet.
    @ViewBuilder
    private var notesBlock: some View {
        if !game.notes.isEmpty {
            // Label and text on one line rather than a stacked section. The
            // page is a one-pager by design and a full section's worth of
            // chrome — title, its own spacing, the parent stack's gap — was
            // enough to push a twelve-player roster onto a second sheet
            // (`testRendersASingleLetterPage` caught it at 827pt of 792).
            //
            // **Wraps, up to 6 lines.** It was one line for a while, to keep
            // the page at exactly 792pt — but that truncated a real note
            // mid-sentence (#178), and the note is often the reason the
            // numbers look odd: "ended 4 minutes early, coach got two techs".
            // The PDF is what goes to the parents' group chat, so losing that
            // sentence costs more than a taller page.
            //
            // Extra lines eat the `Spacer` above the footer first, so a
            // typical game still lands on exactly one Letter page; only a
            // long roster *and* a long note grow it, which `.frame(minHeight:)`
            // already allows. The 6-line cap stops an essay producing an
            // absurd sheet.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                sectionTitle("Notes")
                Text(game.notes)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.black)
                    .lineLimit(6)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.teamAccent)
            .tracking(0.8)
    }

    private var footer: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Courtside Hoop Stats")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                // Drawn as ordinary text — `ImageRenderer` emits glyphs, not
                // annotations, so the tappable hyperlink is attached over this
                // area after rendering. See `GameSummaryPDF.addAppStoreLink`.
                Text("Get the app on the App Store ↗")
                    .font(.system(size: 8.5))
                    .foregroundStyle(Color.teamAccent)
            }
            Spacer()
            Text(Date.now.formatted(date: .abbreviated, time: .shortened))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }
}

// MARK: - Preview sheet

/// Shows the rendered box score before sharing it, with Share in its own
/// toolbar (#55).
///
/// Preview-then-share rather than a bare `ShareLink` for two reasons: you get
/// to see exactly what's going to the group chat before it goes, and it keeps
/// the summary's toolbar at three icons instead of four.
struct GameSummaryPDFPreview: View {
    let url: URL
    let shareTitle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PDFDocumentView(url: url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(shareTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url,
                                  preview: SharePreview(shareTitle,
                                                        image: Image(systemName: "doc.richtext"))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .minimumTapTarget()
                        }
                    }
                }
        }
    }
}

/// Thin `PDFKit` wrapper — SwiftUI has no native PDF viewer.
private struct PDFDocumentView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        // Fit the page to the screen instead of opening at 100% zoom, which on
        // a phone would land the reader in the top-left corner of a Letter page.
        view.autoScales = true
        view.backgroundColor = .systemGroupedBackground
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        guard view.document?.documentURL != url else { return }
        view.document = PDFDocument(url: url)
    }
}

// MARK: - Rendering

enum GameSummaryPDF {
    /// The live App Store listing, linked from the footer of every export.
    static let appStoreURL = URL(string:
        "https://apps.apple.com/us/app/courtside-hoop-stats/id6791865094")!

    /// Renders the box score to a PDF in the temporary directory and returns its
    /// URL, or `nil` if the PDF context couldn't be created.
    ///
    /// **Page 1 is the box score and is never paginated**: a box score is far
    /// more useful as one page, and a youth roster comfortably fits. A long
    /// roster or a long note grows that page rather than spilling onto a second.
    ///
    /// `log` optionally appends the **Score Log** on page 2+ (#182) — a separate
    /// print layout with its own pagination, which cannot affect page 1.
    /// - Parameter roster: the **full** team roster; benched players are listed
    ///   as DNP rows rather than dropped.
    /// - Parameter kit: the team's colour, for the jersey bubbles. Passed rather
    ///   than read from the environment: `ImageRenderer` renders outside the
    ///   view hierarchy, so nothing set by the presenting screen reaches here.
    @MainActor
    static func render(game: Game, teamName: String, roster: [Player],
                       kit: JerseyColor = .blue,
                       log: ScoreLogPrintOption = .off) -> URL? {
        let page = GameSummaryPrintout(game: game, teamName: teamName, roster: roster)
            .environment(\.teamKitColor, kit)

        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: PrintPage.size.width, height: nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(for: game, teamName: teamName))

        // Paginated up front, so the page count is known before anything is
        // drawn — the footer says "Page 2 of 3", which can't be written while
        // still discovering how many there are.
        let logColumns = paginatedLog(for: game, option: log)
        let totalPages = 1 + logColumns.count

        var context: CGContext?

        // The media box is taken from the *rendered* size rather than forced to
        // Letter. The page already carries a Letter minimum, so this is Letter
        // for any normal game — and sizing the box to the content means there
        // is no transform to get wrong and nothing can be clipped.
        renderer.render { size, drawInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }

            pdf.beginPDFPage(nil)
            drawInContext(pdf)
            pdf.endPDFPage()
            context = pdf
        }

        guard let context else { return nil }

        // Each log page carries its **own** media box. The document's default
        // box is page 1's rendered height, which a long note can push past
        // Letter — without a per-page box, a tall page 1 would silently make
        // every log page tall too.
        for (index, columns) in logColumns.enumerated() {
            let logPage = ScoreLogPrintoutPage(game: game,
                                               teamName: teamName,
                                               roster: roster,
                                               columns: columns,
                                               columnCount: log.columns,
                                               pageNumber: index + 2,
                                               pageCount: totalPages)
                .environment(\.teamKitColor, kit)

            let logRenderer = ImageRenderer(content: logPage)
            logRenderer.proposedSize = ProposedViewSize(width: PrintPage.size.width,
                                                        height: PrintPage.size.height)
            logRenderer.render { size, drawInContext in
                context.beginPDFPage(pageInfo(mediaBox: CGRect(origin: .zero, size: size)))
                drawInContext(context)
                context.endPDFPage()
            }
        }

        context.closePDF()
        addAppStoreLink(to: url)
        return url
    }

    /// The log split into pages of columns, or empty when the log is off or the
    /// game has no events.
    static func paginatedLog(for game: Game,
                             option: ScoreLogPrintOption) -> [[[ScoreLogPrintRow]]] {
        guard option != .off, !game.events.isEmpty else { return [] }
        return ScoreLogPaginator.paginate(rows: ScoreLogPaginator.rows(for: game),
                                          columns: option.columns,
                                          columnHeight: logColumnHeight)
    }

    /// Height available to a column of log rows on a Letter page: the trim, less
    /// both margins, the repeated header and the footer.
    static let logColumnHeight: CGFloat =
        PrintPage.size.height - PrintPage.margin * 2
        - 26   // header line + rule
        - 8    // stack spacing under the header
        - 22   // footer rule + line

    /// A per-page media box, for a document whose pages aren't all the same
    /// size. `kCGPDFContextMediaBox` takes the `CGRect` as raw `CFData`.
    private static func pageInfo(mediaBox: CGRect) -> CFDictionary {
        var box = mediaBox
        let data = withUnsafeBytes(of: &box) { Data($0) } as CFData
        return [kCGPDFContextMediaBox as String: data] as CFDictionary
    }

    /// e.g. `Swish-Warriors-vs-Lakeside-Lightning-2026-08-02.pdf`.
    ///
    /// Names **both** teams: these land in a group chat or a Files folder
    /// alongside other seasons' exports, where "vs-Lightning" alone doesn't say
    /// whose game it was.
    static func filename(for game: Game, teamName: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let matchup = [slug(teamName), slug(game.opponent)]
            .filter { !$0.isEmpty }
            .joined(separator: "-vs-")
        let stem = matchup.isEmpty ? "game" : matchup

        return "\(stem)-\(formatter.string(from: game.date)).pdf"
    }

    /// Makes the footer credit a real, tappable hyperlink.
    ///
    /// `ImageRenderer` draws the view as glyphs and paths, so the URL text it
    /// produces is only a picture of a link. PDF hyperlinks are *annotations*,
    /// a separate layer, so they have to be added afterwards — here via PDFKit
    /// (a system framework, so no new dependency).
    private static func addAppStoreLink(to url: URL) {
        guard let document = PDFDocument(url: url),
              let page = document.page(at: 0)
        else { return }

        // PDF coordinates put the origin at the *bottom* left, so the footer is
        // a fixed offset from y = 0 no matter how tall the page ended up. The
        // box deliberately covers both footer lines, making the wordmark
        // tappable as well as the "Get the app" line.
        let hotspot = CGRect(x: PrintPage.margin,
                             y: PrintPage.margin - 4,
                             width: 200,
                             height: 30)

        let link = PDFAnnotation(bounds: hotspot, forType: .link, withProperties: nil)
        link.action = PDFActionURL(url: appStoreURL)
        page.addAnnotation(link)

        document.write(to: url)
    }

    /// Filename-safe form: alphanumeric runs joined by hyphens.
    private static func slug(_ text: String) -> String {
        text.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    /// "Swish Warriors vs Lakeside Lightning" — the document's human-facing
    /// title, used for the preview screen and the share sheet.
    static func title(for game: Game, teamName: String) -> String {
        game.opponent.isEmpty ? teamName : "\(teamName) vs \(game.opponent)"
    }
}
