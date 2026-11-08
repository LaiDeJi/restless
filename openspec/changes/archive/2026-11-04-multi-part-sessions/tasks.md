# Tasks

## 1. Prototype and domain rules

- [x] 1.1 Convert `prototype-workout-timer.html` to sessions made of ordered parts: `sessions: [{ id, name, parts: [{ id, name, rounds, setsPerRound, setRest, roundRest }] }]`, a versioned localStorage key, and migration of each old preset into one part. Verify in Safari that an old `rounds.presets.v1` fixture becomes a one-part Chest session and still shows 3 × 3 / 60 / 120.
- [x] 1.2 Add the multi-part rest engine to the prototype: global set index, per-part position, set rest, in-part round rest, the finished part's round rest before the next part, and no rest after the final set. Verify with Biceps 3 × 3 / 60 / 120 then Triceps 2 × 4 / 45 / 90: 17 sets, transition rest after set 9, and 18:00 total rest.
- [x] 1.3 Add the prototype's timer presentation: part strip, `PART n OF m`, active-part set map with the 6 × 12 dot limit and progress-bar fallback, transition copy, and hours in total rest. Verify a 20 × 30 part draws a bar and a two-part session names the finished and next part during the transition rest.
- [x] 1.4 Add the prototype's TIMER / SESSIONS bottom tabs, sessions list, session editor, and part editor, with unlimited rounds and sets, typed values, steppers, two-step deletes, and part move up/down. Verify creating Biceps then Triceps, reordering, deleting, and running the session from the prototype.
- [x] 1.5 Rewrite `.agents/skills/restless-rest-timer/SKILL.md` for parts, transition rest, unbounded rounds and sets, local-first editing, tabs, island attributes, copy, and the test list. Update `AGENTS.md` rules and layout for sessions, parts, tabs, and editing. Verify both documents describe the same rest sequence and limits as the prototype.

## 2. Shared model, rest plan, and presentation copy

- [x] 2.1 Add `WorkoutPart` beside `WorkoutPreset` in `Shared/WorkoutPreset.swift`, change the plan to `parts`, add the default one-part Chest plan, part-aware `position(at:)` and `rest(after:)` with the transition branch, total rest across parts, overflow-safe totals, `durationString`, and `plural`. Keep temporary first-part accessors and the old convenience initializer so existing call sites compile. Verify with the build command in `AGENTS.md`.
- [x] 2.2 Update `Shared/SessionSnapshot.swift` and `Shared/Theme.swift` with `currentPart`, part-aware `position`, transition subtitle (`AFTER BICEPS · NEXT TRICEPS`), done summary with parts and total rest, and the hours formatter. Verify the build and that a one-part Chest session renders the same copy as before.
- [x] 2.3 Rewrite `RestlessTests/RestPlanTests.swift` and `RestlessTests/SessionTests.swift` for parts: the 1080-second two-part total, transition rest, next-part position, degenerate 1 × 1 and one-round/one-set parts, 40 × 25 totals, no rounds/sets cap, and rest clamping only. Verify with `xcodebuild ... test` and all rest-plan and session tests passing.

## 3. Persistence and migration

- [x] 3.1 Add `partsData: Data?` to `PresetRecord`, a computed `parts` with a one-part fallback from the legacy columns, and `apply`/`init` that encode parts and mirror the first part into the legacy columns. Add `PresetRecordTests` for the legacy fallback, JSON round-trip, and order preservation. Verify the tests pass in the in-memory SwiftData container.
- [x] 3.2 Move `SessionStore` to the v2 key, ignore and remove the v1 snapshot, and keep `ActivePresetStore` unchanged. Verify by starting a rest, terminating the app, relaunching, and seeing the same session restored; a v1-only store must start ready at the active session.
- [x] 3.3 Confirm `PresetRepository.seedIfNeeded` seeds the one-part Chest session and preserves the active session id. Verify a fresh install and a store with an existing record both open on Chest and keep that plan active.

## 4. Live Activity

- [x] 4.1 Change `RestlessActivityAttributes` to carry `preset: WorkoutPreset`, keep `ContentState` unchanged, compare the whole preset when restarting, and add the display-only `SessionSnapshot` bridge. Verify the build and that a one-part session produces the same activity as before.
- [x] 4.2 Update `RestlessWidget/RestlessLiveActivity.swift` to use the shared snapshot copy: session name, active part, position, transition context, accent, and compact 3-character part label. Remove the widget's duplicate position/rest maths. Verify the build and the Lock Screen and expanded/compact island on the simulator.
- [x] 4.3 Check that the activity updates only on transitions and that the island's set-done, pause, resume, skip, and restart links still apply through the app. Verify a full two-part rest from the island, including the transition rest and the final done state.

## 5. Tab shell, sessions screens, and responsive editing

- [x] 5.1 Add `AppRouter` and `RootView` with a styled native `TabView` for TIMER and SESSIONS, move scene-phase reconciliation and `onOpenURL` to the root, and make the timer's EDIT open the active session. Verify tab switching during a rest leaves the countdown running and an island link returns to TIMER.
- [x] 5.2 Add `SessionDraftStore` with immediate local edits, a 350 ms debounced commit, `flush` on dismissal, Done, and background, and an injectable delay. Wire the commit to `record.apply`, `context.save`, and `engine.use` only for the active session. Add `SessionDraftStoreTests` proving several rapid edits produce one commit and `flush` commits immediately.
- [x] 5.3 Build `SessionsScreen` and `SessionEditorScreen`: session cards with active badge, create, rename with 18-character trimmed names and the `Untitled` fallback, parts list with shape and rests, add part, move up/down, two-step part and session deletes, use session, restart warning, and the read-only state during rest. Verify create/edit/reorder/delete/activate manually and that the active session marks correctly.
- [x] 5.4 Build `PartEditorScreen`: name with the 18-character trimmed `Untitled part` fallback, unlimited rounds and sets with steppers plus tap-to-type numeric entry, rests with 15–600 steps, part summary, delete action, and 44 pt stepper hit areas. Verify rapid SET REST taps never lag, typing 120 sets works, 0 clamps to 1, and the last part has no delete action.
- [x] 5.5 Update `TimerScreen` and `SetMap` for multiple parts: part strip hidden for one part, auto-scroll to the active part, active-part map at 6 × 12 or less, progress-bar fallback above that, and a layout that fits above the tab bar on a 6.1-inch and a 6.9-inch simulator. Verify with a two-part session and a 20 × 30 part.
- [x] 5.6 Delete `SetupSheet.swift` and all sheet wiring, and verify the build has no references to it and the timer still opens the editor through the sessions tab.
- [x] 5.7 Verify the edit lock end to end: start a rest, switch to SESSIONS, confirm all edit/add/delete/reorder/activate controls are disabled and the banner is visible, wait or skip the rest, and confirm editing unlocks without losing the rest.

## 6. Cleanup and integration

- [x] 6.1 Remove the temporary first-part accessors and old single-part initializer from `WorkoutPreset`, update every remaining caller, and verify the full test suite still passes.
- [x] 6.2 Run the full commands from `AGENTS.md`: `xcodegen generate`, the iOS simulator test run, and the watchOS build. Fix any shared-model compile issue in the watch target.
- [x] 6.3 Run the integration checklist on the simulator: old-style preset migration, two-part session, transition rest, 120 sets, 20 × 30 map, tab switch during rest, background and relaunch restore, island transition copy, and done summary.
- [x] 6.4 Validate the planning artifacts with `openspec validate --change multi-part-sessions --strict` and confirm the prototype, skill, and code agree on the rest sequence and limits.

## Workflow follow-up

- Archive the change after the implementation and review are complete.
- Verify the archived specs and the updated skill describe the same final behaviour.
