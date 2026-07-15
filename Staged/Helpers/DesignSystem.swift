import SwiftUI

// MARK: - Palette

extension Color {
    /// Dark forest green — primary background / court aesthetic.
    static let courtGreen = Color(red: 0.06, green: 0.18, blue: 0.12)
    /// Slightly lighter card surface sitting on the court background.
    static let courtCard = Color(red: 0.11, green: 0.26, blue: 0.18)
    /// Bright grass green — accent for scores, selection, primary actions.
    static let grassGreen = Color(red: 0.30, green: 0.78, blue: 0.31)
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

/// Compact scoreboard shown at the top of the live-scoring screen.
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
        .background(Color.courtGreen)
    }

    private func teamColumn(name: String, score: Int, highlight: Bool) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.subheadline).bold()
                .lineLimit(1)
                .foregroundStyle(.white)
            Text("\(score)")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(highlight ? Color.grassGreen : .white)
        }
        .frame(maxWidth: .infinity)
    }
}
