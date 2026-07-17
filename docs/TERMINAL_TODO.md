# Terminal To-Do — retired

> **The backlog moved to GitHub Issues.** This file is no longer the work queue.
>
> - **Terminal session:** work from `gh issue list` — pick an issue, implement it,
>   and close it with "Closes #N" in the PR. (Run `gh auth login` once on the Mac
>   if needed.)
> - **Cloud/design sessions:** log new ideas and feedback as GitHub issues.
>
> Open items that used to live here were migrated to issues (#7–#15) on
> 2026-07-17.

---

## 🔵 Cloud session hand-off — draft PRs waiting for Mac build-verify

_Last updated 2026-07-17 by the cloud session._

The roadmap issue **#16** is the live source of truth (priority + status). This
is the plain-file mirror so a `git pull` on the Mac shows the state without
`gh`. **All three PRs were written in the cloud env with no Swift compiler** —
build each in Xcode, fix any compile errors, then mark ready & merge.

**Suggested merge order:**

1. **PR #17** — `cloud/tests-and-a11y` — issues **#14** (model unit tests) +
   **#12** partial (summary stat table now scrolls).
   ⚠️ Needs a **Unit Testing Bundle** target added in Xcode (File ▸ New ▸
   Target… ▸ Unit Testing Bundle, name `CourtsideHoopStatsTests`) before the
   tests compile/run. See the header note in `ModelsTests.swift`.
2. **PR #18** — `cloud/edit-finished-game` — issue **#8**. "Edit Scores" button
   on the summary reopens the full two-tap `LiveScoringView` for a finished
   game; new shared `StatsPanels.swift` (`PlayerStatsTable` +
   `PeriodBreakdownGrid`) reused across live/edit/summary; collapsible stats
   panel in the scoring view.
   ⚠️ Overlaps #17 in `GameSummaryView.statsSection` (both make the stat table
   the shared scrollable version) — **merge #17 first**, then #18 may need a
   trivial rebase.
   ⚠️ Check the `.fullScreenCover` + nested `NavigationStack` "Done" button
   wiring compiles/behaves.
3. **PR #19** — `cloud/location-autocomplete` — issue **#13** (first pass).
   MapKit `MKLocalSearchCompleter` autocomplete on the Location/Gym field
   (`LocationField.swift`); no location permission yet (not region-biased).
   Independent of the other two.
   ⚠️ Check the `MKLocalSearchCompleterDelegate` `nonisolated` +
   `Task { @MainActor }` pattern compiles clean under strict concurrency.

**Left for the terminal (not in any cloud PR):**

- **#9 — reorder score log.** Not done blind — needs a simulator. Design was
  clarified by Thomas: reorder **freely across quarters**, and the
  **end-of-quarter divisions are themselves movable** (to fix accidental
  mis-recording). See the issue comments for the suggested data model (period
  becomes derived from draggable period-end markers, recomputed on reorder).

---

## Completed (historical log)

- [x] **Switch the app theme from green to Swish Warriors blue.** Remapped the
  brand palette to blue (adaptive light/dark). Renamed constants:
  `grassGreen → teamAccent` (#1E5FCF / #5B9CF5), `scoreboardGreen →
  scoreboardBackground` (#0C2C5E). Shipped via PR.
- [x] **Raise minimum iOS version to 26.** `IPHONEOS_DEPLOYMENT_TARGET` 17.0 → 26.0
  (Debug + Release). Clean `xcodebuild`: BUILD SUCCEEDED.
- [x] **App icon.** Realistic basketball + stats bars on team blue, full-bleed
  opaque 1024×1024. ⚠️ Stock ball art — confirm rights before App Store (see #7
  and `docs/DISTRIBUTION.md`).
- [x] **Redo in live scoring** (reverse an accidental Undo) — shipped.
