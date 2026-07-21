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
scripts/screenshots.sh                 # iPhone 17 Pro (default — README shots)
scripts/screenshots.sh "iPhone 16 Plus" # App Store size → 1284 × 2778 frames
```

PNGs land in `screenshots/` (git-ignored), one per `snap(...)` step, named
`NN-name.png` — e.g. `01-games-list`, `02-game-summary`, `03-live-scoring`,
`04-roster`, `12-score-pad`, `13-new-game` (see `ScreenshotUITests.swift` for the
full set).

## Adding a screen

1. Add a `snap(app, "NN-name")` step in `ScreenshotUITests.swift`, driving to the
   screen first (tap by visible label / nav-bar title).
2. If it needs specific state, extend `DemoData.swift`.

## App Store sizes

The app is **iPhone-only**, so only iPhone screenshots are needed. We upload the
**1284 × 2778** set (the largest of Apple's accepted **6.5" / 6.7"** buckets),
captured by running the harness on a Plus/Max-class simulator (e.g.
`scripts/screenshots.sh "iPhone 16 Plus"`). App Store Connect scales that set down
for smaller displays, so a single size covers the listing. The shots are already
full-device frames — no cropping needed.
