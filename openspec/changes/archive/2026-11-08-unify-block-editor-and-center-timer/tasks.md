# Tasks

## 1. Prototype reference

- [x] 1.1 In `prototype-workout-timer.html`, make `+ ADD BLOCK` open the block editor with a staged block: block name, rounds, sets per round, set rest, round rest, empty movement list, order preview, and `+ ADD MOVEMENT`; DONE appends it, back/cancel discards it. Verify in the browser that the new-block page matches the edit-block page and that cancelling leaves the session's blocks unchanged.
- [x] 1.2 Remove the `NEW BLOCK` route from the prototype's movement picker so it only queues movements for a saved or staged block. Verify the picker is reachable only from a block editor and its DONE adds to that block.
- [x] 1.3 Pin the prototype's timer hero at 50% of the timer stage, place the set map and watch strip below it at a fixed gap, and let tall content scroll. Verify the ring's centre stays at the same y between a one-round block and a three-round block while the map grows below it.

## 2. Skill rules

- [x] 2.1 Update `.agents/skills/restless-rest-timer/SKILL.md` for block creation: new block defaults, the shared editor layout, staged commit on DONE, discard on back, the movement requirement, and a picker with no new-block mode. Verify no `NEW BLOCK` step remains and the text matches the prototype.
- [x] 2.2 Update the skill's timer presentation and test list with the fixed ring centre and the map-below-ring rule. Verify the rules name the block strip, position strip, and map as non-moving and mention scrolling for tall content.

## 3. Staged block model

- [x] 3.1 Add `BlockEditingTarget` (`saved(UUID)` / `staged`) and a `stagedBlock` to `SessionDraftStore`, with create, edit, append-movement, commit, and discard methods; staged edits must not mark the draft dirty or schedule a save. Verify with new tests for defaults, inherited rests, movement append, and no commit or flush on staged edits.
- [x] 3.2 Extend `BlockEditorScreen` with the target value: read and edit the staged block, disable DONE while it has no movements, and commit it on DONE; hide `DELETE BLOCK` for a staged block. Verify a build and that editing a saved block is unchanged.
- [x] 3.3 Extend `BlockMovementEditorScreen` with the same target so a staged block's movement condition, target, and removal edit only the staged block. Verify a staged movement edit leaves `session.blocks` unchanged.
- [x] 3.4 Remove `.newBlock` from `MovementPickerSheet.Target`, use `BlockEditingTarget`, drop the `NEW BLOCK` copy and its empty-queue DONE gate, and append queued movements to the staged or saved block. Verify CANCEL leaves the block and library unchanged and DONE appends in display order.
- [x] 3.5 Replace `SessionEditorScreen`'s staged-block sheet with `draft.beginStagedBlock(after:)` and a `navigationDestination(isPresented:)` push of `BlockEditorScreen(target: .staged)`; discard an uncommitted staged block when that destination closes. Verify + ADD BLOCK shows the same layout as a saved block, DONE adds the block to the list, and back adds nothing.
- [x] 3.6 Add `SessionDraftStore` tests for commit, discard, zero-movement rejection, inherited rests, and a multi-movement staged block rising to two rounds. Verify `xcodebuild test` passes these tests.

## 4. Timer layout

- [x] 4.1 Add a pure layout metrics helper and the timer layout that places the top chrome, a ring centred at the viewport's vertical centre, the map and watch strip below it, and the actions at the bottom or below the map. Verify unit tests show the same ring centre for one-row and three-row maps, a wrapping position strip, a tall map that scrolls, and a short viewport.
- [x] 4.2 Integrate the new layout into `TimerScreen`, removing the current `Spacer`/`minHeight` centring while keeping the block strip, position strip, map, watch strip, and actions. Verify the app builds and the timer renders all phases.
- [x] 4.3 On the iPhone 18 Pro Max simulator, run a session with block 1 at one round and block 2 at three rounds; screenshot the ready state in each block and compare the ring's centre y. Verify the centres match within 1 pt and the map grows below the ring.
- [x] 4.4 Verify the ring stays put when the rest starts and ends, when the position strip wraps, and at an accessibility text size; verify a map that does not fit scrolls without clipping text.

## 5. Integration verification

- [x] 5.1 Run `xcodegen generate`, the simulator build, `xcodebuild test`, and `swiftlint`; verify no new warnings or failures.
- [x] 5.2 Run one Argent e2e sequence that opens SESSIONS, adds a block through the shared editor, sets its values, adds a movement, taps DONE, then cancels a second new block and checks the block count. Verify the added block row carries the edited values and the cancelled block leaves no row.
- [x] 5.3 Re-open an existing saved session and the active timer; verify the saved values, running session, and block count are unchanged and no store migration occurred.

## Workflow follow-up

- Archive the change after review and the verification above are complete.
- Verify the archived specs update `workout-sessions` and `rest-timer` as intended.
