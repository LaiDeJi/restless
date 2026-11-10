# Tasks

## 1. Reference and copy

- [x] 1.1 Update `prototype-workout-timer.html`: remove the watch strip and its simulation buttons, the recording route and screens, the trace and profile panels, the REPS end condition, and all profile data and copy. Keep the name-only movement library and MANUAL/TIME add-movement flow; verify `python3 tools/prototype-check.py` prints the timer and library pages without a recording or watch control.
- [x] 1.2 Render before/after mockups of the TIMER without the watch strip and MOVEMENTS without recording controls, and record the review result in the change or a linked note; verify the implemented screens match the approved after state.
- [x] 1.3 Update `.agents/skills/restless-rest-timer/SKILL.md` and `AGENTS.md`: remove the watch app, recording, profiles, REPS, watch strip, watch alerts, watch build command, HealthKit/motion claims, and watch layout rules; describe MANUAL/TIME, the name-only library, and the phone-only alert path. Verify `rg -n "RestlessWatch|record|REPS|profile|watch strip|HKWorkoutSession|CMSensorRecorder" AGENTS.md .agents/skills/restless-rest-timer/SKILL.md` finds only intentional historical or generic references.

## 2. Model, persistence, and migration

- [x] 2.1 In `Shared/WorkoutBlock.swift`, reduce `EndCondition` to `manual` and `time`, make its decoder map legacy `reps` and unknown values to `manual`, remove `requiresWatchProfile`, `MovementAxis`, `MovementProfile`, `Movement.profile`, and the rep-target clamp branch. Verify `RestPlanTests`, `SessionTests`, and `PendingMovementTests` compile and pass with MANUAL/TIME fixtures.
- [x] 2.2 Add migration coverage for every stored shape: a `BlockMovement` JSON with `"endCondition":"reps"` and target 10 decodes as `.manual` with no target; a multi-block `blocksData` plan keeps every block, movement, round, set, rest, and order; a saved `SessionSnapshot` with a REPS row loads at the same position. Verify the new tests in `StoredBlockTests`, `PresetRecordTests`, and `SessionEngineTests` pass.
- [x] 2.3 Make the movement library name-only in `MovementRecord` and `MovementRepository`: remove profile reads/writes, delete `reRecord`, and keep `axisRaw`/`rise`/`fall`/`minPeriod` as dormant legacy columns so old stores open. Update `MovementRecordTests` to cover seed, add, rename, delete, and used-movement refusal without a profile; verify those tests pass.
- [x] 2.4 Update the remaining `.reps` fixtures to MANUAL/TIME in `LibraryAddTests`, `SessionDraftStoreTests`, `StoredBlockTests`, and `PresetRecordTests`, preserving each test's intent; verify those test files pass.
- [x] 2.5 Delete `Shared/MovementProfileDerivation.swift`, `Shared/ProfileRepCounter.swift`, `Shared/WatchMessage.swift`, `RestlessTests/MovementProfileTests.swift`, `RestlessTests/MovementRecordingTests.swift`, `RestlessTests/ProfileRepCounterTests.swift`, `RestlessTests/WatchLinkTests.swift`, and `RestlessTests/WatchMessageTests.swift`. Verify no production target or remaining test references those symbols.

## 3. Remove the watch app and recording pipeline

- [x] 3.1 Delete `RestlessWatch/` and remove the watch target, scheme, embed dependency, watchOS deployment target, watch permission copy, and watch build settings from `project.yml`; remove `RestlessWatch` from `.swiftlint.yml`. Verify `xcodegen generate` succeeds and `xcodebuild -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build build` builds without a watch target.
- [x] 3.2 Delete `Restless/UI/RecordingSheet.swift`, `Restless/UI/MovementRecordingViewModel.swift`, `Restless/Watch/WatchLink.swift`, `Restless/Watch/WatchRecordingService.swift`, `Restless/Watch/WatchSessionTransport.swift`, `tools/curl_live.py`, and `tools/curl_live.html`. Verify `rg -n "WatchLink|WatchMessage|WatchTransport|RecordingSheet|MovementRecording|recordingTrace|curl_live" Restless Shared tools` finds no production references.
- [x] 3.3 Remove `WatchLink` creation and environment injection from `RestlessApp`, the watch completion and alert wiring from `RootView`, `foregroundWatchAlert` from `SessionEngine`, and the `watchAlert` hook from `CompletionAlertCenter`. Update the `CountdownAlertScheduler` comment and `CompletionAlertCenterTests` to assert one phone haptic and no watch side effect; verify those tests pass.
- [x] 3.4 Remove `UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` from `project.yml` and regenerate `Restless/Info.plist`; confirm no watch, motion, or HealthKit usage strings remain in the generated app plist. Update the `Theme.swift` comment that mentions the watch lab. Verify the generated app bundle contains no `Watch/` directory.

## 4. Remove the UI and keep the library

- [x] 4.1 Remove the watch strip, `WatchLink` environment, and arm/disarm logic from `TimerScreen`. Remove `TimerStageRole.watch`, `watchHeight`, and `watchTopY` from `TimerStageLayout` and place the actions directly below the set map; delete the watch-strip layout test and update the remaining metrics fixtures. Leave `SetMap` unchanged: verify `git diff -- Restless/UI/SetMap.swift` is empty, `TimerStageLayoutTests` pass, and the timer still keeps the ring centre.
- [x] 4.2 Simplify `MovementsScreen` and `MovementEditorScreen`: remove the record header button, `+ RECORD MOVEMENT`, the recording sheet, the PROFILE section, and `RE-RECORD ON WATCH`, while keeping list, rename, usage, and delete. Update the empty-state and library card copy in `MovementsScreen` and `SessionsScreen`; verify the TIMER and SESSIONS flows with a manual screenshot or Argent checkpoint.
- [x] 4.3 Reduce `EndConditionPicker` to MANUAL and TIME, delete `MovementProfileGrid` and `TraceChart` from `MovementComponents`, and remove every profile/reps branch from `MovementPickerSheet`, `BlockMovementEditorScreen`, `BlockEditorScreen`, and `BlockLibrarySection`, replacing profile tags with a plain MANUAL label. Update the add-movement and movement-editor tests and verify the picker still starts on MANUAL with no REPS segment.
- [x] 4.4 Sweep the app and tests for stale recording or watch copy: `rg -n -i "record(ed|ing)? movement|re-record|profile|watch armed|watch unavailable|of .* reps|REPS" Restless Shared RestlessWidget RestlessTests` must find no user-facing or model references outside the intentional legacy decode bridge and dormant column comments.

## 5. Integration verification

- [x] 5.1 Run `xcodegen generate`, then `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test`; verify all remaining tests pass and no watch target is built.
- [x] 5.2 Install over a simulator build that already has a saved session and a running REPS snapshot. Verify the session opens with the same blocks, order, rounds, sets, and rests, the REPS row shows MANUAL with no target, movement names survive, and no watch strip, recording control, or profile tag appears.
- [x] 5.3 Update `.argent/e2e/session-start-and-draggable-lists.yaml` from `10 REPS` to `MANUAL`; re-verify or re-record the coordinate-based picker steps in `.argent/e2e/drag-reordering.yaml` after the third end-condition segment disappears. Reset the simulator fixture before the drag e2e, then run both sequences and confirm every checkpoint.
- [x] 5.4 Run `swiftlint lint --quiet --reporter summary` and `openspec validate remove-movement-recording --strict`; verify no warnings from deleted watch files and the change validates.
- [x] 5.5 Run `rg -n "RestlessWatch|RestlessWatch\.entitlements|watchOS|WatchConnectivity|HealthKit|CMSensorRecorder|CMMotionManager|curl_live" . --glob '!node_modules/**' --glob '!build/**' --glob '!openspec/changes/archive/**'` and confirm only intentional mentions remain.

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived result and the five-spec validation baseline.
