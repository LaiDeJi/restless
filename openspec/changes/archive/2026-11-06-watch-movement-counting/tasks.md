# Tasks

## 1. Prototype and skill (review gate)

- [x] 1.1 Update `prototype-workout-timer.html` with the block model, straight and circuit order, the movement library inside SESSIONS, the three set end conditions, the timed-set countdown, watch armed and unavailable states, and the PART to BLOCK copy. Verify by opening the prototype and walking a straight block, a superset, a timed set, and a manual set.
- [x] 1.2 Update `.agents/skills/restless-rest-timer/SKILL.md` with the block model, rest rules, end conditions, the `performing` phase, the island contract, the copy, and the tests. Verify the skill matches the prototype's copy and timing on every flow from 1.1.
- [x] 1.3 Review gate: present the prototype and skill diff to the user. Verify the user approves before any task in group 2 starts.

## 2. Model and persistence

- [x] 2.1 Add `MovementProfile`, `Movement`, `BlockMovement`, `BlockKind`, and `EndCondition` to `Shared/` with Codable defaults and clamping. Add the new files to both targets in `project.yml`, run `xcodegen generate`, and verify the app and watch schemes build.
- [x] 2.2 Replace `WorkoutPart` with `WorkoutBlock` in `WorkoutPreset`; implement total sets, position, rest(after:), and total rest for straight and circuit. Verify with tests for both orders, movement transitions, block transitions, and the 40 x 25 overflow case.
- [x] 2.3 Migrate `PresetRecord` to `blocksData` with a fallback to `partsData`; mirror the first block's first movement into the legacy columns. Verify with a migration test that opens a legacy record and a round-trip test that preserves block and movement ids.
- [x] 2.4 Add the `MovementRecord` SwiftData entity and repository with add, rename, edit defaults, re-record, and delete. Verify with CRUD tests and a refusal test for a movement used by a session.

## 3. Session engine and timed sets

- [x] 3.1 Add `performing`, `setDuration`, `setDeadline`, `startSet`, and set-done from performing to `SessionSnapshot` and `SessionTransitions`; reconcile the set deadline. Verify with transition tests for start, early done, expiry, double tap, and restart.
- [x] 3.2 Update `SessionEngine` and `SessionStore` for the performing ticker and the v3 snapshot; keep pause and resume rest-only. Verify with engine tests for a timed set expiring while the app is inactive and for pause not touching a timed set.
- [x] 3.3 Update position and presentation helpers for block, movement, and set or round. Verify with tests for straight and circuit positions and the last-set clamp.

## 4. Movement library

- [x] 4.1 Add the MOVEMENTS entry to SESSIONS and a flat library screen of recorded movements. Verify with a UI test that opens the library from SESSIONS and returns.
- [x] 4.2 Add movement add, rename, re-record, and delete screens. Verify with UI tests for each action and the used-movement delete refusal.
- [x] 4.3 Add the phone-side recording flow: trigger, waiting, trace received, profile preview, accept or reject. Verify with a mocked watch trace and the timeout, no-motion, and too-few-cycles cases.
- [x] 4.4 Implement profile derivation and validation in `Shared/` (dominant axis, rise, fall, minimum period). Verify with fixture traces from the lab CSV and tests that reject two cycles and unstable periods.

## 5. Block editor and timer

- [x] 5.1 Add the block editor: add, rename, reorder, delete, kind toggle, set rest, round rest, and the straight or circuit count label. Verify with UI tests for each action and the last-block refusal.
- [x] 5.2 Add the movement picker from the library with the end condition and target chosen first, and the straight or circuit order preview. Verify with UI tests for a straight block, a superset, and a mixed block.
- [x] 5.3 Update the timer for block, movement, set or round, the upcoming rest or FINISH, the timed-set countdown, watch armed or unavailable, and START or SET DONE. Verify with UI tests for ready, performing, resting, and done.
- [x] 5.4 Update the set map to fill rows for straight and columns for circuit, with the 72-dot cap and the bar fallback. Verify with snapshot tests for a small block, a large block, and both orders.

## 6. Watch link and counting

- [x] 6.1 Add the phone `WatchLink` coordinator: arm, disarm, token, progress, completion, and reachability. Verify with unit tests using a fake transport for stale tokens, duplicate completion, and disconnect.
- [x] 6.2 Add the watch arm handling: receive the profile and target, start counting, send progress and completion, and play the haptic. Verify with a fake session and a recorded trace.
- [x] 6.3 Wire completion to `SessionTransitions.apply(.setDone)` and verify the target, duplicate, and manual-fallback cases with unit tests.
- [x] 6.4 Add the watch recording flow: a 15-second capture, haptic, and trace transfer. Verify with a manual recording and a trace arrival on the phone.
- [x] 6.5 Add the watch UI states: ready, armed, counting, saved, and unavailable. Verify on the watch simulator or device.

## 7. Live Activity

- [ ] 7.1 Update the attributes to carry blocks and movements and end stale activities on launch. Verify with snapshot tests for a two-block plan and a plan change.
- [ ] 7.2 Update the island and Lock Screen content for block, movement, set or round, the timed-set countdown, and the start-set link. Verify with previews and snapshot tests.
- [ ] 7.3 Update the rest copy and accents for movement and block transitions and the work countdown. Verify with snapshot tests for set rest, round rest, movement transition, block transition, and work.

## 8. Integration checks

- [ ] 8.1 Record a movement, add it to a session, arm a set, count to target, and confirm the rest starts on the timer and the island. Verify on the simulator or device.
- [ ] 8.2 Start a timed set, let it expire, and confirm the rest starts; then start one and tap SET DONE early. Verify on the simulator.
- [ ] 8.3 Install over a build with a saved session and confirm the old plan opens as one straight block with one manual movement. Verify on the simulator with a fixture record.
- [ ] 8.4 Confirm the watch limits: counting continues with the screen off under a workout session, a denied authorization falls back to the foreground, an unavailable watch shows the fallback, and SET DONE always works. Verify on the watch simulator or device.
- [ ] 8.5 Run `xcodegen generate` and `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro Max' -derivedDataPath build test`; verify all tests pass.
- [ ] 8.6 Build the watch lab with `xcodebuild -project Restless.xcodeproj -scheme RestlessWatch -destination 'generic/platform=watchOS' -derivedDataPath "$TMPDIR/restless-watch-dd" build`; verify it succeeds.

## Workflow follow-up

- Archive the change after the prototype review and the integration checks pass.
- Verify the archived specs with `openspec validate --all`.
