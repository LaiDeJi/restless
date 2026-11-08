# Proposal

## Why

Two layout breaks make the app feel inconsistent. Adding a block opens the movement picker with only a movement queue, so the new block arrives as `Untitled block` with default rounds and rests and must be edited afterwards; editing that same block shows a different page with its name, rounds, sets, and rests. On the timer, the countdown ring sits at the screen's middle for a one-row block map, then rises when a later block's position strip wraps and its set map grows, so the timer no longer looks centred while it counts down from block 2.

## What Changes

- **One block form for add and edit.** `+ ADD BLOCK` opens the same block editor layout used to edit a block: block name, summary, rounds, sets per round, set rest, round rest, movement list, order preview, and the add-movement action. A new block starts as `Untitled block` with rounds 1, sets per round 3, the previous block's rests, and no movements. DONE appends it to the session; back or cancel discards it and leaves the session unchanged. DONE stays disabled until the staged block has at least one movement.
- **A staged block is not a session block yet.** The new block lives in a draft outside `session.blocks` while it is authored, so cancelling, backgrounding, or leaving the editor cannot persist an empty block. The add-movement picker is opened from the block editor for the staged block, exactly as it is for an existing block.
- **The add-movement picker loses its NEW BLOCK mode.** It becomes only the movement queue for a block, with the same MANUAL/TIME/REPS staging, TO ADD list, and DONE/CANCEL behaviour, whether that block is staged or saved.
- **The countdown ring stays in the middle.** The timer's hero ring is pinned to a fixed vertical centre of the timer viewport on every block and phase. The block strip and position strip sit above it, and the set map and watch strip sit below it; their heights no longer move the ring. When the content below the ring cannot fit, the timer page scrolls instead of shifting the ring.
- **Prototype first.** The block form, the staged new-block flow, and the pinned timer hero land in `prototype-workout-timer.html` before the skill and the app.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: adding a block is authored in the same form as editing one; the picker no longer creates blocks; a staged block is appended only by DONE and requires a movement.
- `rest-timer`: the timer presentation gains a stable hero position, so the countdown ring does not move between blocks, rounds, or resting and ready states.

## Impact

Touched: `prototype-workout-timer.html`,
`.agents/skills/restless-rest-timer/SKILL.md`,
`Restless/UI/SessionEditorScreen.swift`,
`Restless/UI/BlockEditorScreen.swift`,
`Restless/UI/MovementPickerSheet.swift`,
`Restless/Session/SessionDraftStore.swift`, and
`Restless/UI/TimerScreen.swift` with `SetMap.swift` and
`TimerPositionStrip.swift` as needed. Tests cover the staged block commit and
discard, the movement requirement, and the new-block defaults. No store format
change; saved sessions and the running session stay readable.
