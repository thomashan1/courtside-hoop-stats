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

// MARK: - In-app text size

/// The in-app "Text Size" steps. Applied app-wide as a Dynamic Type *floor*
/// (`.dynamicTypeSize(step...)`), so the app is never smaller than the chosen
/// step but still grows if the device's own text size is set even larger.
enum AppTextSize {
    static let steps: [DynamicTypeSize] = [
        .large, .xLarge, .xxLarge, .xxxLarge,
        .accessibility1, .accessibility2, .accessibility3,
    ]

    static var maxIndex: Int { steps.count - 1 }

    static func floor(for index: Int) -> DynamicTypeSize {
        steps[min(max(index, 0), maxIndex)]
    }
}

// MARK: - Tap targets

extension View {
    /// Guarantees the HIG-minimum 44×44pt tap target for icon-only controls
    /// (#56 — "+" occasionally not responding).
    ///
    /// A `Button` whose label is a bare `Image` is only as tappable as the
    /// glyph itself — an SF Symbol at body size is roughly 17–22pt, so taps
    /// that land a few points off-centre hit nothing at all. That reads as an
    /// intermittently dead button rather than a mis-tap, which is exactly how
    /// it was reported. `contentShape` is required as well: without it the hit
    /// region stays the glyph's shape even once the frame is padded out.
    func minimumTapTarget(_ side: CGFloat = 44) -> some View {
        frame(minWidth: side, minHeight: side)
            .contentShape(Rectangle())
    }
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
///
/// The badge scales with Dynamic Type (issue #12) so the number stays legible
/// at large accessibility text sizes — the caller's `size` is the baseline and
/// grows with the body text scale, capped at 2× so it can't dominate a row.
struct JerseyBadge: View {
    let number: String
    var size: CGFloat = 40

    /// Multiplier tracking the body text scale (1 at the default size).
    @ScaledMetric(relativeTo: .body) private var typeScale: CGFloat = 1

    private var dimension: CGFloat { min(size * typeScale, size * 2) }

    var body: some View {
        Text(number.isEmpty ? "–" : number)
            .font(.system(size: dimension * 0.42, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .frame(width: dimension, height: dimension)
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

    /// The big score scales with Dynamic Type (capped so it can't overflow the
    /// banner) so it grows for larger accessibility text sizes.
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 32

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
        .padding(.top, 4)
        .padding(.bottom, 8)
        .background(Color.scoreboardBackground)
    }

    private func teamColumn(name: String, score: Int, highlight: Bool) -> some View {
        VStack(spacing: 1) {
            Text(name)
                .font(.subheadline).bold()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
            Text("\(score)")
                .font(.system(size: min(scoreSize, 48), weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(highlight ? Color.scoreboardAccent : .white)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Game dates (#67)

extension Date {
    /// A game's date with its **3-letter weekday**, e.g. `Tue, Aug 4, 2026`.
    ///
    /// Youth games are scheduled by weekday far more than by date — "is that
    /// the Saturday one?" — so the day is worth the space wherever a game is
    /// listed. The weekday leads rather than trailing the year, because a
    /// trailing weekday collides with the time ("Aug 4, 2026 at 11:40 AM Tue").
    var gameDay: String {
        formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    /// The same, plus the start time: `Tue, Aug 4, 2026 at 11:40 AM`. For
    /// detail screens, where a full-width row has space for it.
    var gameDayAndTime: String {
        "\(gameDay) at \(formatted(date: .omitted, time: .shortened))"
    }

    /// List-row form: `Tue, Aug 4 at 11:40 AM`.
    ///
    /// Drops the year for games in the current year. A game row also carries a
    /// location, and adding the weekday to the full date pushed the tip-off
    /// time into an ellipsis — the time matters more on a schedule than a year
    /// you can already infer. Past seasons keep the year, so an old game is
    /// never ambiguous.
    var gameDayCompact: String {
        let calendar = Calendar.current
        let sameYear = calendar.component(.year, from: self)
            == calendar.component(.year, from: Date())
        let day = sameYear
            ? formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
            : gameDay
        return "\(day) at \(formatted(date: .omitted, time: .shortened))"
    }
}
