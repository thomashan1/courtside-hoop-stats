# CLAUDE.md — Courtside Hoop Stats

Project context for any Claude Code session. Read this first, then
`docs/REQUIREMENTS.md` for the full product spec.

> **Backlog lives in GitHub Issues.** Work from `gh issue list` — pick an issue,
> implement it, and close it with "Closes #N" in the PR. Log new ideas and
> feedback as issues as they come up.
> Issues are grouped into **milestones** per release, so
> `gh issue list --milestone vX.Y --state closed` gives the shipped list to turn
> into App Store release notes.

## What this is

A native iOS app for tracking youth basketball game stats courtside, replacing a
manual spreadsheet. SwiftUI, **iOS 26 minimum**, zero third-party dependencies,
UserDefaults/JSON persistence. Primary user is one
person (the tracker) operating the phone alone during live games — **speed, big
tap targets, and error recovery are the top UX priorities.**

## Status

**Live on the App Store:**
<https://apps.apple.com/us/app/courtside-hoop-stats/id6791865094>

Releases are grouped by GitHub milestone — `gh issue list --milestone vX.Y` for
what's in a release, and `docs/RELEASE_HISTORY.md` for build numbers and review
turnaround. **v1.7 was approved 2026-09-17** (rebounds, notes shown to
followers, 3-pointers badged in the Score Log, a `Codable` data-loss guard).

**v1.8 is in review**, build 147: automatic **iCloud backup** of every team and
game, the **Score Log printed as page 2+** of the box score PDF, running totals
in period headers, and the REB column hidden when a game has none.

**v1.10 was approved 2026-09-21** (build 167): **overtime** for a tied game
(#199), the scheduled game's actions rebuilt (#195), and the Home Game switch
now saying which team is at home (#197). v1.9 before it moved Following to the
left of the tab bar, centred a short Score Log on its PDF page, and tightened
list density.

**v1.11 is the open train.** Bump `MARKETING_VERSION` as soon as a version is
approved — approval closes that train, and since Xcode Cloud builds every push,
the next commit fails with `ITMS-90186` even if it only touched Markdown.
Minor versions go 1.9 → 1.10 → 1.11: App Store Connect compares components
numerically, so 1.10 > 1.9, and 2.0 is saved for a release that earns it.

The CloudKit schema is deployed to Production and verified for **both**
features — sharing (two TestFlight builds shared and followed each other's
teams end to end, see `docs/SHARING.md`) and backup (`BackupTeam`/`BackupGame`
deployed 2026-09-17, write path confirmed against a real account).

Builds clean (0 warnings). A UI-test screenshot harness covers the main flows
(`scripts/screenshots.sh`). **iPhone-only** — `TARGETED_DEVICE_FAMILY = 1`, and
#32 (iPad layout) is **closed**: iPhone-only is the answer, not a backlog item.

## What's built

- **Live scoring.** Tap a player → a big point pad (+2 / +3 / FT✓ / FT✗). No
  floating action bar, no long-press, no undo/redo. The Score Log sits on top
  (oldest-first, sticky period headers, auto-scroll) and players sit in the
  bottom thumb zone; nav + tab bars hide while scoring. Bench absent players;
  edit or reorder any entry.
- **Games.** Tap **+** for a New Game form where **every field is optional**.
  **Start Game** begins scoring immediately; **Save** schedules it. Period
  format (quarters / halves / pickup) is chosen at creation.
- **Assists.** After a made basket, an optional one-tap "assisted by" step —
  skipping costs nothing. Assists show in the Score Log (`ast. Bradley`), in
  the stats table's **AST** column, and in the PDF.
- **Rebounds.** A **REB** button on its own row below the scoring buttons —
  one tap, no offensive/defensive split (that would cost a decision on every
  board, and speed wins courtside). Worth 0 points, so it's safe against games
  whose period totals are already written down.
- **Overtime.** A tie at the end of regulation *offers* **Start Overtime** in
  the same sheet that takes the opponent's total — never forces it, because a
  youth league lets ties stand. Overtime is the next period number, labelled
  **OT / 2OT / 3OT**; no schema change, since periods were already `Int`.
- **Game Summary.** Final score, cumulative by-period linescore, per-player
  stats with **FT** (`5/6`; the percentage is the PDF's, where there's room),
  editable opponent totals, editable log.
- **Box score PDF.** Game Summary → share icon → a preview. Page 1 is the
  summary; the **Score Log follows on page 2+** in two columns, each period
  closing with its score (`End Q1 Swish 24 – Lakeside 8`). Print-specific
  layout in `GameSummaryPDF.swift` / `ScoreLogPrintout.swift` (*not* a screen
  capture), NBA-style **DNP** rows, and a tappable App Store link attached to
  **every page** via PDFKit because `ImageRenderer` emits glyphs rather than
  annotations. A log short enough for one column is centred on its page.
- **iCloud backup (#177).** Every team and game is copied automatically to the
  owner's *private* CloudKit database, debounced like the follower publish.
  Settings shows "Last backed up" and offers Back Up Now plus a browse-and-pick
  restore. Deliberately **not** sharing: that's a mirror, so unsharing or
  deleting removes it. The backup zone carries no `CKShare` and no parent
  references, so nothing in the sharing code can reach it, and it's one record
  per game so a corrupt record costs one game.
- **Teams.** Multiple teams, managed in Settings; Roster and Games follow the
  active team. **Export a Backup** writes a team + roster to `.json`
  (AirDrop/Files) and Import reads one back — roster-only, and distinct from
  both sharing and the iCloud backup: a copy you own that needs no iCloud.
- **Sharing & Following (#57).** A team owner can share a team via CloudKit
  `CKShare`; invitees are added by Apple Account from the system share sheet and
  get a **read-only** view in a **Following** tab that appears only when
  something is shared with them. Invite-only, no public link. See
  `docs/SHARING.md` for the architecture, four hard-won gotchas, and how to test
  it with a single device.
- **Displays.** In-game and Game Summary show **first names only**, escalating
  only on collision (`Jake` → `Jake L.` → `Jake Moore`); the Roster keeps full
  names.
- **Tabs.** Games / Roster / Settings, plus **Following first** when a team is
  shared with you (#189) — the tab only exists if you follow someone, so a
  tracker's bar is unchanged. Leftmost is not the same as default-selected: an
  owner still lands on Games.
- **Also live:** period headers carrying the running total (`4 pts (11)`), the
  REB column hidden when a game has no rebounds, edit-a-finished-game,
  score-log reorder + movable dividers,
  location autocomplete + address, game start time, 3-pointers badged 🎉 in the
  Score Log (a `+2`/`+3` one character apart was unreadable mid-game), the
  owner's game **notes shown to followers** (and in the PDF), and a consistency
  pass (Cancel/Save editors, delete confirms — see `docs/UI_GUIDELINES.md`).

## Traps worth knowing

- **Icon-only buttons need `.minimumTapTarget()`** — below 44pt they
  intermittently miss taps.
- **`Game.stats(for:)` takes the full roster** and applies benching itself.
  Passing a pre-filtered list makes the stats table disagree with the final
  score.
- **Every change must be backward compatible. There are real saved games now** —
  Jean's actual season, on her phone, not test data. A model change that can't
  read what a previous build wrote doesn't fail loudly; `AppStore.load()`
  decodes with `try?`, so a single unreadable field silently wipes *every*
  game and roster. Assume any schema change is destroying real data until a
  test proves otherwise.
- **A default value does NOT make a `Codable` field safe.** Swift's synthesized
  `init(from:)` throws `keyNotFound` for a missing key even when the property
  has a default — verified, not assumed (`GameMigrationTests`). Only
  `Optional` fields survive on their own. `Game` therefore has a hand-written
  lenient `init(from:)` reading every field with `decodeIfPresent`: **adding a
  stored property to `Game` means adding a line there**, and adding one
  anywhere else means either making it `Optional` or giving that type the same
  treatment. `locationAddress` had exactly this latent bug for months; it
  never bit only because it landed before the v1.4 release, so no shipped
  build ever wrote a `Game` without it.
- Pair any schema change with a `GameMigrationTests`-style test that strips the
  new keys and decodes what's left. It's the only thing standing between a
  refactor and someone's season.
- **`DemoData` is test input, so re-run the tests after touching it.** The PDF
  and demo-coverage suites render the demo game, so lengthening a note or
  adding events can fail a layout assertion with no code change at all. A
  longer demo note shipped a red `testRendersASingleLetterPage` to `main`
  once, because the last test run predated the demo edit.
- **A new `EventType` case must never reach `events` on the wire.** A `Game`
  crosses to followers as one JSON blob, and an older build's `GameEvent`
  decoder *throws* on a type it doesn't recognise — failing the whole game, so
  `CloudKitSchema.game(from:)` returns nil, the caller skips it, and the game
  **silently disappears** from that follower's list. This is why assists were
  safe and rebounds weren't: `assistPlayerID` was an **optional property**
  (unknown keys are ignored), while `rebound` is a new *enum case*.
  `CloudKitSchema.payload(for:)` now keeps `events` to
  `typesEveryShippedBuildKnows` and parks newer ones under a top-level
  `laterEvents` key that old builds never read — so they see the game, score
  intact, minus the new events. **Never add to that frozen set.** Note this
  only works because rebounds are worth **0 points**; a new *scoring* type
  would make an old follower compute a wrong total and needs its own answer.
  `EventType` also decodes unknown raw values to `.unknown` as a second line of
  defence. `CloudKitWireCompatibilityTests` is the proof.
- **A period past regulation is invisible to an older build.** Overtime needed
  no new stored property — it's period 5 — which is exactly what makes it
  dangerous: an old `periodBreakdown()` loops `1...periodCount` and drops the
  row, while `ourScore` counts the baskets, so the linescore stops short of the
  scoreboard. `CloudKitSchema` folds overtime into the last regulation period
  for the wire and parks the truth under `laterPeriods`
  (`OvertimeWireCompatibilityTests`). Same shape of answer as `laterEvents`,
  and the two compose — a rebound in overtime is both problems at once.
- **`@ScaledMetric` content needs a height cap.** Uncapped, Live Scoring's
  player deck pushed the scoreboard and Score Log off the screen at
  accessibility text sizes. See `docs/UI_GUIDELINES.md` §8 — including why a
  bare `ScrollView` can't do this on its own, and how to drive text size from a
  UI test (`-uiTestTextSizeIndex`, *not* `-UIPreferredContentSizeCategoryName`).

## Naming (settled)

| Field | Value |
|---|---|
| App Store name | Courtside Hoop Stats |
| Home-screen label | Courtside |
| Xcode target / folder | `CourtsideHoopStats` |
| Bundle identifier | `com.thomashan.CourtsideHoopStats` |

## Environment

- Dev machine: Mac Mini M4, **Xcode 27 beta** (ships the iOS 27 SDK — all iOS 26
  Liquid Glass APIs available, plus iOS 27 ones).
- Test device: **iPhone 17 Pro**. Signing via free **Personal Team** (works).
- **End user (Thomas's wife):** on **iOS 26 now**, will move to iOS 27 at GM in
  **September 2026**. → Do not require iOS 27 before then.
- **Simulators installed:** iPhone 17e, iPhone Air, iPhone 14 Plus. There is no
  "iPhone 17 Pro" or plain "iPhone 17". Drive `xcodebuild` **by UDID**
  (`xcrun simctl list devices available`) — a `name=` destination that doesn't
  resolve makes `xcodebuild` dump the destination list and exit, which reads as
  a test failure. `scripts/screenshots.sh` resolves the name itself and fails
  loudly if it can't.
- **Don't run two `xcodebuild` invocations at once.** Concurrent runs share the
  simulator and DerivedData, and the UI-test runner dies at bootstrap ("Test
  crashed with signal kill before establishing connection") — which looks like a
  real test failure but isn't. Run them serially.

## Design direction (from WWDC 26 + HIG research)

- iOS 26 (current) introduced **Liquid Glass**; iOS 27 (WWDC 2026) is beta → Sept.
- **Plan: build on iOS 26 / Liquid Glass, avoid iOS 27-only APIs**, marking any
  September upgrades with `// TODO(iOS 27)`.
- **Core HIG rule:** Liquid Glass belongs in the **chrome** (nav bars, tab bar,
  floating controls), **not content**. Player cards, scoreboard numbers, and stat
  tables stay **solid and high-contrast** for courtside legibility.
- **Adopt now (iOS 26):** native controls (automatic glass), `.glassEffect()` on
  the floating action bar in Live Scoring, `GlassEffectContainer`, SF Symbols,
  Dynamic Type, `.monospacedDigit()` for scores, ≥44pt tap targets.
- **Defer to iOS 27 (comment, don't use yet):** `toolbarMinimizeBehavior`,
  item-binding `confirmationDialog`/`alert`.
- **Skip (irrelevant):** reorderable grid containers (List `.onMove` already
  works), Document API (we use UserDefaults), foldable/adaptive, AsyncImage.

## Settled decisions

1. **Minimum iOS target: iOS 26.** The only end user is on iOS 26, so this keeps
   the code simple and lets us use Liquid Glass directly (no `if #available`
   fallbacks). → `IPHONEOS_DEPLOYMENT_TARGET` is set to 26.0 (Debug + Release). ✅ done.
2. **Visual direction: adaptive.** Follow the system light/dark appearance (NO
   forced dark mode) so it stays readable in a bright gym. The accent is
   **Swish Warriors blue** — `#1E5FCF` on light, `#5B9CF5` on dark
   (`Color.teamAccent`), with a fixed navy scoreboard banner. (An early plan
   said grass-green; the app has been blue since the theme pass.) Liquid Glass
   only in the chrome (nav bar, tab bar, floating controls); content — player
   cards, scoreboard, stat tables — stays solid and high-contrast for courtside
   legibility.

## Next steps

The backlog lives in **GitHub Issues** — see `gh issue list` — grouped by
milestone.

**One open issue, paused.** #175 (shooting percentages) needs 2P/3P *attempts*,
i.e. tracking misses — and the field evidence from v1.7 is that even rebounds
are too much to catch while scoring live, which is what pauses it. The narrow
version (one team number per period) is still available if it comes back. There
are no open PRs; new work starts with a decision, not a pick-up.

**Closed doors**, with the reasoning already written down — these are settled,
not waiting:

1. **iPad is declined, twice** — #32 ("iPhone-only is the answer") and #192.
   The strongest iPad use case, reading a box score on a bigger screen, is
   already served by the PDF: a real document that opens full-size anywhere
   and carries the play-by-play since #182. What's left is the Following
   screen looking scaled-up, against a permanent cost of a second App Store
   screenshot set and two form factors to not break on every UI change.
   Reopen only for something the PDF genuinely can't deliver — "it looks big"
   isn't that.
2. **Read-write sharing is declined, three times over** — #57 (co-trackers),
   #169 (co-admin), and a public share link. Don't re-propose it without new
   information: participant management is the *owner's* privilege in CloudKit,
   so a second writer would not have solved the need that prompted #169
   ("add other followers"). `docs/SHARING.md` keeps the full analysis, and the
   prototypes are archived at `archive/144-live-lineup` and
   `archive/169-co-admin-prototype`.

**Branches are not an archive.** `origin` carries `main` plus whatever is
genuinely in flight — nothing else. A merged or closed PR's branch is deleted
(GitHub keeps the head ref, so it restores from the PR page), and a branch with
**no PR** gets an `archive/*` tag *before* it's deleted, since nothing else
would hold it: `archive/182-multipage-pdf-prototype` (the 1-vs-2-vs-3 column
comparison that chose two) and `archive/182-row-style-prototype` (eight ways to
set a printed log row, before zebra striping won) are there for that reason.
The one live exception is `proposal/175-shooting-options`, kept because #175 is
still open.
3. **Tracking minutes played / on-court five (#144)** was **abandoned**, not
   deferred — mid-game lineup tracking is too much work for the tracker. The
   salvaged part (the `Codable` guard) shipped separately.

## MVP defaults chosen for the spec's open questions

(Documented in `README.md`; all easily changed.)

- Free throws: two action buttons (`FT ✓` / `FT ✗`), not a sub-panel.
- Live grid shows the active roster; absent players can be **benched** so they
  drop out of the scoring grid without leaving the team.
- Opponent totals editable after the fact in Game Summary.
- Team name editable inline on the Roster tab.
- Player selection clears after each recorded event (reduces mis-attribution).

## Workflow & git

- **All sessions run on Thomas's Mac** (dispatch in his Mac terminal), so every
  session has the full toolchain: `xcodebuild`, the simulators, and `devicectl`
  for installing to the phone. There is **no docs-only session type** — any
  session can write Swift, build, test, and install.
- **Installing to the phones:** `scripts/install.sh [thomas|jean|all]`. It builds
  once for `generic/platform=iOS` and installs to whichever of the two phones is
  **currently reachable** — the other is skipped, not treated as a failure,
  since they're rarely home together. A failed build stops the install (it used
  to fall through and push the previous `.app`, which reads as a fix that
  changed nothing).
- **Backlog = GitHub Issues.** Every feature/bug/idea is tracked as an issue.
  Work from `gh issue list`, implement one, close it with "Closes #N" in the PR.
- **Merging to `main` ships a TestFlight build.** Xcode Cloud builds every push
  and distributes it to the *Han family* internal group — no Archive step, and
  it assigns its own build numbers rather than following
  `CURRENT_PROJECT_VERSION`. So a merge is externally visible: testers can
  install it. See `docs/APP_STORE_LISTING.md` §11.
- **Change flow:** feature work lands via **PRs**, not direct commits to `main`.
  Docs/metadata-only tweaks may go straight to `main`. Thomas device-tests builds
  before they're considered shippable.
- **⚠️ Never run two `xcodebuild` invocations at once.** They share the simulator
  and DerivedData, and the UI-test runner dies at bootstrap ("Test crashed with
  signal kill before establishing connection"), which reads as a real test
  failure but isn't. This is the main hazard of running more than one session:
  serialise the build loop, and if a subagent needs to build, give it a
  **worktree** and don't build alongside it.
- **One driver at a time** for the same files: whoever is working commits and
  pushes; the other pulls *before* starting. Avoid concurrent `project.pbxproj`
  edits.
- Project uses Xcode 16+ file-system-synchronized groups, so new Swift files are
  picked up automatically — no `.xcodeproj` editing needed to add files.
