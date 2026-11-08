# Tasks

## 1. Prototype first

- [x] 1.1 Update the picker in `prototype-workout-timer.html`: start on MANUAL, list MANUAL → TIME → REPS, and show the no-profile note only for REPS. Verify by opening the prototype, opening ADD MOVEMENT, and checking the default, order, and note for each condition.
- [x] 1.2 Add the staged "TO ADD" list to the prototype picker: ADD MOVEMENT and a library row queue or unqueue an item, DONE appends every queued item to the block in order and returns, and back/CANCEL discards without changing the block or library. Verify by queueing two movements, committing, checking the block order, then queueing one and backing out to confirm nothing changed.
- [x] 1.3 Stage a new block in the prototype: `+ ADD BLOCK` opens the picker without adding a block, DONE adds one block with the queued movements and inherited rests, CANCEL adds nothing, and DONE is disabled while nothing is queued. Add the picker copy that says the movements become the new block's first movements. Verify by adding a block, cancelling, and confirming the block count is unchanged, then adding one and confirming the block and its movements.

## 2. Model order and append paths

- [x] 2.1 Add `EndCondition.editorOrder` (`[.manual, .time, .reps]`) and `EndCondition.requiresWatchProfile` (true only for REPS) in `Shared/WorkoutBlock.swift`, and make `EndConditionPicker` and both profile warnings use them. Add unit tests for the order and the profile rule; verify with `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath build test`.
- [x] 2.2 Add `SessionDraftStore.appendMovements(_:toBlock:)` and make `appendMovement` call it with one item. Add tests for batch order, one commit, rounds rising once when an empty or one-movement block reaches two movements, an already multi-movement block keeping its rounds, a missing block, and an empty batch; verify with the same test command and `swiftlint`.
- [x] 2.3 Add `SessionDraftStore.appendBlock(_:)` that appends one block in a single edit, raises a two-movement block to rounds 2, rejects an empty movement list, and leaves the other blocks untouched. Add tests for each case; verify with the test command and `swiftlint`.

## 3. Staged picker and new block

- [x] 3.1 Add a small pending-selection value type in the app target with queue, toggle, remove, trim, and duplicate rejection, plus unit tests for each rule; verify with the test command.
- [x] 3.2 Give `MovementPickerSheet` a target of either an existing block or a new block. Render the counted "TO ADD" section, toggle library rows, queue the typed name and clear the field, and keep CANCEL and swipe-down side-effect free. For an existing block, DONE resolves typed names through `MovementRepository.addOrReuse`, appends one batch, flushes, and dismisses. For a new block, DONE builds the block with the queued movements, appends it through `appendBlock`, flushes, and dismisses; DONE is disabled while nothing is queued. Set the condition default to MANUAL, gate the no-profile warning on REPS, and show the new-block intro copy and empty-pending note. Run `xcodegen generate` after adding files; verify on the iPhone 18 Pro Max simulator that two queued movements land in order after DONE, CANCEL creates no library movement, MANUAL/TIME hide the warning, and a new block with no queue cannot be committed.
- [x] 3.3 Change `SessionEditorScreen.addBlock` to build the new block locally with the inherited rests, name, rounds, and sets per round, open the picker for that block, and leave the draft untouched until the picker's DONE. Verify on the simulator that tapping `+ ADD BLOCK` does not change the block count or save an untitled block, CANCEL leaves the session unchanged, and DONE adds exactly one block with the queued movements.
- [x] 3.4 Keep the pending list, its remove controls, and the picker's add/commit controls disabled while editing is locked. Verify by opening the picker during a running rest and checking the controls and layout.

## 4. Keyboard dismissal

- [x] 4.1 Add a shared page-tap keyboard-dismiss modifier that uses a named coordinate space and the focused field's frame, and apply it to the add-movement sheet, block editor, movement editor, recording sheet, and session editor (replacing the session editor's inline copy). Add `.scrollDismissesKeyboard(.interactively)` to the picker. Verify on the simulator on each screen: opening the keyboard and tapping the page hides it, tapping inside the field keeps it, and the typed text remains. Run `swiftlint`.

## 5. Skill

- [x] 5.1 Update `.agents/skills/restless-rest-timer/SKILL.md` so its picker paragraph says MANUAL, TIME, REPS with MANUAL as the add default, staged additions committed by DONE, CANCEL discarding, the profile warning applying to REPS only, and `+ ADD BLOCK` staging the new block until the same DONE. Verify by reading it against `openspec/specs/workout-sessions/spec.md` and the prototype flow.

## 6. Integration verification

- [x] 6.1 Build the iPhone app and the watch app with the AGENTS.md commands and run the full `xcodebuild test`; verify both builds succeed and the tests pass.
- [x] 6.2 Walk the full flow on the simulator: add a block, cancel, confirm no block; add a block, queue a typed movement and a library movement, DONE, confirm the block order and inherited rests; open ADD MOVEMENT on that block, queue and CANCEL, confirm the library and block are unchanged; check the MANUAL default, the order in both editors, the REPS-only warning, and the page-tap keyboard dismissal. Verify with the accessibility tree and screenshots.

## Workflow follow-up

- Archive the change with `openspec archive refine-add-movement-picker` after review.
- Verify the archived spec and the skill still match the shipped picker.
