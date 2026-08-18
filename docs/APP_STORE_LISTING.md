# App Store Listing — Courtside Hoop Stats

Copy-paste-ready metadata for App Store Connect. Everything here reflects the
app **as it actually ships today** (iPhone-only, tap-to-score, no foul tracking,
no undo button). Edit tone to taste before submitting.

> **Live on the App Store:**
> <https://apps.apple.com/us/app/courtside-hoop-stats/id6791865094>
>
> Only **promotional text** can be edited without a review. App name, subtitle,
> **description, keywords, screenshots**, "What's New", and the support/privacy
> URLs all require a **new version with a build attached** — so bundle metadata
> changes with the next upload rather than treating them as a separate errand.

---

## 1. Names & identity

| Field | Value |
|---|---|
| **App Name** (30 char max) | `Courtside Hoop Stats` (20) |
| **Subtitle** (30 char max) | `Fast courtside stat tracking` (28) |
| **Bundle ID** | `com.thomashan.CourtsideHoopStats` |
| **SKU** (your internal ref) | `courtside-hoop-stats-01` |
| **Primary category** | Sports |
| **Secondary category** | (optional — leave blank, or *Utilities*) |
| **Version** | `MARKETING_VERSION` in `project.pbxproj` (Apple closes a version's train once approved, so each release needs a *new* version, not just a build) |
| **Build** | `CURRENT_PROJECT_VERSION` — bump each upload |
| **Age rating** | **4+** (see §7) |
| **Price** | Free |
| **Availability** | All countries, or just your region |

Device support: **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`) → **no iPad
screenshots or iPad review required.**

---

## 2. Promotional text (170 char max — editable anytime, no review)

> New: share your team so family can follow the game live from their own iPhone
> — view-only, no account to make, just like a shared photo album.

_(142 chars.)_

Editable anytime without review, so it should lead with whatever is newest —
and it can be swapped the day something changes, without waiting on a
submission. It sits above the description on the App Store page, so it's read
first and often instead.

The evergreen fallback, for when nothing is new: "Tap a player, tap the basket —
the team score adds itself. The fastest way to keep youth-basketball stats from
the sideline, one-handed." (136 chars.)

## 3. Keywords (100 char max, comma-separated, NO spaces)

```
basketball,stats,scorekeeper,box score,youth,coach,team,scoring,tracker,hoops,tally,sideline
```

(96 chars. Don't repeat the app name or category — Apple already indexes those.)

---

## 4. Description

> **The fastest way to keep your team's basketball stats — right from the sideline.**
>
> Courtside Hoop Stats is built for the one parent or coach tracking a youth game alone. It replaces the messy spreadsheet with two taps: tap a player, tap what they did. The team score adds itself.
>
> **BUILT FOR SPEED, COURTSIDE**
> • Tap a player, then a big +2 / +3 / FT button — that's the whole flow
> • Live score log stays on top; players sit in the thumb zone
> • Large, high-contrast buttons and scoreboard, readable in a bright gym
> • Follows Light or Dark automatically
>
> **TRACK WHAT MATTERS**
> • 2-point and 3-point field goals
> • Free throws — made and missed, for accurate FT%
> • Team score, calculated automatically from every basket
> • Bench players who aren't at the game so the roster stays uncluttered
>
> **GAME MANAGEMENT**
> • Quarters, halves, or a no-periods pickup game — pick your league's format
> • New game in seconds: every field is optional, then Start Game or schedule it
> • Enter the opponent's running score at each period break
> • Editable, reorderable score log — fix any mistake, anytime
> • Manage multiple teams; each keeps its own roster and games
>
> **AFTER THE GAME**
> • Period-by-period linescore and final result
> • Per-player stat table: points, 2PT, 3PT, and free-throw shooting
> • Share a one-page PDF box score straight to the team's group chat
> • Notes for scouting and observations
>
> **LET FAMILY FOLLOW ALONG**
> • Share a team so grandparents, friends, or the other parent can watch
> • Invite them from the normal share sheet, like an iCloud Shared Album
> • They get a view-only screen — the score and stats, nothing they can change
> • Updates arrive in seconds with signal, and catch up after a dead-zone gym
>
> **YOUR DATA STAYS YOURS**
> No sign-up. No ads. No tracking. Your games live on your device — and if you
> choose to share a team, it goes through your own iCloud to the people you
> invite, and nowhere else.
>
> Perfect for youth leagues, rec teams, and any parent who wants real stats without the hassle.

## 5. What's New

Write what the user *sees* — "player totals when someone is benched" says
nothing to them. **NEW** first, then **FIXES**, a couple of numbered lines each.
Nobody reads a twenty-line changelog on a phone, so leave out anything they
wouldn't have noticed.

One block per submitted version, newest first, with the date it went to App
Store Connect. This is the one place the project keeps a per-version record:
what shipped when is the question App Review, a bug report, or a "when did this
change?" all start from, and it can't be recovered from the current state of the
code.

### v1.2 — submitted 2026-08-17, approved and released 2026-08-18

> NEW
>
> 1. Share a team so family can follow the live score and player stats from
>    their own iPhone — with optional alerts each quarter and at the final.
> 2. Choose your team's colour.
>
> FIXES
>
> 1. Stays readable and usable at the largest text sizes.
> 2. Buttons in Settings and on the scoring screen no longer miss taps.
> 3. Deleting a team now asks first.
>
> UPDATED PRIVACY
>
> 1. Nothing leaves your device unless you share a team. If you do, that team's
>    roster and games are copied to your own iCloud so the people you invite can
>    see them — and nowhere else.
> 2. Only people you invite by Apple Account can view it. There's no public
>    link, and they can't change anything.
> 3. Still no account, no ads, and no tracking. We receive no copy of your data.

The privacy block exists because earlier versions promised data *"never leaves
your device"*, and sharing makes that no longer true for a team you choose to
share. Saying so in the release notes is the honest version of a changed
promise, and it pre-empts the obvious review question on the submission that
adds iCloud and push entitlements.

Keep it while the sharing feature is still new to users; it can drop out of a
later release's notes once it isn't news.

### v1.1 — submitted 2026-08-04, approved 2026-08-17

> NEW
>
> 1. Share a one-page PDF box score after the game.
>
> FIXES
>
> 1. The "+" button on the Games tab no longer misses taps.
> 2. Player totals now match the final score when someone is benched.

---

## 6. App Privacy (the "nutrition label" questionnaire)

The app collects **nothing** and has no backend of ours, so answer the App Store
Connect privacy questions as:

- **Do you or your third-party partners collect data from this app?** → **No**

That yields a "**Data Not Collected**" label. No account, no analytics SDK, no
ads.

**Sharing does not change that answer.** A shared team's roster and games are
written to **the user's own iCloud** (CloudKit private/shared database), where
the developer has no access and receives no copy. Apple's questionnaire asks
what *we* collect, and data that stays inside a user's own iCloud isn't
developer collection.

What it *does* change is the risk profile: **new iCloud and push entitlements
alongside an unchanged privacy answer draws more scrutiny than a routine
update**. Two things to have ready rather than improvise:

- `docs/PRIVACY_POLICY.md` is already rewritten for sharing. The pre-sharing
  version claimed data is *"stored only on your device"* and *"never sent to any
  server"*, which sharing made false — make sure the **hosted** copy at the
  listing's privacy URL is the current one, not the old text.
- The review notes (§10) should say plainly that sharing is invite-only via
  CKShare, read-only for invitees, and that a shared roster can contain minors'
  first names and jersey numbers.

**Export compliance / encryption:** already declared in the target —
`ITSAppUsesNonExemptEncryption = NO`. App Store Connect will not ask again.

---

## 7. Age rating questionnaire → 4+

Answer **None / No** to every content question (no violence, no mature/suggestive
themes, no user-generated content, no web access, no gambling, no contests). Result: **4+**.

---

## 8. URLs

Both are **required by Apple** and already set in App Store Connect, where they
persist across releases — you don't re-enter them each submission.

| Field | What it is |
|---|---|
| **Privacy Policy URL** | The "Privacy Policy" link on the App Store page. Serves `docs/PRIVACY_POLICY.md`. |
| **Support URL** | The "App Support" link on the App Store page — the repo. |
| **Marketing URL** | Optional; unused. |

Only change them if the repo moves. They can't be edited without a new version.

## 9. Screenshots

**iPhone-only.** This listing uses the **6.5" bucket: `1284 × 2778`** — that's
what App Store Connect asks for here, because the slot was created at the 1.0
submission. Capture on an iPhone 14 Plus-class simulator; see
[`SCREENSHOTS.md`](SCREENSHOTS.md) for the exact command (drive it by simulator
**ID**, the name alone can fail to resolve).

- **1284 × 2778 (6.5")** — what this listing takes.
- 1320 × 2868 (6.9") is what a *new* listing would want, but don't upload it into
  a 6.5" slot; it's rejected on dimensions.

The committed `docs/img/*.png` **are** this upload set, captured at the store
size and **numbered in display order** — see [`SCREENSHOTS.md`](SCREENSHOTS.md).
Don't regenerate a second, smaller README-only set; that drift is what caused an
upload to be rejected.

### Which ten, and in what order

App Store Connect takes **ten**, and `docs/img/` holds exactly ten, **numbered
in upload order**. Work down the directory listing and the sequence is right —
there's nothing to reorder by hand, which is the step that goes wrong.

The first three matter most: they're what shows in search results, before anyone
taps through to the listing.

| # | File | Why it's here |
|---|---|---|
| 1 | `01-game-live-scoring` | The hero: scoring mid-game, bench strip open. The one screen the app exists for. |
| 2 | `02-game-score-pad` | Makes the two-tap promise concrete — tap a player, tap a number. |
| 3 | `03-following-game` | This release's headline. Family watching a live score from their own phone. |
| 4 | `04-game-summary` | The payoff: final score, linescore, per-player stats. |
| 5 | `05-game-summary-share-pdf` | The box score people actually send around. |
| 6 | `06-following` | Sets up #3 — what a follower's list looks like. |
| 7 | `07-games` | Season shape: past, live and scheduled together. |
| 8 | `08-roster` | Answers "how much setup is this?" |
| 9 | `09-new-game` | Every field optional; Start Game gets straight to scoring. |
| 10 | `10-team-jerseys` | Colour and home kit — small, but it's what makes the app feel like *your* team. |

**Two screens were dropped to reach ten**, and it's worth recording why so they
don't get added back: the score-log **reorder editor** (a dozen near-identical
rows — a maintenance screen, not a reason to download) and the **Settings teams
list** (#3 and #6 sell sharing far better than a "Shared" pill does).

Since the cap is hard, adding a screen means choosing one of these ten to lose.

App preview video: optional, still skipped.

---

## 10. Review notes (App Review Information field)

> App for tracking a youth basketball team's stats. No account or login.
>
> To try it: on the Roster tab add a player or two, tap "+" on the Games tab to
> open the New Game form (every field is optional) and tap "Start Game", then tap
> a player and a +2/+3/FT button to score, and tap the period boundary at the top
> of the score log to "End Period".
>
> Data is stored locally on device. The optional sharing feature (Settings ▸
> Teams ▸ a team ▸ Share Team) uses CloudKit CKShare to copy that team's roster
> and games into the *user's own* iCloud so people they invite can view them.
> Invitations go to specific Apple Accounts through the system share sheet;
> there is no public link, invitees are read-only, and we operate no server and
> receive no copy of any data. Push is a silent content-available notification
> used only to refresh a follower's copy; the alert text is generated on device.
>
> A shared roster may contain minors' first names and jersey numbers, entered by
> the user and visible only to the specific Apple Accounts they invite.
>
> Sharing needs two different Apple Accounts to exercise end-to-end. If that
> isn't practical, everything else in the app works without it — the sharing UI
> only appears once a team is shared.

No demo account needed (there is no login).

---

## 11. Pre-submission checklist

- [x] Paid Apple Developer Program membership active
- [x] Bundle ID registered (`com.thomashan.CourtsideHoopStats`)
- [x] iPhone-only (`TARGETED_DEVICE_FAMILY = 1`)
- [x] Encryption declaration set (`ITSAppUsesNonExemptEncryption = NO`)
- [x] App icon present (1024×1024, no alpha) — real art shipped, not a placeholder
- [x] Privacy policy written (`docs/PRIVACY_POLICY.md`, contact thomashan@icloud.com)
- [x] ~~Blocker: build on a release Xcode~~ — resolved; v1.0 was submitted and approved
- [x] Signing **Team** set to the paid team + Distribution profile
- [x] Host the Privacy Policy at a public HTTPS URL
- [x] App Privacy = *Data Not Collected*; Age rating = 4+
- [x] v1.0 approved and live; v1.1 approved and live
- [x] **CloudKit schema deployed to Production** — a one-time promotion in the
  CloudKit Console, because Development auto-creates record types and Production
  doesn't. Verified rather than assumed: two TestFlight builds (which run against
  Production) shared a team and followed each other's games end to end. Only
  needs redoing when the schema changes — a new record type or field is
  Development-only until it's promoted again.

### TestFlight (beta, before a public release)

**Xcode Cloud builds every push to `main` and sends it to TestFlight.** There is
no Archive step — merging *is* the release action for beta. Worth knowing before
you merge: a push produces a build testers can install.

Worth doing for anything touching sharing, because **a TestFlight build runs
against Production CloudKit** and a development-signed build never does. The
environment is chosen by the signature, so everything tested from Xcode has only
ever exercised the Development schema.

1. **Merge to `main`.** The build starts on its own.
2. Watch it under the app's **Xcode Cloud** tab, or **TestFlight ▸ iOS Builds**.
   Expect processing to take a few minutes after the build succeeds.
3. It appears for the **Han family** internal group automatically. Internal
   testers need no Beta App Review; external testers do (about a day).
4. Testers install through the **TestFlight app**.

**Xcode Cloud assigns its own build numbers** — they run in their own sequence
(70s at the time of writing) rather than following `CURRENT_PROJECT_VERSION`.
So there's normally no need to bump that by hand for a TestFlight build;
`MARKETING_VERSION` still has to change for a new App Store version.

⚠️ **Production CloudKit is a different store**, and switching between them
splits cleanly along that line. Verified by installing a TestFlight build over a
development one:

- **Local data survives.** Teams, rosters and games live in `UserDefaults`, and
  the TestFlight build installs over the development one as an update rather
  than requiring a delete. Exporting a backup first is still cheap insurance,
  but it isn't the prerequisite it looks like.
- **The Following tab empties.** Followed teams are a cache of what CloudKit
  returns, and Production has none of the shares made from a development build.
  That's correct behaviour, not data loss — the owner's copy is untouched.

**Both devices have to be on the same environment for sharing to work at all.**
A TestFlight build and a development build cannot see each other's shares, so
testing this with a second person means moving *both* to TestFlight, then
re-sharing and re-accepting there.

**Manual upload**, only if Xcode Cloud is unavailable: set the run destination to
**Any iOS Device (arm64)** (Archive is greyed out on a simulator), then
**Product ▸ Archive ▸ Distribute App ▸ App Store Connect ▸ Upload**. Bump
`CURRENT_PROJECT_VERSION` first, since a manual upload does follow it and a
duplicate build number is rejected.

### Per-release checklist

**Getting a build up:** there's nothing to upload. Xcode Cloud already built
every push to `main`, so the release build is one of the ones sitting in
TestFlight — pick it in App Store Connect rather than archiving a new one. That
also means the build you ship is the build that was beta-tested, which is the
point. `Product ▸ Archive` is the fallback above, for when Xcode Cloud isn't
available.

- [ ] Bump **`MARKETING_VERSION`** (not just the build) — a closed train rejects
  uploads with `ITMS-90186` / `ITMS-90062`
- [ ] Confirm the Xcode Cloud build for the release commit reached TestFlight
- [ ] Re-capture store screenshots if the UI changed
  (`scripts/screenshots.sh "iPhone 14 Plus"`, then refresh `docs/img/` per the
  mapping table in `SCREENSHOTS.md`)
- [ ] Update **What's New** from the milestone's closed issues, and date the
  section
- [ ] Close out the milestone: every shipped issue actually *on* it, anything
  deferred moved to the next one. It's the release-notes source, so an
  unmilestoned issue is invisible here.
- [ ] One real game of use (validate with the actual courtside user) before release
