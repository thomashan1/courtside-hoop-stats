# Multi-User Sharing — Design Notes

**Status:** _Proposed / deferred_ (#57, formerly split across #15 and #57 —
merged 2026-08-05 since both are the same `CKShare` mechanism at different
permission levels; see below). Do not start until the local single-device app
is stable and device-tested.

> **Now shipped — a manual, local-first precursor (#40).** Settings ▸ Teams can
> **export** a team + roster to a `.json` file (ShareLink → AirDrop/Files) and
> **import** it on another device. It's a one-shot copy (roster only, no games, no
> live sync) — enough to seed a second phone or back up a roster without any
> account or backend. Full CloudKit `CKShare` (near-live, multi-account) below is
> still the deferred end goal; the manual flow buys most of the practical value
> at a fraction of the cost. See `CourtsideHoopStats/Models/TeamTransfer.swift`.

## Goal

Let more than one person see — and, for some, edit — the same team's roster,
games, and stats. Two use cases, **one mechanism**:

1. **Co-trackers** (Thomas + Jean): both can enter/edit scores for the same
   team, e.g. while one runs the app courtside, the other can jump in too.
2. **Followers** (friends/family — e.g. Thomas following Jean's team, or
   grandparents following Nicholas's games): read-only, get **push notified**
   whenever there's game activity, similar to subscribing to a shared calendar
   or an iCloud Shared Album.

This is the "iCloud Shared Album" experience, applied to game data — a single
share per team, where **each participant's permission level determines their
role**.

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

### Recommended sharing model: `CKShare` participant permissions

`CKShare` natively supports per-participant permission levels — no custom role
system needed:

- **`.readWrite` participants** = co-trackers/admins (Jean invites Thomas as
  `.readWrite`; both can record scores for the same team). This *does*
  introduce write conflicts (two people editing the same game at once) that
  the single-writer model avoided — see caveat below.
- **`.readOnly` participants** = followers. They get the CloudKit push
  subscription (near-live updates, catch-up-on-reconnect semantics per the
  connectivity caveat above) but cannot edit.

The share owner (whoever creates the team) invites participants and assigns
each a permission level via the standard `UICloudSharingController` share
sheet — same flow as sharing an Album or a Note.

**Write-conflict note:** with two `.readWrite` participants possibly recording
the *same* game concurrently (e.g. both open the Live Scoring screen for
today's game), CloudKit's last-writer-wins can drop an event if both add a
basket in the same instant. Realistic mitigation: this is a rare, low-stakes
collision (worst case, re-tap the missed basket) rather than something to
solve with real conflict resolution up front. Revisit only if it proves
annoying in practice.

### Scope of a share

- **Whole dataset** (team roster + all games) as one shared container is
  simplest — share the team once, done. A follower or co-tracker gets
  everything for that team, not per-game granularity.
- Someone can be a **follower on one team and a co-tracker on another** (e.g.
  Thomas: `.readWrite` on his own team, `.readOnly` following Jean's) — this
  falls out naturally since each team has its own independent `CKShare`.

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
2. Ship `.readOnly` followers first (simplest, no write conflicts), then
   `.readWrite` co-trackers as a follow-up? (Recommended: yes — followers is
   the lower-risk slice and already has real demand.)
3. Share the whole dataset or per-game? (Recommended: whole dataset.)
4. In-app copy that honestly frames "near-live, catches up offline."
5. iCloud account requirement + the share invite/accept flow — permission
   level (`.readWrite` vs `.readOnly`) is chosen by the owner at invite time.
6. Push notification content/frequency for followers (every basket vs.
   period-end summaries vs. game-start/end only) — avoid notification fatigue.
