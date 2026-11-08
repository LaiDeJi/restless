# Tasks

## 1. Reference First

- [x] 1.1 Update `prototype-workout-timer.html` with the not-started timer state and START SESSION action, the red danger-link treatment, and the grip/trash row layout for blocks and movements. Verify by opening the prototype and checking each state and row by hand.
- [x] 1.2 Update `.agents/skills/restless-rest-timer/SKILL.md` with the not-started state, start and gate-entry transitions, draggable list rules, red delete copy, gate presentation, and the Live Activity gate. Verify each changed rule appears in the state table, transitions, editing, timer presentation, and copy sections.

## 2. Session Start Gate

- [x] 2.1 Add `SessionPhase.notStarted` and handle it in snapshot time/progress, `Theme` copy, the timer hero, and the Live Activity widget switches. Verify the AGENTS.md simulator build command succeeds, which proves every phase switch is covered.
- [x] 2.2 Add the `startSession` action and transition, make `initial` and `replacePreset` return the gate, and update the `ready()` test helper. Add tests that a fresh snapshot is not started, START SESSION reaches block 1 set 1 without counting, and set done or a second start is ignored. Verify the new tests and the existing session tests pass with the AGENTS.md test command.
- [x] 2.3 Add `SessionEngine.use(_:startImmediately:)` and route activation (USE THIS SESSION, active-plan edits) through the gate while RESTART SESSION starts directly. Verify in the simulator that activating a session shows START SESSION, and restarting an active session lands at set 1 ready with zero sets.
- [x] 2.4 Gate the timer: show READY / START / START SESSION / first-block preview, hide the watch strip and skip-rest action, and make the primary button apply `.startSession`. Verify by launching with no saved run, confirming no set is counted before the tap, and confirming the watch link is disarmed.
- [x] 2.5 Make the Live Activity gate-aware: no activity exists in the gate, entering the gate ends a stale one, and START SESSION requests one. Verify in the simulator by activating a session (no island activity), starting it (one activity), and resetting it (activity gone).

## 3. Destructive Red

- [x] 3.1 Add `Theme.destructive` and apply it to DELETE SESSION, DELETE BLOCK, and REMOVE FROM BLOCK, including the armed second-tap treatment. Verify on a simulator screenshot that the resting delete is red and the armed delete is the stronger red with TAP AGAIN TO DELETE.

## 4. Draggable Lists

- [x] 4.1 Add session-draft methods for moving and removing blocks and movements, with the last-item guards, and unit tests for up, down, delete, and the last-item refusal. Verify the new tests pass with the AGENTS.md test command.
- [x] 4.2 Build the reusable grip/drop row and replace the session editor's move-chevron column with the grip and trash actions on each block row. Keep row taps navigating, hide trash on the only block, disable drag and delete while locked, and keep a 44 pt target. Verify in the simulator by dragging blocks up and down, arming and confirming a delete, and trying to drag during a rest.
- [x] 4.3 Apply the same row to the block editor's movement list and remove the MOVE UP / MOVE DOWN buttons from `BlockMovementEditorScreen`. Verify dragging, row delete, the only-movement guard, and locked behaviour in the simulator.
- [x] 4.4 Add VoiceOver move and delete actions to both lists, and verify at the largest accessibility text size that rows grow, the grip and trash stay visible, and neither row truncates.

## 5. Integration

- [x] 5.1 Run the full simulator test suite and the watch build from AGENTS.md; fix any compile or test regressions.
- [x] 5.2 Run one Argent e2e sequence on a throwaway simulator: fresh launch shows START SESSION, start, reorder blocks, delete a block, reorder movements, delete a movement, confirm DELETE SESSION is red, and leave the fixture restored. Verify two consecutive full passes.
- [x] 5.3 Grep the UI and skill copy for stale `MOVE UP`, `MOVE DOWN`, and part-based delete wording; verify only accessibility labels remain.

## Workflow follow-up

- Archive the change after implementation and review are complete.
