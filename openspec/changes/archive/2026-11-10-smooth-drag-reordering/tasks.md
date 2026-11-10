# Tasks

## 1. Baseline and drag preview

- [x] 1.1 Record the current drag behaviour for comparison: build the app, create
  a session with at least eight movements, and use a 120 fps screen recording
  plus an Instruments Animation Hitches trace while dragging a movement across
  two rows. Keep both files and note the longest hitch and the card's offset
  from the pointer. Verify the recording shows the current late lift and trailing
  card before any code changes.
- [x] 1.2 Add `CADisableMinimumFrameDurationOnPhone: true` to the app's
  Info.plist properties in `project.yml`, run `xcodegen generate`, and verify the
  key is present in the generated `Restless/Info.plist` with `plutil -p`.
- [x] 1.3 In `PlanListRow.swift`, move the visual drag setup from
  `sessionWillBegin` to `willAnimateLiftWith`: set the drag bindings, add the
  preview layer, and start the display link there, with an idempotent fallback
  in `sessionWillBegin`. Set `allowsSimultaneousRecognitionDuringLift` and add
  `onDragBegan`/`onDragEnded` callbacks to `PlanDragHandle`, `PlanListRow`, and
  `SessionDragRow`. Verify by dragging a block in the simulator: the card and
  dimmed source are visible while the lift runs, before the pointer moves.
- [x] 1.4 Make the preview layer track the pointer: disable implicit actions for
  `position`, `bounds`, `contents`, and `opacity`, give the display link a
  60–120 Hz preferred range, and keep the layer's shadow path in sync with the
  card's corner radius. Verify with a slow-motion 120 fps recording that the card
  stays under the pointer across a fast drag and back; compare with 1.1.
- [x] 1.5 Pre-render the lift card on grip touch-down: add the zero-duration
  long-press recognizer with simultaneous recognition, cache the rendered card,
  invalidate it from `updateUIView`, and clear it on touch end without a lift.
  Remove the baked shadow and 30 pt padding from both preview builders; render at
  the window scale and draw the shadow on the layer while preserving the card's
  current bottom offset and edge inset. Verify a screenshot of the lifted card
  matches the pre-change position and shadow, and that tapping a grip without
  dragging leaves no card and no retained image.
- [x] 1.6 Tighten `PlanDropDelegate`: guard duplicate `dropEntered` moves, write
  `dropTargetID` from `dropUpdated` only when it changes, and report the drag end
  operation so a cancel can revert. Verify a slow drag across several rows does
  not oscillate, the outline stays on the row under the pointer, and releasing
  outside every row clears the card and the outline.

## 2. Provisional order in the editors

- [x] 2.1 Add `reorderBlocks(to:)` and `reorderMovements(in:to:)` to
  `SessionDraftStore`, validating a permutation before applying one `edit`.
  Add `beginDrag()`/`endDrag()` to cancel a pending debounce and suspend
  scheduled flushes for the gesture, then flush once on end. Add unit tests for
  valid block and saved/staged movement permutations, missing or duplicate ids,
  unchanged state on rejection, no commit before `endDrag()`, exactly one commit
  after it, and a pending edit that is not committed until `endDrag()` and then
  commits once. Verify with `xcodebuild ... test` and the new cases passing.
- [x] 2.2 Give `SessionEditorScreen` a provisional `dragOrder` captured on drag
  begin. Call `draft.beginDrag()` there, render `displayedBlocks` from the
  provisional order, reorder only the array on a crossing, call
  `draft.reorderBlocks(to:)` then `draft.endDrag()` on a completed drop, and
  discard the array but still call `draft.endDrag()` on cancel, lock, background,
  or disappear and when the order did not change. Verify by typing a name and
  immediately starting a drag: nothing is saved while the finger is down, the
  name and order save together on drop, and a paused drag leaves the active
  session phase and Live Activity unchanged.
- [x] 2.3 Give `BlockEditorScreen` the same provisional order for movements,
  including the staged-block path where the order is applied directly without a
  flush, and the same `beginDrag()`/`endDrag()` bracketing. Verify a saved
  movement drag, a staged-block movement drag, and a cancelled drag in the
  simulator.

## 3. Provisional order in SESSIONS

- [x] 3.1 Give `SessionsScreen` a provisional record order captured on drag
  begin; render the cards from it, write contiguous `sortIndex` values and save
  only on drop, and discard it on cancel. Keep the accessibility Move up/Move
  down actions persisting immediately. Verify that dragging the active session's
  card leaves its badge and running timer unchanged during the drag and that the
  dropped order survives a relaunch.

## 4. Integration verification

- [x] 4.1 Extend or add an Argent sequence that covers a block drag across two
  rows, a movement drag, a cancelled drag that restores the previous order, and a
  session-card drag. Verify it passes twice in a row on `iPhone 18 Pro`.
- [x] 4.2 Build and run the full test suite, then repeat the 1.1 measurement:
  confirm the card stays under the pointer, the lift is visible at the start, and
  no new main-thread hitch longer than the baseline remains. Record the final
  trace and compare it with the baseline.
- [x] 4.3 Run `swiftlint lint --quiet --reporter summary` from the repo root and
  `openspec validate smooth-drag-reordering --strict`. Both must pass with no
  unresolved warnings.

## 5. Follow-up: one card and a still list

- [x] 5.1 Hide the card chrome, grip, and trash of the source row while it is
  the drag source, leaving its height as an empty gap and its row hit-testable
  so a drop back onto the slot commits. Verify the session, block, and movement
  lists show only the floating card, the active session's green outline and
  ACTIVE badge do not appear twice, and a crossed-row drop back into the slot
  persists across a relaunch.
- [x] 5.2 Disable user scrolling in `SessionsScreen`, `SessionEditorScreen`, and
  `BlockEditorScreen` while `draggingID` is set. Verify an upward drag from the
  middle to the header does not bounce or cancel the gesture, the card tracks
  the pointer, and the drag ends normally on release.
- [x] 5.3 Re-run the drag-reordering Argent sequence (96 steps, pass twice) and
  a top-edge cancel, run the unit tests, then `swiftlint lint --quiet
  --reporter summary` and `openspec validate smooth-drag-reordering --strict`.
- [x] 5.4 Accept a release in the header above the first row as an insert at the
  top: overlay a top drop zone while a row is dragged in all three lists, using
  the first row as the target. Verify dragging a later block or session to the
  top keeps it there, commits once, and no longer springs back.
- [x] 5.5 Mirror the top zone at the bottom: overlay a footer drop zone while a
  row is dragged in all three lists, using the last row as the target. Verify
  dragging an earlier block, movement, or session to the bottom keeps it there,
  commits once, and no longer springs back.

## 6. Reminders-parity pass

Native iOS lists (Reminders) lift the dragged row at its own card's size and
start it from the card's slot, keep the grab point under the finger with no
window clamp, and glide the other rows into their new slots instead of
re-snapping the layout on every crossing.

- [x] 6.1 Measure the row card's own frame in `PlanListRow` and
  `SessionDragRow` (not the whole row, which includes the grip and the trash)
  and hand it to `PlanDragHandle`: the lift card is the card's size and starts
  at the card's centre. Before this, the card was 100 pt wider than the row
  card, so the 30 pt window clamp pinned it left of the finger. Verified from
  30 fps frames: at lift the card covers its row card exactly.
- [x] 6.2 Replace the 42 pt / 30 pt positioning with a grab offset captured at
  lift and kept for the whole gesture: the card follows the pointer at the
  display rate with no clamp, like a native lifted row. Keep the touch-down
  render and the cancel return animation.
- [x] 6.3 Animate the provisional order in all three lists
  (`.smooth(duration: 0.26)`) so a crossing moves the rows and the empty slot
  instead of re-laying them out in one frame; animate the cancel revert the
  same way. Verified from frames: the rows pass through intermediate positions
  for about eight frames per crossing.
- [x] 6.4 Crossfade the card out and the row in over 0.14 s on drop
  (`PlanDropDelegate` + `fadeOutPreview`) so the card settles instead of
  vanishing in one frame.
- [x] 6.5 Re-record a movement drag on the final build: the card covers its
  row at lift, keeps the grab point across the crossings, the rows glide, and
  the drop settles without a flash. Re-run the drag-reordering Argent sequence
  (96 steps) twice, `xcodebuild ... test`, `swiftlint lint --quiet
  --reporter summary`, and `openspec validate smooth-drag-reordering
  --strict`.

## 7. Native-feel pass

- [x] 7.1 Hold the row card's frame in a reference box (`PlanCardMetrics`)
  instead of `@State`: a geometry write during a crossing or a drag no longer
  re-evaluates the row, and the handle still reads a live frame at lift and on
  drop. Verified by the drag sequence and the settle reading the destination
  slot.
- [x] 7.2 Grow the card to 1.02 over 0.12 s on lift, matching the prototype's
  ghost, so the lift reads as picking the card up instead of swapping the row
  for a picture.
- [x] 7.3 Settle on drop: move the card onto the slot that took the row, shrink
  it back to 1.0 and fade it over 0.16 s while the row fades in; a cancel
  shrinks and fades as the card returns home. Verified in frames: the card lands
  instead of vanishing.
- [x] 7.4 End every drag. A stationary hold-and-release could cancel the UIKit
  session without `didEndWith`, leaving the source row hidden forever; the
  display link now finishes the drag 0.45 s after finger-up if the system has
  not. Verified: hold a grip for a second, release without moving, the row
  returns and the order is unchanged.
- [x] 7.5 Re-run the drag-reordering Argent sequence twice, the unit tests,
  `swiftlint lint --quiet --reporter summary` and `openspec validate --all
  --strict`.

## Workflow follow-up

- Archive the change once the integration checks and the user's review are
  complete.
