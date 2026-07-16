import SwiftUI

/// A grouped, editable event log. Events are grouped under period (quarter/half)
/// separators, newest period first. Tapping any event opens an editor to change
/// the player/action or delete it. Used in both Live Scoring and Game Summary.
struct EventLogView: View {
    @Binding var game: Game
    let players: [Player]
    /// Called after any edit/delete so the caller can persist the game.
    var persist: () -> Void

    @State private var editingEvent: GameEvent?

    /// Periods that have at least one event, most recent first.
    private var periodsDescending: [Int] {
        Set(game.events.map(\.period)).sorted(by: >)
    }

    var body: some View {
        Group {
            if game.events.isEmpty {
                Text("No events yet. Select a player, then tap an action.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(periodsDescending, id: \.self) { period in
                        periodGroup(period)
                    }
                }
            }
        }
        .sheet(item: $editingEvent) { event in
            EventEditSheet(
                event: event,
                players: players,
                onSave: { update($0) },
                onDelete: { delete(event) }
            )
        }
    }

    private func periodGroup(_ period: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quarter / half separator.
            HStack(spacing: 8) {
                Text(game.periodFormat.periodLabel(period))
                    .font(.subheadline).bold()
                    .foregroundStyle(.secondary)
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 1)
                Text("\(ourPoints(in: period)) pts")
                    .font(.caption).bold()
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ForEach(eventsNewestFirst(in: period)) { event in
                Button {
                    editingEvent = event
                } label: {
                    EventLogRow(event: event,
                                player: player(for: event.playerID),
                                format: game.periodFormat)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Derived

    private func eventsNewestFirst(in period: Int) -> [GameEvent] {
        game.events
            .filter { $0.period == period }
            .sorted { $0.timestamp > $1.timestamp }
    }

    private func ourPoints(in period: Int) -> Int {
        game.events.filter { $0.period == period }.reduce(0) { $0 + $1.type.points }
    }

    private func player(for id: UUID) -> Player? {
        players.first { $0.id == id }
    }

    // MARK: - Mutations

    private func update(_ updated: GameEvent) {
        guard let i = game.events.firstIndex(where: { $0.id == updated.id }) else { return }
        game.events[i] = updated
        persist()
    }

    private func delete(_ event: GameEvent) {
        game.events.removeAll { $0.id == event.id }
        persist()
    }
}

// MARK: - Event log row

struct EventLogRow: View {
    let event: GameEvent
    let player: Player?
    let format: PeriodFormat

    var body: some View {
        HStack(spacing: 10) {
            JerseyBadge(number: player?.number ?? "?", size: 24)

            Text(player?.name ?? "Unknown")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            Text(event.type.logLabel)
                .font(.caption).bold()
                .foregroundStyle(.secondary)

            if event.type.points > 0 {
                Text("+\(event.type.points)")
                    .font(.caption).bold()
                    .foregroundStyle(Color.teamAccent)
                    .monospacedDigit()
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(Rectangle())
    }
}

// MARK: - Event editor

/// Edit an event's player/action, or delete it.
struct EventEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let event: GameEvent
    let players: [Player]
    var onSave: (GameEvent) -> Void
    var onDelete: () -> Void

    @State private var playerID: UUID
    @State private var type: EventType

    init(event: GameEvent, players: [Player],
         onSave: @escaping (GameEvent) -> Void, onDelete: @escaping () -> Void) {
        self.event = event
        self.players = players
        self.onSave = onSave
        self.onDelete = onDelete
        _playerID = State(initialValue: event.playerID)
        _type = State(initialValue: event.type)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Player") {
                    Picker("Player", selection: $playerID) {
                        ForEach(players) { player in
                            Text(player.number.isEmpty ? player.name
                                                       : "#\(player.number)  \(player.name)")
                                .tag(player.id)
                        }
                    }
                }

                Section("Action") {
                    Picker("Action", selection: $type) {
                        ForEach(EventType.allCases, id: \.self) { type in
                            Text(type.logLabel).tag(type)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Label("Delete Event", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated = event
                        updated.playerID = playerID
                        updated.type = type
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
    }
}
