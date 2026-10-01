import SwiftUI
import PDFKit

/// The season as a one-page sheet (#215): the team's record, every player's
/// averages, and the games behind them.
///
/// A print layout, not a capture of the screen — the same split the box score
/// makes. The page has room the phone doesn't, so it shows what had to be cut
/// there: twos alongside threes, free throws as made/attempted **and** a
/// percentage, and the game-by-game results that are the honest version of a
/// league table.
struct SeasonPrintout: View {
    let teamName: String
    let roster: [Player]
    let games: [Game]

    private var season: [SeasonStats] { SeasonStats.season(for: roster, in: games) }
    private var record: TeamRecord { TeamRecord.record(from: games) }
    private var results: [Game] {
        games.filter { $0.lifecycle == .complete }.sorted { $0.date < $1.date }
    }

    private static let nameColumn: CGFloat = 132

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            recordRow
            averages
            resultsTable
            Spacer(minLength: 0)
            PrintFooter(trailing: .madeOn(.now))
        }
        .padding(PrintPage.margin)
        .frame(width: PrintPage.size.width, alignment: .topLeading)
        .frame(minHeight: PrintPage.size.height, alignment: .topLeading)
        .background(.white)
        // Print sizes are fixed points, so the sheet can't be reflowed by
        // whatever text size the phone happens to be set to.
        .dynamicTypeSize(.large)
        .environment(\.colorScheme, .light)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(teamName) · Season")
                .font(.system(size: 20, weight: .heavy))
                .foregroundStyle(.black)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }

    /// Says what the sheet counted. Without it the record reads as the league's
    /// standing, which it isn't — the app only knows the games this tracker
    /// kept (#213).
    private var subtitle: String {
        let count = results.count
        let games = "\(count) game\(count == 1 ? "" : "s") recorded in Courtside Hoop Stats"
        guard let first = results.first?.date, let last = results.last?.date else { return games }
        return count == 1
            ? "\(first.formatted(date: .abbreviated, time: .omitted)) · \(games)"
            : "\(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted)) · \(games)"
    }

    private var recordRow: some View {
        HStack(spacing: 0) {
            recordTile(record.display, record.ties > 0 ? "W–L–T" : "W–L", wide: true)
            recordTile(String(format: "%.3f", record.winPercent)
                .replacingOccurrences(of: "0.", with: "."), "PCT")
            recordTile(String(format: "%.1f", record.pointsForPerGame), "PTS FOR")
            recordTile(String(format: "%.1f", record.pointsAgainstPerGame), "PTS AGAINST")
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
    }

    private func recordTile(_ value: String, _ label: String, wide: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: wide ? 22 : 18, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(wide ? Color.teamAccent : .black)
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Player averages

    private var showsAssists: Bool { SeasonStats.hasAny(\.assists, in: season) }

    private var averages: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Per game")
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Text("Player").frame(width: Self.nameColumn, alignment: .leading)
                    Text("PPG").frame(maxWidth: .infinity)
                    Text("2s").frame(maxWidth: .infinity)
                    Text("3s").frame(maxWidth: .infinity)
                    if showsAssists { Text("AST").frame(maxWidth: .infinity) }
                    // Made/attempted *and* the percentage: the sheet has the
                    // width the phone doesn't, and the fraction is what makes
                    // a percentage from four attempts readable as such.
                    Text("FT").frame(maxWidth: .infinity)
                    Text("GP").frame(maxWidth: .infinity)
                }
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                ForEach(Array(season.enumerated()), id: \.element.id) { index, line in
                    HStack(spacing: 0) {
                        Text(line.player.name)
                            .font(.system(size: 10))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: Self.nameColumn, alignment: .leading)
                        cell(average(line.pointsPerGame), bold: true)
                        cell(average(line.twosPerGame))
                        cell(average(line.threesPerGame))
                        if showsAssists { cell(average(line.assistsPerGame)) }
                        cell(line.ftAttempts == 0
                             ? "—"
                             : "\(line.ftMade)/\(line.ftAttempts) (\(line.freeThrowPercent ?? 0)%)")
                        cell("\(line.gamesPlayed)")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.black.opacity(0.03))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))

            Text("GP is games played — a game a player sat out isn't counted against their average. 2s / 3s are baskets made per game.")
                .font(.system(size: 8.5))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Results

    /// The games behind the record, which is what a league table can't show
    /// and a parent actually wants to scan.
    private var resultsTable: some View {
        VStack(alignment: .leading, spacing: 6) {
            sectionTitle("Results")
            VStack(spacing: 0) {
                ForEach(Array(results.enumerated()), id: \.element.id) { index, game in
                    HStack(spacing: 0) {
                        Text(game.date.formatted(.dateTime.month(.abbreviated).day()))
                            .frame(width: 54, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Text(game.opponent.isEmpty ? "—" : game.opponent)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(resultLetter(game))
                            .font(.system(size: 10, weight: .heavy))
                            .foregroundStyle(resultColour(game))
                            .frame(width: 18)
                        Text("\(game.ourScore)–\(game.opponentScore)")
                            .monospacedDigit()
                            .frame(width: 58, alignment: .trailing)
                        // Overtime is worth saying on a results line: a
                        // six-point loss in overtime isn't the same game as a
                        // six-point loss in regulation.
                        Text(wentToOvertime(game) ? "OT" : "")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 20, alignment: .leading)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(index.isMultiple(of: 2) ? Color.clear : Color.black.opacity(0.03))
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
        }
    }

    private func wentToOvertime(_ game: Game) -> Bool {
        (game.periodEndScores.keys.max() ?? 0) > game.periodFormat.periodCount
    }

    private func resultLetter(_ game: Game) -> String {
        switch game.result {
        case .win:  return "W"
        case .loss: return "L"
        case .tie:  return "T"
        }
    }

    private func resultColour(_ game: Game) -> Color {
        switch game.result {
        case .win:  return Color.teamAccent
        case .loss: return .red
        case .tie:  return .secondary
        }
    }

    // MARK: Furniture

    private func cell(_ text: String, bold: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10, weight: bold ? .semibold : .regular))
            .monospacedDigit()
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
    }

    private func average(_ value: Double) -> String { String(format: "%.1f", value) }

    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.teamAccent)
            .tracking(0.8)
    }
}

// MARK: - Rendering

enum SeasonPDF {

    /// Renders the season sheet and returns its URL, or nil if the PDF context
    /// couldn't be made.
    ///
    /// One page that **grows** rather than paginating, like the box score: a
    /// season is a sheet, and a roster plus a season's results fits Letter with
    /// room to spare. A very long season grows the page instead of spilling.
    @MainActor
    static func render(teamName: String, roster: [Player], games: [Game],
                       kit: JerseyColor = .blue) -> URL? {
        let page = SeasonPrintout(teamName: teamName, roster: roster, games: games)
            .environment(\.teamKitColor, kit)

        let renderer = ImageRenderer(content: page)
        renderer.proposedSize = ProposedViewSize(width: PrintPage.size.width, height: nil)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(filename(teamName: teamName))

        var made = false
        renderer.render { size, drawInContext in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let pdf = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
            else { return }
            pdf.beginPDFPage(nil)
            drawInContext(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            made = true
        }

        guard made else { return nil }
        GameSummaryPDF.addAppStoreLink(to: url)
        return url
    }

    /// e.g. `Swish-Warriors-season-2026-09-30.pdf`. Dated, because a season
    /// sheet is exported more than once and two of them in a Files folder
    /// otherwise look identical.
    static func filename(teamName: String, on date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let team = teamName.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let stamp = formatter.string(from: date)
        return team.isEmpty ? "season-\(stamp).pdf" : "\(team)-season-\(stamp).pdf"
    }

    static func title(teamName: String) -> String {
        teamName.isEmpty ? "Season" : "\(teamName) · Season"
    }
}
