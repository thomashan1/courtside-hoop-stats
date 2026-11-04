import AppIntents
import CoreSpotlight

// Siri and Shortcuts (#255): read-only questions about your own teams. Nothing
// here writes to the store, so none of it can touch saved games or sync.

/// One of the owner's teams, as Siri and Shortcuts see it. Indexed in
/// Spotlight so Siri can search for it by name (#256); without the index
/// Siri "had nothing to search".
struct TeamEntity: AppEntity, IndexedEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Team"
    static let defaultQuery = TeamQuery()

    let id: UUID
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ team: Team) {
        id = team.id
        name = team.name
    }
}

struct TeamQuery: EntityStringQuery {
    @MainActor func entities(for identifiers: [UUID]) async throws -> [TeamEntity] {
        SiriStore.teams.filter { identifiers.contains($0.id) }.map(TeamEntity.init)
    }

    @MainActor func entities(matching string: String) async throws -> [TeamEntity] {
        SiriStore.teams.filter { $0.name.localizedStandardContains(string) }.map(TeamEntity.init)
    }

    @MainActor func suggestedEntities() async throws -> [TeamEntity] {
        SiriStore.teams.map(TeamEntity.init)
    }
}

/// The app's own store, handed over at launch so Siri says what the app shows.
/// Not `@Dependency`: that needs a `Sendable` store, and `AppStore` isn't one.
@MainActor enum SiriStore {
    static var current: AppStore?

    static var teams: [Team] { current?.teams ?? [] }

    /// Replaces the indexed teams with `teams`: cleared first, so a deleted
    /// or renamed team doesn't linger, nor the demo season after a UI test.
    static func index(_ teams: [Team]) async {
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: TeamEntity.self)
        try? await index.indexAppEntities(teams.map(TeamEntity.init))
    }

    /// What a question about `entity` answers — the team named, or else the
    /// active team (the one the Games tab shows).
    static func answer(about entity: TeamEntity?, _ say: (Team, [Game]) -> String) -> String {
        guard let store = current else { return "Open Courtside once, then ask again." }
        let team = entity.flatMap { e in store.teams.first { $0.id == e.id } } ?? store.team
        return say(team, store.games)
    }
}

struct LastGameScoreIntent: AppIntent {
    static let title: LocalizedStringResource = "Last Game Score"
    // Siri's planner reads these to choose an intent (#256): without them it
    // answered "how did we do" from the open screen, or from the web.
    static let description = IntentDescription(
        "Tells you the final score of a youth basketball team's most recent finished game, kept in Courtside: who won, the opponent, and the date.",
        categoryName: "Basketball Games",
        searchKeywords: ["score", "last game", "result", "won", "lost", "basketball"])

    @Parameter(title: "Team", description: "One of your teams in Courtside. Leave empty for the team open in the app.")
    var team: TeamEntity?

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = SiriStore.answer(about: team, SiriAnswers.lastGame)
        return .result(dialog: "\(answer)")
    }
}

struct TeamRecordIntent: AppIntent {
    static let title: LocalizedStringResource = "Team Record"
    static let description = IntentDescription(
        "Tells you a youth basketball team's season record in Courtside: wins, losses and ties across its finished games.",
        categoryName: "Basketball Games",
        searchKeywords: ["record", "wins", "losses", "season", "standings", "basketball"])

    @Parameter(title: "Team", description: "One of your teams in Courtside. Leave empty for the team open in the app.")
    var team: TeamEntity?

    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let answer = SiriStore.answer(about: team, SiriAnswers.record)
        return .result(dialog: "\(answer)")
    }
}

/// Phrases that work with no setup. Apple requires the app's name in each,
/// so "What was the score" alone can't reach us — "…in Courtside" does.
struct CourtsideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LastGameScoreIntent(),
            phrases: [
                // First, because the in-app tip shows the first phrase. "What
                // was the score of the last game…" stays, but Siri Evaluations
                // found Siri answering it as a sports question every time.
                "Last game score in \(.applicationName)",
                "What was the score of the last game in \(.applicationName)",
                "How did \(\.$team) do in \(.applicationName)",
                "How did we do in our last game in \(.applicationName)",
                "Did \(\.$team) win their last game in \(.applicationName)",
            ],
            shortTitle: "Last Game Score",
            systemImageName: "basketball"
        )
        AppShortcut(
            intent: TeamRecordIntent(),
            phrases: [
                "What's our record in \(.applicationName)",
                "\(.applicationName) record",
                "What's \(\.$team)'s record in \(.applicationName)",
                "How many games have we won in \(.applicationName)",
            ],
            shortTitle: "Team Record",
            systemImageName: "trophy"
        )
    }
}
