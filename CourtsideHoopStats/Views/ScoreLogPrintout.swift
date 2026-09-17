import SwiftUI

/// Print layout for the Score Log — page 2+ of the box-score PDF (#182).
///
/// A **print-specific layout**, like the stats table on page 1: not a render of
/// `EventLogView`. The screen log was compressed hard for courtside legibility
/// (`isMinorLogEntry`, one-line scoring rows, a thumb-sized tap target per row)
/// and none of those constraints apply to paper, which instead has 556pt of
/// width to spend and no scrolling.
///
/// What it *does* share is the source of truth: the running team total per event
/// is computed the same way `EventLogView` computes it (chronological prefix sum
/// over `game.events`), and the per-period scores come from
/// `Game.periodBreakdownCumulative()` — the same method page 1's linescore uses.

// MARK: - Option

/// How much of the log to print, and how densely.
///
/// The column count is the whole design question: a log row is narrow (jersey,
/// name, action, running total), so one column leaves two-thirds of a Letter
/// page white and roughly doubles the page count.
enum ScoreLogPrintOption: String, CaseIterable {
    /// Page 1 only — today's behaviour.
    case off
    case oneColumn
    case twoColumn
    case threeColumn

    var columns: Int {
        switch self {
        case .off:         return 0
        case .oneColumn:   return 1
        case .twoColumn:   return 2
        case .threeColumn: return 3
        }
    }
}

// MARK: - Rows

/// One printed line of the log. Heights are **fixed constants** rather than
/// measured, which is what makes pagination deterministic: the layout can be
/// split into pages arithmetically before anything is rendered, so a page can
/// never overflow and no row can be half-drawn at a page break.
///
/// Fixed heights are safe here only because the page pins its own text size
/// (`.dynamicTypeSize(.large)`) and uses fixed point sizes, exactly as page 1
/// does.
enum ScoreLogPrintRow: Identifiable {
    /// A quarter/half boundary. `continued` marks the repeat at the top of a
    /// column that carries on a period started in the previous one.
    case periodHeader(period: Int, our: Int, opponent: Int?, continued: Bool)
    case event(GameEvent, runningTotal: Int)

    var id: String {
        switch self {
        case let .periodHeader(period, _, _, continued):
            return "h\(period)\(continued ? "c" : "")"
        case let .event(event, _):
            return event.id.uuidString
        }
    }

    var height: CGFloat {
        switch self {
        case .periodHeader: return Self.headerHeight
        case .event:        return Self.eventHeight
        }
    }

    /// 15pt at a 9.5pt name: tight, but this is a reference sheet rather than
    /// something read at arm's length, and every point here is a row.
    static let eventHeight: CGFloat = 15
    /// The period header carries its own rule and breathing space above.
    static let headerHeight: CGFloat = 22

    var period: Int {
        switch self {
        case let .periodHeader(period, _, _, _): return period
        case let .event(event, _):               return event.period
        }
    }

    var isHeader: Bool {
        if case .periodHeader = self { return true }
        return false
    }
}

// MARK: - Pagination

/// Splits the log into pages of columns, arithmetically, before rendering.
enum ScoreLogPaginator {

    /// Every log row for `game`, in the same chronological order the screen
    /// shows (oldest first), with period headers interleaved.
    static func rows(for game: Game) -> [ScoreLogPrintRow] {
        // Running total computed over the whole game in array order — the same
        // prefix sum `EventLogView.cumulativeTotals` uses, so the numbers on
        // paper and on screen cannot disagree.
        var total = 0
        var totals: [UUID: Int] = [:]
        for event in game.events {
            total += event.type.points
            totals[event.id] = total
        }

        let cumulative = game.periodBreakdownCumulative()
        var rows: [ScoreLogPrintRow] = []
        for period in Set(game.events.map(\.period)).sorted() {
            let line = cumulative.first { $0.period == period }
            let ours = line?.our
                ?? game.events.filter { $0.period <= period }.reduce(0) { $0 + $1.type.points }
            rows.append(.periodHeader(period: period,
                                      our: ours,
                                      opponent: line?.opponent,
                                      continued: false))
            for event in game.events.filter({ $0.period == period })
                                    .sorted(by: { $0.timestamp < $1.timestamp }) {
                rows.append(.event(event, runningTotal: totals[event.id] ?? 0))
            }
        }
        return rows
    }

    /// Lays `rows` out into pages of `columns` columns each `columnHeight` tall.
    ///
    /// Two rules beyond "fill until full":
    ///
    /// 1. **No orphaned period header.** A header with fewer than two of its
    ///    events under it is pushed to the next column rather than left dangling
    ///    at the foot of this one — the header is the thing that makes the rows
    ///    beneath it mean something.
    /// 2. **Continuation headers.** A column that carries on the previous
    ///    column's period repeats its header as "Q3 (cont.)", so no column is
    ///    ever a list of plays with no period attached to it.
    /// Fills **and balances** the columns.
    ///
    /// `columns` is a ceiling, not a quota. Two things went wrong in the
    /// prototype before this:
    ///
    /// - Filling each column greedily to the full page height put the demo
    ///   game's 40 rows in column one and left the right half of the sheet
    ///   blank.
    /// - Spreading those same 40 rows evenly across both columns instead left
    ///   the *bottom* half blank, which looks no better.
    ///
    /// So: work out how many full-height columns the log actually needs, then
    /// balance across **those**. A typical game needs one, and a two-column
    /// layout quietly renders as a single full-height column; the second column
    /// appears when there are enough plays to fill it.
    static func paginate(rows: [ScoreLogPrintRow],
                         columns: Int,
                         columnHeight: CGFloat) -> [[[ScoreLogPrintRow]]] {
        guard columns > 0, !rows.isEmpty else { return [] }

        let total = rows.reduce(0) { $0 + $1.height }
        let columnsNeeded = max(1, Int((total / columnHeight).rounded(.up)))

        // Continuation headers are added *during* the fill, so a perfectly
        // balanced target can spill into an extra column. Step up from the
        // balanced height until it doesn't. The floor is a header plus three
        // rows, so a short log can never balance down to a column holding
        // nothing but a period header.
        let floorHeight = ScoreLogPrintRow.headerHeight + ScoreLogPrintRow.eventHeight * 3
        var target = max(floorHeight, (total / CGFloat(columnsNeeded)).rounded(.up))
        while target < columnHeight {
            let laid = fill(rows: rows, columns: columns, columnHeight: target)
            if laid.flatMap({ $0 }).count <= columnsNeeded { return laid }
            target += ScoreLogPrintRow.eventHeight
        }
        return fill(rows: rows, columns: columns, columnHeight: columnHeight)
    }

    /// Greedy fill, one column at a time, to `columnHeight`.
    private static func fill(rows: [ScoreLogPrintRow],
                             columns: Int,
                             columnHeight: CGFloat) -> [[[ScoreLogPrintRow]]] {

        var pages: [[[ScoreLogPrintRow]]] = []
        var page: [[ScoreLogPrintRow]] = []
        var column: [ScoreLogPrintRow] = []
        var used: CGFloat = 0
        /// The last period printed anywhere, for the continuation header.
        var carriedPeriod: (period: Int, our: Int, opponent: Int?)?

        func closeColumn() {
            page.append(column)
            column = []
            used = 0
            if page.count == columns {
                pages.append(page)
                page = []
            }
        }

        var index = 0
        while index < rows.count {
            let row = rows[index]

            // Starting a fresh column mid-period: reprint the header.
            if column.isEmpty, !row.isHeader, let carried = carriedPeriod,
               carried.period == row.period {
                column.append(.periodHeader(period: carried.period,
                                            our: carried.our,
                                            opponent: carried.opponent,
                                            continued: true))
                used += ScoreLogPrintRow.headerHeight
            }

            // A header needs room for itself plus two rows, or it waits.
            let needed = row.isHeader
                ? row.height + ScoreLogPrintRow.eventHeight * 2
                : row.height

            if used + needed > columnHeight, !column.isEmpty {
                closeColumn()
                continue          // re-test the same row against the new column
            }

            column.append(row)
            used += row.height
            if case let .periodHeader(period, our, opponent, _) = row {
                carriedPeriod = (period, our, opponent)
            }
            index += 1
        }

        if !column.isEmpty { page.append(column) }
        if !page.isEmpty { pages.append(page) }
        return pages
    }
}

// MARK: - The printed page

/// One Letter page of the log. Fixed height, never growing: the paginator has
/// already guaranteed the rows fit, so this page can be exactly 792pt — which
/// is also what lets the PDF assert its own page size.
struct ScoreLogPrintoutPage: View {
    let game: Game
    let teamName: String
    let roster: [Player]
    /// Columns of rows, pre-split by `ScoreLogPaginator`.
    let columns: [[ScoreLogPrintRow]]
    /// The layout's column count, which the last page may not fill.
    let columnCount: Int
    let pageNumber: Int
    let pageCount: Int

    private var displayNames: [UUID: String] { PlayerDisplayName.map(for: roster) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            HStack(alignment: .top, spacing: 16) {
                ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(column) { row in
                            rowView(row)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                // A short last page must not stretch its columns to full width
                // — half a column of plays spread across 556pt reads as a
                // layout bug rather than the end of the game.
                if columns.count < columnCount {
                    ForEach(columns.count..<columnCount, id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
            }
            Spacer(minLength: 0)
            footer
        }
        .padding(PrintPage.margin)
        .frame(width: PrintPage.size.width, height: PrintPage.size.height,
               alignment: .topLeading)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .dynamicTypeSize(.large)
    }

    /// Repeated on every log page: a sheet that gets separated from page 1, or
    /// scrolled to in a group chat, has to say which game it belongs to.
    private var header: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text("Score Log" + (pageNumber > 2 ? " (cont.)" : ""))
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.teamAccent)
                Spacer()
                Text(matchupLine)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Rectangle().fill(Color.teamAccent.opacity(0.35)).frame(height: 1)
        }
    }

    private var matchupLine: String {
        let matchup = game.opponent.isEmpty
            ? teamName : "\(teamName) \(game.ourScore) — \(game.opponent) \(game.opponentScore)"
        return [matchup, game.date.formatted(date: .abbreviated, time: .omitted)]
            .joined(separator: "  ·  ")
    }

    private var footer: some View {
        HStack {
            Text("Courtside Hoop Stats")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text("Page \(pageNumber) of \(pageCount)")
                .font(.system(size: 9))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
        .overlay(alignment: .top) {
            Rectangle().fill(Color.black.opacity(0.1)).frame(height: 0.5)
        }
    }

    // MARK: Rows

    @ViewBuilder
    private func rowView(_ row: ScoreLogPrintRow) -> some View {
        switch row {
        case let .periodHeader(period, our, opponent, continued):
            periodHeader(period: period, our: our, opponent: opponent, continued: continued)
        case let .event(event, runningTotal):
            eventRow(event, runningTotal: runningTotal)
        }
    }

    /// `Q1` on the left, the score at the buzzer on the right.
    ///
    /// The opponent's score only exists at period boundaries — it's entered once
    /// per quarter, not per play — so it can't be a per-row column; the period
    /// header is the only honest place for it. Same fact the screen log states
    /// as "End Q1 · Opp 8", said at the top of the period instead of the bottom
    /// so a column that begins mid-game still opens with a score.
    private func periodHeader(period: Int, our: Int, opponent: Int?,
                              continued: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(game.periodFormat.periodLabel(period) + (continued ? " (cont.)" : ""))
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(Color.teamAccent)
                .tracking(0.5)
            Rectangle().fill(Color.black.opacity(0.12)).frame(height: 0.5)
            if let opponent {
                Text("\(our)–\(opponent)")
                    .font(.system(size: 9, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: ScoreLogPrintRow.headerHeight, alignment: .bottom)
    }

    private func eventRow(_ event: GameEvent, runningTotal: Int) -> some View {
        let player = roster.first { $0.id == event.playerID }
        let assist = event.assistPlayerID.flatMap { id in roster.first { $0.id == id } }
        // A rebound stays subordinate on paper too (#174) — grey rather than a
        // separate row shape, because on a printed sheet the aligned columns
        // are doing the work the card outline does on screen.
        let isMinor = event.type.isMinorLogEntry

        return HStack(spacing: 5) {
            JerseyBadge(number: player?.number ?? "?", size: 13)
                .opacity(isMinor ? 0.5 : 1)
            Text(player.map { displayNames[$0.id] ?? $0.firstName } ?? "Unknown")
                .font(.system(size: 9.5))
                .foregroundStyle(isMinor ? Color(white: 0.45) : .black)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            if let assist {
                Text("ast. \(assist.firstName)")
                    .font(.system(size: 8, weight: .regular).italic())
                    .foregroundStyle(Color(white: 0.45))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 3)
            Text(Self.printLabel(for: event.type))
                .font(.system(size: 9, weight: isMinor ? .regular : .bold))
                .foregroundStyle(isMinor ? Color(white: 0.45)
                                         : (event.type.points > 0 ? Color.teamAccent : .black))
                .monospacedDigit()
            // The running team total, only where there is one to run: a rebound
            // doesn't move the score and printing an unchanged number beside it
            // reads as if it did.
            // 22pt, not 16: a three-digit running total truncated to "1…" in
            // the first prototype. Youth scores rarely pass 99, but a cell that
            // can't hold the number it exists to show is a bug waiting for a
            // high-scoring game.
            Text(event.type.points > 0 ? "\(runningTotal)" : "")
                .font(.system(size: 8.5))
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 22, alignment: .trailing)
        }
        .frame(height: ScoreLogPrintRow.eventHeight)
    }

    /// Compact action tokens for paper.
    ///
    /// The screen's "+3 points" and its 🎉 badge (#172) exist for a glance at a
    /// phone mid-game; on a sheet with the plays in columns, `3PT` in accent
    /// bold is both narrower and quieter, and an emoji in a printed box score
    /// looks like a mistake.
    static func printLabel(for type: EventType) -> String {
        switch type {
        case .twoPoint:   return "2PT"
        case .threePoint: return "3PT"
        case .ftMade:     return "FT"
        case .ftMissed:   return "FT ✗"
        case .rebound:    return "REB"
        case .foul:       return "FOUL"
        case .unknown:    return "—"
        }
    }
}
