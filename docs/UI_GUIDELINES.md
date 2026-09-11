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

### Confirming a swipe delete — the crash to avoid

When a swipe delete goes through a `confirmationDialog`, the swipe action
**must not** use `role: .destructive`. That role makes SwiftUI animate the row
away the moment it's tapped, assuming the data is about to lose it. Behind a
confirmation it isn't, so the next update reports the row back and UIKit traps:

```
Invalid update: invalid number of items in section 0. The number of items
after the update (4) must be equal to the number before the update (3),
plus or minus the number inserted or deleted (0 inserted, 0 deleted)
```

Use a plain `Button` with `.tint(.red)` instead — it still reads as destructive
and leaves the row alone until the delete actually happens. `.onDelete` is safe
with a confirmation (the Games list does exactly this); only a hand-rolled
`role: .destructive` swipe button pre-empts the data.

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

When a UI test needs to swipe that deck, address it by
`.accessibilityIdentifier`, never as "the lowest scroll view on screen". The
deck now contains the bench chips' own horizontal `ScrollView`, and that
heuristic silently started picking a 55pt-tall offscreen element no swipe can
act on — a failure that reads as "the deck doesn't scroll".

## 9. A scrollable table hides columns silently — count the width

`PlayerStatsTable` scrolls horizontally so large text sizes widen columns
instead of clipping them. The cost: anything past the right edge is invisible
at the *default* size too, because a horizontal scroll indicator only shows
while scrolling. Nobody discovers a column they've never seen.

AST was added, screenshotted, and off the edge in the Game Summary at the
default text size — found by trying to add another column, not by looking at
the table. So when adding a column, add up the widths against the narrowest
supported screen rather than trusting the scroll to save you, and read the
column off a fresh screenshot — from the **live Stats panel**, which is
narrower than the Game Summary's row. Fixing the Summary alone left AST
needing a sideways scroll there, and the deck hid the evidence.

Three levers, in order: put the widest column **last**, so a squeeze clips the
least important value instead of hiding a whole column — FT's `1/1 (100%)` is
three times any other width, which is why it sits after AST and MIN — then the
column gaps, then that value's format (`MIN` in whole minutes fits where
`15:12` doesn't).

## 10. Owning a team and following one must look different

The Games tab and the Following tab show the same team, the same games, the same
stats. The only structural difference is that one accepts taps that change the
score. That is not enough on its own, so each side says which it is, in the
**same slot** — the navigation subtitle:

| | Subtitle | Also |
|---|---|---|
| **Games** (you own it) | "Shared with 2 followers", or nothing when unshared | followers button in the toolbar |
| **Following** (someone shared with you) | "Updated Just Now" | read-only footer; no edit affordances |

Settings ▸ Teams tags each shared team, so you can see which rosters other
people can see without opening every team in turn.

Deliberately **not** done: read-only badges on the Following side. The absence
of edit controls already carries it, and a badge on every screen reads as a
warning about something that isn't wrong.

`.navigationSubtitle` takes a plain `String` — `^[…](inflect:)` markup is passed
through and rendered literally, so pluralise by hand.

## Anti-patterns (do not reintroduce)

- A detail screen that edits the store live *and* looks like a record editor
  (mixing patterns 1 and 4).
- Inline delete/modify controls on a read-only screen.
- A custom swipe gesture where a `List` + `.swipeActions` would do (it fights
  the scroll view — see the old Score Log).
- An "Edit" mode toggle on a list whose only purpose is delete (swipe covers it);
  reserve edit-mode for reordering.
- White text on a solid colour fill for a badge (see 6).
