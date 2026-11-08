# Proposal

## Why

Three edges of the planning flow are harder to read than they should be. The
DELETE SESSION action does not look destructive, reordering a plan depends on
small up/down chevrons while block deletion is buried inside the block editor,
and the timer opens already showing SET DONE, so a stray tap can count the first
set before the user has deliberately begun.

## What Changes

- **DELETE SESSION turns red.** The session editor's delete action uses a
  shared destructive red at rest and a stronger armed treatment for the second
  tap. The new row delete actions use the same token.
- **Draggable block and movement lists.** The session editor's block list and
  the block editor's movement list become reorderable rows with a trailing grip
  handle and a row delete action. The up/down chevrons are removed. Tapping the
  row still opens its editor. The last block and the last movement keep no
  delete action, deletion stays two-step, and the editing lock disables drag and
  delete.
- **START SESSION gate.** The timer gains a not-started state. Launch,
  activating a session, and committing an edit to the active plan land there.
  START SESSION enters the normal ready state at set 1 without counting a set.
  START AGAIN and RESTART SESSION remain direct starts. Nothing is armed,
  counted, or shown in the Live Activity before the session starts.
- **Prototype first.** Timing, copy, layout, and colour changes go into
  `prototype-workout-timer.html` before the skill and the app.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `rest-timer`: adds the not-started state, the START SESSION transition and
  its presentation, and makes a change to the active plan reset to the gate.
- `workout-sessions`: activation lands in the gate; the block and movement
  lists are draggable and carry their own delete actions; DELETE SESSION and
  row deletes use the destructive red.
- `live-activity`: no activity exists before the session starts, and entering
  the gate ends a stale one.
- `app-typography`: the reorder handle joins the interactive controls that keep
  a 44 × 44 pt target and grow with text; the stale move-chevron example is
  replaced.

## Impact

Touched: the prototype, the rest-timer skill, `Shared/SessionSnapshot.swift`,
`Shared/Theme.swift`, `Shared/RestlessActivity.swift`,
`Restless/Session/SessionEngine.swift`, `Restless/UI/TimerScreen.swift`,
`SessionEditorScreen.swift`, `BlockEditorScreen.swift`, and the Live Activity
widget. Tests cover the new transition guard and the list mutations. No new
dependencies and no store format change; existing saved snapshots stay
readable.
