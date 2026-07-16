# CLAUDE.md — Courtside Hoop Stats

Project context for any Claude Code session (local or cloud). Read this first,
then `docs/REQUIREMENTS.md` for the full product spec.

## What this is

A native iOS app for tracking youth basketball game stats courtside, replacing a
manual spreadsheet. SwiftUI, **iOS 26 minimum**, zero third-party dependencies,
UserDefaults/JSON persistence. Primary user is one
person (the tracker) operating the phone alone during live games — **speed, big
tap targets, and error recovery are the top UX priorities.**

## Current status (2026-07-16)

- **Pipeline validated ✅** — the app currently ships as a **minimal dummy**
  (single welcome screen) that has been built and installed on-device
  successfully. This confirmed Xcode + signing + device install work end-to-end.
- The **full app scaffold** (models, store, all views) is preserved in
  [`Staged/`](Staged/) — **not compiled** — waiting to be reintroduced with the
  design pass below.
- **Compiled target** right now is just `CourtsideHoopStats/CourtsideHoopStatsApp.swift`
  + `ContentView.swift` + assets.

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
   fallbacks). → Project `IPHONEOS_DEPLOYMENT_TARGET` still needs to change from
   17.0 to 26.0 — **pending, a terminal/project change.**
2. **Visual direction: adaptive.** Follow the system light/dark appearance (NO
   forced dark mode) so it stays readable in a bright gym. Grass-green as the
   accent color. Liquid Glass only in the chrome (nav bar, tab bar, floating
   controls); content — player cards, scoreboard, stat tables — stays solid and
   high-contrast for courtside legibility.

## Next steps

1. **(Terminal/project)** Set `IPHONEOS_DEPLOYMENT_TARGET` to 26.0.
2. Reintroduce `Staged/` code with the design pass applied (adaptive light/dark,
   Liquid Glass in chrome only).
3. Build screen by screen: Roster → Games list → Live Scoring (core) → Summary.

## MVP defaults chosen for the spec's open questions

(Documented in `README.md`; all easily changed.)

- Free throws: two action buttons (`FT ✓` / `FT ✗`), not a sub-panel.
- No bench toggle — live grid shows the full roster.
- Opponent totals editable after the fact in Game Summary.
- Team name editable inline on the Roster tab.
- Player selection clears after each recorded event (reduces mis-attribution).

## Workflow & git

- **Git is the source of truth** between Thomas's Mac and any cloud Claude session.
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
