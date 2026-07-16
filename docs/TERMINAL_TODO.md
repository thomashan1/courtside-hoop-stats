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

- [x] **App icon added (Thomas-generated realistic basketball on dark).**
  Committed from the cloud session (image asset). Thomas generated the icon art;
  it was processed into a full-bleed, opaque **1024×1024** PNG (white margin +
  rounded corners removed so iOS masks the squircle itself) and wired up:
  - `CourtsideHoopStats/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
  - `AppIcon.appiconset/Contents.json` references it as the universal 1024 image.
  **Next time at the Mac:** just build + install and confirm it appears on the
  home screen (no action needed unless it looks wrong).
