# Tasks

## 1. Prototype and rule reference

- [x] 1.1 Update the watch remote section of `prototype-workout-timer.html`: replace the session-wide `.w-bar` slivers with one current-block bar per figure, a large block count above it (`5 / 16 · SETS IN THIS BLOCK`), and the session count below. Keep every block size on the same bar; add one large-block figure that proves the bar does not change form. Verify with `python3 tools/prototype-check.py` and a DOM check that no watch figure has a 16-segment session bar.
- [x] 1.2 Update the Watch remote and verification sections of `.agents/skills/restless-rest-timer/SKILL.md` (one continuous current-block bar, block count and session count, no dots or fallback, no time) and the date rule in `AGENTS.md` rule 12 (today's plan is followed; a manual pick holds for the day). Verify by reading the changed sections and grepping that no watch "segmented bar" or "set map" description remains.

## 2. Shared block progress

- [x] 2.1 Add one shared done-in-block helper to `Shared/SessionSnapshot.swift` (for example `doneSets(inBlockAt:)` or a small block-progress value) and have the phone's `SetMap` use it without changing its dots or limits. Add tests for the first block, a later block, a done session, and clamping past either end. Verify with `xcodebuild test -only-testing:RestlessTests/SessionTests`.

## 3. Watch block bar

- [x] 3.1 Add `WatchBlockBar` (in `WatchRemoteView.swift` or a new `RestlessWatch` file, with `xcodegen generate` if new) showing the large block count, `SETS IN THIS BLOCK`, one continuous bar at `doneInBlock / block.totalSets`, and the session count below. Replace `WatchSetBar` and give the block one accessibility label. Verify with `xcodebuild -scheme RestlessWatch` for the watch simulator.
- [x] 3.2 Add preview fixtures for a two-block session (5 of 16 in block 1, 5 of 24 session sets) and a large block with many rounds and sets. Verify on both the 42 mm and 46 mm simulators: the bar reads 5 / 16 above and 5 OF 24 SETS below, the large block uses the exact same bar, the done state shows a full bar, and the action stays visible. Capture a screenshot for each and run `WatchRemoteTests`.
- [x] 3.3 Verify the wrist still follows the published session: after `setDone` and `skipRest` on the phone, the bar advances; a paused rest keeps the bar and shows no ticking value. Verify manually with the paired phone and watch simulators.

## 4. Active-day marker and manual activation

- [x] 4.1 Add a day marker and an `activate(id:on:)` helper to `ActivePresetStore` in `Shared/SessionStore.swift`, backed by an injectable defaults suite and keys behind the existing static facade. Add `ActivePresetStoreTests` using a unique suite for writing both values, replacing them, and treating a missing marker as stale. Verify with `xcodebuild test -only-testing:RestlessTests/ActivePresetStoreTests`.
- [x] 4.2 Route the manual activation sites through `activate`: `SessionEditorScreen.use` for existing and draft sessions, the delete fallback, and `CalendarDaySheet.activate`. Leave the editor's active-session save/restart and `seedIfNeeded` untouched. Verify the app builds and the existing session-management tests pass.
- [x] 4.3 Check that editing or restarting the active session does not move the day marker, and that the fallback after deleting the active session holds for the day. Add assertions to `ActivePresetStoreTests` or a session-management test where the call sites can be exercised without the UI.

## 5. Date-follow decision

- [x] 5.1 Add the pure decision in `Shared/` (`keep`, `recordDay`, `switchTo`) with inputs for active id, active day, today, today's plan, snapshot, and calendar. Unit-test a stale day at the gate, the same plan with a stale day, the current day, a running or paused session with progress, a done session with a different plan, a done single-session rotation with the same plan, and a day with no plan. Verify with `xcodebuild test -only-testing:RestlessTests/ActiveSessionDecisionTests`.
- [x] 5.2 Add the app-side follower in `Restless/App/` or `Restless/Session/`: initialise the anchor, read the ordered presets, resolve the plan, apply the decision, and call `engine.use` only on a switch. Add an in-memory integration test with a fixed calendar: tomorrow's plan replaces an idle Chest, a manual pick on the same day holds, and a session with a completed set is not replaced. Verify with `xcodebuild test -only-testing:RestlessTests/ActiveSessionFollowerTests`.

## 6. Lifecycle wiring

- [x] 6.1 Call the follower from `RootView` on first appearance, on foreground after `engine.refreshFromStore()`, on `NSCalendarDayChanged`, and on `UIApplication.significantTimeChangeNotification`; pass `.now` and the current calendar. Verify by reading the scene-phase order and launching with the stored active day set to yesterday, then checking the timer opens on today's plan.
- [x] 6.2 Verify the watch receives the switched plan: after the phone switches at launch, the wrist shows the new session at its gate; a running session keeps the previous plan. Verify manually with the phone and watch simulators.

## 7. Integration and gates

- [x] 7.1 Run the full test suite on the iPhone 18 Pro simulator with `xcodebuild test` and verify all tests pass, including the block-progress, active-session, and existing timer tests.
- [x] 7.2 Run `swiftlint lint --quiet --reporter summary` from the repo root and verify no new warnings.
- [x] 7.3 Run `openspec validate watch-block-progress-and-daily-session --strict` and verify 0 failed; run `openspec validate --all --strict` if main specs were touched.
- [x] 7.4 Re-run the 42 mm and 46 mm watch screenshots after the final build and verify the block bar, the two counts, and the action button; restore the simulator fixture after any destructive check.

## Workflow follow-up

- Archive the change after review and verification.
