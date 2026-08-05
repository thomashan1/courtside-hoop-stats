# CLAUDE.md — Courtside Hoop Stats

Project context for any Claude Code session. Read this first, then
`docs/REQUIREMENTS.md` for the full product spec.

> **Backlog lives in GitHub Issues.** Work from `gh issue list` — pick an issue,
> implement it, and close it with "Closes #N" in the PR. Log new ideas and
> feedback as issues as they come up.
> Issues are grouped into **milestones** per release, so
> `gh issue list --milestone v1.1 --state closed` gives the shipped list to turn
> into App Store release notes.
> (`docs/TERMINAL_TODO.md` is retired — it's now just a pointer + a log of
> already-completed work.)

## What this is

A native iOS app for tracking youth basketball game stats courtside, replacing a
manual spreadsheet. SwiftUI, **iOS 26 minimum**, zero third-party dependencies,
UserDefaults/JSON persistence. Primary user is one
person (the tracker) operating the phone alone during live games — **speed, big
tap targets, and error recovery are the top UX priorities.**

## Current status (2026-08-05) — **live on the App Store** 🎉

- **v1.0 is approved and public:**
  <https://apps.apple.com/us/app/courtside-hoop-stats/id6791865094>
  The old "beta macOS ⇒ beta Xcode ⇒ rejected binary" blocker is **resolved** —
  submitting works. Development-signed installs straight to a device still work
  for day-to-day testing (see the device-install flow).
- **v1.1 is complete in git and awaiting submission.** Version bumped to
  **1.1 (build 17)** — Apple closes a version's train once approved, so 1.0
  couldn't take another build. Milestone `v1.1` = #56, #59, #55, all merged.
- All four screens are live and device-tested on Thomas's iPhone 17 Pro:
  **Roster, Games, Live Scoring, Game Summary**, plus multi-team management in
  Settings. Builds clean (0 warnings); a UI-test screenshot harness verifies the
  main flows (`scripts/screenshots.sh`).
- **iPhone-only (#7 resolved):** `TARGETED_DEVICE_FAMILY = 1`. No iPad layout;
  #32 (iPad) remains open/deferred.
- **Real app icon** shipped (basketball + stat bars on blue) — no longer a
  placeholder.
- **Live scoring (Jean's feedback).** Tap a player → a big point pad
  (+2 / +3 / FT✓ / FT✗); no floating action bar, no long-press, no undo/redo.
  The Score Log is on top (oldest-first, sticky period headers, auto-scroll);
  players sit in the bottom thumb zone. Nav + tab bars are hidden while scoring
  for space. Bench absent players; edit/reorder any entry.
- **New Game form (#44):** tap **+** → a form where **every field is optional**.
  **Start Game** begins scoring immediately; **Save** schedules it for later.
  Period format (quarters / halves / pickup) is chosen at creation. The old ⚡️
  "Quick Pickup" lightning button was removed.
- **Displays:** in-game and Game Summary show **first names only**; the Roster
  keeps full names (#42). The stats table shows **FT%** (e.g. `5/6 (83%)`, #41).
- **Team export / import (#40):** share a team + roster as a `.json` file via
  ShareLink (AirDrop / Files) — Export in a team's detail, Import from the Teams
  list in Settings. Roster-only in v1; a manual, local-first precursor to
  CloudKit sharing.
- **Box score PDF (#55, v1.1):** Game Summary → share icon → a preview of a
  one-page PDF, with Share in the preview's own toolbar. Print-specific layout
  in `GameSummaryPDF.swift` (*not* a capture of the summary screen), first names
  disambiguated only on collision (`Jake` → `Jake L.` → `Jake Moore`), NBA-style
  **DNP** rows, filename naming both teams, and a tappable App Store link in the
  footer. `ImageRenderer` emits glyphs rather than annotations, so that
  hyperlink is attached afterwards via PDFKit.
- **Also live:** multiple teams (#20), edit-a-finished-game (#8), score-log
  reorder + movable dividers (#9), location autocomplete (#13) + address, game
  start time, consistency pass (Cancel/Save editors, delete confirms — see
  `docs/UI_GUIDELINES.md`), `.pickup` format (#34/#35).
- **Recent fixes (v1.1):** the `+` button occasionally not responding (#56 —
  icon-only buttons were smaller than the 44pt minimum; use
  `.minimumTapTarget()`), and benching a player who had already scored making
  the stats table disagree with the final score (#59 — `Game.stats(for:)` now
  takes the **full roster** and does the benching itself; pass the whole roster,
  not a pre-filtered list).
- **Deferred:** multi-user sharing (#57, CloudKit `CKShare` — see
  `docs/SHARING.md`). Note #15 was **merged into #57**: co-trackers and
  followers are the same mechanism at different participant permission levels.

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
- **Simulators:** there is **no "iPhone 17 Pro" simulator** installed, despite
  that being the default in `scripts/screenshots.sh`. Use **"iPhone 17"** for
  `xcodebuild` destinations, or pass a name to the script.
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
   forced dark mode) so it stays readable in a bright gym. Grass-green as the
   accent color. Liquid Glass only in the chrome (nav bar, tab bar, floating
   controls); content — player cards, scoreboard, stat tables — stays solid and
   high-contrast for courtside legibility.

## Next steps

The backlog lives in **GitHub Issues** — see `gh issue list` — and releases are
grouped by **milestone** (`gh issue list --milestone v1.1 --state closed` gives
the shipped list to turn into App Store release notes).

1. **Submit v1.1.** The code is merged and the version is bumped; it just needs
   an archive + upload. Description, keywords, screenshots and "What's New" all
   require a new version *with a build attached* — only **promotional text** is
   editable without review, so metadata edits ride along with this submission.
   Practical notes: updates typically clear review in **~1 day** (the queue, not
   the review, is the long pole); submitting **Tue/Wed morning** roughly halves
   the wait; choose **Manual release** so approval and go-live are decoupled.
2. **#57 — multi-user sharing** (CloudKit `CKShare`; `docs/SHARING.md`). The big
   one, and the largest architectural change the app would take: persistence
   moves off `UserDefaults`/JSON. Ship **read-only followers first** (no write
   conflicts, and there's real demand — two friends asked to follow games), then
   read-write co-trackers. Budget a longer review runway: new entitlements plus
   a changed privacy declaration is the profile that draws a rejection.
3. **#32 — iPad layout.** Deferred; the app is iPhone-only.

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
- **Backlog = GitHub Issues.** Every feature/bug/idea is tracked as an issue.
  Work from `gh issue list`, implement one, close it with "Closes #N" in the PR.
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
