# Proposal

## Why

Dragging a session, a block, or a movement stutters. The floating card appears
late and trails the finger, and a pause during the gesture can freeze the list
while the editor saves the half-finished order, resets the active session, and
refreshes the Live Activity. The lists should feel attached to the finger and
commit exactly once, when the drag ends.

## What Changes

- **The card lifts with the grip.** The floating card is prepared when the grip
  is touched and added when the system lift begins, not after the lift. It
  tracks the pointer at the display's refresh rate with no chase animation.
- **The card is the row's own card.** It lifts at the row card's size from that
  card's position and keeps the grabbed point under the finger, with no window
  clamp, so it stays attached to the finger the way a native lifted row does.
- **The list follows the finger from a provisional order.** Block, movement, and
  session rows reorder in view state while the drag runs; the draft or SwiftData
  record is written once on drop. A paused drag does not trigger the edit
  debounce, a save, an active-session reset, or a Live Activity refresh. Rows
  animate into their new slots instead of re-laying out in one frame, and a
  drop settles the card into the row that takes its place.
- **Cancel restores the order from before the drag.** This is what the existing
  lifted-row requirement already says; today a cancelled drag keeps every row
  crossed so far.
- **Lift work leaves the main-thread path.** The row image is rendered without a
  baked shadow and without the large shadow padding; the preview layer draws the
  shadow. The app opts into the full ProMotion frame rate so the card is not
  limited to 60 Hz on a 120 Hz phone.
- **The standard long-press lift stays.** A dedicated grip still uses the system
  drag, drop targeting, and VoiceOver actions; replacing it with a hand-rolled
  gesture is out of scope.
- **No visual redesign.** The card, empty source slot, drop outline, row
  layout, and drop behaviour keep their current look.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `workout-sessions`: the session, block, and movement drag lists follow the
  pointer from a provisional order, commit once on drop, and restore the
  pre-drag order on cancel; the lifted card tracks the pointer for the whole
  gesture.

## Impact

- `Restless/UI/PlanListRow.swift` — drag preview timing, tracking, layer
  shadow, and drag begin/end callbacks.
- `Restless/UI/SessionEditorScreen.swift`, `BlockEditorScreen.swift`, and
  `SessionsScreen.swift` — provisional order during a drag.
- `Restless/Session/SessionDraftStore.swift` — batch reorder methods for blocks
  and movements.
- `project.yml` and the generated `Restless/Info.plist` — ProMotion frame-rate
  key.
- `RestlessTests/` — batch reorder validation and commit-once tests; the Argent
  drag sequence gains an order checkpoint.
- No store-format change, no new dependency, no prototype visual change, and no
  change to rest timing, the live session state machine, or the watch.
