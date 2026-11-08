# Proposal

## Why

Three parts of session editing fight the user. The session name field needs a
keyboard accessory button to dismiss the keyboard, a block can only receive a
movement that already exists in the LIBRARY, and a dragged block or movement
row gives no clear sign of what is being moved or where it will land.

## What Changes

- **Tap the page to dismiss the keyboard.** The session editor's name field
  loses the keyboard accessory bar and its Done button. Tapping anywhere on the
  session page that is not another control dismisses the keyboard, and the name
  still commits on focus loss, submit, and leaving the page.
- **Create a movement while adding it.** The add-movement picker gains a name
  field beside the library list. Typing a name and confirming creates a
  library movement and appends it to the current block with the selected set
  end (REPS, TIME, or MANUAL) and target. A new movement carries no watch
  profile, so it is usable immediately but the existing no-profile warning
  still explains that the watch cannot count it until it is recorded.
- **Drag rows that look picked up.** While a block or movement row is dragged,
  a full row card floats under the finger, the row's original slot dims, and
  the row that would receive it is outlined. The treatment clears on drop or
  cancel and remains unavailable while editing is locked.
- **Prototype first.** Timing, copy, layout, and colour changes land in
  `prototype-workout-timer.html` before the skill and the app.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: the session name field dismisses through the page rather
  than a keyboard accessory; the movement picker can create a library movement
  from a typed name and the chosen set end; dragged block and movement rows
  show a floating card, a dimmed source slot, and a highlighted drop target.

## Impact

Touched: the prototype, `Restless/UI/SessionEditorScreen.swift`,
`Restless/UI/MovementPickerSheet.swift`, `Restless/UI/PlanListRow.swift`, and
`Restless/Data/MovementRecord.swift` if creation needs a repository entry
point. Tests cover name normalization at creation and the picker's append
behaviour. No store format change and no new dependency; existing sessions and
library movements stay readable.
