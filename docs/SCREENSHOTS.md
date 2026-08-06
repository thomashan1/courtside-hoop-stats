# Screenshots

Automated screenshots for **merge-gate visual verification**, the **README**, and
the **App Store** listing — all from one XCUITest harness, so they never drift
from the real UI.

## How it works

- **`CourtsideHoopStatsUITests`** (UI-test target) drives the app through its
  main screens and captures a full-device screenshot at each.
  - `ScreenshotUITests.swift` — the owner's app (games, scoring, summary, PDF…).
  - `FollowingScreenshotTests.swift` — the follower's read-only view (#57). Split
    out because it's the only flow that depends on a seeded **followed** team
    (`DemoData.makeFollowedTeam()`) rather than the user's own team.
- The app seeds **deterministic demo data** when launched with the
  `-uiTestSeedDemo` argument (`DemoData.swift`, `#if DEBUG` only). This never
  touches real persisted data — mutations are held in memory for the run.
- The demo roster is **fictional on purpose**: public listing/README shots must
  not contain a real minor's name, jersey number, or a real gym address.

## Run it

**Drive by simulator ID, not name.** The script takes a name, but a bare name
routinely fails to resolve — `xcodebuild` then dumps its whole destination list
and exits, leaving the previous run's PNGs in place, so it looks like it worked.
Get the UDID from `xcrun simctl list devices available`.

```bash
# 6.5" / 1284 × 2778 — the size this listing uses. iPhone 14 Plus.
xcodebuild test -project CourtsideHoopStats.xcodeproj -scheme CourtsideHoopStats \
  -destination 'platform=iOS Simulator,id=<iPhone 14 Plus UDID>' \
  -only-testing:CourtsideHoopStatsUITests -resultBundlePath /tmp/shots.xcresult
xcrun xcresulttool export attachments --path /tmp/shots.xcresult --output-path /tmp/att
# then copy /tmp/att files to screenshots/ using manifest.json's
# suggestedHumanReadableName, as scripts/screenshots.sh does
```

⚠️ There is **no "iPhone 17 Pro" simulator installed**, despite it being the
script's default. Pass a device that exists.

PNGs land in `screenshots/` (git-ignored), one per `snap(...)` step, named
`NN-name.png` — e.g. `01-games-list`, `02-game-summary`, `03-live-scoring`,
`04-roster`, `12-score-pad`, `13-new-game`, `20-following-list`,
`21-following-game` (see the two test files for the full set).

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

Each file is `NN-<section>-<screen>.png`: **`NN` is README display order** and
`<section>` is the README heading it sits under, so a filename alone says where
the image is used and the directory sorts the way the README reads.

| File | README section | Captured from |
|---|---|---|
| `01-game-live-scoring.png` | Scoring courtside | `11-bench` — live scoring with the "Not playing" strip open, so one image shows both |
| `02-game-score-pad.png` | Scoring courtside | `12-score-pad` |
| `03-game-score-log.png` | Scoring courtside | `07-score-log-editor` |
| `04-new-game.png` | Starting a game | `13-new-game` |
| `05-game-summary.png` | After the game | `02-game-summary` |
| `06-game-summary-share-pdf.png` | After the game | `14-box-score-pdf` |
| `07-games.png` | Your team | `01-games-list` |
| `08-roster.png` | Your team | `04-roster` |
| `09-settings.png` | Your team | `08-settings-teams` — the Teams list in Settings |
| `10-following.png` | Following a shared team | `20-following-list` — teams shared with you |
| `11-following-game.png` | Following a shared team | `21-following-game` — a follower watching a game |
| `app-icon.png` | header | not a screenshot; unnumbered |

Renumber the whole set if the README order changes — the prefix *is* the order,
so a stale number is worse than none. Keep it **under 12 images**: past that the
README reads as a catalogue rather than a tour, and only the critical screens
earn a slot.

The live-scoring image is deliberately the **bench** capture (`11-bench`) — the
live scoring screen with the "Not playing" strip open, so one image shows both.

