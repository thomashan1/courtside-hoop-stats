# Courtside Hoop Stats — Requirements & Architecture Reference

> Onboarding reference for any Claude Code session. Kept in sync with the
> implemented app — update this file as features change.
> Reflects the **v1-ready** app (2026-07-21): iPhone-only, multi-team, New Game
> form, first-name displays, FT%, and team export/import.

---

## 1. Project Overview

A native iOS app for tracking youth basketball game statistics courtside,
replacing a manual Excel spreadsheet.

**Primary user:** the tracker (Thomas's wife, Jean) operating the phone alone
during live games. **Speed, big tap targets, legibility, and error recovery** are
the top UX priorities.

**Team context:** Swish Warriors, youth league. Longer-term goal: App Store
release. Second goal (designed, deferred): let two people (Thomas + Jean) see the
same games/stats — see [`SHARING.md`](SHARING.md).

---

## 2. Tech Stack

| Concern | Decision |
|---|---|
| Platform / min target | **iOS 26** (Liquid Glass; no `if #available` fallbacks) |
| Device family | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`; #7 resolved) |
| Language / UI | Swift / SwiftUI |
| Persistence | UserDefaults + JSON (Codable) |
| Dependencies | None (zero third-party) |
| Sync | None. Manual **team export/import** via a shared `.json` file (roster-only). CloudKit `CKShare` still planned/deferred (see `SHARING.md`). |
| Dev env | Xcode 27 beta (iOS 27 SDK); test device iPhone 17 Pro |

New stored `Codable` fields are added as **optionals** so existing saved data
still decodes (a `try?` decode failure would wipe the user's games).

---

## 3. Features (current)

### 3.1 Roster (Roster tab)
- Team name (editable inline), players with **name** + **jersey number** (String, handles "0"/"00").
- Add / edit (Cancel-Save sheet) / delete / reorder players.
- **Jerseys:** a single **Home jersey** choice (Blue/White); away is the opposite.
- **Multiple teams** — the active team scopes the Roster and Games tabs; switch/
  manage teams in Settings.

### 3.2 Settings (Settings tab)
- **Text Size:** in-app `A− / A+` control (with live "Aa" preview) + **Reset to Default**. Applied app-wide as a Dynamic Type *floor* (`.dynamicTypeSize(step...)`), persisted, and still honors a larger device text size.
- **Teams:** list of teams (add / select active / open a team's detail). A team's
  detail offers **Export Team…** (`ShareLink` → a `.json` file for AirDrop/Files);
  the Teams list offers **Import Team…** (`fileImporter`) to add a team + roster
  from such a file. Export/import is **roster-only** in v1 (games excluded) — a
  local-first precursor to CloudKit sharing (`TeamTransfer.swift`, #40).

### 3.3 Games list (Games tab)
- Two sections: **Upcoming** (scheduled, soonest first) and **Games** (in-progress + completed, newest first).
- Row shows opponent, date, location, and a state indicator: **Scheduled** badge / **In Progress** badge / final score + **W/L/T** badge.
- Routing by lifecycle: scheduled → **Game Detail**; in-progress → **Live Scoring**; complete → **Game Summary**.
- Swipe-to-delete.

### 3.4 New Game (form — #44)
- Opened by the **+** button on the Games tab. **Every field is optional** —
  nothing is required to start.
- **Details:** League/Tournament and Location/Gym (each with **autocomplete** from
  prior entries), Date/start-time (picker — supports pre-scheduling), Home/Away
  toggle with a live **Jersey indicator**, and **Period format** chosen at
  creation: **4 Quarters** / **2 Halves** / **Pickup** (single running period).
- Two actions: **Start Game** (creates it in-progress and jumps straight into
  scoring) and **Save** (creates a *scheduled* game for later). The old ⚡️ "Quick
  Pickup" lightning button was removed — pickup is now just a format in this form.

### 3.5 Game Detail (scheduled games)
- Read-only summary of the matchup, with **Edit** (Cancel-Save sheet), **Start Game** (→ Live Scoring), and **Delete Game**.

### 3.6 Live Scoring — core screen
**Two-tap:** tap a player card → tap an action → event recorded immediately, then selection clears.

- **Player cards:** compact — **first name** + jersey number (e.g. `Ava #4`) over `N pts`. Grid widens with Dynamic Type. Absent players can be **benched** so they drop out of the grid.
- **Scoreboard:** solid navy banner (both appearances); our score auto-calculated (blue), opponent score in white; period label. Score scales with Dynamic Type (capped). A compact top bar (Back / Details) replaces the system nav bar; nav + tab bars are hidden while scoring.
- **Point pad:** tapping a player card raises a big point pad — **2 PT / 3 PT / FT ✓ / FT ✗** — recorded immediately; selection then clears. There is no floating action bar and no undo/redo.
- **End Period:** a tappable **quarter/half boundary at the top of the Score Log** opens a sheet to enter the opponent's cumulative total, then advances / finishes. (A pickup game has no period breaks — it just ends via **Finish Game**.)
- **Score Log:** grouped by period with quarter/half separators + per-period points; each row shows a concise action label + running team total; **tap to edit** (player/action) or **swipe to delete**.

**Events:** 2-pt (+2), 3-pt (+3), FT made (+1), FT missed (0, counts as attempt). *(Fouls are no longer tracked in the UI; the `foul` case is retained only so older saved games still decode.)*

### 3.7 Game Summary (completed games)
- Final score + W/L/T; period grid (our points derived from events, opponent from recorded totals); **editable opponent totals**.
- Player stats table (sorted by points), first names: PTS, 2P, 3P, and **FT** shown made/attempts with a whole-percent **FT%** when there's ≥1 attempt (e.g. `5/6 (83%)`).
- **Editable event log** (same component as Live Scoring). Notes field. Metadata (date, home/away, league, location, format).

### 3.8 Design / accessibility
- **Adaptive** light/dark (no forced dark mode). **Swish Warriors blue** accent (`#1E5FCF` light / `#5B9CF5` dark); navy scoreboard. Liquid Glass confined to chrome.
- Dynamic Type respected; live scoring scales; in-app Text Size control.

---

## 4. Data Model (`Models.swift`)

Key types (see source for full detail):

- `Team { name, players, homeJersey: JerseyColor? }` + `jersey(isHome:)` (away = opposite).
- `Player { id, name, number }` + `firstName`.
- `JerseyColor { white, blue }` + `opposite`.
- `EventType { twoPoint, threePoint, ftMade, ftMissed, foul }` (+ points, labels).
- `GameEvent { id, playerID, type, period, timestamp }`.
- `PeriodFormat { quarters, halves, pickup }` (pickup = 1 running period, no breaks).
- `PeriodEndScore { ourRunningTotal, opponentRunningTotal }` (opponent side authoritative; our side derived from events).
- `Game { id, date, opponent, league, location, isHome, periodFormat, events, periodEndScores, notes, isComplete, hasStarted: Bool? }`
  - Derived: `ourScore`, `opponentScore`, `currentPeriod`, `result`, `periodBreakdown()` (our points from events), `stats(for:)`, `isStarted`, and **`lifecycle` { scheduled, inProgress, complete }**.
- `PlayerStats` (derived, never stored).

---

## 5. Architecture

```
AppStore (ObservableObject, injected as @EnvironmentObject)
  ├── team, games, textSizeIndex   — @Published, didSet → save() (UserDefaults JSON)
  ├── roster/game CRUD             — addPlayer, updateGame, deleteGame(id:), …
  └── knownLeagues / knownLocations — autocomplete sources

Views
  ContentView                 — TabView (Games / Roster / Settings) + app-wide Dynamic Type floor
  ├── GamesListView           — sectioned list + value-based navigation
  │   ├── GameRowView, NewGameSheet
  │   ├── GameDetailView (+ EditGameSheet)   — scheduled game
  │   ├── LiveScoringView (+ EndPeriodSheet)
  │   └── GameSummaryView
  ├── RosterView (+ PlayerEditSheet)
  └── SettingsView            — text size; Teams list (+ TeamDetailView),
                                team export (ShareLink) / import (fileImporter)
  EventLogView (+ EventLogRow, EventEditSheet)  — shared editable log
  Models/TeamTransfer.swift   — TeamExport / TeamPackage (Transferable) for #40

Helpers/DesignSystem.swift
  Color.teamAccent (blue, adaptive), scoreboardBackground (navy),
  JerseyBadge, ScoreboardView, JerseyColor.swatch, JerseyIndicator,
  SuggestingTextField (autocomplete), AppTextSize (Dynamic Type steps)
```

`LiveScoringView` / `GameSummaryView` / `GameDetailView` hold a local `@State`
copy of the `Game` and call `store.updateGame(game)` on each mutation. No
ViewModel layer yet.

---

## 6. Key UI/UX decisions

| Decision | Choice | Reason |
|---|---|---|
| Interaction | Two-tap (player → action); selection clears after | Fast, reduces mis-attribution |
| FT tracking | Made/missed separate | Accurate FT% |
| Opponent score | Cumulative total per period (editable after) | Tracker can't follow opponent live |
| Our score | Always derived from events | No arithmetic errors; survives event edits |
| Error recovery | Tap-to-edit / swipe-to-delete any logged event | Fat-finger + after-the-fact fixes |
| Game lifecycle | scheduled → inProgress → complete | Pre-enter the season, then start |
| Color | Swish Warriors blue accent, navy scoreboard | Team identity; high courtside contrast |
| Navigation | Tabs: Games / Roster / Settings | Clear concerns |
| Accessibility | Dynamic Type + in-app Text Size floor | End user needs larger text |
| Persistence | UserDefaults JSON, optional new fields | Zero setup, migration-safe |

---

## 7. Out of scope / deferred

Game timer/shot clock · opponent player tracking · CSV/PDF export · season
summary/archiving · push · watchOS · **iPad layout** (#32, iPhone-only ships).
**CloudKit sharing** is designed but deferred (`SHARING.md`); manual team
export/import is the local-first stopgap. **App Store**: metadata is drafted
(`APP_STORE_LISTING.md`) and the icon + privacy policy are ready — the only
remaining blocker is building on a **release** Xcode (the dev Mac is on beta
macOS; see `DISTRIBUTION.md`).

## 8. Queued work

The v1 feature set has shipped. See [`TERMINAL_TODO.md`](TERMINAL_TODO.md) and
GitHub Issues for what's left — notably **#15** (CloudKit sharing) and **#32**
(iPad), both deferred.
