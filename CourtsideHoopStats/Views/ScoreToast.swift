import SwiftUI

/// A basket that just landed, shown briefly to a follower watching the game.
struct ScoreFlash: Equatable, Identifiable {
    let id: UUID
    let playerName: String
    let jerseyNumber: String
    let label: String
    let teamScore: Int
    let opponentScore: Int
}

/// Transient banner announcing a new basket (#57).
///
/// A push notification is useless when the app is already open and in front of
/// you — iOS suppresses it, and you'd be staring at the very screen it would
/// have sent you to. This fills that gap: while a follower is watching a live
/// game, new scores arrive as a banner instead.
struct ScoreToast: View {
    let flash: ScoreFlash

    var body: some View {
        HStack(spacing: 12) {
            JerseyBadge(number: flash.jerseyNumber, size: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(flash.playerName)
                    .font(.subheadline.weight(.semibold))
                Text(flash.label)
                    .font(.caption)
                    .foregroundStyle(Color.teamAccent)
            }

            Spacer(minLength: 12)

            Text("\(flash.teamScore)–\(flash.opponentScore)")
                .font(.headline)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule().fill(.regularMaterial)
                .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(flash.playerName), \(flash.label). \(flash.teamScore) to \(flash.opponentScore)")
    }
}

extension View {
    /// Shows `flash` as a banner sliding in from the top, clearing itself after
    /// a few seconds. Binding rather than state so the caller owns when a new
    /// score replaces the one on screen.
    func scoreToast(_ flash: Binding<ScoreFlash?>) -> some View {
        overlay(alignment: .top) {
            if let current = flash.wrappedValue {
                ScoreToast(flash: current)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: current.id) {
                        try? await Task.sleep(for: .seconds(3.5))
                        withAnimation(.snappy) { flash.wrappedValue = nil }
                    }
            }
        }
        .animation(.snappy(duration: 0.28), value: flash.wrappedValue)
    }
}
