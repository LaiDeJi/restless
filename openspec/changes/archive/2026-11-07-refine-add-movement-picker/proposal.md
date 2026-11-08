# Proposal

## Why

The add-movement page commits too early: tapping ADD MOVEMENT or a library row
saves and closes immediately, so the DONE button is a no-op and there is no way
to review or cancel the choice. On the session page, `+ ADD BLOCK` adds an
untitled block before the picker is completed, so cancelling the picker leaves
an empty block behind. The page also defaults to REPS, lists REPS first, warns
that a new movement cannot be counted even when the chosen set end is MANUAL or
TIME, and leaves the keyboard with no page-tap dismissal.

## What Changes

- **ADD stages, DONE commits.** Tapping ADD MOVEMENT or a library row queues the
  movement on the page instead of saving it. DONE appends every queued movement
  to the block in the order shown, creates or reuses the typed library
  movements, flushes the plan, and closes. CANCEL closes without changing the
  block or the library. The page stays open while movements are queued so
  several can be added in one visit.
- **A new block waits for DONE too.** `+ ADD BLOCK` opens the picker without
  adding a block. DONE appends one block with the queued movements and the
  previous block's rests, then flushes; CANCEL adds no block. DONE stays
  disabled for a new block until at least one movement is queued, so an empty
  block cannot be saved.
- **MANUAL first and default.** The set-end control lists MANUAL, TIME, REPS in
  that order and starts on MANUAL. The shared end-condition picker uses the same
  order in the block movement editor.
- **The no-profile warning follows the set end.** The warning below the new
  movement name appears only for REPS, where the watch needs a recorded profile
  to count. MANUAL and TIME hide it; their existing target or tap-to-finish copy
  already explains how the set ends.
- **A page tap dismisses the keyboard.** On the add-movement page and the other
  editor pages with a text field, tapping the page outside the focused field
  ends editing and dismisses the keyboard; that field's usual commit rule still
  applies. Tapping inside the field keeps the keyboard. The session editor
  already behaves this way.
- **Prototype first.** The order, default, copy, keyboard dismissal, staged
  movement list, and staged new block land in `prototype-workout-timer.html`
  before the skill and the app.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: the add-movement picker becomes a staged editor whose DONE
  is the only commit; a new block is appended only on that DONE and never when
  the picker is cancelled; its set-end order and default become MANUAL, TIME,
  REPS; the no-profile warning is REPS-only; text-entry editor pages dismiss the
  keyboard on a page tap.

## Impact

Touched: `prototype-workout-timer.html`,
`.agents/skills/restless-rest-timer/SKILL.md`,
`Restless/UI/MovementPickerSheet.swift`,
`Restless/UI/SessionEditorScreen.swift`,
`Restless/UI/MovementComponents.swift`,
`Restless/UI/BlockMovementEditorScreen.swift`,
`Restless/Session/SessionDraftStore.swift` for a batch append and a block
append, and the text-field editors that need the shared page-tap keyboard
dismissal. Tests cover the batch append, the new-block append, the default end
condition, and the REPS-only profile warning. No store format change; existing
sessions and library movements stay readable.
