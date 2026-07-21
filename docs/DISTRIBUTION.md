# Distribution Guide — Courtside Hoop Stats

How to get the app onto Jean's phone now, and onto the App Store eventually.

> **The one prerequisite for both:** the **Apple Developer Program — $99/year**
> (enroll at [developer.apple.com](https://developer.apple.com)). It's the only
> cost, and it unlocks both TestFlight *and* the App Store. Approval usually
> takes a day or two.

> ⛔ **Current hard blocker (both TestFlight *and* App Store):** the dev Mac runs
> **macOS 27 beta**, so only the **beta Xcode** runs on it, and Apple **rejects
> beta-SDK binaries for upload** — that stops TestFlight *and* App Store, not just
> the public listing. Unblock by waiting for the macOS 27 / Xcode 27 **GM
> (~Sept 2026)**, or by archiving from a **release-macOS Mac / CI**. The
> **development-signed install straight to a device** (Path A stopgap below) is
> unaffected and still works today.

---

## App facts (for the forms)

| Field | Value |
|---|---|
| App name | Courtside Hoop Stats |
| Home-screen label | Courtside |
| Bundle identifier | `com.thomashan.CourtsideHoopStats` |
| Category | Sports |
| Min iOS | 26.0 |
| Data collected | **None** (all local; see `docs/PRIVACY_POLICY.md`) |
| Age rating | 4+ |

---

## Path A — Get it to Jean now: **TestFlight** (recommended)

Reliable, over-the-air, no cables, updates automatically. Requires the $99 program.

1. **Enroll** in the Apple Developer Program (once).
2. In Xcode: **Product → Archive** (Release build). ⚠️ Use a **release Xcode**,
   not the beta (see gotchas).
3. In the Organizer window: **Distribute App → App Store Connect → Upload**.
4. Wait ~15–30 min for the build to finish processing in **App Store Connect →
   TestFlight**.
5. Add Jean as a tester — either:
   - **Internal** (fastest): add her Apple ID email under Users; or
   - **Public link**: create a TestFlight public link and text it to her.
6. Jean installs the free **TestFlight** app from the App Store, opens your
   invite/link, and installs Courtside Hoop Stats.
7. **Updates:** upload a new build; it appears on her phone automatically.
   Builds expire after **90 days** — just upload a fresh one.

### Free stopgap (no $99, not recommended for real use)
Plug **Jean's** iPhone into the Mac and run from Xcode with your personal team.
Downsides: the app **stops working after 7 days**, must be re-installed from your
Mac, and her phone has to physically connect. Fine for a one-off demo only.

---

## Path B — App Store (eventual, post-retirement)

Same $99 program, plus prep. Steps:

1. **App Store Connect → My Apps → +** → create the app record (name, bundle ID,
   SKU, primary language).
2. Fill the **listing** — copy is drafted in `docs/APP_STORE_LISTING.md`:
   subtitle, description, keywords, promotional text, support URL.
3. Upload **screenshots** (required; see the listing doc for sizes).
4. **App Privacy:** answer the questionnaire → *"Data Not Collected"*; provide the
   **privacy policy URL** (host `docs/PRIVACY_POLICY.md` — GitHub Pages is free).
5. Complete the **age rating** questionnaire (→ 4+).
6. **Archive a Release build → upload → attach** it to the version.
7. **Submit for review.** Apple review is typically **1–3 days**; they may ask for
   changes (fix + resubmit).
8. **Release** — automatically on approval, or manually when you're ready.

---

## Gotchas / to-do before App Store

- **Release Xcode, not beta — the current blocker.** Apple rejects builds made
  with beta tools for *any* upload (TestFlight or App Store). The dev Mac is on
  macOS 27 beta, which only runs the beta Xcode, so no upload works from it today.
  Use the macOS 27 / Xcode 27 **GM** or a release-macOS Mac / CI. (See the blocker
  callout at the top.)
- **Privacy policy must be hosted** at a public URL. The policy is already written
  (`docs/PRIVACY_POLICY.md`, contact thomashan@icloud.com) — it just needs
  hosting. Easiest: enable GitHub Pages on this repo and point it at that file (or
  paste it into a simple page).
- **Screenshots** need capturing at 1284 × 2778 (see `docs/APP_STORE_LISTING.md`
  and `docs/SCREENSHOTS.md`).
- **App icon** is real, shipped art (basketball + stat bars on blue) — no longer a
  placeholder, nothing to swap.
- App name **"Courtside Hoop Stats"** was availability-checked and is clear.

---

## Cost & timeline summary

- **$99/year** Apple Developer Program — the only cost; covers everything.
- **TestFlight → Jean:** same day once enrolled and a build is uploaded.
- **App Store:** whenever ready; review takes a few days.
