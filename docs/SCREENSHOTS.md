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

**iPhone-only, and this listing uses the 6.5" bucket: `1284 × 2778`.**

That is what App Store Connect asks for on this app ("Screenshots dimensions
should be: 1242 × 2688px, 2688 × 1242px, 1284 × 2778px or 2778 × 1284px"),
because the listing acquired a 6.5" slot at the 1.0 submission and kept it.

```bash
# 6.5" / 1284 x 2778 — the set this listing uses.
# Drive by simulator ID: the name alone can fail to resolve.
xcodebuild test -project CourtsideHoopStats.xcodeproj -scheme CourtsideHoopStats \
  -destination 'platform=iOS Simulator,id=<iPhone 14 Plus UDID>' \
  -only-testing:CourtsideHoopStatsUITests -resultBundlePath /tmp/shots.xcresult
# then export attachments as scripts/screenshots.sh does

scripts/screenshots.sh "iPhone 17 Pro Max"   # 6.9" / 1320 x 2868, if ever needed
```

> ⚠️ Two traps, both hit for real:
> - Older revisions of this file called **1284 × 2778** the *"6.9-inch"* size.
>   It isn't — that's the **6.5"** bucket. The **size** was right for this
>   listing; only the **name** was wrong.
> - A *new* listing in 2026 would want **6.9" (1320 × 2868)**, since Apple takes
>   the largest display per family. That guidance does **not** override what
>   App Store Connect is actually asking for on an existing listing. Upload what
>   the slot demands.

**One set, committed.** `docs/img/*.png` *are* the upload set — the same files
the README renders (at `width="240"`, so resolution costs nothing visually).
Don't keep a second, smaller README-only set; that drift is what caused the
confusion above.

Upload order, hero first: **live-scoring → score-pad → box-score-pdf →
game-summary → games-list → roster**. (`teams.png` is README-only.)

`live-scoring.png` is deliberately the **bench** capture (`11-bench`) — the live
scoring screen with the "Not playing" strip open, so one image shows both.

