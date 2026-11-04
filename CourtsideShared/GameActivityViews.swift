import SwiftUI

// The Live Activity's views (#260), one per place the system shows it. In
// `CourtsideShared/` rather than the extension alone so the app's unit tests
// can render them (`LiveActivitySnapshotTests`); the extension's
// `GameLiveActivity` puts them in their slots.
//
// The look is Live Scoring's scoreboard: solid navy, our score in the
// scoreboard's bright blue, theirs in white, digits monospaced. It's content,
// so no Liquid Glass, and it's the same in light and dark — like the banner it
// copies, it's tuned for a bright gym, not for the system appearance.
//
// Player names appear only in the **expanded Dynamic Island** (the last
// basket). The Lock Screen can be read by anyone near the phone without
// unlocking it, so it shows teams and scores only.

typealias GameActivityState = GameActivityAttributes.ContentState

extension GameActivityState {
    /// One sentence for VoiceOver, in place of the separate numbers:
    /// "Swish Warriors 42, Northgate Falcons 38, Q3".
    var accessibilitySummary: String {
        var parts = ["\(ourName) \(ourScore)", "\(opponentName) \(opponentScore)"]
        if !status.isEmpty { parts.append(status) }
        if let through = opponentThrough { parts.append("\(opponentName) as of \(through)") }
        return parts.joined(separator: ", ")
    }

    /// "thru Q2" — said beside the opponent's score while it's a break old.
    var opponentNote: String? { opponentThrough.map { "thru \($0)" } }
}

// MARK: - Lock Screen

/// The Lock Screen card, which is also the banner on an iPhone without a
/// Dynamic Island. Laid out like Live Scoring's `ScoreboardView`.
struct GameActivityLockScreenView: View {
    let state: GameActivityState

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            team(state.ourName, score: state.ourScore, color: .scoreboardAccent, note: nil)
            middle
                .fixedSize()
            team(state.opponentName, score: state.opponentScore, color: .white,
                 note: state.opponentNote)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .foregroundStyle(.white)
        // The card stays a fixed size, so its type has a ceiling: past it the
        // names would crowd the scores off a card that can't grow.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(state.accessibilitySummary)
    }

    private func team(_ name: String, score: Int, color: Color, note: String?) -> some View {
        VStack(spacing: 0) {
            Text(name)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("\(score)")
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(color)
            // Both columns keep the line once either has one, so the two
            // scores stay level with each other.
            if state.opponentNote != nil {
                Text(note ?? " ")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .accessibilityHidden(note == nil)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var middle: some View {
        if let outcome = state.outcome {
            VStack(spacing: 6) {
                Text(state.status.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.8))
                GameActivityOutcomeBadge(outcome: outcome)
            }
        } else {
            VStack(spacing: 2) {
                if !state.status.isEmpty {
                    Text(state.status)
                        .font(.headline.bold())
                        .monospacedDigit()
                        .foregroundStyle(.white.opacity(0.85))
                }
                Text("vs")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }
}

/// W / L / T on a solid chip. Dark text on the blue and grey chips, white on
/// the red, so each clears 4.5:1.
struct GameActivityOutcomeBadge: View {
    let outcome: GameActivityAttributes.Outcome

    var body: some View {
        Text(outcome.letter)
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(foreground)
            .frame(minWidth: 28, minHeight: 24)
            .background(Capsule().fill(fill))
    }

    private var fill: Color {
        switch outcome {
        case .win:  return .scoreboardAccent
        case .loss: return Color(red: 0.80, green: 0.16, blue: 0.18)
        case .tie:  return Color(white: 0.85)
        }
    }

    private var foreground: Color {
        outcome == .loss ? .white : .scoreboardBackground
    }
}

// MARK: - Dynamic Island

/// Compact, left of the camera: our score, behind a basketball so the number
/// says whose it is.
struct GameActivityCompactLeading: View {
    let state: GameActivityState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "basketball.fill")
                .font(.caption)
                .foregroundStyle(Color.scoreboardAccent)
            Text("\(state.ourScore)")
                .font(.system(.body, design: .rounded).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(Color.scoreboardAccent)
        }
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.ourName) \(state.ourScore)")
    }
}

/// Compact, right of the camera: the opponent's score.
struct GameActivityCompactTrailing: View {
    let state: GameActivityState

    var body: some View {
        Text("\(state.opponentScore)")
            .font(.system(.body, design: .rounded).weight(.heavy))
            .monospacedDigit()
            .lineLimit(1)
            .foregroundStyle(.white)
            .accessibilityLabel("\(state.opponentName) \(state.opponentScore)")
    }
}

/// Minimal — sharing the island with another app's activity: our score.
struct GameActivityMinimal: View {
    let state: GameActivityState

    var body: some View {
        Text("\(state.ourScore)")
            .font(.system(.body, design: .rounded).weight(.heavy))
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .foregroundStyle(Color.scoreboardAccent)
            .accessibilityLabel("\(state.ourName) \(state.ourScore)")
    }
}

/// Expanded, leading: our team and score.
struct GameActivityExpandedLeading: View {
    let state: GameActivityState

    var body: some View {
        GameActivityExpandedTeam(name: state.ourName, score: state.ourScore,
                                 color: .scoreboardAccent, alignment: .leading,
                                 note: nil, keepsNoteLine: state.opponentNote != nil)
    }
}

/// Expanded, trailing: theirs, and how old their total is.
struct GameActivityExpandedTrailing: View {
    let state: GameActivityState

    var body: some View {
        GameActivityExpandedTeam(name: state.opponentName, score: state.opponentScore,
                                 color: .white, alignment: .trailing,
                                 note: state.opponentNote, keepsNoteLine: state.opponentNote != nil)
    }
}

struct GameActivityExpandedTeam: View {
    let name: String
    let score: Int
    let color: Color
    let alignment: HorizontalAlignment
    var note: String?
    /// Keep the note's line even without a note, so the two regions' scores
    /// sit level, as on the Lock Screen.
    var keepsNoteLine = false

    var body: some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(name)
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(score)")
                .font(.system(size: 38, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(color)
            if keepsNoteLine {
                Text(note ?? " ")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
                    .accessibilityHidden(note == nil)
            }
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) \(score)")
    }
}

/// Expanded, centre: the period, or the result.
struct GameActivityExpandedCenter: View {
    let state: GameActivityState

    var body: some View {
        if let outcome = state.outcome {
            HStack(spacing: 6) {
                Text(state.status)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white.opacity(0.85))
                GameActivityOutcomeBadge(outcome: outcome)
            }
        } else {
            Text(state.status.isEmpty ? "vs" : state.status)
                .font(.headline.bold())
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.85))
        }
    }
}

/// Expanded, bottom: the last basket — the one place a player is named.
struct GameActivityExpandedBottom: View {
    let state: GameActivityState

    var body: some View {
        if let lastBasket = state.lastBasket {
            Label(lastBasket, systemImage: "basketball.fill")
                .labelStyle(.titleAndIcon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .accessibilityLabel("Last basket: \(lastBasket)")
        }
    }
}
