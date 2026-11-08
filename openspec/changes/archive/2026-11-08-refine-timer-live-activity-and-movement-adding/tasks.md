# Tasks

## 1. Prototype and skill first

- [x] 1.1 Add the two-tap RESTART pill beside EDIT and the deduplicated position strip to `prototype-workout-timer.html`; verify a one-block and a two-block session at ready and resting show the same one-line strip and that the first tap arms, the second restarts
- [x] 1.2 Add the `ADD FROM LIBRARY` rows to the prototype's block editor, including the staged-block path; verify one tap appends a MANUAL movement, a second raises rounds to 2, and a staged block's DONE enables without touching the session
- [x] 1.3 Add the glass and flat states for the timer EDIT/restart pills and the SESSIONS add control to the prototype; verify both states render and the labels keep contrast
- [x] 1.4 Update `.agents/skills/restless-rest-timer/SKILL.md` for the restart control, the strip rules, the one-tap library add, the Lock Screen 160-point panel and xxLarge cap, the glass scope, and the new tests; verify no stale `BLOCK n OF m` or `accessibility1` claim remains

## 2. Timer restart control

- [x] 2.1 Add a `canRestart` rule to `SessionSnapshot` (`doneSets > 0`, phase not `done` and not `notStarted`) and unit-test every phase; verify `xcodebuild test` covers ready, performing, resting, paused, notStarted and done
- [x] 2.2 Add the restart control to the timer header with the armed `TAP AGAIN` state, amber emphasis, accessibility label and phase-change disarm, and call `engine.perform(.restart)`; verify on a throwaway simulator that it is hidden before the first set and when done, arms without changing the session, and resets to block 1 set 1 on the second tap
- [x] 2.3 Verify the Live Activity follows a restart to ready with zero sets and remains a single activity; check the lock screen or `log stream` for one update and no new activity request

## 3. Position strip

- [x] 3.1 Extract an internal pure `TimerPositionCopy` segment builder and use it from `TimerPositionStrip`; verify multi-block, single-block, block-name-equals-movement, resting `UP NEXT`, round-only, set-only and 1 × 1 cases in unit tests
- [x] 3.2 Remove the `BLOCK n OF m` segment and keep the one-line/stacked `ViewThatFits` pair; verify on the simulator at default, XXL and an accessibility size that the strip is one line at default and wraps above the ring only when needed
- [x] 3.3 Check a two-block session while resting and a five-block session at the active chip; verify the block name appears only in the chip and the active chip stays centred

## 4. Lock Screen panel

- [x] 4.1 Rebuild `LockScreenPanel` as the three-row layout and delete the separate position and rest-context rows; verify the state row shows the chosen copy in ready, resting, paused, performing and done
- [x] 4.2 Reduce the timer to 26 pt scaled and capped at 32, cap Dynamic Type at `.xxLarge`, limit every row to one line, and apply the 14 pt padding and 8 pt spacing; verify the panel's measured height is at most 160 pt at default, XXL, xxLarge and an accessibility size
- [x] 4.3 Verify the panel in the simulator's Notification Center and Lock Screen during a set rest with an 18-character movement name: the countdown, progress bar, PAUSE and SKIP are fully visible; repeat for ready, timed work, paused and done
- [x] 4.4 Verify the expanded island and compact island are unchanged and still show the block, position, countdown and controls

## 5. One-tap library add

- [x] 5.1 Add the `ADD FROM LIBRARY` rows to `BlockEditorScreen`, list only movements not already in the block, append one with `.manual` and no target, and flush once; verify the sheet does not open and the page updates in the same frame
- [x] 5.2 Hide the list while editing is locked and when no unused movement remains; verify a running rest shows no list and a block containing every library movement shows no list
- [x] 5.3 Unit-test the single append to a saved block and a staged block, the two-movement rounds rule, and the empty/invalid targets; verify `xcodebuild test`
- [x] 5.4 Verify the single-movement flow on a throwaway simulator: `ADD BLOCK` → tap a library movement → `DONE` creates a block with that movement, rounds 1, sets per round 3 and the previous rests

## 6. Liquid Glass chrome

- [x] 6.1 Add the `chromeGlass` modifier beside `PlanPillButton` with the iOS 26 `.glassEffect(.regular.tint(...).interactive(), in:)` branch and the existing translucent fill for iOS 18–25; verify the app builds with the iOS 27 SDK and the deployment target stays 18
- [x] 6.2 Apply it to the timer EDIT, the timer restart (amber tint when armed) and the SESSIONS add control only; verify on the iOS 27 simulator that those three are glass, editor DONE/back, cards, ring, map and primary buttons stay flat, and the labels keep contrast

## 7. Integration verification

- [x] 7.1 Run `xcodegen generate`, the simulator build, `xcodebuild test`, and `swiftlint`; verify no new warnings and all tests pass
- [x] 7.2 Run one Argent e2e sequence on a throwaway simulator: start a session, complete a set, arm and confirm RESTART, add a movement from the library to a block, and capture the timer, block editor and Lock Screen at the checkpoints; verify the accessibility tree and screenshots match the specs
- [x] 7.3 Run `openspec validate refine-timer-live-activity-and-movement-adding --strict`; verify the change is valid with no warnings

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result.
