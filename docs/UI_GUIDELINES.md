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

Presentational components *are* shared (`GameRowView`, `PlayerStatsTable`,
`PeriodBreakdownGrid`, `EventLogView` in display-only mode), so a follower's
numbers can't drift from the owner's. Where a shared component has an editable
mode, disarm it twice: pass the flag **and** a constant binding, so there's
nothing to write back to even if the flag were wrong.

## 5. Preferences are not records

Only true app preferences (**Text Size**) edit live with no Save button — the
Settings-app model. Anything that is *data* uses pattern 1.

## Anti-patterns (do not reintroduce)

- A detail screen that edits the store live *and* looks like a record editor
  (mixing patterns 1 and 4).
- Inline delete/modify controls on a read-only screen.
- A custom swipe gesture where a `List` + `.swipeActions` would do (it fights
  the scroll view — see the old Score Log).
- An "Edit" mode toggle on a list whose only purpose is delete (swipe covers it);
  reserve edit-mode for reordering.
