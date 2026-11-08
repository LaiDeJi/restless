# Tasks

## 1. Prototype first

- [x] 1.1 Change the prototype's `newSession()` to keep a draft instead of pushing and saving: `+` opens the session editor, DONE commits and saves the draft, USE THIS SESSION commits and activates it, and back drops it. Verify by adding a session, backing out, confirming the list is unchanged, then adding one, editing its name, tapping DONE, and confirming exactly one card; repeat with USE THIS SESSION and confirm it becomes active.
- [x] 1.2 Add press-and-hold repeat to the prototype steppers: the full chip is the target, a tap steps once, a 500 ms hold repeats every 100 ms, release stops, and the limits still clamp. Verify in the browser with a click, a mouse hold on each direction, and a hold at a rest limit.

## 2. Draft sessions

- [x] 2.1 Add `SessionRoute.newSession(WorkoutPreset)` and map it in `RootView` to the session editor's draft mode; keep `.session(UUID)` for saved sessions and `openActiveSession`. Verify the project builds and the SESSIONS add control reaches the editor through the new route.
- [x] 2.2 Stop inserting in `SessionsScreen.addSession()`: build the draft from the active session's first block with a fresh block id, `Untitled block`, name `New session`, and append the route only. Extract the draft builder so tests can call it; add a Swift Testing case that the draft has a new session id, a new first-block id, the active block's values, and no `PresetRecord` side effect.
- [x] 2.3 Give `SessionEditorScreen` an existing/draft mode and split the commit paths: existing DONE flushes and closes as today; draft DONE calls one `commitDraft()` that normalizes the name, resolves a unique default, inserts exactly one `PresetRecord`, saves, and dismisses; back and swipe-back discard without inserting; USE THIS SESSION commits then activates and shows the timer. Move the unique-name helper out of `SessionsScreen`. Verify with Swift Testing cases for one insert, preserved blocks and name, unique `New session 2`, discard leaves zero records, and USE leaves the active store unchanged until the explicit activation.
- [x] 2.4 Keep draft persistence off: the draft store's `commit` stays nil, `scenePhase` and `onDisappear` only flush existing sessions, and no Live Activity or `engine.use` runs for a draft. Verify with a test that a flushed draft store with no commit leaves the in-memory container empty, and by backgrounding the app on the simulator with an unsaved draft and confirming no card appears.
- [x] 2.5 Hide ACTIVE SESSION, RESTART, and DELETE SESSION for a draft, and keep USE disabled while editing is locked. Verify by opening a draft and reading the footer, then starting a session from TIMER and confirming DONE still saves the draft while USE is disabled.

## 3. Steppers and tap targets

- [x] 3.1 Replace `PlanCountRow.stepButton` and `PlanStepperRow.stepButton` with one full-surface `PlanStepButton`: a single filled 48 × 44 rounded chip with the symbol on top, `.contentShape(Rectangle())` on the Button, and no nested 34 × 30 frame. Add a repeat loop that fires after 500 ms and every 100 ms, cancels on release, lock, disable, and disappearance, and stops at the range bound; make the interval injectable and add Swift Testing cases for first fire, repeat, stop, and limit. Verify a center tap on the block page's ROUNDS/SETS/SET REST/ROUND REST plus and minus with an Argent sequence and confirm each value steps once.
- [x] 3.2 Move the DONE, back, picker DONE/CANCEL, and end-condition segment hit surfaces into full-size styled bodies: the capsule or the whole 44 pt-tall third is the Button's body, with no `contentShape` inside a padded label. Verify with an Argent sequence that taps the center of DONE on the session editor, the center of the picker DONE, and the middle of the TIME segment and each action fires.
- [x] 3.3 Give the steppers directional accessibility labels (`Increase ROUNDS`, `Decrease SETS PER ROUND`, and the rest targets) and expose them as buttons in the accessibility tree. Verify with `describe` on the block page that each plus/minus is an `AXButton` with the row-and-direction label, and that a locked editor's steppers do not change on tap or hold.
- [x] 3.4 Verify a hold produces one save: hold a stepper for two seconds, leave the block editor, return, and confirm the final value persisted once; inspect that the session/Live Activity refresh did not run per repeat.

## 4. Documentation

- [x] 4.1 Update `.agents/skills/restless-rest-timer/SKILL.md`: the new-session default says the draft is unsaved until DONE or USE, back discards, and the default name gets its suffix at save; the editing section says the whole stepper chip is the target, a tap steps once, a 500 ms hold repeats every 100 ms, and DONE is the commit. Verify by reading the skill against `openspec/specs/workout-sessions/spec.md` and `openspec/specs/app-typography/spec.md`.
- [x] 4.2 Check the prototype's copy and the app's copy stay aligned for `New session`, `DONE`, `USE THIS SESSION`, and the new-session editor; verify by walking the prototype and the simulator side by side.

## 5. Integration

- [x] 5.1 Run `xcodegen generate` and the `Restless` build for the iPhone 18 Pro Max simulator; fix any build or SwiftLint issue.
- [x] 5.2 Run the full `xcodebuild test` suite and confirm the new session and stepper tests pass with the existing suites.
- [x] 5.3 Walk one Argent e2e on the simulator: add a draft, back out, confirm the list count; add again, edit the name and one stepper, tap DONE at its visual center, confirm one new card and the edited values; open it, tap USE, confirm it activates; then open a block and tap every stepper center, hold one, and tap DONE/TIME centers.
- [x] 5.4 Run `swiftlint` and confirm no new violations.

## Workflow follow-up

- Archive the change after review and verification are complete, then re-check the archived specs.
