# Tasks

## 1. Prototype first

- [x] 1.1 Add the new-movement name field, no-profile note, and confirmation button to the prototype's add-movement picker, update the prototype's header comment, and verify the flow by opening `prototype-workout-timer.html` and adding a named movement with each end condition
- [x] 1.2 Give the prototype's dragged rows a lifted opaque card and stronger shadow while keeping the dimmed source and outlined drop target, and verify a block drag and a movement drag both read as picked up

## 2. Session name keyboard

- [x] 2.1 Remove the keyboard accessory toolbar from `SessionEditorScreen` and add the named-coordinate-space tap that dismisses the keyboard only when the tap lands outside the name field; verify on the simulator that tapping empty page space closes the keyboard, tapping the name field keeps it, and tapping a block row commits and opens the block
- [x] 2.2 Confirm the name still commits on focus loss, Return, Done, and page dismissal, and that clearing the field still yields Untitled

## 3. Movement creation

- [x] 3.1 Add `MovementRepository.addOrReuse(name:in:)` that trims, caps at 18 characters, rejects an empty name, reuses a case-insensitive match, and inserts a profile-less movement otherwise; verify with tests for create, reuse, trim, cap, and empty input
- [x] 3.2 Add `SessionDraftStore.appendMovement(_:toBlock:condition:target:)` with the existing second-movement round bump and target clamping; verify with tests that a second movement raises a one-round block to two and that existing multi-movement blocks keep their rounds
- [x] 3.3 Build the NEW MOVEMENT section in `MovementPickerSheet` with the name field, no-profile note, and disabled-until-valid confirmation, and route both the typed name and a library row through the shared append path; verify on the simulator that Cable Fly with TIME 0:45 appears in the block, appears in LIBRARY as NO PROFILE, and closes the picker
- [x] 3.4 Verify a blank or whitespace-only name creates nothing, a name typed with surrounding spaces is trimmed, and the block movement editor still shows the no-profile warning for a REPS movement

## 4. Lifted drag rows

- [x] 4.1 Add the measured row width, opaque floating preview card, dimmed source row, and set-accent outline for the row under the drag in `PlanListRow`; verify both the session block list and the block movement list show the card and the outlined target
- [x] 4.2 Clear the drag state on drop, a release outside the rows, a scene-phase change, screen dismissal, and the next drag start; verify a release over the header or footer leaves no dimmed or outlined row
- [x] 4.3 Verify reordering still follows the finger, the delete action and grip stay tappable, and no drag or outline appears while a rest locks editing

## 5. Integration verification

- [x] 5.1 Run `xcodegen generate`, the simulator build, and `xcodebuild test`; verify the new repository and draft tests pass alongside the existing suite
- [x] 5.4 Run `swiftlint` and verify no new warnings
