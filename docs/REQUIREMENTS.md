# HoopsTracker — Requirements & Architecture Reference

> Use this file to onboard Claude Code or any new session.
> Last updated: based on initial design + Swift implementation session.

---

## 1. Project Overview

A native iOS app for tracking youth basketball game statistics courtside.
Replacing a manual Excel spreadsheet workflow used by a parent during games.

**Primary user:** One person (the tracker) operating the phone alone during live games.
Speed and error recovery are the top UX priorities.

**Team context:** Swish Warriors, B10U/B12U youth league (SVNJB, Choops).
Longer-term goal: publish to App Store post-retirement.

---

## 2. Tech Stack

| Concern | Decision |
|---|---|
| Platform | iOS 17+ |
| Language | Swift |
| UI framework | SwiftUI |
| Persistence | UserDefaults + JSON (Codable) |
| Dependencies | None (zero third-party) |
| Sync | None in MVP; iCloud/CloudKit later |
| Minimum target | iOS 17 |

---

## 3. Features (MVP scope)

### 3.1 Roster Management
- Enter each player's **name** and **jersey number** once per season
- Add, edit, delete, reorder players
- One team/roster per app install (no multi-team in MVP)
- Jersey number stored as String (handles "0", "00", etc.)

### 3.2 New Game Setup
Fields captured per game:
- Opponent name (required)
- League / Tournament name (optional)
- Location / Gym (optional)
- Home or Away toggle
- Period format: **4 Quarters** or **2 Halves** (league-dependent)
- Date (auto-set to now)

### 3.3 Live Scoring — Core Screen
**Interaction model: two-tap**
1. Tap a player card (highlights it as selected)
2. Tap an action button → event recorded immediately

**Trackable events per player:**
| Event | Points | Notes |
|---|---|---|
| 2-point field goal | +2 | |
| 3-point field goal | +3 | |
| Free throw made | +1 | Tracked individually for FT% |
| Free throw missed | 0 | Counted as attempt |
| Foul | 0 | Count per player |

**Scoreboard:**
- Our score: auto-calculated from all events
- Opponent score: NOT tracked live; entered as a running total at end of each period

**Period management:**
- "End Period" action opens a sheet showing our auto-calculated score
- User enters opponent's running total for that period
- Advances to next period automatically

**Undo:**
- Single "Undo last event" button removes the most recently added event
- No multi-level undo in MVP

**Event log:**
- Scrollable list of all events, most recent first
- Shows: period label, jersey badge, player name, event type, point value

### 3.4 Game Summary (post-game)
- Period-by-period score grid (e.g. Q1: 4–5, Q2: 12–9 …)
- Final score and W/L result
- Player stats table (sorted by points, descending):
  - Points, 2pt made, 3pt made, FT (made/attempts), Fouls
- Editable notes field (free text; used for scouting observations)
- Game metadata: date, opponent, location, league

### 3.5 Games List
- Reverse-chronological list of all games
- Shows: opponent, date, location, final score, W/L badge
- In-progress games navigate to Live Scoring; completed games navigate to Summary
- Swipe-to-delete

---

## 4. Data Model

```swift
struct Team: Codable {
    var name: String
    var players: [Player]
}

struct Player: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var number: String          // jersey number, stored as String
}

enum EventType: String, Codable, CaseIterable {
    case twoPoint               // +2
    case threePoint             // +3
    case ftMade                 // +1
    case ftMissed               // +0, counts as FT attempt
    case foul                   // +0
}

struct GameEvent: Identifiable, Codable {
    var id: UUID
    var playerID: UUID
    var type: EventType
    var period: Int             // 1-based
    var timestamp: Date
}

struct Game: Identifiable, Codable {
    var id: UUID
    var date: Date
    var opponent: String
    var league: String
    var location: String
    var isHome: Bool
    var periodFormat: PeriodFormat  // .quarters (4) or .halves (2)
    var events: [GameEvent]
    var periodEndScores: [Int: PeriodEndScore]   // key = period number
    var notes: String
    var isComplete: Bool
}

struct PeriodEndScore: Codable {
    var ourRunningTotal: Int        // cumulative (not delta)
    var opponentRunningTotal: Int   // cumulative (not delta)
}

// Derived — never stored
struct PlayerStats {
    let player: Player
    var points: Int
    var twoPointers: Int
    var threePointers: Int
    var ftMade: Int
    var ftAttempts: Int
    var fouls: Int
}

enum PeriodFormat: String, Codable, CaseIterable {
    case quarters   // 4 periods, label "Q"
    case halves     // 2 periods, label "H"
}
```

---

## 5. Architecture

```
AppStore (ObservableObject, singleton)
  ├── team: Team               — roster
  ├── games: [Game]            — all games, newest first
  └── CRUD methods             — addPlayer, updateGame, deleteGame, etc.
       └── didSet → save()     — auto-persist to UserDefaults on every change

Views (SwiftUI)
  ContentView              — TabView root
  ├── GamesListView        — game history + NavigationLink routing
  │   ├── GameRowView      — single row
  │   ├── NewGameSheet     — modal setup form
  │   ├── LiveScoringView  — active game tracking
  │   └── GameSummaryView  — completed game read/edit
  └── RosterView           — player CRUD
      └── PlayerEditSheet  — add/edit modal

Helpers
  DesignSystem.swift       — Color.courtGreen, JerseyBadge, ScoreboardView
```

**State flow:**
- `AppStore` injected as `@EnvironmentObject` at root
- `LiveScoringView` and `GameSummaryView` hold a local `@State` copy of `Game`
- On every mutation, they call `store.updateGame(game)` to persist
- No ViewModel layer — views are thin enough that one will be added only when complexity demands it

---

## 6. UI / UX Decisions

| Decision | Choice | Reason |
|---|---|---|
| Interaction model | Two-tap (player → action) | Fastest single-hand courtside input |
| FT tracking | Made and missed tracked separately | Enables accurate FT% calculation |
| Opponent score | Entered as running total per period | Tracker can't follow opponent events live |
| Undo | Single-level, last event only | Handles the common fat-finger case |
| Score calculation | Auto from events, never manual | Eliminates arithmetic errors |
| Period end flow | Sheet modal, required before advancing | Forces capturing opponent score at natural break |
| Color scheme | Dark forest green + bright grass green accent | Basketball / court aesthetic |
| Navigation | Tab bar: Games / Roster | Two clear concerns, no deep nav needed |
| Live game routing | GamesListView detects `isComplete` flag | Seamless tap-to-resume for in-progress games |
| Data persistence | UserDefaults JSON | Zero setup, sufficient for single-device MVP |

---

## 7. File Structure

```
HoopsTracker/
├── HoopsTrackerApp.swift           @main, injects AppStore
├── Models/
│   ├── Models.swift                All Codable data types
│   └── AppStore.swift              ObservableObject + UserDefaults persistence
├── Views/
│   ├── ContentView.swift           Root TabView
│   ├── RosterView.swift            Player list + PlayerEditSheet
│   ├── GamesListView.swift         Game history + NewGameSheet
│   ├── LiveScoringView.swift       Live scoring (player grid, action strip, event log)
│   └── GameSummaryView.swift       Stats table, period scores, notes
└── Helpers/
    └── DesignSystem.swift          Shared colors, JerseyBadge, ScoreboardView
```

---

## 8. Out of Scope for MVP

These were discussed and intentionally deferred:

- **Game timer / shot clock** — overkill for youth games; tracker doesn't need it
- **Multi-team support** — one team per install is sufficient
- **Opponent player tracking** — not needed; only opponent running score matters
- **iCloud / CloudKit sync** — post-MVP; UserDefaults is fine for one device
- **CSV / PDF export** — post-MVP; high value for App Store but not day-one
- **Season summary view** — aggregated stats across all games; post-MVP
- **Dark mode polish** — SwiftUI handles basics automatically; deep polish later
- **Push notifications** — not applicable
- **watchOS companion** — interesting idea, deferred

---

## 9. Open Questions

These were not fully resolved and need a decision before implementing:

1. **FT sub-panel UX** — should tapping "FT" on the action strip open a sub-panel with "Made" / "Missed" buttons, or are two separate top-level buttons (FT ✓ / FT ✗) cleaner? Current impl uses two buttons in the strip.

2. **Substitution / bench tracking** — the spreadsheet has players marked with "–" or "(sub)" notations. Should the app support a "benched" toggle per player per game so inactive players don't clutter the grid?

3. **Opponent score editing** — if your wife enters the wrong opponent total at period end, can she go back and fix it? Currently not exposed in the UI.

4. **Team name** — hardcoded default "My Team" in the Team model. Should there be a settings screen to rename it (especially for App Store release where other teams use it)?

5. **Multiple seasons / season reset** — the spreadsheet has 2024 and 2025-2026 seasons. Should the app support archiving/resetting the roster between seasons while keeping game history?

6. **App Store metadata** — name, icon, category, privacy policy all needed. App doesn't collect any data but Apple still requires a privacy policy URL.

---

## 10. Source Spreadsheet Reference

Original Excel file: `NH_Basketball_Games_Tracking.xlsx`

Key observations used in design:
- Team: **Swish Warriors**, B10U/B12U
- Regular players: Lucas, Nicholas, Clayton, Adrian, Mason, Bradley + rotating subs (Jake, Austin, Kaleb, Brendan, Wesley, Max, Evan, Ethan)
- Events tracked per game: shot (2pt/3pt), free throws (individual made/missed), fouls
- Quarter scores captured as running totals at end of each period
- Some games use 4 quarters (SVNJB), some use 2 halves (Choops league)
- Rich per-game notes (scouting observations, play names, substitution notes)
- Win/loss, date, opponent, location, coach name recorded per game
