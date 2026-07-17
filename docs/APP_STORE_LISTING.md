# App Store Listing — Courtside Hoop Stats

Draft copy and assets checklist for the App Store submission. Edit to taste
before submitting.

## Names & identity

- **App Name (30 char max):** Courtside Hoop Stats
- **Subtitle (30 char max):** `Fast courtside stat tracking`
- **Category:** Primary: Sports · Secondary: (optional)
- **Age rating:** 4+

## Promotional text (170 char max — editable anytime without review)

> Two taps to track every basket, free throw, and foul — the team score adds
> itself. Built for keeping youth-game stats from the sideline.

## Keywords (100 char max, comma-separated, no spaces)

```
basketball,stats,scorekeeper,box score,youth,coach,team,scoring,tracker,hoops,tally,stat
```

## Description

> **Courtside Hoop Stats is the fastest way to keep your team's basketball stats — right from the sideline.**
>
> Built for the parent or coach tracking a youth game alone, it replaces the messy spreadsheet with two taps: tap a player, tap what they did. The score adds itself.
>
> **TRACK WHAT MATTERS**
> • 2-point and 3-point field goals
> • Free throws — made and missed, for accurate FT%
> • Fouls
> • Team score, calculated automatically from every event
>
> **BUILT FOR SPEED, COURTSIDE**
> • Two-tap scoring — no fiddly menus
> • One-tap Undo for fat-finger fixes
> • Big, readable buttons and scoreboard
> • Clear in a bright gym (light and dark)
>
> **GAME MANAGEMENT**
> • 4 quarters or 2 halves — your league's format
> • Enter the opponent's running score at each period break
> • Editable event log — fix a mistake anytime
>
> **AFTER THE GAME**
> • Period-by-period score grid and final result
> • Per-player stat table: points, 2PT, 3PT, FT, fouls
> • Notes for scouting and observations
>
> **YOUR DATA STAYS YOURS**
> No account. No ads. No tracking. Everything is stored on your device.
>
> Perfect for youth leagues, rec teams, and any parent who wants real stats without the hassle.

## Support / marketing URLs

- **Support URL (required):** [TBD — a simple page or the GitHub repo]
- **Privacy Policy URL (required):** [TBD — host `docs/PRIVACY_POLICY.md`]
- **Marketing URL (optional):** —

## Screenshots checklist

Capture 3–10 per required size, on the Simulator (Cmd+S saves a screenshot).
Good screens to show: **Live Scoring** (the hero), **Game Summary** stat table,
**Games list**, **Roster**.

Required sizes (as of 2026 — verify in App Store Connect at submission):
- **6.9-inch** iPhone (e.g. iPhone 16 Pro Max) — **required**
- **6.5-inch** iPhone — recommended
- **iPad 13-inch** — **only required if the app ships as universal** (see note)

> **Decision needed:** the Xcode target is currently universal
> (`TARGETED_DEVICE_FAMILY = 1,2` → iPhone + iPad). If you submit as universal,
> Apple requires iPad screenshots and the app must look right on iPad. Since this
> is a phone-first courtside app, consider setting it to **iPhone-only**
> (`TARGETED_DEVICE_FAMILY = 1`) before submission to skip iPad requirements.
> (Would be a small terminal/project change — not urgent until App Store time.)

## Review notes (optional field, to help Apple's reviewer)

> Single-user local app for tracking a youth basketball team's stats. No account
> or login required. To try it: add a player or two on the Roster tab, tap "+" on
> Games to start a game, tap a player then an action to score, then "End Period"
> to finish.
