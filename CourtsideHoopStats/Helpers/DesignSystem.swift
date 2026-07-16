import SwiftUI

// MARK: - Palette
//
// Design pass (CLAUDE.md settled decision #2): the app follows the system
// light/dark appearance — no forced dark mode — so it stays legible in a bright
// gym. Grass-green is the single accent. Liquid Glass lives only in the chrome
// (nav/tab bars, the floating action bar); content surfaces stay solid and
// high-contrast. Screens use the system grouped-background colors so they adapt
// automatically; the only intentionally-fixed element is the scoreboard banner,
// which reads as a real (always-dark) gym scoreboard in both appearances.

extension Color {
    /// The app accent — grass green, tuned per appearance so it keeps strong
    /// contrast as *text* (scores, "+2") on both light and dark surfaces.
    /// A deep green on light, a brighter green on dark.
    static let grassGreen = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.82, blue: 0.42, alpha: 1)
            : UIColor(red: 0.13, green: 0.55, blue: 0.24, alpha: 1)
    })

    /// Fixed dark green used *only* for the scoreboard banner (see note above).
    static let scoreboardGreen = Color(red: 0.06, green: 0.18, blue: 0.12)
    /// The bright grass green used on the always-dark scoreboard, regardless of
    /// the system appearance.
    static let scoreboardAccent = Color(red: 0.35, green: 0.82, blue: 0.42)
}

// MARK: - Jersey badge

/// A circular jersey number badge. Used across the roster and scoring screens.
struct JerseyBadge: View {
    let number: String
    var size: CGFloat = 40

    var body: some View {
        Text(number.isEmpty ? "–" : number)
            .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(Color.grassGreen))
    }
}

// MARK: - Scoreboard

/// Compact scoreboard shown at the top of the live-scoring screen. Intentionally
/// a solid dark banner in both light and dark mode — highest contrast courtside.
struct ScoreboardView: View {
    let ourName: String
    let ourScore: Int
    let opponentName: String
    let opponentScore: Int
    let periodLabel: String

    var body: some View {
        HStack(alignment: .center) {
            teamColumn(name: ourName, score: ourScore, highlight: true)

            VStack(spacing: 2) {
                Text(periodLabel)
                    .font(.caption).bold()
                    .foregroundStyle(.white.opacity(0.75))
                Text("vs")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .frame(maxWidth: .infinity)

            teamColumn(name: opponentName, score: opponentScore, highlight: false)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color.scoreboardGreen)
    }

    private func teamColumn(name: String, score: Int, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.subheadline).bold()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
            Text("\(score)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? Color.scoreboardAccent : .white)
        }
        .frame(maxWidth: .infinity)
    }
}
