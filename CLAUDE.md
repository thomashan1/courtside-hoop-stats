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

## Current status (2026-07-15)

- **Pipeline validated ✅** — earlier confirmed Xcode + signing + device install
  work end-to-end (via a minimal dummy app).
- **Full app reintroduced & compiling ✅** — the staged scaffold has been moved
  into the compiled target (`Staged/` is gone) with the adaptive design pass
  applied. All four screens are live: **Roster, Games list, Live Scoring
  (core), Game Summary**. Builds clean (0 warnings) for the iPhone 17 Pro
  simulator; verified in both light and dark mode via screenshots.
- **Design pass done** — forced-dark palette replaced with adaptive system
  colors; grass-green accent tuned per light/dark; Liquid Glass (`.glassEffect()`)
  confined to the Live Scoring floating action bar; scoreboard banner is the one
  intentional solid-dark element.
- **Next up:** on-device testing, then multi-user sharing (see
  [`docs/SHARING.md`](docs/SHARING.md), deferred until the local app is stable).

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
Issues tab). Currently open highlights: model unit tests (⭐ prioritized),
edit-a-finished-game in the scoring view, score-log reorder/running-total,
accessibility pass, location autocomplete, and (deferred) CloudKit sharing.

## MVP defaults chosen for the spec's open questions

(Documented in `README.md`; all easily changed.)

- Free throws: two action buttons (`FT ✓` / `FT ✗`), not a sub-panel.
- No bench toggle — live grid shows the full roster.
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
