import SwiftUI

/// A grouped event log. Events are grouped under period (quarter/half)
/// separators, oldest first — so the most recent entry sits at the bottom,
/// nearest the player cards / action bar.
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
    /// When true, the per-period (Q1/Q2/…) headers stick to the top of the
    /// enclosing scroll view as you scroll, so you always see the current period.
    var pinsPeriodHeaders: Bool = false
    /// Reverses the log so the newest play is at the top — periods count down
    /// and events run newest-first within each. Live Scoring wants the opposite
    /// (newest nearest the thumb, next to the buttons); a follower is watching
    /// rather than tapping, so new plays should arrive where they're looking.
    var newestFirst: Bool = false
    /// Called after any edit/delete so the caller can persist the game.
    var persist: () -> Void

    @State private var editingEvent: GameEvent?

    /// Periods that have at least one event, in display order.
    private var periodsInOrder: [Int] {
        let periods = Set(game.events.map(\.period)).sorted()
        return newestFirst ? periods.reversed() : periods
    }

    var body: some View {
        Group {
            if game.events.isEmpty {
                Text("No events yet. Select a player, then tap an action.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 14,
                           pinnedViews: pinsPeriodHeaders ? [.sectionHeaders] : []) {
                    ForEach(periodsInOrder, id: \.self) { period in
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(eventsInOrder(in: period)) { event in
                                    eventRow(event)
                                }
                            }
                        } header: {
                            periodHeader(period)
                        }
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

    /// Quarter / half separator — the sticky header when pinning is on.
    private func periodHeader(_ period: Int) -> some View {
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
        .padding(.vertical, 4)
        // Opaque behind the sticky header so scrolling rows don't show through.
        .background(pinsPeriodHeaders ? Color(.systemGroupedBackground) : Color.clear)
    }

    @ViewBuilder
    private func eventRow(_ event: GameEvent) -> some View {
        let row = EventLogRow(event: event,
                              player: player(for: event.playerID),
                              format: game.periodFormat,
                              runningTotal: cumulativeTotals[event.id] ?? 0,
                              showsChevron: isEditable)
        if isEditable {
            // Tap opens the editor (which also deletes). No custom swipe here —
            // it fought the scroll view; delete + reorder live in the List-based
            // ScoreLogEditor now (#9).
            Button { editingEvent = event } label: { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    // MARK: - Derived

    private func eventsInOrder(in period: Int) -> [GameEvent] {
        let events = game.events
            .filter { $0.period == period }
            .sorted { $0.timestamp < $1.timestamp }
        // Running totals are keyed by event id and computed over the whole
        // game, so reversing the display can't affect the numbers shown.
        return newestFirst ? events.reversed() : events
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
            // Same size as the stats table's badge: on the Game Summary both
            // sections are visible at once, and two sizes of the same bubble
            // reads as a mistake.
            JerseyBadge(number: player?.number ?? "?", size: 26)

            Text(player?.firstName ?? "Unknown")
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
