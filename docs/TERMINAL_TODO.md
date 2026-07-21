# Terminal To-Do — retired

> **The backlog lives in GitHub Issues.** This file is not the work queue.
>
> - **Terminal session:** work from `gh issue list` — pick an issue, implement it,
>   and close it with "Closes #N" in the PR.
> - **Cloud/design sessions:** log new ideas and feedback as GitHub issues.

Open work is tracked on the Issues tab. As of 2026-07-21 (**v1-ready**) the
notable open issues are **#15** (multi-user CloudKit sharing — deferred) and
**#32** (iPad layout — deferred; the app ships iPhone-only). Everything below has
shipped.

## Completed (historical log)

- [x] **Team export / import** as a shared `.json` file — AirDrop/Files via
  ShareLink; Export in team detail, Import in the Teams list; roster-only,
  local-first precursor to CloudKit sharing (#40).
- [x] **FT%** in the per-player stats table, e.g. `5/6 (83%)` (#41).
- [x] **First names only** in live scoring + Game Summary; Roster keeps full
  names (#42).
- [x] **New Game form** — every field optional; **Start Game** begins scoring,
  **Save** schedules for later; format (quarters/halves/pickup) chosen at
  creation; removed the ⚡️ Quick Pickup lightning button (#44).
- [x] **iPhone-only** — `TARGETED_DEVICE_FAMILY = 1`, no iPad layout (#7).
- [x] **Screenshot harness → App Store sizes**; real app icon shipped (#45).
- [x] Theme → team blue; min iOS 26; app icon (basketball + stat bars on blue).
- [x] Model unit tests + accessibility pass (#14/#12).
- [x] Edit a finished game in the scoring view (#8); shared stat panels.
- [x] Score-log reorder + movable period dividers (#9); running totals; swipe-delete.
- [x] Location autocomplete via MapKit (#13) + address FYI; game start time.
- [x] Multiple teams, managed in Settings (#20); Games/Roster scoped to active team.
- [x] Read-only Game Summary + app-wide edit/save/delete consistency pass
  (`docs/UI_GUIDELINES.md`); delete confirmations.
- [x] Live-scoring rework (Jean): tap-to-score point pad (#33), removed the
  floating action bar, controls folded into the scoreboard, bench players,
  score log on top with sticky period headers.
- [x] Quick **Pickup Game** start (#34) + `.pickup` single-period format (#35).
- [x] XCUITest screenshot harness (`scripts/screenshots.sh`, `docs/SCREENSHOTS.md`).
