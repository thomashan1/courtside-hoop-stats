# UI Guidelines — edit, save, delete

One consistent, Apple-HIG-aligned way to create/edit/delete across every screen.
When adding UI, match these patterns rather than inventing a new one.

## 1. Editing a *record* → a modal sheet with **Cancel / Save**

A "record" is a data entry: a **player**, a **game** (its details + notes), a
**score-log entry**, a **team**.

- Present a **sheet** wrapped in a `NavigationStack`.
- Nav bar: **Cancel** (leading, `.cancellationAction`) discards; **Save** —
  or **Add** when creating — (trailing, `.confirmationAction`, bold) commits.
- **Save is disabled until the record is valid** (e.g. non-empty name/opponent).
- Edits are **staged in local `@State`** and applied only on Save, so Cancel
  truly backs out. Never bind sheet fields straight to the store.

Editors that follow this: `PlayerEditSheet`, `EditGameSheet`, `EventEditSheet`,
`NewGameSheet`, `TeamDetailView`.

## 2. Deleting a record → the same two affordances everywhere

- **Swipe-to-delete** (trailing) in every list: Roster, Games, Score Log editor.
- A red destructive **"Delete …"** button at the bottom of that record's edit
  sheet (the Contacts pattern).
- **Confirm only when the delete loses *other* data** — deleting a team removes
  its games; deleting a played game removes its recorded scores. Use a
  `confirmationDialog`. Simple deletes (a player, an empty scheduled game) don't
  need confirmation — swipe is already deliberate.

## 3. Read vs edit is one-directional

Read-only screens (the **Game Summary**) stay read-only and expose editing only
through explicit buttons — never inline mutation on a read screen. A game screen
offers:
- **Details** (ⓘ) → `EditGameSheet` for metadata + notes.
- **Edit Scores** → the Live Scoring surface for events/periods.

## 4. Read-only means no edit path exists

A follower's screens don't hide editing behind a flag — they're built without it.
`FollowingView` is its own view rather than `GamesListView` with `isReadOnly`,
because a flag leaves an edit path one missed check away from appearing.

Presentational components *are* shared (`GameRowView`, `GameScoreCard`,
`PlayerStatsTable`, `PeriodBreakdownGrid`, `EventLogView` in display-only mode),
so a follower's numbers can't drift from the owner's. Where a shared component
has an editable mode, disarm it twice: pass the flag **and** a constant binding,
so there's nothing to write back to even if the flag were wrong.

## 5. Preferences are not records

Only true app preferences (**Text Size**) edit live with no Save button — the
Settings-app model. Anything that is *data* uses pattern 1.

## 6. One badge style: `StatusBadge`

Game status — WIN / LOSS / In Progress / Scheduled — is **coloured text on an
18% wash of the same colour** (`StatusBadge` in `DesignSystem.swift`), never
white text on a solid fill. `Color.teamAccent` is deliberately lighter on dark
(`#5B9CF5`), so white on it lands at **2.80:1** — under even the 3:1 large-text
floor. Tinting keeps the colour as the signal and lets the text carry the
contrast, in both themes.

Use the shared view rather than restyling per screen, so a game's status reads
identically in the Games list, a summary card, and a follower's view.

## 7. Two targets in one row means an explicit 44pt

Where a row's own tap does something (Settings ▸ Teams: tap = make active) and
it also contains a button, that button needs `.minimumTapTarget()`. A bare SF
Symbol is ~22pt; a miss doesn't do nothing, it falls through to the row. In the
Teams list that silently re-pointed Games and Roster at another team.

## 8. Content that grows with Dynamic Type needs a cap, not just a scroll

`@ScaledMetric` sizes grow fast at accessibility text sizes. Live Scoring's
player deck is measured and capped at half the screen, scrolling within that —
uncapped, a ten-player roster pushed the scoreboard and Score Log entirely off
the screen and the tracker was scoring blind. Note that a bare `ScrollView` is
*greedy* in a `VStack`: it claims whatever it's offered, so the content has to
be measured and the height set to `min(content, cap)`.

`CourtsideHoopStatsUITests/AccessibilityTextSizeTests.swift` guards this at the
largest step. Use `-uiTestTextSizeIndex N` to drive text size in a UI test —
the OS-level `-UIPreferredContentSizeCategoryName` argument does **not** reach
a SwiftUI app whose root applies its own `.dynamicTypeSize` floor, and a test
that uses it silently exercises the default size instead.

## Anti-patterns (do not reintroduce)

- A detail screen that edits the store live *and* looks like a record editor
  (mixing patterns 1 and 4).
- Inline delete/modify controls on a read-only screen.
- A custom swipe gesture where a `List` + `.swipeActions` would do (it fights
  the scroll view — see the old Score Log).
- An "Edit" mode toggle on a list whose only purpose is delete (swipe covers it);
  reserve edit-mode for reordering.
- White text on a solid colour fill for a badge (see 6).
