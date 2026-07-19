# Terminal To-Do — retired

> **The backlog lives in GitHub Issues.** This file is not the work queue.
>
> - **Terminal session:** work from `gh issue list` — pick an issue, implement it,
>   and close it with "Closes #N" in the PR.
> - **Cloud/design sessions:** log new ideas and feedback as GitHub issues.

Open work is tracked on the Issues tab. As of 2026-07-19 the notable open
issues are **#7** (iPhone-only vs universal), **#15** (multi-user sharing), and
**#32** (iPad layout). Everything below has shipped.

## Completed (historical log)

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
