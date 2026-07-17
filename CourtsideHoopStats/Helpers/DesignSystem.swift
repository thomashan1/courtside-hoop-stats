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
    /// The team/brand accent — Swish Warriors blue, tuned per appearance so it
    /// keeps strong contrast as *text* (scores, "+2") on both light and dark
    /// surfaces. Deep blue (#1E5FCF) on light, brighter blue (#5B9CF5) on dark.
    static let teamAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.357, green: 0.612, blue: 0.961, alpha: 1)  // #5B9CF5
            : UIColor(red: 0.118, green: 0.373, blue: 0.812, alpha: 1)  // #1E5FCF
    })

    /// Fixed deep navy (#0C2C5E) used *only* for the scoreboard banner — an
    /// intentionally-dark, always-high-contrast element.
    static let scoreboardBackground = Color(red: 0.047, green: 0.173, blue: 0.369)
    /// The bright blue (#5B9CF5) used on the always-dark scoreboard, regardless
    /// of the system appearance.
    static let scoreboardAccent = Color(red: 0.357, green: 0.612, blue: 0.961)
}

// MARK: - Jersey color

extension JerseyColor {
    /// The swatch fill for this jersey.
    var swatch: Color {
        switch self {
        case .white: return Color(white: 0.96)
        case .blue:  return .teamAccent
        }
    }
}

/// A small "wear this jersey" indicator: a colored swatch + label.
struct JerseyIndicator: View {
    let color: JerseyColor

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color.swatch)
                .frame(width: 14, height: 14)
                .overlay(Circle().strokeBorder(Color(.separator), lineWidth: 1))
            Text(color.label)
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Autocomplete field

/// A text field that, while focused, offers previously-entered values matching
/// what's typed. Tapping a suggestion fills the field. Renders as multiple form
/// rows (the field plus suggestion rows), so place it directly inside a Section.
struct SuggestingTextField: View {
    let title: String
    @Binding var text: String
    let suggestions: [String]

    @FocusState private var focused: Bool

    private var matches: [String] {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return suggestions.filter { value in
            value.caseInsensitiveCompare(query) != .orderedSame
                && (query.isEmpty || value.localizedCaseInsensitiveContains(query))
        }
        .prefix(4)
        .map { $0 }
    }

    var body: some View {
        Group {
            TextField(title, text: $text)
                .focused($focused)

            if focused {
                ForEach(matches, id: \.self) { value in
                    Button {
                        text = value
                        focused = false
                    } label: {
                        Label(value, systemImage: "clock.arrow.circlepath")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
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
            .background(Circle().fill(Color.teamAccent))
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
        .background(Color.scoreboardBackground)
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
