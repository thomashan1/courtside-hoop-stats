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
what's in a release. **v1.2 shipped 2026-08-18: read-only followers and their
notifications.** The CloudKit schema is deployed to Production and verified —
two TestFlight builds shared and followed each other's teams end to end (see
`docs/SHARING.md`). v1.3 is open, led by #57 (co-trackers).

Builds clean (0 warnings). A UI-test screenshot harness covers the main flows
(`scripts/screenshots.sh`). **iPhone-only** (`TARGETED_DEVICE_FAMILY = 1`); #32
(iPad) is open and deferred.

## What's built

- **Live scoring.** Tap a player → a big point pad (+2 / +3 / FT✓ / FT✗). No
  floating action bar, no long-press, no undo/redo. The Score Log sits on top
  (oldest-first, sticky period headers, auto-scroll) and players sit in the
  bottom thumb zone; nav + tab bars hide while scoring. Bench absent players;
  edit or reorder any entry. A made 2 or 3 offers an optional **assist** —
  always skippable, since the basket is already banked (#143).
- **On-court five & time (#144).** Optional lineup tracking: the deck splits
  into the five on the floor and the bench, **Subs** changes the whole five in
  one confirm (a bulk swap at a whistle is one sheet, not a modal per player),
  and the five narrows the assist picker to four names. Games that never set a
  lineup behave exactly as before. The **MIN** column is **wall clock inside a
  period** — no game clock exists, so stoppages count, but the break between
  periods doesn't. Whole minutes only: a seconds digit would claim a precision
  nothing measured.
- **Games.** Tap **+** for a New Game form where **every field is optional**.
  **Start Game** begins scoring immediately; **Save** schedules it. Period
  format (quarters / halves / pickup) is chosen at creation.
- **Game Summary.** Final score, cumulative by-period linescore, per-player
  stats with **FT%** (`5/6 (83%)`), editable opponent totals, editable log.
- **Box score PDF.** Game Summary → share icon → a preview of a one-page PDF.
  Print-specific layout in `GameSummaryPDF.swift` (*not* a screen capture),
  NBA-style **DNP** rows, and a tappable App Store link attached via PDFKit
  because `ImageRenderer` emits glyphs rather than annotations.
- **Teams.** Multiple teams, managed in Settings; Roster and Games follow the
  active team. **Export a Backup** writes a team + roster to `.json`
  (AirDrop/Files) and Import reads one back — roster-only, and distinct from
  sharing: a copy you own, no iCloud needed, and the only real backup.
- **Sharing & Following (#57).** A team owner can share a team via CloudKit
  `CKShare`; invitees are added by Apple Account from the system share sheet and
  get a **read-only** view in a **Following** tab that appears only when
  something is shared with them. Invite-only, no public link. See
  `docs/SHARING.md` for the architecture, four hard-won gotchas, and how to test
  it with a single device.
- **Displays.** In-game and Game Summary show **first names only**, escalating
  only on collision (`Jake` → `Jake L.` → `Jake Moore`); the Roster keeps full
  names.
- **Also live:** edit-a-finished-game, score-log reorder + movable dividers,
  location autocomplete + address, game start time, and a consistency pass
  (Cancel/Save editors, delete confirms — see `docs/UI_GUIDELINES.md`).

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

1. **#57 — co-trackers.** Read-write participants, so two people can score the
   same team. Roughly 3–4x the followers work and it *changes* code followers
   depend on, so it leads the **v1.3** milestone.
   `docs/SHARING.md` covers what it needs and names a smaller first slice
   (baton-passing rather than merging).
2. **#32 — iPad layout.** Deferred; the app is iPhone-only.

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
