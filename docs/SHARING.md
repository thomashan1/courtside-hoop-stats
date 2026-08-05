# Multi-User Sharing — Design Notes

**Status:** _In progress_ — implementation started 2026-08-05 on
`feature/57-sharing-followers`, **followers (read-only) first**. #57 formerly
split across #15 and #57 — merged 2026-08-05 since both are the same `CKShare`
mechanism at different permission levels; see below.

> **Visual design + iPhone mockups:** the share flow, follower live view, and
> notification screens are mocked up in the design doc artifact (published
> 2026-08-05). Scope is **Apple ecosystem only** — see the settled decisions.

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

## Settled decisions (2026-08-05)

Confirmed with Thomas after reviewing the design mockups:

1. **Ship read-only followers first**, co-trackers as a fast follow-up.
2. **Share the whole team** (roster + all its games) as one `CKShare` — not
   per-game.
3. **Apple ecosystem only.** `CKShare` requires every participant to have an
   Apple Account signed into iCloud (exactly like a Shared Album). Non-Apple /
   web followers are explicitly out of scope; reaching them would mean a public
   web link + custom backend, which breaks the "zero dependencies, no server"
   rule. Confirmed the interested followers are on iPhones.
4. **Notifications: one per period end** (quarter/half), plus game start and
   final. **Make the cadence configurable** if it's not much extra work
   (per-basket / per-period / start-and-end-only) so followers can dial down
   noise.

### Invite mechanism (answer to "how do people get added?")

The owner taps **Share Team** on a team → the standard iOS share sheet
(`UICloudSharingController`) → adds people **by email or phone number** tied to
their Apple Account (or opens the link to "anyone with the link"), sets each to
**View only** (follower) or **Can edit** (co-tracker), and sends the link via
Messages / Mail / AirDrop. The invitee taps the link, it opens in Courtside, and
the shared team appears in their Games list. Same flow as sharing a Note or an
Album.

## Store decision: what backs persistence (answered 2026-08-05)

**For the followers-first slice: keep the current `UserDefaults`/JSON store and
add a lightweight one-way CloudKit publish on top — i.e. use _neither_ Core Data
nor SwiftData yet.** Rationale:

- Followers are **read-only**, so the owner is the *only* writer. There is **no
  bidirectional sync and no conflict resolution** to handle — the hard part of
  CloudKit — so we don't need `NSPersistentCloudKitContainer`'s automatic
  merge machinery.
- Keeping the local store means **zero migration of the live season** — the
  shipping app's data is untouched. Sharing is purely additive.
- The work is: on share / on each local edit to a shared team, mirror the
  team + games + events into a CloudKit **custom zone** and hang a `CKShare` off
  the team root record (child records share along with it). Followers accept the
  share, fetch the shared zone, decode back into the **same Codable structs**,
  and render read-only. A `CKDatabaseSubscription` drives push.

**When we later add read-write co-trackers** (true bidirectional sync, real
write-conflict surface), _then_ the store question bites — and the answer is
**Core Data via `NSPersistentCloudKitContainer`, not SwiftData**:

| | Core Data + CloudKit | SwiftData + CloudKit |
|---|---|---|
| Cross-**user** `CKShare` | **Mature, proven** — first-class `share(_:to:)`, `UICloudSharingController` integration, years in production behind Notes/Reminders. | Newer; automatic CloudKit historically covered a user's **own** devices (private DB) well, with cross-user **sharing** arriving later and rougher. |
| Verdict | **Recommended** for the sharing-critical path. | Re-check current iOS 26/27 support before trusting it for sharing; nicer API, but not worth a sharing regression. |

So: **neither now, Core Data if/when co-trackers need a synced store.** Verify
SwiftData's current cross-user sharing maturity at that point in case it has
caught up, but default to the proven path.

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

## Implementation plan (followers first)

Broken into small, reviewable PRs. Only the code compiles without the CloudKit
capability; **runtime needs Thomas to enable the capability + device-test** (see
below).

- **PR 1 — Foundation (no live CloudKit; fully compile- + unit-testable).**
  - A `TeamSharingService` protocol (the seam): `share(team:)`, `publish(team:games:)`,
    `stopSharing(team:)`, `acceptedShares()`, plus a `SharingRole`
    (`follower` / `coTracker`) and an availability flag.
  - A `NoopSharingService` default so the app builds and runs exactly as today.
  - `CloudKitSchema` — pure `Team`/`Game`/`GameEvent` ⇄ `CKRecord` mapping, with
    round-trip **unit tests** (CKRecord instantiates offline, so this is testable
    without an account).
  - UI seam: a **Share Team** row in `TeamDetailView`, shown only when the
    injected service reports itself available (hidden under Noop, so no dead
    button ships).
- **PR 2 — Live `CloudKitSharingService` + invite UI. ✅ shipped 2026-08-05.**
  Custom zone per team, `CKShare` on the team root, `UICloudSharingController`
  share sheet, publish-at-share-time. Owner side only.
  - **Verified on device:** the share is created, the invite sheet opens with
    the team name + app icon, and re-sharing reuses the existing share.
  - **Not yet verified:** accepting on a *second* iCloud account. Nothing
    consumes an accepted share yet, so that lands with PR 3.
  - Permissions are deliberately pinned to **read-only, invite-only**
    (`.allowReadOnly` + `.allowPrivate`, `publicPermission = .none`): there's no
    co-tracker write path yet, and a public link would put a children's roster
    behind a forwardable URL. This makes the sheet's "Sharing Options" a
    single-choice menu — it becomes a real choice when co-trackers ship.
  - Gotchas worth remembering: games carry a **parent reference** to their team,
    so the team record must be saved **before** its games or CloudKit rejects
    them ("Parent record … does not exist on the server"); and the share sheet
    reads its title/icon from **system fields on the share record**, not from
    the controller's delegate (the delegate only applies while creating one).
- **PR 3 — Follower experience.** Accept-share entry point, read-only rendering
  of a followed team (views become read-only), the "Following" badge + honest
  "updated N ago" line.
- **PR 4 — Push.** `CKDatabaseSubscription`, remote-notification handling,
  content per period end + start/final, with a **configurable cadence** setting.

### ⚠️ Human-in-the-loop (only Thomas can do these)

CloudKit can't be exercised by the CLI/simulator build alone:

1. **Enable the capability in Xcode** ▸ target ▸ Signing & Capabilities ▸ add
   **iCloud → CloudKit** (creates the `iCloud.com.thomashan.CourtsideHoopStats`
   container + writes the entitlements file + registers it in the developer
   portal), **Background Modes → Remote notifications**, and **Push
   Notifications**. Doing this via the Xcode UI is what keeps the portal +
   entitlements in sync; hand-editing `project.pbxproj` risks breaking signing.
2. **Device-test with a second iCloud account** (a family member's phone or a
   second device) to verify invite → accept → live update actually works
   end-to-end. The simulator can't sign into a real shared CloudKit database
   meaningfully for two accounts.

## Migration notes

Because followers-first keeps the existing store (see the store decision above),
**there is no data migration for the shipping app** — sharing is additive. The
notes below apply only if/when a synced Core Data store is introduced for
co-trackers:

- Keep the local-first behavior; layer sync on top (offline still works).
- Persistence keys are already versioned (`chs.teams.v1`, `chs.games.v1`) — a
  one-time import from existing `UserDefaults` data into the new store avoids
  losing the current season.
- Updates a documented assumption: `CLAUDE.md` says "single user operating
  alone." Adding a viewer is a deliberate product scope change — record it there
  when this ships.

## Resolved (was: open questions)

1. ~~SwiftData vs `NSPersistentCloudKitContainer`~~ → **Neither for followers**
   (one-way publish on the existing store); **Core Data** if co-trackers later
   need a synced store. See "Store decision" above.
2. ~~Followers first?~~ → **Yes.**
3. ~~Whole dataset or per-game?~~ → **Whole team, one share.**
4. In-app copy that honestly frames "near-live, catches up offline." → still to
   write (PR 3).
5. ~~iCloud account requirement + invite/accept flow~~ → **Apple-only, invite by
   email/phone via the share sheet; owner sets each role at invite.**
6. ~~Push frequency~~ → **One per period end + start/final, cadence
   configurable** (PR 4).
