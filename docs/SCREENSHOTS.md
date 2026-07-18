# Screenshots

Automated screenshots for **merge-gate visual verification**, the **README**, and
the **App Store** listing — all from one XCUITest harness, so they never drift
from the real UI.

## How it works

- **`CourtsideHoopStatsUITests`** (UI-test target) drives the app through its
  main screens and captures a full-device screenshot at each
  (`ScreenshotUITests.swift`).
- The app seeds **deterministic demo data** when launched with the
  `-uiTestSeedDemo` argument (`DemoData.swift`, `#if DEBUG` only). This never
  touches real persisted data — mutations are held in memory for the run.
- The demo roster is **fictional on purpose**: public listing/README shots must
  not contain a real minor's name, jersey number, or a real gym address.

## Run it

```bash
scripts/screenshots.sh                     # iPhone 17 Pro (default)
scripts/screenshots.sh "iPhone 17 Pro Max" # App Store 6.9" device size
```

PNGs land in `screenshots/` (git-ignored). Named `01-games-list.png`,
`02-game-summary.png`, `03-live-scoring.png`, `04-roster.png`.

## Adding a screen

1. Add a `snap(app, "NN-name")` step in `ScreenshotUITests.swift`, driving to the
   screen first (tap by visible label / nav-bar title).
2. If it needs specific state, extend `DemoData.swift`.

## App Store sizes

Apple requires 6.9" (iPhone 17 Pro Max class) and, if you support it, 6.5"/6.1".
Re-run the script per simulator name; the shots are already full-device frames.
