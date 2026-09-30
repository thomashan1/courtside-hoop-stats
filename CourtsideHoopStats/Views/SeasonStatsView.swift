import SwiftUI

/// A team's season so far: every player's per-game averages across the games
/// that have finished (#211).
///
/// One screen for both sides. The owner reaches it from the Roster tab, a
/// follower from the followed team's games list — which is that side's team
/// view, since there's no Roster tab over there. Nothing here can change
/// anything, so the same view is safe on both.
struct SeasonStatsView: View {
    let teamName: String
    let roster: [Player]
    let games: [Game]

    private var season: [SeasonStats] { SeasonStats.season(for: roster, in: games) }

    /// Games that actually contributed — the denominator people will check.
    private var completedGames: Int {
        games.filter { $0.lifecycle == .complete }.count
    }

    var body: some View {
        Group {
            if season.isEmpty {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "chart.bar.xaxis",
                    description: Text("Averages appear once a game has been played and finished.")
                )
            } else {
                List {
                    Section {
                        TeamRecordCard(record: TeamRecord.record(from: games))
                            .listRowInsets(EdgeInsets(top: 12, leading: 16,
                                                      bottom: 12, trailing: 16))
                    } header: {
                        Text("Record")
                    } footer: {
                        // Said out loud because it will sometimes disagree with
                        // the league's table: this counts the games *we* kept,
                        // and a missed one simply isn't here (#213).
                        Text("From the games recorded in this app, which may not be every game in the league.")
                    }

                    Section {
                        SeasonStatsTable(season: season)
                    } header: {
                        Text("Per game, across \(completedGames) game\(completedGames == 1 ? "" : "s")")
                    } footer: {
                        Text("GP is games played — a game someone sat out isn't counted against their average. 3s are three-pointers made per game. FT% is the season's free throws.")
                    }
                }
            }
        }
        .navigationTitle("\(teamName) · Season")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The season table. Built like `PlayerStatsTable` — a horizontally scrollable
/// `Grid` — so the two read as the same object with different numbers in them.
struct SeasonStatsTable: View {
    let season: [SeasonStats]

    /// A column is only drawn when the season has any of it.
    ///
    /// Rebounds have barely been tracked since they proved too hard to catch
    /// live, and assists are optional by design. "1.2 REB/game" drawn from
    /// games where nobody was counting reads as a fact about the player rather
    /// than about the tracking — worse than leaving it out, which is the call
    /// #187 already made for a single game.
    private var showsAssists: Bool { SeasonStats.hasAny(\.assists, in: season) }
    private var showsFreeThrows: Bool { SeasonStats.hasAny(\.ftAttempts, in: season) }

    /// **No rebounds column, deliberately.** Rebounds proved too hard to catch
    /// while scoring live, so they're effectively not being tracked — and a
    /// season average drawn from a handful of games where someone happened to
    /// tap REB says more about the tracking than the player. The auto-hide
    /// below would already drop it for a season with none; this drops it even
    /// where a few exist. Thomas's call while rebounds aren't being kept.
    ///
    /// The totals are still aggregated in `SeasonStats`, so restoring the
    /// column is one line if rebound tracking ever becomes real.

    private func average(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Player").frame(minWidth: 100, alignment: .leading)
                    Text("GP")
                    Text("PPG")
                    // No 2s column. Eight columns clipped FT% off the right
                    // edge — the failure §9 of the UI guidelines warns about,
                    // where a scrollable table hides a column nobody knows to
                    // scroll for. PPG already carries the twos; threes are the
                    // number people actually look for.
                    Text("3s")
                    if showsAssists { Text("AST") }
                    if showsFreeThrows { Text("FT%") }
                }
                .font(.caption).bold()
                .foregroundStyle(.secondary)

                ForEach(season) { line in
                    GridRow {
                        HStack(spacing: 8) {
                            JerseyBadge(number: line.player.number, size: 26)
                            Text(line.player.firstName).lineLimit(1)
                        }
                        .frame(minWidth: 100, alignment: .leading)

                        Text("\(line.gamesPlayed)").monospacedDigit()
                        Text(average(line.pointsPerGame)).bold().monospacedDigit()
                        value(line.threesPerGame)
                        if showsAssists { value(line.assistsPerGame) }
                        if showsFreeThrows {
                            // A player with no attempts all season gets a dash,
                            // not 0% — they never stepped to the line.
                            Text(line.freeThrowPercent.map { "\($0)%" } ?? "—")
                                .monospacedDigit()
                                .foregroundStyle(line.freeThrowPercent == nil ? .secondary : .primary)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
    }

    /// Zero fades back, exactly as a game's table does, so the players who
    /// actually did the thing stand out.
    private func value(_ average: Double) -> some View {
        Text(self.average(average))
            .monospacedDigit()
            .foregroundStyle(average == 0 ? .secondary : .primary)
    }
}


/// The team's own record, above the player averages (#213).
///
/// Four numbers, no streak: a streak says little about a youth team and costs
/// width that the points pair uses better.
struct TeamRecordCard: View {
    let record: TeamRecord

    private var percent: String {
        String(format: "%.3f", record.winPercent)
            .replacingOccurrences(of: "0.", with: ".")
    }

    var body: some View {
        // Wraps rather than scrolls: four short tiles fit a phone at default
        // size, and at accessibility sizes they stack instead of clipping —
        // unlike the stats table, which has to scroll because its columns
        // can't be reflowed.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 20) { tiles }
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 20) { recordTile; percentTile }
                HStack(spacing: 20) { forTile; againstTile }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var tiles: some View {
        recordTile
        percentTile
        forTile
        againstTile
    }

    private var recordTile: some View {
        tile(record.display, "W–L" + (record.ties > 0 ? "–T" : ""), emphasised: true)
    }
    private var percentTile: some View { tile(percent, "PCT") }
    private var forTile: some View {
        tile(String(format: "%.1f", record.pointsForPerGame), "PTS FOR")
    }
    private var againstTile: some View {
        tile(String(format: "%.1f", record.pointsAgainstPerGame), "PTS AGAINST")
    }

    private func tile(_ value: String, _ label: String, emphasised: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(emphasised ? .title2.bold() : .title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasised ? Color.teamAccent : .primary)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}
