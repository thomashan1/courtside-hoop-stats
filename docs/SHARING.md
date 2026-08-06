# Multi-User Sharing

**Status:** read-only **followers** are built and shipping in **v1.2** (#57).
Read-write **co-trackers** are deferred — see [Not built yet](#not-built-yet).

## What it does

A team owner can share a team so family and friends can watch its games and
stats from their own iPhone. Invitations go out through the standard iOS share
sheet — addressed to the invitee's **Apple Account** by email or phone number,
delivered by Messages / Mail / AirDrop — exactly like an iCloud Shared Album.

Followers get a **read-only** view: they see the roster, live score, player
stats, and per-period breakdown, and can change nothing.

### Scope and limits

- **One share per team.** Sharing a team shares its whole roster and every one
  of its games. There's no per-game sharing.
- **Apple ecosystem only.** Every participant needs an Apple Account signed into
  iCloud on an Apple device. Android or web followers are out of scope —
  reaching them would need a public link plus a server, which breaks the app's
  zero-dependency, no-backend constraint.
- **Invite-only.** There is deliberately no "anyone with the link" option: a
  forwardable URL to a roster of children is the wrong default. Owners can still
  invite anyone by email or phone.
- **Read-only.** The share sheet offers "View only" and nothing else. Offering
  an edit permission would let a participant make changes the app has no code to
  sync back, and the failure would be silent.

### Honest expectations about liveness

The app is local-first because gyms are dead zones. CloudKit queues changes and
syncs when signal returns, but a follower only sees updates when the **tracker's**
phone has a connection:

- **Signal present:** updates land within seconds.
- **Dead-zone gym:** the follower sees the game catch up in a burst once the
  tracker is back online — not tap-by-tap.

Either way the follower ends up with the complete game. The UI says this plainly
rather than promising "live", and every followed team shows an "Updated N ago"
line.

## How it works

**CloudKit `CKShare`** — Apple's native mechanism for sharing between *different*
iCloud accounts, and the same plumbing behind Shared Albums and collaborative
Notes. It runs on participants' existing iCloud accounts, needs no third-party
backend, and stays free.

### Data layout

One **custom zone per shared team** (`team-<uuid>`). Sharing requires a custom
zone — records in the default zone can't be shared — and a zone per team keeps
hierarchies isolated, so "stop sharing" is a single zone delete that cannot
reach another team's data.

- **`SharedTeam`** root record, one per shared team.
- **`SharedGame`** child records, each holding a **parent reference** to its
  team. A single `CKShare` on the team root therefore shares every game with it
  (CloudKit hierarchical sharing), and deleting the team cascades.

A game's events, period scores, and bench list ride **inside its JSON payload**
rather than as separate records. A season is a few kilobytes, so re-uploading a
whole game on edit is cheaper than normalizing every basket into its own record
and reconciling them.

### No data migration

The local `UserDefaults`/JSON store stays the source of truth; sharing is purely
additive. CloudKit records reuse the **same `Codable` structs**, so there is no
schema translation and the live season is never touched.

This is why followers need **neither Core Data nor SwiftData**: followers are
read-only, so the owner is the only writer and there is no bidirectional sync or
conflict resolution to manage. Publishing is one-way.

### Why the data model shares well

Events are effectively append-only (undo = remove-last) and every aggregate is
*derived*, not stored — so there's no separate stats store to reconcile, and the
conflict surface is small.

## Code map

| File | Role |
|---|---|
| `Sharing/SharingService.swift` | `TeamSharingService` protocol — the seam between the app and CloudKit — plus `SharingRole`, `NoopSharingService`, and environment injection. Views never `import CloudKit`. |
| `Sharing/CloudKitSharingService.swift` | The live implementation: zones, share creation, publish, follower fetch. |
| `Sharing/CloudKitSchema.swift` | `Team`/`Game` ⇄ `CKRecord` mapping. Pure and unit-tested. |
| `Sharing/CloudSharingSheet.swift` | SwiftUI wrapper over `UICloudSharingController`. |
| `Sharing/ShareAcceptance.swift` | Scene delegate that catches share invitations. |
| `Sharing/FollowedTeam.swift` | A followed team's read-only snapshot. |
| `Views/FollowingView.swift` | The follower's read-only UI. |
| `Sharing/FollowerAlerts.swift` | Decides what's worth notifying about. Pure and heavily tested. |
| `Sharing/FollowerNotifier.swift` | Posts those alerts; owns the permission request. |

Swapping `NoopSharingService` in for the live service at the app root hides every
sharing affordance and returns the app to local-only.

### Design choices worth keeping

- **Followed teams live in `AppStore.followedTeams`, never in `teams`.** Mixing
  them into the owner's own collection would put read-only data behind every
  editor in the app. Keeping them separate makes "look but don't touch" a
  property of the data rather than something each view must remember.
- **`FollowingView` is its own smaller view, not `GamesListView` with a
  read-only flag.** Those views are built around editing; a missed check would
  leave an edit path one tap away. A view with no edit affordances can't grow
  one by accident.
- **The Following tab is conditional** — it appears only when something is
  actually shared with you, so a tracker running their own team never sees an
  empty tab.
- **Followed teams are cached** to `UserDefaults`, so a follower opening the app
  in a dead-zone gym still sees the last known score.

## Notifications

A follower is notified when a game **starts**, at each **period end**, and at the
**final score**. The cadence is configurable — every score / each period / start
and final only / off — because notification fatigue is the real failure mode: a
grandparent pinged on every basket mutes the app and then misses the final.

**Why the app posts its own notifications.** CloudKit's push can't carry a score;
it only says "something in the shared database changed". So a
`CKDatabaseSubscription` wakes the app silently, the app fetches, compares
against the snapshot the follower last saw, and posts a **local** notification
with the real numbers in it. That round trip is why the wording lives in
`FollowerAlerts.swift` rather than in a push payload.

Two behaviours worth keeping:

- **The first fetch never notifies.** A freshly accepted share has nothing to
  compare against, so every game looks new — announcing a whole season at once
  is the worst possible first impression.
- **A final supersedes the period end that lands with it.** A game usually ends
  and closes its last period in the same publish; two notifications for one
  moment is noise.

Alert ids are derived from the event (`period-<game>-<n>`), so a repeated fetch
replaces its own notification instead of stacking duplicates.

Permission is requested only once a team is *actually* shared with you — a
prompt on first launch has no context and gets declined. Declining still leaves
the silent wake working, so the Following tab stays current either way.

## Gotchas

Four things that cost real debugging time and will not be obvious next time:

1. **`CKSharingSupported` must be `true` in `Info.plist`.** Without it, tapping
   an invite shows *"Update Courtside — you'll need the latest version"* and
   offers the App Store; the app never opens and
   `userDidAcceptCloudKitShareWith` never fires. The message blames the app
   version, which sends you looking in entirely the wrong place.
2. **Save the team record before its games.** Games carry a parent reference, and
   CloudKit rejects a child whose parent isn't on the server yet with *"Parent
   record … does not exist on the server"*. `saveHierarchy` enforces the order.
3. **The share sheet reads its title and icon from system fields on the *share
   record*,** not from `UICloudSharingController`'s delegate — the delegate is
   only consulted while a share is being created. Setting them on the record is
   also what lets an existing share pick up a renamed team.
4. **Share discovery can't live inside the Following tab.** The tab only renders
   once `followedTeams` is non-empty, so a fetch that ran only from inside it
   could never populate it. `ContentView` looks for shared teams at launch;
   otherwise a follower who reinstalled the app would never see shares they had
   already accepted.

## Testing with one device

There is **no CloudKit equivalent of StoreKit's sandbox testers** (confirmed by
Apple DTS, February 2026). Cross-account sharing needs a **second real Apple
Account**. With one iPhone plus a Mac:

- **Owner on the physical iPhone, follower in a Simulator** signed into a second
  Apple Account. Simulator iCloud sign-in works but is historically flaky; if it
  hangs, `xcrun simctl erase` and retry.
- **Hand the share URL over manually** (log `CKShare.url`) rather than fighting
  Messages/Mail in the Simulator.
- ⚠️ Opening a share link in **Simulator Safari fails** ("iCloud has stopped
  responding"). Open it from inside another app instead.
- ⚠️ Test **cold launch and warm launch separately** — `userDidAcceptCloudKitShareWith`
  has been reported not to fire on cold launch, including in Apple's own sample.
- ⚠️ Create the test Apple Account **once and keep it.** Repeatedly creating
  accounts triggers rate-limiting Apple support may not lift.
- Stay in the **Development** CloudKit environment. Production does not
  auto-create schema — deploy it from the CloudKit Console before any
  TestFlight/App Store build tries to share.

The **follower UI itself needs no iCloud account**: `DemoData.makeFollowedTeam()`
seeds a followed team and `FollowingScreenshotTests` drives the whole flow. Only
the accept handshake and the real fetch require two accounts.

## Not built yet

**Co-trackers (`.readWrite` participants)** — two people scoring the same team,
e.g. one running the app courtside while the other jumps in. The mechanism is
identical; a co-tracker is just a participant at a higher permission level.

Roughly **3–4x the work followers took**, and a different kind of work: followers
were purely additive, while co-trackers *change* the code followers depend on —
the service's database/zone handling, the publish path, and `Game`'s shape.

What it needs:

- **Writing into someone else's zone.** Every private method here assumes the
  private database and a self-owned zone (`ownerName: CKCurrentUserDefaultName`).
  A co-tracker writes into the *owner's* zone in the shared database, so the
  database and zone have to be threaded through rather than assumed.
- **Echo suppression.** Applying an inbound change mutates `@Published` state,
  which triggers `save()` → `schedulePublish()` — republishing what was just
  downloaded. Needs an apply-remote path that doesn't re-publish.
- **Change tokens and subscriptions.** Followers get away with fetch-on-launch
  and a refresh button. Co-trackers can't: if one person's baskets don't appear
  until the other pulls to refresh, they double-record.
- **A merge policy.** Here the event-sourced model helps, but less than it looks:
  - Events carry stable ids, so merging two event lists is **union by id,
    sorted by timestamp** — commutative, idempotent, converges in any order.
  - But events are **not** actually append-only in this code: the log editor
    deletes and edits them in place. Deletes need **tombstones** (a union merge
    can't tell "deleted" from "not seen yet", so deleted events resurrect), and
    in-place edits have no modification stamp to arbitrate with.
  - `periodEndScores` is hand-typed and mutable, `applyingReorderedLog` rewrites
    every event's period, and `benchedPlayerIDs` is a plain list. None of these
    merge — they need whole-game last-writer-wins or an owner-only lock.
- **Live Scoring's ownership model.** It holds a local `@State` copy of the game
  loaded once. A remote change landing while it's open is invisible, and the
  next tap republishes the stale copy over it.

**Not Core Data.** An earlier version of this doc said co-trackers require
`NSPersistentCloudKitContainer`. That's over-conservative: its attribute-level
merge buys nothing while a whole game rides as one JSON blob in a single field,
so getting value from it would *also* mean normalizing every event into its own
record and migrating everyone off the `UserDefaults` blob — three large changes
instead of one. Merging locally on the existing `Codable` structs is the smaller
path.

**Smallest useful slice: baton-passing, not merging.** Share at `.readWrite` but
have the app enforce a single writer — an active-tracker marker on the game plus
an explicit "Take over scoring" handoff. That delivers the real story (one person
takes over at halftime) with almost no conflict surface: no tombstones, no merge
function, no per-field policy.

**Riskiest part** is not the CloudKit plumbing, which is mechanical. It's that
whole-game last-writer-wins plus Live Scoring's stale local copy can lose data
*silently and retroactively, during a live game* — exactly when the user can't
stop and debug. Followers could never lose data; co-trackers can.

## Related

- **Export a Backup (#40)** still earns its place next to sharing: it's a
  **copy you own** rather than a live view of someone else's team, needs no
  iCloud account, works offline, and is the only real backup — sharing is a
  mirror, so deleting a team removes it from followers too. See
  `Models/TeamTransfer.swift`.
- The app is no longer single-user: a team's games can be watched by anyone the
  owner invites, though only the owner can record them.
