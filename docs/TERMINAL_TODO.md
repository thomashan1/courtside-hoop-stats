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
