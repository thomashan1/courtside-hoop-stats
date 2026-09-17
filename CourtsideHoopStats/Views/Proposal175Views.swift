import SwiftUI

#if DEBUG
// MARK: - Option B: arm a miss mode over the player deck

/// **PROPOSAL #175, Option B.** A two-state arming bar that sits at the top of
/// the player deck. While armed, tapping a player card records a missed field
/// goal for them — one tap, no sheet, no Score Log row — and tapping the armed
/// segment again returns the deck to scoring.
///
/// The bar is deliberately loud: a deck that silently means something different
/// than it looks is the one real hazard of a mode, so the armed state repaints
/// the deck and says in words what a tap will do.
struct Proposal175MissBar: View {
    @Binding var mode: EventType?

    private var isArmed: Bool { mode != nil }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                segment("MISS 2", .missedTwo)
                segment("MISS 3", .missedThree)
            }
            if let mode {
                Text(mode == .missedTwo
                     ? "Tap a player = missed 2-pointer"
                     : "Tap a player = missed 3-pointer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.orange)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func segment(_ label: String, _ value: EventType) -> some View {
        Button {
            mode = (mode == value) ? nil : value
        } label: {
            Text(label)
                .font(.subheadline.weight(.heavy))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(mode == value ? Color.orange : Color(.secondarySystemGroupedBackground))
                )
                .foregroundStyle(mode == value ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - Option C: type the attempts in once, after the game

/// **PROPOSAL #175, Option C.** No live tracking at all. Makes are already
/// known from the log, so this asks only for **attempts**, once, per player —
/// ten fields on one screen, filled in from the scorebook or from memory at the
/// final whistle.
///
/// The honest weakness is right there on the screen: nothing validates these
/// numbers, and nobody remembers that Lucas went 3-for-7 twenty minutes later.
/// A tracker who wants them accurate has to keep a tally somewhere while the
/// game runs — which is the thing this option was supposed to avoid.
struct Proposal175ShootingSheet: View {
    @Environment(\.dismiss) private var dismiss
    let stats: [PlayerStats]

    /// Pre-filled with the demo game's real attempts so the screenshot shows a
    /// completed screen rather than an empty one.
    @State private var twoAttempts: [UUID: String] = [:]
    @State private var threeAttempts: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Makes come from the Score Log. Enter how many times each player **shot**.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section {
                    HStack(spacing: 10) {
                        Text("Player").frame(maxWidth: .infinity, alignment: .leading)
                        Text("2P made").frame(width: 62, alignment: .trailing)
                        Text("2PA").frame(width: 52, alignment: .trailing)
                        Text("3P made").frame(width: 62, alignment: .trailing)
                        Text("3PA").frame(width: 52, alignment: .trailing)
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)

                    ForEach(stats) { stat in
                        HStack(spacing: 10) {
                            HStack(spacing: 6) {
                                JerseyBadge(number: stat.player.number, size: 24)
                                Text(stat.player.firstName).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            Text("\(stat.twoPointers)")
                                .frame(width: 62, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            field(for: stat.player.id, in: $twoAttempts)
                            Text("\(stat.threePointers)")
                                .frame(width: 62, alignment: .trailing)
                                .foregroundStyle(.secondary)
                            field(for: stat.player.id, in: $threeAttempts)
                        }
                        .font(.subheadline)
                        .monospacedDigit()
                    }
                } header: {
                    Text("Attempts")
                }
            }
            .navigationTitle("Shooting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { dismiss() }.bold()
                }
            }
            .onAppear(perform: prefill)
        }
    }

    private func field(for id: UUID, in binding: Binding<[UUID: String]>) -> some View {
        TextField("", text: Binding(
            get: { binding.wrappedValue[id] ?? "" },
            set: { binding.wrappedValue[id] = $0 }
        ))
        .keyboardType(.numberPad)
        .multilineTextAlignment(.trailing)
        .frame(width: 52)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color(.tertiarySystemFill)))
    }

    private func prefill() {
        for stat in stats {
            twoAttempts[stat.player.id] = stat.twoAttempts > 0 ? "\(stat.twoAttempts)" : ""
            threeAttempts[stat.player.id] = stat.threeAttempts > 0 ? "\(stat.threeAttempts)" : ""
        }
    }
}
#endif
