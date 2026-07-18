import SwiftUI

/// Full-screen editor for the score log (#9): a native `List` so reordering and
/// deletion use the system's own gestures — no custom swipe fighting the scroll
/// view (the inline log's old problem).
///
/// The log is one ordered sequence of **events** and **period-end markers**,
/// shown newest-first. Dragging an event or a marker across a boundary
/// reassigns periods (`Game.applyingReorderedLog`). Opponent totals ride with
/// their marker. Events can be edited (tap) or deleted (swipe); markers reorder
/// only.
struct ScoreLogEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var game: Game
    let players: [Player]
    var persist: () -> Void

    /// Newest-first display order of the log.
    @State private var items: [ScoreLogItem] = []
    @State private var editingEvent: GameEvent?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        row(for: item)
                    }
                    .onMove(perform: move)
                } footer: {
                    Text("Drag to reorder. Drag a **period divider** to move where a quarter/half ends — events that cross it change period. Swipe an event to delete.")
                }
            }
            .navigationTitle("Edit Score Log")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, .constant(.active))   // always reorderable
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingEvent) { event in
                EventEditSheet(
                    event: event,
                    players: players,
                    onSave: { updateEvent($0) },
                    onDelete: { deleteEvent(event) }
                )
            }
        }
        .onAppear { items = game.orderedLog().reversed() }
    }

    // MARK: - Rows

    @ViewBuilder
    private func row(for item: ScoreLogItem) -> some View {
        switch item {
        case .event(let event):
            Button {
                editingEvent = event
            } label: {
                EventLogRow(event: event,
                            player: player(for: event.playerID),
                            format: game.periodFormat,
                            runningTotal: cumulativeTotals[event.id] ?? 0)
            }
            .buttonStyle(.plain)
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) { deleteEvent(event) } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        case .periodEnd(let period):
            periodMarkerRow(period)
                .deleteDisabled(true)
        }
    }

    private func periodMarkerRow(_ period: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "flag.checkered")
            Text("End \(game.periodFormat.periodLabel(period))")
                .font(.subheadline).bold()
            Spacer()
            if let opp = game.periodEndScores[period]?.opponentRunningTotal {
                Text("Opp \(opp)")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(Color.teamAccent)
        .listRowBackground(Color.teamAccent.opacity(0.10))
    }

    // MARK: - Derived

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

    private func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        // `items` is newest-first; the model wants oldest-first.
        game = game.applyingReorderedLog(items.reversed())
        // Re-derive the display list so ids/periods stay in sync.
        items = game.orderedLog().reversed()
        persist()
    }

    private func updateEvent(_ updated: GameEvent) {
        guard let i = game.events.firstIndex(where: { $0.id == updated.id }) else { return }
        game.events[i] = updated
        persist()
        items = game.orderedLog().reversed()
    }

    private func deleteEvent(_ event: GameEvent) {
        game.events.removeAll { $0.id == event.id }
        persist()
        items = game.orderedLog().reversed()
    }
}
