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
    /// The team's colour, for the sheet's jersey bubbles and accents.
    /// `ImageRenderer` draws outside the view hierarchy, so nothing from the
    /// environment reaches the printout — it has to be handed over (#215).
    var kit: JerseyColor = .blue

    @State private var pdf: SeasonPDFFile?

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
                        Text("Win % counts a tie as half a win. From the games recorded in this app, which may not be every game in the league.")
                    }

                    Section {
                        SeasonStatsTable(season: season)
                    } header: {
                        Text("Per game, across \(completedGames) game\(completedGames == 1 ? "" : "s")")
                    } footer: {
                        Text("GP is games played — a game someone sat out isn't counted against their average. 3s are three-pointers made per game. FT is the season's free throws — made out of attempted, with the percentage under it.")
                    }
                }
            }
        }
        .navigationTitle("\(teamName) · Season")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Only worth offering once there's a season to send.
            if !season.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        pdf = SeasonPDF.render(teamName: teamName, roster: roster,
                                               games: games, kit: kit)
                            .map(SeasonPDFFile.init)
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .minimumTapTarget()
                    }
                    .accessibilityLabel("Share Season Summary")
                }
            }
        }
        .sheet(item: $pdf) { file in
            GameSummaryPDFPreview(url: file.url,
                                  shareTitle: SeasonPDF.title(teamName: teamName))
        }
    }
}

struct SeasonPDFFile: Identifiable {
    let url: URL
    var id: URL { url }
}

/// The season table. Built like `PlayerStatsTable` — a horizontally scrollable
/// `Grid` — so the two read as the same object with different numbers in them.
struct SeasonStatsTable: View {
    let season: [SeasonStats]

    /// The table's own width, measured.
    ///
    /// `ViewThatFits` can't decide this: inside a horizontally scrolling grid
    /// the proposal it measures against is unbounded, so it always picked the
    /// wide candidate and pushed the header row out of the card. A measured
    /// width is deterministic, and it keys off the actual space rather than a
    /// size class — which on iPhone says "compact" in landscape for every
    /// model except the biggest (#216).
    @State private var width: CGFloat = 0

    /// Enough room to put the free-throw fraction and its percentage on one
    /// line. Below this they stack, which is still better than scrolling the
    /// column off the edge where nobody finds it (§9).
    private var isWide: Bool { width >= 560 }

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
        WidthFillingTable {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Player").frame(minWidth: 100, alignment: .leading)
                    Text("PPG").frame(minWidth: 40, maxWidth: .infinity)
                    // No 2s column. Eight columns clipped FT% off the right
                    // edge — the failure §9 of the UI guidelines warns about,
                    // where a scrollable table hides a column nobody knows to
                    // scroll for. PPG already carries the twos; threes are the
                    // number people actually look for.
                    Text("3s").frame(maxWidth: .infinity)
                    if showsAssists { Text("AST").frame(maxWidth: .infinity) }
                    // "FT" as made/attempted, not "FT%". A season percentage
                    // with no denominator can't tell 1-for-1 from 12-for-12,
                    // and it's the same rule the game table follows: the
                    // fraction on screen, the percentage in the PDF where
                    // there's room for both (#213).
                    // Wider than an equal share: "12/15" is nearly twice the
                    // width of "0.2", and on a phone an equal split truncated
                    // it to "12/…" — the widest value has to claim its room
                    // before the rest divide what's left (#216).
                    if showsFreeThrows {
                        Text("FT").frame(minWidth: 46, maxWidth: .infinity)
                    }
                    Text("GP").frame(maxWidth: .infinity)
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

                        Text(average(line.pointsPerGame)).bold().monospacedDigit()
                            .frame(minWidth: 40, maxWidth: .infinity)
                        value(line.threesPerGame)
                        if showsAssists { value(line.assistsPerGame) }
                        if showsFreeThrows { freeThrows(line) }
                        Text("\(line.gamesPlayed)").monospacedDigit()
                            .frame(maxWidth: .infinity)
                    }
                    .font(.subheadline)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width = $0 }
    }

    /// Made/attempted with the percentage **under** it, not beside it:
    /// "12/15 (80%)" is wider than the whole column on a phone, and the two
    /// numbers answer different questions — the fraction says how often they
    /// were at the line, the percentage how they did there. Stacking costs a
    /// little row height, which a reading screen can spend; width it can't.
    ///
    /// A dash, not 0/0 or 0%: someone who never went to the line hasn't missed
    /// anything.
    @ViewBuilder
    private func freeThrows(_ line: SeasonStats) -> some View {
        Group {
            if line.ftAttempts == 0 {
                Text("—").foregroundStyle(.secondary)
            } else {
                // One line where there's room, stacked where there isn't.
                if isWide {
                    HStack(spacing: 4) {
                        Text("\(line.ftMade)/\(line.ftAttempts)")
                        Text("(\(line.freeThrowPercent ?? 0)%)")
                            .foregroundStyle(.secondary)
                    }
                    .monospacedDigit()
                    .fixedSize()
                } else {
                    VStack(spacing: 0) {
                        Text("\(line.ftMade)/\(line.ftAttempts)")
                            .monospacedDigit()
                        Text("\(line.freeThrowPercent ?? 0)%")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .fixedSize()
                }
            }
        }
        .frame(minWidth: 46, maxWidth: .infinity)
    }

    /// Zero fades back, exactly as a game's table does, so the players who
    /// actually did the thing stand out.
    private func value(_ average: Double) -> some View {
        Text(self.average(average))
            .monospacedDigit()
            .foregroundStyle(average == 0 ? .secondary : .primary)
            // Flexible, so the columns spread across the table's width (#216).
            .frame(maxWidth: .infinity)
    }
}


/// The team's own record, above the player averages (#213).
///
/// Four numbers, no streak: a streak says little about a youth team and costs
/// width that the points pair uses better.
struct TeamRecordCard: View {
    let record: TeamRecord

    var body: some View {
        // Wraps rather than scrolls: four short tiles fit a phone at default
        // size, and at accessibility sizes they stack instead of clipping —
        // unlike the stats table, which has to scroll because its columns
        // can't be reflowed.
        // Spread across the row rather than packed against the left edge:
        // four `fixedSize` tiles in a leading-aligned stack left the rest of
        // the width empty, which reads as crowding on a wide phone and is
        // glaring in landscape (#216).
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { tiles }
            VStack(spacing: 14) {
                HStack(spacing: 12) { recordTile; percentTile }
                HStack(spacing: 12) { forTile; againstTile }
            }
        }
        .frame(maxWidth: .infinity)
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
    // Words, not standings abbreviations: "PCT" and "PTS FOR / AGAINST"
    // meant nothing to the family reading it.
    private var percentTile: some View { tile(record.winPercentDisplay, "WIN %") }
    private var forTile: some View {
        tile(String(format: "%.1f", record.pointsForPerGame), "POINTS SCORED\nPER GAME")
    }
    private var againstTile: some View {
        tile(String(format: "%.1f", record.pointsAgainstPerGame), "POINTS ALLOWED\nPER GAME")
    }

    private func tile(_ value: String, _ label: String, emphasised: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(emphasised ? .title2.bold() : .title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(emphasised ? Color.teamAccent : .primary)
            // Two lines rather than a shorthand: "POINTS ALLOWED / PER GAME"
            // keeps four tiles in a row on a phone.
            Text(label)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        // Each tile takes an equal share of the row, so they distribute
        // instead of huddling. `fixedSize` on the *text* keeps a label from
        // wrapping inside its share.
        .fixedSize(horizontal: true, vertical: false)
        .frame(maxWidth: .infinity)
    }
}
