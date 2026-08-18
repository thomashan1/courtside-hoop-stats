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

The script defaults to **iPhone 17e** and resolves the name to a UDID before
running. A name that matches no installed simulator now fails loudly with the
list of what *is* installed — previously `xcodebuild` printed the destination
list, exited, and the script's `>/dev/null` swallowed it, leaving the previous
run's PNGs in place and looking like a successful capture.

PNGs land in `screenshots/` (git-ignored), one per `snap(...)` step, named
`NN-name.png` — e.g. `01-games-list`, `02-game-summary`, `03-live-scoring`,
`04-roster`, `12-score-pad`, `13-new-game`, `20-following-list`,
`21-following-game` (see the two test files for the full set).

## What the demo data covers

`DemoData.makeGames` is built so one run of the harness exercises the real
range, not one happy path:

| Dimension | Covered by |
|---|---|
| Sections | Playing Now (Northgate), Coming Up (Summit), Final Scores (four games) |
| Results | **win** (Lakeside 48–41), **loss** (Central 38–44), **tie** (Pine Ridge 30–30) |
| Period formats | quarters, **halves** (Pine Ridge), **pickup** (Bayview — no periods, no location) |
| Edge cases | a DNP row (Wesley benched), a missed FT so FT% isn't always 100%, optional fields left blank on the pickup game |

`DemoDataTests` asserts this coverage, so dropping a game while editing the seed
fails a test rather than quietly costing a badge nothing screenshots any more.

Two more things it's tuned for: **Nicholas (#77) leads every game on threes**,
which keeps one narrative across owner and follower screens, and each game gets
its **own tip-off time** — the reference date is built from calendar components
so it lands at a plausible 10:00 AM rather than the 4:40 AM a raw epoch produced.

`15-game-summary-halves` is a **verification capture, not part of the committed
set** — it exists so the halves linescore and the TIE badge get looked at.

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

scripts/screenshots.sh "iPhone 14 Plus"      # 6.5" / 1284 x 2778 — this listing

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

Each file is `NN-<screen>.png`, and **`NN` is App Store upload order** — so
`ls docs/img` gives the sequence to work top-to-bottom in App Store Connect,
where the order is manual and easy to get wrong.

It is *not* README order. The README places images by explicit `<img src>` and
groups them by theme, so it doesn't care what the numbers say; only the
directory listing sorts, and it's the upload that needs sorting. That's why the
README captions carry no numbers — a caption reading "3." under the *sixth*
image in the page is worse than no number at all.

| # | File | Captured from |
|---|---|---|
| 1 | `01-game-live-scoring.png` | `11-bench` — live scoring with the "Not playing" strip open, so one image shows both |
| 2 | `02-game-score-pad.png` | `12-score-pad` |
| 3 | `03-following-game.png` | `21-following-game` — a follower watching a game |
| 4 | `04-game-summary.png` | `02-game-summary` |
| 5 | `05-game-summary-share-pdf.png` | `14-box-score-pdf` |
| 6 | `06-following.png` | `20-following-list` — teams shared with you |
| 7 | `07-games.png` | `01-games-list` |
| 8 | `08-roster.png` | `04-roster` |
| 9 | `09-new-game.png` | `13-new-game` |
| 10 | `10-team-jerseys.png` | `09-team-detail` — the team editor, where the colour and home kit are picked |
| — | `app-icon.png` | not a screenshot; unnumbered |

**Ten, because App Store Connect takes ten.** That's a hard cap, not a taste
call — so a new screen has to displace one, and the reasoning for the current
ten (and for the two that were cut) lives in
[`APP_STORE_LISTING.md`](APP_STORE_LISTING.md) §9, next to the upload it serves.

If the order changes, renumber the whole set and update the README's `src`
paths in the same commit — a stale number is worse than none, and a renumber
that skips the README leaves it rendering files that no longer exist.

The live-scoring image is deliberately the **bench** capture (`11-bench`) — the
live scoring screen with the "Not playing" strip open, so one image shows both.

