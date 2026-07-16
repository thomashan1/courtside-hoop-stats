# Terminal To-Do

A work queue handed from **cloud design sessions** to the **local terminal
session** — the terminal is the only session that writes code and pushes it.

**How to use it (on the Mac):**
1. `git pull`
2. Tell your terminal session: *"Do the pending items in `docs/TERMINAL_TODO.md`."*
3. For each task, make the change, then move it from **Pending** to **Done** in
   the *same commit*, and push to `main`.

---

## Pending

- [ ] **Switch the app theme from green to Swish Warriors blue.**
  Decided in a design session (the icon is going blue too, to match). Keep the
  existing **adaptive light/dark** structure — just swap the green brand palette
  for blue equivalents:
  - **`Assets.xcassets/AccentColor.colorset`:**
    - Light / default: sRGB `red 0.118, green 0.373, blue 0.812` (#1E5FCF)
    - Dark: sRGB `red 0.357, green 0.612, blue 0.961` (#5B9CF5)
  - **`DesignSystem.swift`** (and any hardcoded greens in the views): remap the
    brand colors to blue, preserving the light/dark treatment —
    - accent / selected player / primary action (was grass green) → **#1E5FCF**
      light, **#5B9CF5** dark
    - solid scoreboard banner (was dark court green) → deep navy **#0C2C5E**
    - tinted card / surface (was court-green tint) → blue-tinted equivalent
      (≈ **#10233F** dark, **#E8F0FB** light)
  - Reference/identity blue is **#2F76E3** (matches the icon background).
  - Build once in **both** light and dark to confirm contrast still reads
    courtside, then commit + push. Exact shade can be fine-tuned later once the
    icon is locked.

- [ ] **Add the app icon — "Stat Line" concept (basketball crowning a bar chart), team blue.**
  Locked in a design session. Production SVG is below — it is **full-bleed and
  opaque with NO rounded corners** (iOS masks the squircle itself; app icons must
  have no transparency). Steps:
  1. Save the SVG below as `design/AppIcon.svg` (create the `design/` folder).
  2. Rasterize to a **1024×1024 PNG**, e.g.
     `rsvg-convert -w 1024 -h 1024 design/AppIcon.svg -o CourtsideHoopStats/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`
     (`brew install librsvg` if needed; Inkscape / resvg / headless Chromium also
     fine). Verify the PNG is exactly 1024×1024 and fully opaque (no alpha).
  3. Update `AppIcon.appiconset/Contents.json` to reference `AppIcon-1024.png` as
     the universal 1024 iOS image (a single 1024 size is sufficient for iOS 26).
  4. Build + install to the iPhone and confirm the icon appears on the home screen.
  5. Commit the SVG, the PNG, and `Contents.json`; push.
  Tweaks welcome later (ball size, bar prominence, exact blue). Keep the icon blue
  consistent with the app theme task above.

  Production SVG:

  ```svg
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">
    <defs>
      <linearGradient id="bg" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="1024" y2="1024">
        <stop offset="0" stop-color="#2A6DD8"/>
        <stop offset="1" stop-color="#0A2650"/>
      </linearGradient>
      <radialGradient id="ballFill" cx="0.40" cy="0.34" r="0.75">
        <stop offset="0" stop-color="#F7A24E"/>
        <stop offset="0.5" stop-color="#E56F1E"/>
        <stop offset="1" stop-color="#AC450E"/>
      </radialGradient>
      <radialGradient id="ballEdge" cx="0.5" cy="0.5" r="0.5">
        <stop offset="0.64" stop-color="#3A1503" stop-opacity="0"/>
        <stop offset="1" stop-color="#260F02" stop-opacity="0.5"/>
      </radialGradient>
    </defs>
    <rect width="1024" height="1024" fill="url(#bg)"/>
    <g fill="#EAF1FB" opacity="0.93">
      <rect x="269" y="642" width="96" height="170" rx="16"/>
      <rect x="399" y="562" width="96" height="250" rx="16"/>
      <rect x="529" y="482" width="96" height="330" rx="16"/>
      <rect x="659" y="402" width="96" height="410" rx="16"/>
    </g>
    <circle cx="512" cy="300" r="190" fill="url(#ballFill)"/>
    <g fill="none" stroke="#572006" stroke-width="15" stroke-linecap="round" transform="rotate(22 512 300)">
      <line x1="322" y1="300" x2="702" y2="300"/>
      <line x1="512" y1="110" x2="512" y2="490"/>
      <path d="M512 110 C 402 190, 402 410, 512 490"/>
      <path d="M512 110 C 622 190, 622 410, 512 490"/>
    </g>
    <circle cx="512" cy="300" r="190" fill="url(#ballEdge)"/>
  </svg>
  ```

- [ ] **Multi-user sharing (Thomas + wife see games/stats near-live).**
  ⛔️ **Blocked / deferred** — do **not** start until the local single-device app
  is stable and device-tested. Native approach is CloudKit `CKShare` (the iCloud
  Shared-Album mechanism); this is a large persistence-layer change off
  `UserDefaults`/JSON. Full design, tradeoffs, the gym-connectivity caveat, and
  open decisions are in [`SHARING.md`](SHARING.md). When unblocked, resolve the
  open questions there first, then implement.

---

## Done

- [x] **Raise minimum iOS version to 26.**
  Changed `IPHONEOS_DEPLOYMENT_TARGET` from `17.0` to `26.0` in **both** the Debug
  and Release build configurations in
  `CourtsideHoopStats.xcodeproj/project.pbxproj`.
  Verified with a clean `xcodebuild` for `generic/platform=iOS` (Debug):
  **BUILD SUCCEEDED**.
