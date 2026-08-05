# App Store Listing — Courtside Hoop Stats

Copy-paste-ready metadata for App Store Connect. Everything here reflects the
app **as it actually ships today** (iPhone-only, tap-to-score, no foul tracking,
no undo button). Edit tone to taste before submitting.

> **v1.0 is live:**
> <https://apps.apple.com/us/app/courtside-hoop-stats/id6791865094>
> **v1.1 is merged and awaiting submission.**
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
| **Version** | `1.1` (`MARKETING_VERSION` — Apple closes a version's train once approved, so each release needs a *new* version, not just a build) |
| **Build** | `17` (`CURRENT_PROJECT_VERSION` — bump each upload) |
| **Age rating** | **4+** (see §7) |
| **Price** | Free |
| **Availability** | All countries, or just your region |

Device support: **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`) → **no iPad
screenshots or iPad review required.**

---

## 2. Promotional text (170 char max — editable anytime, no review)

> New in 1.1: share any finished game as a one-page PDF box score — straight to
> the team group chat, no spreadsheet, no screenshots of a scrolling table.

_(151 chars. Previous: "Tap a player, tap the basket — the team score adds
itself. The fastest way to keep youth-basketball stats from the sideline,
one-handed." — worth restoring once 1.1 is no longer new.)_

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
> **YOUR DATA STAYS YOURS**
> No account. No ads. No tracking. Everything is stored on your device.
>
> Perfect for youth leagues, rec teams, and any parent who wants real stats without the hassle.

## 5. What's New

**v1.1** (pending submission — 374 chars):

> NEW: Share the box score as a PDF.
>
> Finish a game, tap share, and preview a clean one-page recap — final score,
> period by period, and every player's line. Send it to the team group chat,
> print it, or save it to Files. Players who sat out are listed as DNP.
>
> Also: the "+" button no longer misses a tap, and a player benched after
> scoring keeps their points in the box score.

Regenerate for future releases from the milestone:
`gh issue list --milestone vX.Y --state closed`. Write what the user *sees* —
"player totals when someone is benched" says nothing to them.

**v1.0** (shipped):

> First release. Fast two-tap courtside scoring, editable score log, multi-team
> rosters, quarter/half/pickup formats, and a per-player + period-by-period game
> summary.

---

## 6. App Privacy (the "nutrition label" questionnaire)

The app collects **nothing** and has no backend, so answer the App Store Connect
privacy questions as:

- **Do you or your third-party partners collect data from this app?** → **No**

That yields a "**Data Not Collected**" label. (No account, no analytics SDK, no
ads, no network calls — all storage is local UserDefaults/JSON.)

**Export compliance / encryption:** already declared in the target —
`ITSAppUsesNonExemptEncryption = NO`. App Store Connect will not ask again.

---

## 7. Age rating questionnaire → 4+

Answer **None / No** to every content question (no violence, no mature/suggestive
themes, no user-generated content, no web access, no gambling, no contests). Result: **4+**.

---

## 8. URLs

| Field | Required? | Value |
|---|---|---|
| **Support URL** | **Required** | e.g. the GitHub repo, or a one-page site. `https://github.com/thomashan1/courtside-hoop-stats` |
| **Privacy Policy URL** | **Required** | Host `docs/PRIVACY_POLICY.md` somewhere public (GitHub Pages, or the raw file URL). |
| **Marketing URL** | Optional | — |

> The privacy policy is **written and ready** (`docs/PRIVACY_POLICY.md`, contact
> **thomashan@icloud.com**) — it just needs to be reachable over HTTPS. Easiest
> path: enable GitHub Pages on the repo (once it's public) and link the rendered
> `PRIVACY_POLICY.md`, or paste its contents into a gist/page.

---

## 9. Screenshots

**iPhone-only.** This listing uses the **6.5" bucket: `1284 × 2778`** — that's
what App Store Connect asks for here, because the slot was created at the 1.0
submission. Capture on an iPhone 14 Plus-class simulator; see
[`SCREENSHOTS.md`](SCREENSHOTS.md) for the exact command (drive it by simulator
**ID**, the name alone can fail to resolve).

- **1284 × 2778 (6.5")** — what this listing takes.
- 1320 × 2868 (6.9") is what a *new* listing would want, but don't upload it into
  a 6.5" slot; it's rejected on dimensions.

Suggested 5–6 to upload (hero first): **Live Scoring**, **Score pad**,
**Game Summary**, **Box score PDF** (the v1.1 headline), **Games list**,
**Roster**. (The committed `docs/img/*.png` are the README set at iPhone 17
size; regenerate at the store size above for the listing.)

App preview video: optional, skip for v1.0.

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

- [ ] Bump **`MARKETING_VERSION`** (not just the build) — a closed train rejects
  uploads with `ITMS-90186` / `ITMS-90062`
- [ ] `Product ▸ Archive`, upload via Organizer (or `xcodebuild -exportArchive`)
- [ ] Re-capture store screenshots if the UI changed
  (`scripts/screenshots.sh "iPhone 14 Plus"`)
- [ ] Update **What's New** from the milestone's closed issues
- [ ] Choose **Manual release**; skip phased release at this user count
- [ ] Submit **Tue/Wed morning** — roughly half the queue wait of a weekend
- [ ] One real game of use (validate with the actual courtside user) before release
