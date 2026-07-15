# Courtside Hoop Stats

A native iOS app for tracking youth basketball game statistics courtside —
replacing a manual spreadsheet workflow. Built with SwiftUI, zero third-party
dependencies, iOS 17+.

- **App Store name:** Courtside Hoop Stats
- **Home-screen label:** Courtside
- **Bundle identifier:** `com.thomashan.CourtsideHoopStats`

The full product spec lives in [`docs/REQUIREMENTS.md`](docs/REQUIREMENTS.md).

## Getting started (Mac Mini)

```bash
git clone https://github.com/thomashan1/courtside-hoop-stats.git
cd courtside-hoop-stats
git checkout claude/ios-basketball-stats-app-wxo4ds
open CourtsideHoopStats.xcodeproj
```

Requires **Xcode 16 or later** (the project uses file-system-synchronized
groups, `objectVersion = 77`).

### First-run setup in Xcode

1. Select the **CourtsideHoopStats** target → **Signing & Capabilities**.
2. Set your **Team** (personal Apple ID or Developer account). The project ships
   with `DEVELOPMENT_TEAM` empty, so you'll see a signing error until you pick
   one — this is expected and only needs doing once per machine.
3. Choose a simulator or your connected device and press **⌘R** to build & run.

## Working across machines

Git is the shared source of truth between local Xcode development and cloud
Claude Code sessions.

- **Pull before you start** local work: `git pull origin claude/ios-basketball-stats-app-wxo4ds`
- **Commit & push** any local changes before a cloud session edits the project,
  so nothing gets clobbered.
- Because the project uses synchronized folder groups, new Swift files added on
  either side are picked up automatically — no `.xcodeproj` surgery needed.

## Project structure

```
CourtsideHoopStats/
├── CourtsideHoopStatsApp.swift     @main, injects AppStore
├── Models/
│   ├── Models.swift                Codable data types + derived stats
│   └── AppStore.swift              ObservableObject + UserDefaults persistence
├── Views/
│   ├── ContentView.swift           Root TabView (Games / Roster)
│   ├── RosterView.swift            Player CRUD + team rename
│   ├── GamesListView.swift         Game history + New Game sheet
│   ├── LiveScoringView.swift       Live scoring (grid, action strip, event log)
│   └── GameSummaryView.swift       Stats table, period scores, notes
├── Helpers/
│   └── DesignSystem.swift          Colors, JerseyBadge, ScoreboardView
└── Assets.xcassets/                AppIcon (placeholder) + AccentColor
```

## MVP decisions baked in (easily changed)

These resolve the open questions in the spec with sensible defaults:

- **Free throws:** two separate action buttons (`FT ✓` / `FT ✗`) rather than a
  sub-panel.
- **Bench tracking:** not included — the live grid shows the full roster.
- **Opponent score editing:** editable after the fact in Game Summary →
  "Edit opponent totals".
- **Team name:** editable inline at the top of the Roster tab.
- **Player selection:** cleared after each recorded event, so every event
  requires an explicit player tap (reduces mis-attribution courtside).
