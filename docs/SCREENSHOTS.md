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
scripts/screenshots.sh "iPhone 14 Plus" # App Store size → 1284 × 2778 frames
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

The app is **iPhone-only**, so only iPhone screenshots are needed, and since
2025 Apple only wants the **largest** display in the family — it scales that set
down for everything smaller.

Upload the **6.9" set: 1320 × 2868**, captured on a Pro-Max-class simulator:

```bash
scripts/screenshots.sh "iPhone 17 Pro Max"   # → 1320 × 2868, the App Store set
scripts/screenshots.sh "iPhone 17"           # → the README set
```

> ⚠️ Earlier revisions of this file called **1284 × 2778** the "6.9-inch" size.
> It isn't — that's the **6.5"** bucket (iPhone 14 Plus class). App Store Connect
> still accepts it as a fallback class, but 6.9" is the one to upload.

The shots are already full-device frames — no cropping needed.
