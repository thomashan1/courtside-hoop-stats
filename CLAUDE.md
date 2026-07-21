# CLAUDE.md — Courtside Hoop Stats

Project context for any Claude Code session (local or cloud). Read this first,
then `docs/REQUIREMENTS.md` for the full product spec.

> **Backlog lives in GitHub Issues.** Local terminal session: work from
> `gh issue list` — pick an issue, implement it, and close it with "Closes #N"
> in the PR. Cloud/design sessions log new ideas & feedback as issues.
> (`docs/TERMINAL_TODO.md` is retired — it's now just a pointer + a log of
> already-completed work.)

## What this is

A native iOS app for tracking youth basketball game stats courtside, replacing a
manual spreadsheet. SwiftUI, **iOS 26 minimum**, zero third-party dependencies,
UserDefaults/JSON persistence. Primary user is one
person (the tracker) operating the phone alone during live games — **speed, big
tap targets, and error recovery are the top UX priorities.**

## Current status (2026-07-21) — **v1-ready**

- **Shipping to one device; App-Store-ready metadata is drafted.** All four
  screens are live and device-tested on Thomas's iPhone 17 Pro: **Roster, Games,
  Live Scoring, Game Summary**, plus multi-team management in Settings. Builds
  clean (0 warnings); a UI-test screenshot harness verifies the main flows
  (`scripts/screenshots.sh`).
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
- **Also live:** multiple teams (#20), edit-a-finished-game (#8), score-log
  reorder + movable dividers (#9), location autocomplete (#13) + address, game
  start time, consistency pass (Cancel/Save editors, delete confirms — see
  `docs/UI_GUIDELINES.md`), `.pickup` format (#34/#35).
- **App Store blocker:** the current Mac runs macOS 27 **beta**, so only the beta
  Xcode runs, and Apple rejects beta-built binaries — this blocks **both** App
  Store and TestFlight. Paths: wait for the macOS 27 / Xcode 27 **GM (~Sept
  2026)**, or archive from a release-macOS Mac / CI. Development-signed install
  straight to a device still works.
- **Deferred:** multi-user sharing (#15, CloudKit — see `docs/SHARING.md`).

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
- Note: App Store submission (post-retirement goal) will need a *release* Xcode,
  not the beta — irrelevant for now.

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

The backlog now lives in **GitHub Issues** — see `gh issue list` (or the repo's
Issues tab). With the v1 feature set shipped, the notable open items are
**#15** (multi-user CloudKit sharing — deferred; see `docs/SHARING.md`) and
**#32** (iPad layout — deferred, app is iPhone-only). The remaining gate to an
actual App Store submission is the beta-macOS build blocker described above, not
a feature gap.

## MVP defaults chosen for the spec's open questions

(Documented in `README.md`; all easily changed.)

- Free throws: two action buttons (`FT ✓` / `FT ✗`), not a sub-panel.
- Live grid shows the active roster; absent players can be **benched** so they
  drop out of the scoring grid without leaving the team.
- Opponent totals editable after the fact in Game Summary.
- Team name editable inline on the Roster tab.
- Player selection clears after each recorded event (reduces mis-attribution).

## Workflow & git

- **Git is the source of truth** between Thomas's Mac and any cloud Claude session.
- **Backlog = GitHub Issues.** Every feature/bug/idea is tracked as an issue. The
  terminal works from `gh issue list`, implements one, and closes it with
  "Closes #N" in the PR. Cloud sessions create issues from design discussion and
  Thomas's feedback. (Requires `gh auth login` once on the Mac.)
- **Change flow:** feature work lands via **PRs (auto-merge)**, not direct commits
  to `main`. Thomas device-tests builds before they're considered shippable.
- **Role split (current):** the cloud session is for **design discussion** and may
  edit/push **Markdown docs only** (e.g. this file, `docs/*.md`). All **code**
  (Swift, the Xcode project) is generated and pushed **only from the local
  terminal** session.
- **One driver at a time:** whoever is working commits and pushes; the other
  pulls *before* starting. Avoid both editing `project.pbxproj` simultaneously.
- A **local** Claude session can build/run in Xcode and verify compiles; a
  **cloud** session cannot (no macOS toolchain) — prefer local for the build loop.
- Project uses Xcode 16+ file-system-synchronized groups, so new Swift files are
  picked up automatically — no `.xcodeproj` editing needed to add files.
