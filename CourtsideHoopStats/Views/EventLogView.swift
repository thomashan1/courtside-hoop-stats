import SwiftUI

/// A grouped event log. Events are grouped under period (quarter/half)
/// separators, newest period first.
///
/// - In **editable** mode (Live Scoring and the Edit-Scores view) tapping an
///   event opens an editor and a left-swipe deletes it.
/// - In **read-only** mode (the Game Summary) rows are display-only — the
///   Summary is a box score; all mutation happens behind its "Edit Scores"
///   button (#23).
struct EventLogView: View {
    @Binding var game: Game
    let players: [Player]
    /// When false the log is display-only (no tap-to-edit, no swipe-to-delete).
    var isEditable: Bool = true
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
                let row = EventLogRow(event: event,
                                      player: player(for: event.playerID),
                                      format: game.periodFormat,
                                      runningTotal: cumulativeTotals[event.id] ?? 0,
                                      showsChevron: isEditable)
                if isEditable {
                    SwipeToDelete(onDelete: { delete(event) }) {
                        Button { editingEvent = event } label: { row }
                            .buttonStyle(.plain)
                    }
                } else {
                    row
                }
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

    /// Cumulative team points after each event, in chronological order,
    /// keyed by event id — the running score "so far".
    private var cumulativeTotals: [UUID: Int] {
        var total = 0
        var map: [UUID: Int] = [:]
        for event in game.events {
            total += event.type.points
            map[event.id] = total
        }
        return map
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
    /// Cumulative team points through this event.
    let runningTotal: Int
    /// Whether to show the trailing chevron (hidden in read-only mode).
    var showsChevron: Bool = true

    var body: some View {
        HStack(spacing: 10) {
            JerseyBadge(number: player?.number ?? "?", size: 24)

            Text(player?.name ?? "Unknown")
                .font(.subheadline)
                .foregroundStyle(.primary)

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(event.type.scoreLogLabel)
                    .font(.caption).bold()
                    .foregroundStyle(event.type.points > 0 ? Color.teamAccent : Color.secondary)
                if event.type.points > 0 {
                    Text("\(runningTotal) pts")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .monospacedDigit()

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.secondarySystemGroupedBackground)))
        .contentShape(Rectangle())
    }
}

// MARK: - Swipe to delete

/// Wraps an (opaque) row so a left-swipe reveals a red Delete button. Used
/// because the Score Log is a `VStack`, not a `List` (no native `.swipeActions`).
private struct SwipeToDelete<Content: View>: View {
    let onDelete: () -> Void
    @ViewBuilder var content: Content

    @State private var offset: CGFloat = 0
    @State private var base: CGFloat = 0

    /// Resting position when the delete button is revealed.
    private let revealWidth: CGFloat = 76
    /// Swiping past this (a "full" swipe) deletes immediately on release.
    private let commitThreshold: CGFloat = 200
    /// How far the row can be dragged.
    private let maxDrag: CGFloat = 360

    var body: some View {
        ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red)
                .overlay(alignment: .trailing) {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .frame(width: revealWidth)
                        .frame(maxHeight: .infinity)
                }
                .opacity(offset < 0 ? 1 : 0)
                .contentShape(Rectangle())
                // Tap the revealed button to delete (partial-swipe path).
                .onTapGesture { if offset < 0 { commitDelete() } }

            content
                .offset(x: offset)
                .highPriorityGesture(
                    DragGesture(minimumDistance: 12)
                        .onChanged { value in
                            offset = min(0, max(-maxDrag, base + value.translation.width))
                        }
                        .onEnded { value in
                            let projected = base + value.translation.width
                            if projected <= -commitThreshold {
                                commitDelete()                 // full swipe → delete
                            } else if projected < -revealWidth / 2 {
                                snap(to: -revealWidth)         // reveal the button
                            } else {
                                snap(to: 0)                    // close
                            }
                        }
                )
        }
    }

    private func snap(to value: CGFloat) {
        withAnimation(.snappy(duration: 0.2)) { offset = value }
        base = value
    }

    private func commitDelete() {
        withAnimation(.snappy(duration: 0.2)) { offset = -maxDrag }
        onDelete()
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

    /// Selectable actions, plus the event's own type if it's a legacy `foul`
    /// (so an old foul event can still be re-classified rather than stranded).
    private var actionOptions: [EventType] {
        EventType.selectable.contains(type) ? EventType.selectable : EventType.selectable + [type]
    }

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
                        ForEach(actionOptions, id: \.self) { option in
                            Text(option.logLabel).tag(option)
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
