# App Store Listing — Courtside Hoop Stats

Copy-paste-ready metadata for the App Store Connect submission. Everything here
reflects the app **as it actually ships today** (iPhone-only, tap-to-score, no
foul tracking, no undo button). Edit tone to taste before submitting.

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
| **Version** | `1.0` (`MARKETING_VERSION`) |
| **Build** | `1` (`CURRENT_PROJECT_VERSION` — bump each upload) |
| **Age rating** | **4+** (see §7) |
| **Price** | Free |
| **Availability** | All countries, or just your region |

Device support: **iPhone only** (`TARGETED_DEVICE_FAMILY = 1`) → **no iPad
screenshots or iPad review required.**

---

## 2. Promotional text (170 char max — editable anytime, no review)

> Tap a player, tap the basket — the team score adds itself. The fastest way to
> keep youth-basketball stats from the sideline, one-handed.

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
> • Quarters, halves, or a no-periods pickup game — your league's format
> • Quick Pickup Game: start scoring instantly, zero setup
> • Enter the opponent's running score at each period break
> • Editable, reorderable score log — fix any mistake, anytime
> • Manage multiple teams; each keeps its own roster and games
>
> **AFTER THE GAME**
> • Period-by-period linescore and final result
> • Per-player stat table: points, 2PT, 3PT, and free-throw shooting
> • Notes for scouting and observations
>
> **YOUR DATA STAYS YOURS**
> No account. No ads. No tracking. Everything is stored on your device.
>
> Perfect for youth leagues, rec teams, and any parent who wants real stats without the hassle.

## 5. What's New (release notes for v1.0)

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

> **Action:** you need a *reachable* HTTPS Privacy Policy URL. Easiest path:
> enable GitHub Pages on the repo (once it's public) and link the rendered
> `PRIVACY_POLICY.md`, or paste its contents into a gist/page.

---

## 9. Screenshots

**iPhone-only → you only need iPhone sizes.** As of 2026 App Store Connect
accepts a single required size and scales it:

- **6.9-inch** (iPhone 17 Pro Max / 16 Pro Max) — **required**, 1320 × 2868.
- 6.5-inch / 6.1-inch — optional; the 6.9" set is reused if omitted.

Generate them with the harness at the Max size:

```bash
scripts/screenshots.sh "iPhone 17 Pro Max"
```

Suggested 4–6 to upload (hero first): **Live Scoring**, **Score pad**,
**Game Summary**, **Games list**, **Roster**. (The committed `docs/img/*.png`
are the 6.3" set used for the README — regenerate at Max size for the store.)

App preview video: optional, skip for v1.0.

---

## 10. Review notes (App Review Information field)

> Single-user local app for tracking a youth basketball team's stats. No account
> or login. To try it: on the Roster tab add a player or two (or it ships with a
> sample team), tap "+" on the Games tab (or the ⚡️ Quick Pickup button) to start
> a game, tap a player then a +2/+3/FT button to score, then "End Period" to
> advance. All data is stored locally on device.

No demo account needed (there is no login).

---

## 11. Pre-submission checklist

- [x] Paid Apple Developer Program membership active
- [x] Bundle ID registered (`com.thomashan.CourtsideHoopStats`)
- [x] iPhone-only (`TARGETED_DEVICE_FAMILY = 1`)
- [x] Encryption declaration set (`ITSAppUsesNonExemptEncryption = NO`)
- [x] App icon present (1024×1024, no alpha)
- [ ] **Build with a release Xcode** (App Store rejects beta-SDK binaries) — not the Xcode 27 beta
- [ ] Set the signing **Team** to your paid team + a Distribution provisioning profile
- [ ] Bump build number, `Product ▸ Archive`, upload via Organizer (or `xcodebuild -exportArchive`)
- [ ] Capture 6.9" screenshots (`scripts/screenshots.sh "iPhone 17 Pro Max"`)
- [ ] Host the Privacy Policy at a public HTTPS URL and paste it in
- [ ] Fill App Privacy = *Data Not Collected*; Age rating = 4+
- [ ] One real game of use (validate with the actual courtside user) before release
