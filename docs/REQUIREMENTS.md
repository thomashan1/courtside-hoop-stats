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
Others can follow a team **read-only** (§3.10), which is the final state, not a
stepping stone: read-write sharing has been declined three times (#57, #169,
and a public link). See [`SHARING.md`](SHARING.md).

---

## 2. Tech Stack

| Concern | Decision |
|---|---|
| Platform / min target | **iOS 26** (Liquid Glass; no `if #available` fallbacks) |
| Device family | **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`; #7 resolved) |
| Language / UI | Swift / SwiftUI |
| Persistence | UserDefaults + JSON (Codable) |
| Dependencies | None (zero third-party) |
| Sync | **CloudKit `CKShare`** for read-only followers (§3.10, `SHARING.md`), and a **private CloudKit backup** of every team and game (§3.9a). The owner's local store stays the source of truth and is mirrored up; nothing syncs back except an explicit restore. Manual **team export/import** via a `.json` file remains, as an offline copy that needs no iCloud. |
| Dev env | Xcode 27 beta (iOS 27 SDK); test device iPhone 17 Pro |

New stored `Codable` fields are added as **optionals** so existing saved data
still decodes (a `try?` decode failure would wipe the user's games).

---

## 3. Features (current)

**Tabs:** Games · Roster · Settings, plus a **Following** tab — **first in the
bar** — that appears only when someone has shared a team with you (§3.10).
Leftmost is not the same as default-selected: an owner still lands on Games. A follower sees the owner's **game notes** too, on screen and in the box score PDF — they were always published inside the game blob, so this shows what was already on their device. The editor says so where the note is typed. The "Shared by" name is **per team** on purpose — "Jean (Nicky's mom)" is a different answer for a different child's team — and the Followers screen asks for it when a shared team hasn't got one, that being the only screen where it has any effect. The team last viewed is remembered across launches, and **Switch Team** (shown only when following two or more) carries its own label rather than a bare icon.

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
    Distinct from both sharing and the iCloud backup (§3.9a): a copy you own and
    can edit, that needs no iCloud and works offline.
  - **Backup** — "Last Backed Up", what's in iCloud, **Back Up Now**, and a
    browse-and-pick **restore** (§3.9a).

### 3.3 Games list (Games tab)
- Three sections, live first (mid-game it's the row you're reaching for):
  **Playing Now**, **Coming Up** (soonest first), **Final Scores** (newest first).
- Start time is picked in **5-minute steps** (`GameDatePicker`). Not 1 — spinning sixty positions at the gym door is the thing that control exists to avoid — and not 10, which can't reach a 2:45 tip-off at all.
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
- **Point pad:** tapping a player card raises a big point pad — **2 PT / 3 PT / FT ✓ / FT ✗**, with **REB** on its own full-width row below — recorded immediately; selection then clears. There is no floating action bar and no undo/redo. REB sits apart from the scoring buttons on purpose: it's worth no points, so a mis-tap beside `+2` would silently change the score.
- **End Period:** a tappable **quarter/half boundary at the top of the Score Log** opens a sheet to enter the opponent's cumulative total, then advances / finishes. (A pickup game has no period breaks — it just ends via **Finish Game**.)
- **Overtime (#199):** when the total typed at the end of regulation **ties** the score, that same sheet offers **Start Overtime** beside Finish. Offered, never forced — a youth league will let a tie stand, and this one does. Overtime is simply the next period number, labelled **OT / 2OT / 3OT**; still level at the end of OT and the offer repeats. Nothing new is stored: `GameEvent.period` and `periodEndScores` are already `Int`-keyed, so no schema change and no migration.
- **Score Log:** grouped by period with quarter/half separators + per-period points; each row shows a concise action label + running team total, with **3-pointers badged 🎉** so they're distinguishable from a two at a glance; **tap to edit** (player/action) or **swipe to delete**.

**Events:** 2-pt (+2), 3-pt (+3), FT made (+1), FT missed (0, counts as attempt), **rebound (0)**. *(Fouls are no longer tracked in the UI; the `foul` case is retained only so older saved games still decode.)*

Period headers in the Score Log show the points scored in that period **and the running total at the end of it** — `4 pts (11)`. Computed *through* the period rather than "everything above this row", so it still reads correctly in a follower's log, which runs newest-period-first. Every running total in the log is bracketed, rows included, so they form one column.

A rebound is a full event, not a counter — it lands in the Score Log and can be edited, reordered or deleted there like anything else, because error recovery matters more than tidiness. It renders as a **subordinate row**: no card, indented, one grey line. At a real game's rebound volume, full cards buried the baskets and the log stopped answering the question it exists for — what just happened to the score. An **FT miss is not** subordinate: it's an attempt, it moves FT%, and it's half of a stat the table shows.

**Overtime is folded into regulation on the wire.** An older build's
`periodBreakdown()` loops `1...periodCount`, so it can't see a period past
regulation — while `ourScore`, summed from every event, can. It would show a
linescore ending 38–38 under a scoreboard reading 40–46. So the published copy
moves overtime events into the last regulation period and gives that period's
marker the **final** totals, parking the true periods under `laterPeriods`. An
old follower sees what a tracker used to do by hand — overtime scored inside Q4
— with the score right; a current one puts the periods back.

**A new `EventType` case must never reach `events` on the wire.** A `Game` reaches followers as one JSON blob, and an older build's `GameEvent` decoder throws on a type it doesn't recognise — failing *the whole game*, so `CloudKitSchema.game(from:)` returns nil, the caller skips it, and the game silently disappears from that follower's list. (Assists escaped this because `assistPlayerID` is an optional *property* and unknown keys are ignored; a new enum case is different.)

`CloudKitSchema.payload(for:)` keeps `events` to the types every shipped build knows and parks newer ones under a top-level `laterEvents` key an old `Game.init(from:)` never reads. An old follower sees the game with the correct score and no rebounds; a current one gets them merged back. This works only because a rebound is worth **0 points** — a new *scoring* type would leave an old follower computing a wrong total and needs a different answer. `EventType` additionally decodes unknown raw values to `.unknown` as a second line of defence.

### 3.7 Game Summary (completed games)
- Final score + W/L/T (`GameScoreCard`, shared with the follower's detail); period grid (our points derived from events, opponent from recorded totals); **editable opponent totals**.
- Player stats table (sorted by points), first names: PTS, 2P, 3P, **AST**, **REB**, then **FT** as made/attempts (`5/6`). **REB is hidden entirely when no player in that game has one** — rebounds are hard to catch while scoring live, so a column of zeroes is the common case and reads as "nobody got one" rather than "nobody recorded one". REB was the seventh column and the last of the slack at the default text size; anything further needs a column removed, not added. The whole-percent **FT%** (`5/6 (83%)`) is the **PDF's** — on a phone that column is roughly three times the width of any other, and the Player column is sized by the longest name on the roster, so a long name leaves too little for it. The fraction says the same thing in a third of the space. A stat the player didn't record is drawn in grey rather than full contrast, on screen and in the PDF alike — a youth roster puts several all-zero rows in the table and a wall of identical `0`s buries the two or three who carried the game. Grey, not a dash: `—` already means *no data* here, and the DNP row exists to keep "played, didn't score" distinct from "wasn't there". `0/1 (0%)` stays full contrast — a missed free throw is a real event; `0/0` is not. FT is deliberately **last**: it's three times the width of any other value, so anywhere else it pushes the columns to its right off the edge, and it's the least urgent number mid-game. The same table and order appear in the Game Summary, the live **Stats** panel and a follower's game view — the live panel is the narrowest of the three and the one a new column has to fit.
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

Game Summary → share icon → a preview, with Share in the preview's toolbar.
**Page 1 is the box score; the Score Log follows on page 2+** in two columns
(#182). Each period closes with its score — `End Q1  Swish 24 – Lakeside 8` —
rather than opening with it, which read as the score *going into* the quarter.
Rows are zebra-striped, because the action and running total are already in
hard columns and what fails is the eye tracking across the gap from the name.
A log short enough for a single column is **centred on its page**, horizontally
and vertically; a multi-page log's short final page is not, since a half-filled
last column centred reads as a bug. Two columns rather than one because a
rebound-heavy game is 2 pages instead of 3. `GameSummaryPDF.swift` holds a **print-specific layout**, not
a capture of the summary screen — but it derives every number from the same
model methods the screen uses (`Game.stats(for:)`,
`Game.periodBreakdownCumulative()`), so the two can't disagree. Page is sized to
its content with a US Letter minimum, so a normal game is exactly one page and a
long roster grows rather than clipping. Players who didn't play are listed
**DNP**. Every page carries the same footer — wordmark, App Store link, app version and
build, page number — because a log page gets forwarded on its own and a PDF
outlives the app that made it. The footer's App Store link is a PDFKit **link
annotation** added to **every page** after rendering, because `ImageRenderer`
emits glyphs rather than annotations.

### 3.9a iCloud backup (#177)

Every team and game is copied automatically to the owner's **private** CloudKit
database, on a debounce like the follower publish and protected by the same
background-task assertion. Settings shows **"Last Backed Up"**, what's in
iCloud, a **Back Up Now** button, and a **browse-and-pick restore**.

**Not sharing, deliberately.** Sharing is a *mirror*: unshare or delete a team
and it's gone for followers, so it can never be the backup. The backup zone
carries **no `CKShare` and no parent references**, so nothing in the sharing
code — `stopSharing`'s zone delete, `deleteGamesNoLongerPresent` — can reach
it. **One record per game**, not one archive blob, because surviving a corrupt
record is the entire point.

**Restore only ever adds.** It merges by id and never overwrites or deletes, so
it's safe to tap when unsure — which matters, because you reach for a restore
exactly when you can least afford a destructive surprise. A game picked from a
team that isn't on the phone brings its team with it, or it would arrive
orphaned. Deleting a game locally deletes it from the backup too: keeping
everything forever sounds safer but makes the backup diverge from what the user
believes they have.

`BackupTeam`/`BackupGame` were deployed to the Production CloudKit schema on
2026-09-17. **A new record type must be deployed before it can be used at all**
— Development auto-creates types, Production does not, and TestFlight runs
against Production.

### 3.10 Sharing & Following (#57)
- **Owner:** Settings ▸ Teams ▸ ⓘ ▸ **Share with Followers** creates a CloudKit
  `CKShare` for that team and opens the system invite sheet. Invitees are added
  by the email/phone on their Apple Account and the link goes out via Messages /
  Mail / AirDrop. Re-sharing reuses the existing share rather than making a
  second one.
- **Permissions:** **read-only, invite-only** — a settled decision, not a gap.
  No "Can edit" (read-write was explored twice and declined; see
  [`SHARING.md`](SHARING.md)) and no public link (a forwardable URL to a
  children's roster is the wrong default, and the trade for link-joining is
  losing *control* of who joins, not gaining visibility).
- **Follower:** a **Following tab** appears only when a team is actually shared
  with you. It lists each followed team's games with scores and a **Live** flag,
  opening to a read-only detail (score card, player stats, per-period
  breakdown). No scoring or editing anywhere in it. The detail leads with the
  **same `GameScoreCard` the Game Summary uses**, not Live Scoring's navy
  banner: a scheduled game shows dashes with its **day and** tip-off time (the follower's band says "Following" where the owner's says the date, so this is the only place a follower can see *when* an upcoming game is), a live one the
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

- `Team { id, name, players, homeJersey: JerseyColor?, teamColor: JerseyColor?, ownerDisplayName: String? }` +
  `jersey(isHome:)`. The optionals are optional so older saved teams decode;
  `kitColor` defaults to blue, which is what they had, and `ownerDisplayName`
  is the per-team "Shared by" name (§3).
- `Player { id, name, number }` + `firstName`.
- `JerseyColor { white, blue }` + `opposite`.
- `EventType { twoPoint, threePoint, ftMade, ftMissed, rebound, foul, unknown }`
  (+ points, labels). `foul` is retained only so older games decode; `unknown`
  is never recorded — it's where an event type written by a *newer* build lands,
  so it degrades instead of throwing (§3.6).
- `GameEvent { id, playerID, type, period, timestamp, assistPlayerID: UUID? }`.
- `PeriodFormat { quarters, halves, pickup }` (pickup = 1 running period, no breaks).
- `PeriodEndScore { ourRunningTotal, opponentRunningTotal }` (opponent side authoritative; our side derived from events).
- `Game { id, teamID: UUID?, date, opponent, league, location, locationAddress, isHome, periodFormat, events, periodEndScores, notes, benchedPlayerIDs, isComplete, hasStarted: Bool? }`
  - Derived: `ourScore`, `opponentScore`, `currentPeriod`, `result`, `periodBreakdown()` (our points from events), `stats(for:)`, `isStarted`, and **`lifecycle` { scheduled, inProgress, complete }**.
  - **Decodes leniently.** `Game` has a hand-written `init(from:)` (in an extension, so the memberwise init survives) reading every field with `decodeIfPresent`. This is a data-loss guard, not style: `AppStore.load()` uses `try?`, so one missing key silently wipes every saved game, and Swift's synthesized decoder throws on a missing key *even when the property has a default*. **Adding a stored property to `Game` means adding a line there**, covered by `GameMigrationTests`.
- `PlayerStats` (derived, never stored).

---

## 5. Architecture

```
AppStore (ObservableObject, injected as @EnvironmentObject)
  ├── teams, activeTeamID, games,  — @Published, didSet → save() (UserDefaults JSON)
  │   textSizeIndex, followedTeams,
  │   alertCadence, sharedTeamIDs
  ├── roster/game CRUD             — addPlayer, updateGame, deleteGame(id:), …
  ├── backupSnapshot / backUpNow / — iCloud backup (§3.9a), debounced
  │   restoreFromBackup
  └── knownLeagues / knownLocations — autocomplete sources

Views
  ContentView                 — TabView (Following, when following / Games /
                                Roster / Settings) + app-wide Dynamic Type floor
  ├── GamesListView           — sectioned list + value-based navigation
  │   ├── GameRowView, NewGameSheet
  │   ├── GameDetailView (+ EditGameSheet)   — scheduled game
  │   ├── LiveScoringView (+ EndPeriodSheet, StatsPanels)
  │   └── GameSummaryView (+ GameSummaryPDF, ScoreLogPrintout)
  ├── FollowingView           — a follower's read-only games and game detail
  ├── FollowersView           — the owner's side: who this team is shared with
  ├── RosterView (+ PlayerEditSheet)
  └── SettingsView            — text size; Teams list (+ TeamDetailView),
                                team export (ShareLink) / import (fileImporter),
                                backup status (+ BackupBrowserView)
  EventLogView (+ EventLogRow, EventEditSheet)  — shared editable log
  Models/TeamTransfer.swift   — TeamExport / TeamPackage (Transferable) for #40

Sharing/
  SharingService / CloudKitSharingService   — CKShare publish + fetch (#57)
  CloudKitSchema                            — Game ⇄ CKRecord, incl. the
                                              `laterEvents` wire guard (§3.6)
  CloudKitBackupService                     — the private backup zone (§3.9a)
  FollowerNotifier / FollowerAlerts         — silent push → local notification
  ShareAcceptance                           — accepting an invite

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
| Navigation | Tabs: **Following** (first, when a team is shared with you) / Games / Roster / Settings | The extra tab appears only when it has content, so a tracker's bar is unchanged; leftmost ≠ default-selected, and an owner still lands on Games |
| Accessibility | Dynamic Type + in-app Text Size floor | End user needs larger text |
| Persistence | UserDefaults JSON, optional new fields | Zero setup, migration-safe |

---

## 7. Out of scope / deferred

Game timer/shot clock · opponent player tracking · CSV export · season
summary/archiving · watchOS · **iPad layout** (#32 closed — iPhone-only is the
decision, and `TARGETED_DEVICE_FAMILY = 1` enforces it).

**iPad** is declined twice (#32, #192): the strongest use case — reading a box
score on a bigger screen — is already served by the PDF, and supporting iPad
costs a second App Store screenshot set and a second form factor to not break,
permanently.

**Sharing:** read-only followers shipped in v1.2 (§3.10), and so did the two
things this section used to list as pending — **push notifications** for
followers and **publish-on-edit** (a debounced publish, protected by a
background-task assertion). **Co-trackers / read-write sharing is declined**,
not pending: see [`SHARING.md`](SHARING.md) for the analysis and where the
prototypes are archived.

**App Store**: live; see [`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) for
listing copy and the per-release checklist.

## 8. Queued work

Tracked in GitHub Issues, grouped by milestone —
`gh issue list --milestone vX.Y --state closed` for what shipped in a release,
`gh issue list` for what's open. Not restated here; it rots.
