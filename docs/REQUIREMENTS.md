# Courtside Hoop Stats — Requirements & Architecture Reference

> Onboarding reference for any Claude Code session. Describes the app as it is
> now — update this file as features change, rather than appending history.
> **Live on the App Store:**
> <https://apps.apple.com/us/app/courtside-hoop-stats/id6791865094>

---

## 1. Project Overview

A native iOS app for tracking youth basketball game statistics courtside,
replacing a manual Excel spreadsheet.

**Primary user:** the tracker (Thomas's wife, Jean) operating the phone alone
during live games. **Speed, big tap targets, legibility, and error recovery** are
the top UX priorities.

**Team context:** Swish Warriors, youth league. Shipped to the App Store.
Others can follow a team read-only (§3.10). Next: co-trackers
who can edit, and read-only followers — see [`SHARING.md`](SHARING.md) and #57.

---

## 2. Tech Stack

| Concern | Decision |
|---|---|
| Platform / min target | **iOS 26** (Liquid Glass; no `if #available` fallbacks) |
| Device family | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`; #7 resolved) |
| Language / UI | Swift / SwiftUI |
| Persistence | UserDefaults + JSON (Codable) |
| Dependencies | None (zero third-party) |
| Sync | **CloudKit `CKShare`** for read-only followers (§3.10, `SHARING.md`). The owner's local store stays the source of truth and is mirrored up; nothing syncs back. Manual **team export/import** via a `.json` file remains, as a backup and an offline copy. |
| Dev env | Xcode 27 beta (iOS 27 SDK); test device iPhone 17 Pro |

New stored `Codable` fields are added as **optionals** so existing saved data
still decodes (a `try?` decode failure would wipe the user's games).

---

## 3. Features (current)

**Tabs:** Games · Roster · Settings, plus a **Following** tab that appears only
when someone has shared a team with you (§3.10).

### 3.1 Roster (Roster tab)
- Team name (editable inline), players with **name** + **jersey number** (String, handles "0"/"00").
- Add / edit (Cancel-Save sheet) / delete / reorder players.
- **Jerseys:** a team is **white plus one colour of its own** (blue, red, green,
  black, gold, purple, orange, maroon, grey). Pick the colour, then which of the
  two is worn at home; away wears the other. Editing lives in Settings ▸ Teams ▸ ⓘ.
- **Multiple teams** — the active team scopes the Roster and Games tabs; switch/
  manage teams in Settings.

### 3.2 Settings (Settings tab)
- **Text Size:** in-app `A− / A+` control (with live "Aa" preview) + **Reset to Default**. Applied app-wide as a Dynamic Type *floor* (`.dynamicTypeSize(step...)`), persisted, and still honors a larger device text size.
- **Teams:** list of teams (add / select active / open a team's detail). A team's
  detail offers, in order:
  - **Share with Followers** — CloudKit `CKShare`; invite people by Apple Account
    from the system share sheet so they can watch this team read-only. See §3.9.
  - **Export a Backup** (`ShareLink` → a `.json` file for AirDrop/Files); the
    Teams list offers **Import Team…** (`fileImporter`) to add a team + roster
    from such a file. Roster-only — games excluded (`TeamTransfer.swift`, #40).
    Distinct from sharing: a copy you own and can edit, needs no iCloud, works
    offline, and is the only real backup.

### 3.3 Games list (Games tab)
- Three sections, live first (mid-game it's the row you're reaching for):
  **Playing Now**, **Coming Up** (soonest first), **Final Scores** (newest first).
- Row shows opponent, date + start time with the **weekday** ("Tue, Aug 4 at
  11:40 AM" — the year is dropped in-season), location, and a state indicator:
  **Scheduled** badge / **In Progress** badge / final score + **W/L/T** badge.
  The date outranks the gym name when the two compete for width.
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
- Final score + W/L/T (`GameScoreCard`, shared with the follower's detail); period grid (our points derived from events, opponent from recorded totals); **editable opponent totals**.
- Player stats table (sorted by points), first names: PTS, 2P, 3P, and **FT** shown made/attempts with a whole-percent **FT%** when there's ≥1 attempt (e.g. `5/6 (83%)`).
- Players benched for the game are listed below the scorers as **DNP** rather
  than dropped — a roster that silently loses people reads as a bug, and zeroes
  would wrongly say "played, didn't score". A benched player who *did* record
  something keeps a normal row (#59). Shared by the summary, the follower's
  view, and the PDF via `Game.didNotPlay(from:)`.
- **Editable event log** (same component as Live Scoring). Notes field. Metadata (date, home/away, league, location, format).

### 3.8 Design / accessibility
- **Adaptive** light/dark (no forced dark mode). **Swish Warriors blue** accent (`#1E5FCF` light / `#5B9CF5` dark); navy scoreboard. Liquid Glass confined to chrome.
- Dynamic Type respected; live scoring scales; in-app Text Size control.

### 3.9 Box score PDF (#55)

Game Summary → share icon → a preview of a one-page box score, with Share in the
preview's toolbar. `GameSummaryPDF.swift` holds a **print-specific layout**, not
a capture of the summary screen — but it derives every number from the same
model methods the screen uses (`Game.stats(for:)`,
`Game.periodBreakdownCumulative()`), so the two can't disagree. Page is sized to
its content with a US Letter minimum, so a normal game is exactly one page and a
long roster grows rather than clipping. Players who didn't play are listed
**DNP**. The footer's App Store link is a PDFKit **link annotation** added after
rendering, because `ImageRenderer` emits glyphs rather than annotations.

### 3.10 Sharing & Following (#57)
- **Owner:** Settings ▸ Teams ▸ ⓘ ▸ **Share with Followers** creates a CloudKit
  `CKShare` for that team and opens the system invite sheet. Invitees are added
  by the email/phone on their Apple Account and the link goes out via Messages /
  Mail / AirDrop. Re-sharing reuses the existing share rather than making a
  second one.
- **Permissions:** **read-only, invite-only.** No "Can edit" (co-tracker writes
  aren't implemented) and no public link (a forwardable URL to a children's
  roster is the wrong default).
- **Follower:** a **Following tab** appears only when a team is actually shared
  with you. It lists each followed team's games with scores and a **Live** flag,
  opening to a read-only detail (score card, player stats, per-period
  breakdown). No scoring or editing anywhere in it. The detail leads with the
  **same `GameScoreCard` the Game Summary uses**, not Live Scoring's navy
  banner: a scheduled game shows dashes and its tip-off time, a live one the
  current period in place of a result, a finished one WIN/LOSS/TIE and "Final".
- **Liveness:** honest rather than "live" — updates land in seconds with signal,
  and catch up in a burst after a dead-zone gym. Every followed team shows an
  "Updated N ago" line. An open live game re-fetches every 20s on its own.
- **Notifications:** game start, each period end, and the final score, with a
  cadence setting (every score / each period / start and final / off) in
  Settings. CloudKit wakes the app silently; the app fetches and posts a local
  notification carrying the real score.
- **Storage:** followed teams are cached in `AppStore.followedTeams`, held
  **separately from `teams`** so read-only data never reaches an editor, and
  persisted so a follower with no signal still sees the last known score.
- Requires an Apple Account on an Apple device; Android/web followers are out of
  scope. Full detail, gotchas, and single-device testing notes in
  [`SHARING.md`](SHARING.md).

---

## 4. Data Model (`Models.swift`)

Key types (see source for full detail):

- `Team { name, players, homeJersey: JerseyColor?, teamColor: JerseyColor? }` +
  `jersey(isHome:)`. Both optional so older saved teams decode; `kitColor`
  defaults to blue, which is what they had.
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

Game timer/shot clock · opponent player tracking · CSV export · season
summary/archiving · watchOS · **iPad layout** (#32, iPhone-only ships).

**Sharing:** read-only followers ship in v1.2 (§3.10). Still to come:
**co-trackers** (read-write participants, which is where a synced Core Data
store becomes necessary), **push notifications** for followers, and
**publish-on-edit** so a followed game updates continuously rather than at share
time. See [`SHARING.md`](SHARING.md).

**App Store**: live; see [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) for
listing copy and the per-release checklist.

## 8. Queued work

Tracked in GitHub Issues, grouped by milestone —
`gh issue list --milestone vX.Y --state closed` for what shipped in a release,
`gh issue list` for what's open. Not restated here; it rots.
