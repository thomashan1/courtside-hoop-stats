# Terminal To-Do

A work queue handed from **cloud design sessions** to the **local terminal
session** — the terminal is the only session that writes code and pushes it.

**How to use it (on the Mac):**
1. `git pull`
2. Tell your terminal session: *"Do the pending items in `docs/TERMINAL_TODO.md`."*
3. For each task, make the change, then move it from **Pending** to **Done** in
   the *same commit*, and push to `main`.

---

## Pending

- [ ] **Accessibility / larger text pass.** Feedback from **Jean** (the end user):
  "make it bigger, I can't see." Audit the app under large **Dynamic Type** sizes
  and ensure everything scales and stays legible — player cards, scoreboard,
  stat tables, event log, buttons. Prefer semantic text styles over fixed sizes;
  add `minimumScaleFactor`/wrapping where needed; verify tap targets stay ≥44pt.
  Consider a larger baseline font option if system Dynamic Type isn't enough.

- [ ] **Location field: address autocomplete via Maps.**
  Augment the Location/Gym field (which already suggests prior values) with real
  address/place search using **MapKit `MKLocalSearchCompleter`**. Needs: an
  ObservableObject wrapping the completer with debounced queries + delegate
  results, a suggestions UI, and selection that fills the field with the place
  name/address. To bias results locally, add `CLLocationManager` +
  `NSLocationWhenInUseUsageDescription` in Info.plist (optional first pass can
  skip location and just do text search). Its own PR. From Thomas's feedback.

- [ ] **Add Redo to live scoring (reverse an accidental Undo).**
  Today `undo()` just removes the last event; there's no way to undo the undo.
  Keep a transient "undone events" stack in `LiveScoringView` (cleared whenever a
  new event is recorded), and add a Redo control next to Undo in the action bar
  that re-appends the last undone event. From Thomas's device testing.

- [ ] **Add unit tests for the model logic.** ⭐ Prioritized — Thomas wants this
  started next.
  Cover the derived, pure logic in `Models.swift`: `Game.stats(for:)`,
  `periodBreakdown()`, `ourScore` / `opponentScore`, `result`, and
  `currentPeriod` / `isFinalPeriod`. These have no UI dependencies and are the
  app's real computation, so they're cheap, high-value tests (and a safety net
  before the CloudKit sharing rework). Add a unit test target if one doesn't
  exist yet.

- [ ] **Multi-user sharing (Thomas + wife see games/stats near-live).**
  ⛔️ **Blocked / deferred** — do **not** start until the local single-device app
  is stable and device-tested. Native approach is CloudKit `CKShare` (the iCloud
  Shared-Album mechanism); this is a large persistence-layer change off
  `UserDefaults`/JSON. Full design, tradeoffs, the gym-connectivity caveat, and
  open decisions are in [`SHARING.md`](SHARING.md). When unblocked, resolve the
  open questions there first, then implement.

---

## Done

- [x] **Switch the app theme from green to Swish Warriors blue.**
  Remapped the brand palette to blue, preserving the adaptive light/dark
  treatment. Renamed the color constants off "green" so they're honest:
  `grassGreen → teamAccent` (#1E5FCF light / #5B9CF5 dark),
  `scoreboardGreen → scoreboardBackground` (deep navy #0C2C5E), and the
  scoreboard accent → #5B9CF5. `AccentColor.colorset` updated to match. Blue-
  tinted card/surfaces come from `teamAccent` at low opacity (adapts
  automatically). Built + verified in both light and dark. Shipped via PR.

- [x] **Raise minimum iOS version to 26.**
  Changed `IPHONEOS_DEPLOYMENT_TARGET` from `17.0` to `26.0` in **both** the Debug
  and Release build configurations in
  `CourtsideHoopStats.xcodeproj/project.pbxproj`.
  Verified with a clean `xcodebuild` for `generic/platform=iOS` (Debug):
  **BUILD SUCCEEDED**.

- [x] **App icon added (realistic basketball + stats bars on team blue).**
  Committed from the cloud session (image asset). Final icon composites a
  high-resolution realistic basketball crowning a rising bar chart on a blue
  gradient — full-bleed, opaque **1024×1024**, no rounded corners (iOS masks the
  squircle). Wired up:
  - `CourtsideHoopStats/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
  - `AppIcon.appiconset/Contents.json` references it as the universal 1024 image.
  **Next time at the Mac:** build + install and confirm it appears on the home
  screen (no action needed unless it looks wrong).
  ⚠️ **App Store note:** the ball art is from a stock image — fine for personal
  use, but confirm usage rights (or swap in owned art) before any App Store
  submission.
