# Multi-User Sharing — Design Notes

**Status:** _Proposed / deferred._ Do not start until the local single-device app
is stable and device-tested. Tracked in [`TERMINAL_TODO.md`](TERMINAL_TODO.md).

## Goal

Let more than one person see the same team's roster, games, and stats — starting
with **two people** (Thomas + his wife). Ideal experience: while one person
tracks a game courtside, the other can watch the score and stats update
**near-live** on their own iPhone, signed in with their **own iCloud account**.

This is the "iCloud Shared Album" experience, applied to game data.

## Recommended approach: CloudKit sharing (`CKShare`)

Apple's native mechanism for *different* iCloud accounts sharing the same data is
**CloudKit's shared database** with a `CKShare` — the exact plumbing behind
Shared Albums and Shared Photo Library. It runs on the users' existing iCloud
accounts, needs **no third-party backend**, and stays within the project's
"zero dependencies / free" constraint. Change notifications arrive via CloudKit
push subscriptions, so updates land in **seconds** when the writing device has
connectivity.

### Ruled out (and why)

| Option | Why not |
|---|---|
| `NSUbiquitousKeyValueStore` (iCloud KVS) | Syncs only across **one person's own** devices, not between two accounts. |
| Family Sharing | Shares purchases/subscriptions, **not app data**. |
| One shared Apple ID | "Works" but bleeds Messages/Photos/etc. together — bad idea. |
| Firebase / custom websocket backend | True real-time, but adds a dependency + hosting/accounts. Overkill for two users. |

## ⚠️ The connectivity caveat (most important practical point)

The current app is **local-first** precisely because gyms are Wi-Fi/cellular dead
zones. CloudKit is offline-tolerant — it queues local changes and syncs when
signal returns — but a *viewer* only sees updates when the **tracker's** phone
has a connection at that moment.

Realistic expectation to set with users:

- **Signal present:** near-live, updates within seconds.
- **Dead-zone gym:** the viewer sees the game **catch up in a burst** once the
  tracker is back online — not tap-by-tap.

Either way the viewer always ends up with the complete game + stats. We should
say this plainly in-app rather than promise "live."

## Architecture impact

This is the **largest change the app would take**: moving persistence off the
simple `UserDefaults`/JSON store (`AppStore.swift`) onto a CloudKit-backed store.
The **views mostly survive** — stats are all *derived* from stored events
(`Models.swift`), so there is no separate stats store to migrate or reconcile.

Two implementation routes (decision below is **open** — verify against current
docs before building):

1. **SwiftData + CloudKit** — cleanest long-term; models become `@Model` classes.
   *Risk:* SwiftData's automatic CloudKit historically covered only the
   **private** database (a user's own devices); cross-**user** `CKShare` sharing
   required Core Data. Confirm whether current SwiftData (iOS 26/27) supports
   first-class sharing before committing.
2. **`NSPersistentCloudKitContainer` (Core Data)** — heavier API but **mature,
   proven `CKShare` support**. The safe bet if we want sharing for certain.

### Why our data model syncs well

Events are effectively **append-only** (undo = remove-last), and aggregates are
derived, not stored. Append-only data merges cleanly under CloudKit's
last-writer-wins semantics, so the conflict surface is small.

### Recommended sharing model (start simple)

- **Single writer, multiple viewers.** The tracker (game owner) edits; the
  other person is **read-only**. This sidesteps almost all write-conflict
  complexity and matches the real use (one person runs the app courtside).
- Revisit "both can edit" only if a genuine need appears.

### Scope of a share

- **Whole dataset** (team roster + all games) as one shared container is simplest
  for a couple following one team — share once, done.
- Per-game shares are more granular but more UI/overhead. Prefer whole-dataset to
  start.

## Migration notes

- Keep the local-first behavior; layer sync on top (offline still works).
- Persistence keys are already versioned (`chs.team.v1`, `chs.games.v1`) — a
  one-time import from existing `UserDefaults` data into the new store avoids
  losing the current season.
- Updates a documented assumption: `CLAUDE.md` says "single user operating
  alone." Adding a viewer is a deliberate product scope change — record it there
  when this ships.

## Open questions / decisions needed

1. SwiftData vs `NSPersistentCloudKitContainer` — resolve via current Apple docs.
2. Viewer strictly read-only to start? (Recommended: yes.)
3. Share the whole dataset or per-game? (Recommended: whole dataset.)
4. In-app copy that honestly frames "near-live, catches up offline."
5. iCloud account requirement + the share invite/accept flow (how the wife joins).
