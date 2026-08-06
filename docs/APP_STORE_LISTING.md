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
> changes with the v1.1 upload rather than treating them as a separate errand.

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

_(158 chars.)_

Editable anytime without review, so it should lead with whatever is newest.
The evergreen fallback, for when nothing is new: "Tap a player, tap the basket —
the team score adds itself. The fastest way to keep youth-basketball stats from
the sideline, one-handed."

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
nothing to them. Regenerate each release from the milestone:
`gh issue list --milestone vX.Y --state closed`.

**v1.2** (in progress):

> NEW: Let family follow your games.
>
> Share a team and invite grandparents, friends, or the other parent from the
> normal share sheet — just like a shared photo album. They get a view-only
> screen with the live score and player stats on their own iPhone, and can't
> change anything. Updates arrive in seconds when you have signal, and catch up
> once you're out of a dead-zone gym.

---

## 6. App Privacy (the "nutrition label" questionnaire)

The app collects **nothing** and has no backend of ours, so answer the App Store
Connect privacy questions as:

- **Do you or your third-party partners collect data from this app?** → **No**

That yields a "**Data Not Collected**" label. No account, no analytics SDK, no
ads. Storage is local UserDefaults/JSON.

⚠️ **Re-check this now that sharing exists.** A shared team's roster and games
are written to **the user's own iCloud** (CloudKit private/shared database).
Apple's questionnaire is about data *we* collect, and data that stays inside a
user's own iCloud is not collection by the developer — so "No" should still be
right. But a **changed privacy answer plus new iCloud entitlements is the
profile that draws review scrutiny**, so re-read the questions against the
sharing feature before submitting rather than answering from memory, and expect
more friction than a routine update.

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

Upload hero-first: `01-game-live-scoring` → `02-game-score-pad` →
`06-game-summary-share-pdf` → `10-following-teams` (the headline for this
release) → `05-game-summary` → `07-team-games`.

App preview video: optional, still skipped.

---

## 10. Review notes (App Review Information field)

> Single-user local app for tracking a youth basketball team's stats. No account
> or login. To try it: on the Roster tab add a player or two, tap "+" on the
> Games tab to open the New Game form (every field is optional) and tap "Start
> Game", then tap a player and a +2/+3/FT button to score, and tap the period
> boundary at the top of the score log to "End Period". All data is stored
> locally on device.

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
- [x] v1.0 approved and live

### Per-release checklist (v1.1 onward)

**Upload:** `Product ▸ Archive` in Xcode, then in the Organizer
`Distribute App ▸ App Store Connect ▸ Upload`. Organizer re-signs for
distribution, so a development-signed archive is fine. Processing takes roughly
15–30 minutes before the build is selectable in App Store Connect.

- [ ] Bump **`MARKETING_VERSION`** (not just the build) — a closed train rejects
  uploads with `ITMS-90186` / `ITMS-90062`
- [ ] `Product ▸ Archive`, upload via Organizer (or `xcodebuild -exportArchive`)
- [ ] Re-capture store screenshots if the UI changed
  (`scripts/screenshots.sh "iPhone 14 Plus"`)
- [ ] Update **What's New** from the milestone's closed issues
- [ ] One real game of use (validate with the actual courtside user) before release
