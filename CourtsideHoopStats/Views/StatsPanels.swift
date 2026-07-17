import SwiftUI

/// Shared read-only stat panels (issue #8).
///
/// These are the single implementation of the player-stats table and the
/// by-period score grid, reused across the post-game **Summary**, the **Live
/// Scoring** screen, and while **editing** a finished game — so the numbers
/// look identical everywhere and there's one place to change them.

// MARK: - Player stats table

/// A horizontally-scrollable per-player stat table. At large Dynamic Type the
/// columns grow and the table scrolls sideways instead of clipping the numbers
/// or squeezing the player name (issue #12). `Grid` keeps header and rows
/// column-aligned.
struct PlayerStatsTable: View {
    let stats: [PlayerStats]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                GridRow {
                    Text("Player").frame(minWidth: 120, alignment: .leading)
                    Text("PTS")
                    Text("2P")
                    Text("3P")
                    Text("FT")
                }
                .font(.caption).bold()
                .foregroundStyle(.secondary)

                ForEach(stats) { stat in
                    GridRow {
                        HStack(spacing: 8) {
                            JerseyBadge(number: stat.player.number, size: 26)
                            Text(stat.player.name).lineLimit(1)
                        }
                        .frame(minWidth: 120, alignment: .leading)
                        Text("\(stat.points)").bold()
                        Text("\(stat.twoPointers)")
                        Text("\(stat.threePointers)")
                        Text(stat.freeThrowDisplay)
                    }
                    .font(.subheadline)
                    .monospacedDigit()
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - By-period score grid

/// The read-only period-by-period score grid (our points vs opponent). Our
/// column is derived from events; the opponent column from recorded running
/// totals. Editing opponent totals lives with the caller (the Summary keeps its
/// "Edit opponent totals" disclosure) — this component is display-only.
struct PeriodBreakdownGrid: View {
    let game: Game
    let ourName: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("").frame(width: 44, alignment: .leading)
                Text(ourName).font(.caption).bold().frame(maxWidth: .infinity)
                Text(game.opponent).font(.caption).bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            ForEach(game.periodBreakdown(), id: \.period) { row in
                HStack {
                    Text(game.periodFormat.periodLabel(row.period))
                        .font(.subheadline).bold()
                        .frame(width: 44, alignment: .leading)
                    Text("\(row.our)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                    Text("\(row.opponent)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
