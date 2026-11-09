# Tasks

## 1. Prototype Reference

- [x] 1.1 Raise the prototype's `trimName`, `liveName`, every name `maxlength`, and the unique-name suffix from 18 to 40; verify with `python3 tools/prototype-check.py` and a driver that types a 40-character session name.
- [x] 1.2 Add a grip and drag reorder to the prototype's SESSIONS cards, keep the ACTIVE badge on its card, and persist the demo order; verify with a driver that drags Core above Chest and reloads the page.
- [x] 1.3 Replace the prototype's two-tap restart arm and `TAP AGAIN` state with a modal confirmation that names the lost sets, cancelled rest, and return to block 1; verify the cancel and confirm branches with a driver.
- [x] 1.4 Add a simulated completion alert to the prototype: a notification card at rest end with the same title and body the app will use, without expanding the island; verify the card appears in the driver dump and the island stays compact.
- [x] 1.5 Update the prototype's header comment and inline restart copy so no old 18-character, `TAP AGAIN`, or silent-completion claim remains; verify with `grep -n '18\|TAP AGAIN' prototype-workout-timer.html` that the remaining matches are unrelated dimensions.

## 2. Forty-Character Names

- [x] 2.1 Set `WorkoutPreset.bounds.nameLimit` to 40 and make `WorkoutPreset.clampedName` and `NameRules.live` flatten newlines and tabs to spaces before trimming and capping; verify new `NameRulesTests` for 40 characters, trim, fallback, and pasted newlines pass.
- [x] 2.2 Update the session, block, movement, recording, and add-movement fields to use the shared 40-character live cap; verify a 40-character entry survives save and reload in the editor.
- [x] 2.3 Update display surfaces: session cards and movement/pending rows wrap to two lines, the timer header and block strip scale or truncate to one line, the position strip keeps one line before its accessibility stack, and the Lock Screen movement row uses a 0.55 minimum scale; verify screenshots with a 40-character name at default and xxLarge sizes and the existing `TimerPositionCopyTests`.
- [x] 2.4 Update the `restless-rest-timer` skill's name rule and the prototype notes from 18 to 40 characters; verify the skill says 40 and the app has no remaining `18` name cap.

## 3. Manual Session Order

- [x] 3.1 Add `sortIndex: Int?` to `PresetRecord`, add `PresetRepository.ordered` and `normalizeOrder`, and make `fetchAll` use the manual order with creation order as the fallback; verify a SwiftData test that legacy nil indexes read in creation order and normalize to 0..<n.
- [x] 3.2 Add the grip and drop reorder to `SessionsScreen`, reusing the `PlanListRow` drag surface, with the active badge following its card and drag disabled while editing is locked; verify a move updates the list, persists across relaunch, and leaves the running timer unchanged.
- [x] 3.3 Append new sessions at the end by normalising before insert and assigning the next index; verify a test that saves a third session after two existing ones and lists it last.
- [x] 3.4 Update the skill's navigation section with the manual order, the active-badge rule, and the locked-grip rule; verify the skill describes the same drag and persistence rules as the tests.

## 4. Restart Confirmation

- [x] 4.1 Replace `TimerScreen`'s `restartArmed` state, `TAP AGAIN` label, and amber arm with a restart button that opens a confirmation alert with the agreed title, message, destructive `Restart Session`, and `Cancel`; verify cancel leaves the snapshot unchanged and confirm lands in the start gate at block 1 set 1, shows START SESSION, and ends the Live Activity.
- [x] 4.2 Add the same confirmation to `SessionEditorScreen`'s `RESTART SESSION` action, keeping the existing flush and return path; verify cancel preserves completed sets and confirm calls `engine.use` and lands in the gate without starting.
- [x] 4.3 Remove the armed-restart references from `app-chrome`, the prototype, and the skill; verify `grep -R 'TAP AGAIN' Restless Shared RestlessTests` finds no restart arm and `TimerRestartTests` still passes.
- [x] 4.4 Extend `.argent/e2e/session-start-and-draggable-lists.yaml` or add a short e2e that opens the dialog, cancels, opens it again, confirms, and reads START SESSION at the gate; verify the sequence passes on the iPhone 18 Pro simulator. The manual sequence passed on the simulator; the e2e runner on this Mac could not connect to native devtools.

## 5. Countdown Completion Alerts

- [x] 5.1 Remove AlarmKit from the alert path: delete the alarm scheduling, authorization, fixed alarm ID, and silent alarm asset so the scheduler only manages the local notification; verify no `AlarmKit` or `AlarmManager` reference remains in the app target.
- [x] 5.2 Add the pure `CompletionAlertCopy` builder for rest, round rest, movement switch, block transition, timed work, final set, and session complete; verify unit tests for each title/body pair and a 40-character movement name.
- [x] 5.3 Add the alert scheduler protocol and the UserNotifications implementation with one request per deadline, a stable prefix identifier, a deadline trigger, cancel, and a delegate that opens TIMER and suppresses foreground banners; verify a fake-scheduler test for schedule/cancel. The manual background-notification tap is part of 5.10.
- [x] 5.4 Remove `NSAlarmKitUsageDescription` from `project.yml` and the generated `Info.plist`, and delete `Restless/Resources/silence.caf`; run `xcodegen generate` and verify the app builds for the simulator.
- [x] 5.5 Add the `CompletionAlertCenter` state machine over the scheduler and haptic closures: foreground haptic, a background deadline that leaves the notification pending, pause/resume/skip/restart/plan-change cancellation, zero-rest suppression, and late-reconcile suppression; verify unit tests with a fake scheduler and fake haptic.
- [x] 5.6 Wire the centre into `SessionEngine`, `RootView`'s scene phase, the 200 ms ticker, `use`, `refreshFromStore`, and init; verify a late deadline applies one transition and raises no second alert, and a background deadline leaves the notification pending while updating the activity state.
- [x] 5.7 Remove the alerting Live Activity path: delete `LiveActivityCoordinator.alert` and the centre's activity closure, keep the normal state updates and the expanded movement label scale, and verify no `AlertConfiguration` remains in the app and the widget tests pass.
- [x] 5.8 Add `WatchMessage.alert`, `WatchLink.alertIfReachable`, and `WatchHaptics.alert`; verify the watch model plays one notification haptic without changing reps, target, or phase, and update `RestlessWatch/README.md`.
- [x] 5.9 Update the skill's completion section and `AGENTS.md` rule 10: foreground is haptic-only, a background deadline uses the one local notification the system delivers and mirrors to the watch, and no alerting Live Activity update or system alarm is used. Verify both documents no longer say completion is undecided, silent, or island-based.
- [x] 5.10 Verify the whole alert path on the simulator and device: foreground rest end, foreground timed work end, background rest with the app alive (the local notification is delivered and is not cancelled, no island alert), background long rest with the app suspended (local notification), pause/resume, skip, restart, and a paired watch notification mirror; capture screenshots and logs for each. Verified: simulator foreground rest end, simulator background notification delivery on the Lock Screen, device background notification and watch mirror with the phone locked; pause/resume/skip/restart and the timed-work copy are covered by unit tests.

## 6. Integration Verification

- [x] 6.1 Build and run the full test suite on the iPhone 18 Pro simulator with the commands in `AGENTS.md`; verify 0 failures.
- [x] 6.2 Build the watch scheme for `generic/platform=watchOS`; verify the alert message and haptic compile with no new warnings.
- [x] 6.3 Run `swiftlint lint --quiet --reporter summary` from the repo root; verify no new lint violations.
- [x] 6.4 Run `openspec validate session-polish-and-countdown-alerts --strict`; verify it reports valid.
- [x] 6.5 Run the updated Argent e2e on the iPhone 18 Pro simulator; verify session sorting, the restart dialog, and the 40-character name flow pass in one sequence. The same sequence was verified manually on the iPhone 18 Pro simulator; the e2e runner could not connect to native devtools on this Mac.
- [x] 6.6 Run the device build and install from `AGENTS.md` on the iPhone 15 Pro Max; verify the notification permission, the background notification while the app is alive and while suspended, the watch mirror, and no alerting island expansion. Build and install done; the background notification and watch mirror were verified on the device with the phone locked; no `AlertConfiguration` remains.

## Workflow follow-up

- Archive the change with `openspec-archive-change` after implementation and review.
- Verify `openspec validate --all --strict` reports every capability, including the new `countdown-alerts`, and that the main specs carry the updated name, sorting, restart, and alert requirements.
