# Tasks

## 1. Prototype

- [x] 1.1 Add the CALENDAR tab and its month grid to `prototype-workout-timer.html`: recorded code with filled set bar, planned code with hollow bar, REST and CLOSED words, today ring, muted adjacent-month days, filter chips, inline month label and the UP NEXT line; verify with `python3 tools/prototype-check.py tools/prototype-driver-calendar.js` that the driver prints each marker it asserts.
- [x] 1.2 Add the day sheet states (planned START, recorded read-only, closed with no action), the WEEK STARTS / REST DAYS / EXCEPTION DATES rows and editors, and the week-start column rotation to the prototype; verify the same driver opens one sheet per state and prints the rotated weekday order.
- [x] 1.3 Add the reorder boundary to the prototype's demo data: a recorded past day, a planned tomorrow, and a drag in SESSIONS that restarts tomorrow at the first session; verify the driver prints the unchanged past cell and the new upcoming codes.

## 2. Calendar model in Shared

- [x] 2.1 Add `CalendarSettings` and `ExceptionRange` to `Shared/` with Codable synthesis, normalised start-of-day ranges, the six-rest-weekday limit, and the device-derived week start (Sunday only when the device starts on Sunday); verify `RestlessTests/CalendarSettingsTests.swift` covers round-trip, refusing a seventh rest day, refusing an end before the start, and the Sunday/Monday default.
- [x] 2.2 Add the training-day predicate (weekday not rest and not inside an exception) and the pure rotation projection `index = training days in [anchor, target) % sessions.count`, with the anchor counting as index 0 on its first training day on or after it; verify `RestlessTests/TrainingRotationTests.swift` covers Chest/Arms/Legs over four days, one session repeating, a rest weekday consuming nothing, and a closure consuming nothing.
- [x] 2.3 Add the next-unstarted boundary (today when it is a training day with no record, else the next training day) and the anchor reset used by a reorder; verify tests cover a reorder restarting at the first session, today changing before its first set, and no plan being drawn before the boundary.
- [x] 2.4 Add a `CalendarSettingsStore` over `UserDefaults` key `restless.calendar.v1`, injected for tests; verify a test writes settings, builds a fresh store and reads the same values, and that a missing document yields the device week start with no rest days or exceptions.
- [x] 2.5 Keep the projection input as ordered ids and names so `Shared/` stays SwiftData-free and `PresetRepository.ordered` remains the one ordering; verify the projection test passes a manually ordered list and that no Shared file imports SwiftData or SwiftUI outside `Theme.swift`.

## 3. History records

- [x] 3.1 Add `WorkoutRecord` to `Restless/Data/` with `runKey` unique, `presetID`, `sessionName`, `blocksData`, `totalSets`, `startedAt`, `startDay`, `lastActivityAt`, `finishedAt`, `doneSets` and `phaseRaw`, and add the entity to the app's `ModelContainer`; verify `RestlessTests/WorkoutHistoryTests.swift` inserts and fetches a record in an in-memory container and that the store opens with `PresetRecord` and `MovementRecord` alongside it.
- [x] 3.2 Add the history store's upsert by `runKey`, gated on `doneSets > 0` or an existing record, updating sets, phase and last activity, setting `finishedAt` once at done and skipping the save when nothing changed; verify tests cover the gate creating nothing, the first set creating exactly one record, later sets reusing it, done finalising once, and a repeat write not duplicating.
- [x] 3.3 Encode the run's `[WorkoutBlock]` snapshot into the record and expose a decoded `WorkoutPreset` for the day sheet; verify a test renames, edits and deletes the source `PresetRecord` and the record still returns the old name, blocks and rests.
- [x] 3.4 Store `startDay` as the local start of day and keep a run on the date it started; verify a test with a 23:50 start and a 00:20 finish finds the record on the start date only.

## 4. Engine recording

- [x] 4.1 Add the `WorkoutHistoryRecording` protocol and an optional recorder to `SessionEngine`, called after persistence in `perform`, `performDeadline`, `refreshFromStore` and the initial restore; verify `RestlessTests/SessionEngineRecorderTests.swift` with a fake recorder covers a completed set, a timed set that expired before launch, and an island action applied while away, with one `runKey` across them.
- [x] 4.2 Construct the history store in `RestlessApp`, inject it as the engine's recorder next to the existing movement-name provider, and keep the recorder optional so previews and tests still build; verify `xcodegen generate` and the test build succeed and a store test shows the engine's recorder receiving the first set.

## 5. Calendar UI

- [x] 5.1 Add `AppTab.calendar` and a third `NavigationStack` tab in `RootView` after SESSIONS, with the timer still the default; verify the app builds and the tab bar reads TIMER, SESSIONS, CALENDAR left to right in the simulator.
- [x] 5.2 Build `CalendarScreen` with the header, ALL and per-session filter chips, the inline month label with previous/next controls, the weekday row following the week start, the grid cells from the design's mark rules, and the UP NEXT line; verify in the simulator at the default and an accessibility text size that seven columns hold, codes truncate, and every cell keeps its 44 pt hit target.
- [x] 5.3 Build the day sheet: a recorded day lists its records read-only with a two-tap delete, a planned day offers START, and START asks first when the engine snapshot has completed sets; a rest or closed day offers no action; verify with an Argent e2e flow that START activates the session and opens TIMER at the gate, and that cancelling the overwrite confirmation changes nothing.
- [x] 5.4 Build the settings editors for WEEK STARTS, REST DAYS and EXCEPTION DATES beneath the grid, reading and writing `CalendarSettingsStore`, refusing a seventh rest day and an end before the start; verify the values survive a relaunch and an edit during a running rest leaves the rest deadline and phase unchanged.
- [x] 5.5 Update `AGENTS.md` for three tabs and the new calendar, day sheet and settings files; verify the tab sentence, the Layout list and the source-of-truth notes match the shipped names.

## 6. Rotation integration

- [x] 6.1 Reset the rotation anchor in `SessionsScreen.persistOrder` after the order saves, reading today's records through the history store, and leave a cancelled drag untouched; verify an Argent drag flow shows Monday's record unchanged while the next unstarted day restarts at the new first session.
- [x] 6.2 Keep the anchor on add, rename, delete and every settings edit, and recalculate upcoming unstarted days from the changed inputs; verify deleting a planned session leaves its records, removes it from upcoming days, and that the last session still offers no enabled delete.
- [x] 6.3 Refresh the grid when the order or the settings change and when the app returns to the foreground, so a record written by the engine appears without a relaunch; verify by completing a set, switching to CALENDAR, and seeing the day's record and set bar.

## 7. Verification

- [x] 7.1 Run `swiftlint lint --quiet --reporter summary` from the repository root and clear the warnings this change introduced.
- [x] 7.2 Run the full suite with `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test` and confirm every test passes, including the new calendar, rotation and history tests.
- [x] 7.3 Walk the record lifecycle on the simulator: a finished run, a paused run, a deadline rest completed in the background and an island SET DONE each leave one accurate record, and START AGAIN then a set creates a second record.
- [x] 7.4 Reopen the existing simulator store with the new build and confirm the session list and the live timer are unchanged, so the added entity is a lightweight schema change.
- [x] 7.5 Run `openspec validate workout-calendar --strict` and fix any spec-shape error before archive.

## Workflow follow-up

- Archive the change once the review requirements are satisfied and the specification deltas are synced.
