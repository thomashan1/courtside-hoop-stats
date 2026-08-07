import SwiftUI

/// Shared read-only stat panels (issue #8).
///
/// These are the single implementation of the score card, the player-stats
/// table and the by-period score grid, reused across the post-game **Summary**,
/// the **Live Scoring** screen, a follower's read-only detail, and while
/// **editing** a finished game — so the numbers look identical everywhere and
/// there's one place to change them.

// MARK: - Score card

/// The score panel at the top of a game screen: both teams, their scores, and
/// where the game is up to. Shared by the owner's **Game Summary** and a
/// follower's read-only detail — the follower's screen used to carry Live
/// Scoring's navy banner, which is tuned for reading at ten feet in a gym
/// rather than for a phone in your hand.
///
/// State-aware rather than final-score-only, because a follower opens games at
/// every stage: a scheduled game drawn as a final score reads as a 0–0 tie that
/// has already been played.
struct GameScoreCard: View {
    let game: Game
    /// Whose team this is — the active team, or the followed one. Passed in
    /// rather than read from the store: a follower is looking at someone else's.
    let ourName: String

    /// Score digits scale with Dynamic Type (capped so they can't overflow the
    /// row), matching the live scoreboard's behavior (issue #12).
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 36

    /// A game that hasn't tipped off has no score — nothing to show, rather than
    /// a pair of zeros that would read as a game played to a scoreless tie.
    private var isScoreless: Bool { game.lifecycle == .scheduled }

    var body: some View {
        HStack {
            teamColumn(name: ourName, score: game.ourScore, highlight: true)
            VStack {
                statusBadge
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            teamColumn(name: game.opponent.isEmpty ? "Opponent" : game.opponent,
                       score: game.opponentScore,
                       highlight: false)
        }
        .padding(.vertical, 8)
    }

    private func teamColumn(name: String, score: Int, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name).font(.subheadline).bold().lineLimit(1).minimumScaleFactor(0.6)
            if isScoreless {
                // Small and grey: a placeholder shouldn't carry the visual
                // weight of a score, which at this size reads as a black bar.
                Text("—").font(.title2).foregroundStyle(.tertiary)
            } else {
                Text("\(score)")
                    .font(.system(size: min(scoreSize, 64), weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(highlight ? Color.teamAccent : .primary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statusBadge: some View {
        let (text, color): (String, Color) = {
            switch game.lifecycle {
            case .complete:
                switch game.result {
                case .win:  return ("WIN", .teamAccent)
                case .loss: return ("LOSS", .red)
                case .tie:  return ("TIE", .secondary)
                }
            case .inProgress:
                // The period stands in for the result there isn't one of yet.
                // Pickup games have no periods, so they say they're live.
                return (game.periodFormat == .pickup
                        ? "LIVE"
                        : game.periodFormat.periodLabel(game.currentPeriod),
                        .teamAccent)
            case .scheduled:
                return ("SCHEDULED", .secondary)
            }
        }()
        return StatusBadge(text: text, color: color)
    }

    /// One line under the badge saying what the scores mean — for a game not
    /// yet played, the tip-off time is more use than restating "scheduled".
    private var caption: String {
        switch game.lifecycle {
        case .complete:   return "Final"
        case .inProgress: return "In Progress"
        case .scheduled:  return game.date.formatted(date: .omitted, time: .shortened)
        }
    }
}

/// A game's header: a band in the team's colour above the shared score card.
///
/// One implementation for both sides. The owner's finished game and a
/// follower's live one show the same thing and must keep looking like it —
/// they had drifted into two copies of the band before this existed, each with
/// its own padding, background and contrast handling.
///
/// Only the band's **contents** differ, because only they should: a follower
/// gets "Following" and a live indicator, the owner gets the date and the kit
/// they wore. Everything structural — the colour, the readable foreground, the
/// inset onto the card — lives here.
struct GameHeaderCard<Banner: View>: View {
    let game: Game
    /// Whose team this is: the active team, or the followed one.
    let ourName: String
    /// The team's kit colour. Drives the band and, via `onSwatch`, its text.
    let kit: JerseyColor
    @ViewBuilder var banner: Banner

    var body: some View {
        VStack(spacing: 0) {
            banner
                .foregroundStyle(kit.onSwatch)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(kit.swatch)

            // Scores stay on the solid card: content is legible before it's
            // decorative, and a score on a coloured field is harder to read
            // than one on white.
            GameScoreCard(game: game, ourName: ourName)
                .padding(.horizontal, 4)
        }
        .listRowInsets(EdgeInsets())
    }
}

// MARK: - Player stats table

/// A horizontally-scrollable per-player stat table. At large Dynamic Type the
/// columns grow and the table scrolls sideways instead of clipping the numbers
/// or squeezing the player name (issue #12). `Grid` keeps header and rows
/// column-aligned.
struct PlayerStatsTable: View {
    let stats: [PlayerStats]
    /// Players who sat the game out, listed below the scorers as **DNP**
    /// instead of being dropped — a roster that silently loses people reads as
    /// a bug, and zeroes would wrongly say "played, didn't score".
    var didNotPlay: [Player] = []

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
                            Text(stat.player.firstName).lineLimit(1)
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

                // Below the scorers: they contributed nothing to the numbers
                // above, so listing them among them would imply otherwise.
                ForEach(didNotPlay) { player in
                    GridRow {
                        HStack(spacing: 8) {
                            JerseyBadge(number: player.number, size: 26)
                            Text(player.firstName).lineLimit(1)
                        }
                        .frame(minWidth: 120, alignment: .leading)
                        Text("DNP")
                            .gridCellColumns(4)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 2)
            // Matches the inset the Score Log's row cards apply, so the jersey
            // bubbles in both sections line up down the Game Summary instead of
            // sitting 10pt apart.
            .padding(.horizontal, 10)
        }
    }
}

// MARK: - By-period score grid

/// The read-only period-by-period score grid — a **cumulative** running
/// linescore (score at the end of each period; the last row is the final).
/// Our column is derived from events; the opponent column from the recorded
/// running totals. Display-only.
struct PeriodBreakdownGrid: View {
    let game: Game
    let ourName: String

    /// The period-label column. Scaled, because the labels aren't all "Q1":
    /// a pickup game's period is labelled **"Game"**, which is already tight in
    /// 44pt at default text size and truncates outright at accessibility sizes.
    @ScaledMetric private var labelColumn: CGFloat = 44

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("").frame(width: labelColumn, alignment: .leading)
                Text(ourName).font(.caption).bold().frame(maxWidth: .infinity)
                Text(game.opponent).font(.caption).bold().frame(maxWidth: .infinity)
            }
            .foregroundStyle(.secondary)

            ForEach(game.periodBreakdownCumulative(), id: \.period) { row in
                HStack {
                    Text(game.periodFormat.periodLabel(row.period))
                        .font(.subheadline).bold()
                        .frame(width: labelColumn, alignment: .leading)
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
