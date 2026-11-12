# Tasks

## 1. Prototype

- [x] 1.1 Replace the weekday rest grid in `prototype-workout-timer.html` with the rest gap: a 0–6 value, alternating REST days, and a closed slot that drops its session while the next open day carries the following one. Extend `tools/prototype-driver-calendar.js` and verify with `python3 tools/prototype-check.py tools/prototype-driver-calendar.js` that the driver prints the gap, the REST cells and the dropped-slot codes.
- [x] 1.2 Add the skip mark and the day-sheet actions SKIP, UNSKIP and NEW ROUND to the prototype. Verify the driver prints the hidden plan, the unchanged next day's code, the restored plan after unskip, and the re-phased codes after starting a round on a rest day.
- [x] 1.3 Add the two-mode EXCEPTIONS editor to the prototype: a dated range and a weekday closure in one list, with DATES and WEEKDAY add forms. Verify the driver prints both rows, the duplicate-weekday refusal and a weekday row closing every matching cell.
- [x] 1.4 Remove the WEEK STARTS row and the driver's column-rotation step from the prototype; its demo grid keeps a fixed Monday start. Verify the driver still prints the month and no longer asserts a rotated weekday order.
- [x] 1.5 Add CHANGE, the CHANGED tag and the exercise picker to the prototype: changing Sat 14 to Chest leaves Tue 17 on Legs, and picking the scheduled Arms clears the tag. Verify the driver prints the CHANGED code, the unchanged next code and the cleared tag.
- [x] 1.6 Remove NEW ROUND from a past date and a past record in the prototype; verify the driver prints no new-round action on 5 Nov and still one on a future rest day.

## 2. Settings document

- [x] 2.1 Replace `restWeekdays` with `restDaysBetween` 0...6, clamped by the setter and the sanitizer, and delete `toggleRestDay`, `setRestDays`, `maxRestWeekdays` and `isRestDay`; verify `RestlessTests/CalendarSettingsTests.swift` covers the round trip and clamps at 0 and 6.
- [x] 2.2 Replace `ExceptionRange` with `CalendarException` carrying a dated or weekday kind, keep dated ranges overlapping and refuse an end before the start, refuse a second exception on the same weekday, and prefer a dated range when both cover a date; verify `CalendarSettingsTests` covers each rule and the v2 round trip.
- [x] 2.3 Add `skippedDays` as local start-of-day dates with `isSkipped` and skip/unskip mutations; verify `CalendarSettingsTests` covers normalization, the round trip and that a skipped day does not alter the anchor, the gap or the order.
- [x] 2.4 Move the document to `restless.calendar.v2` and migrate v1 on load: keep the exceptions and anchor, turn each rest weekday into a weekday exception, remove `weekStart`, `firstWeekday`, `setWeekStart`, `deviceWeekStart` and `validWeekStart` from `CalendarSettings`, set the gap to 0 and the skips and changes empty, save v2 and leave v1 untouched; verify `CalendarSettingsTests` decodes a hand-written v1 fixture, ignores its week-start value, and still decodes a v1 build-shaped document, and delete the week-start and device-default cases from the test file.
- [x] 2.5 Confirm `Shared/` stays SwiftData- and SwiftUI-free with the new types; verify `RestlessTests/SharedPurityTests.swift` passes.
- [x] 2.6 Add `DayChange` (local day and preset id) with at most one per day, `change(for:)`, set and clear, and prune changes before today when the document is saved; verify `CalendarSettingsTests` covers replacement, clearing, the prune and the empty change list from a v1 document.

## 3. Rotation

- [x] 3.1 Replace the training-day count with the arithmetic cadence (`slot` from the anchor offset, `index` from the slot number modulo the session count), delete `trainingDayCount`, `isTrainingDay` and `nextTrainingDay`, and add `isSessionSlot`; verify `RestlessTests/TrainingRotationTests.swift` covers four days at gap 0, five days at gap 1, one session repeating, a closed slot dropping its session and a weekday closure recurring.
- [x] 3.2 Add `.skipped` to `TrainingDayMark`, make `mark(for:boundary:)` follow exception → skip → boundary → rest → plan, and make `nextUnstartedDay` skip closed, skipped and recorded slots; verify `TrainingRotationTests` covers the precedence order, no plan or rest word before the boundary, and a skipped slot not being the boundary.
- [x] 3.3 Implement the new-round anchor write: the selected date must be open and today or later, becomes slot 0, clears skips and changes and restarts at the first session; verify `TrainingRotationTests` covers a rest day becoming the first session, a planned day re-phasing the following days, a closed date and a past date refusing the round.
- [x] 3.4 Wire skip and unskip through the rotation so a skipped slot hides its plan and unskip restores it, without moving the next session; verify `TrainingRotationTests` covers the unchanged next day, a persistent skip across a store round trip, and a restored plan after unskip.
- [x] 3.5 Resolve a day change after the slot and index: the chosen preset replaces the plan, the slot still consumes the scheduled session, a deleted preset falls back, and `isChanged` reports a live change; verify `TrainingRotationTests` covers the unchanged next slot, the fallback and the cleared change after a round.

## 4. Settings model and editors

- [x] 4.1 Add `setRestGap`, `addWeekdayException`, `startNewRound(on:today:)` (today or later only, clearing skips and changes), `skip` and `unskip` to `CalendarSettingsModel`, initialize the anchor to today when today is open else the next open day, and keep the reorder on `nextUnstartedDay`; verify a new `RestlessTests/CalendarSettingsModelTests.swift` covers the gap save, the cleared skips and changes after a round, the past-date refusal, skip/unskip persistence and the initialization rule.
- [x] 4.2 Replace `RestDaysEditorScreen` with an inline `−` / value / `+` stepper in the REST DAYS settings row (0–6, 44 pt targets, the line BETWEEN SESSIONS) and delete the rest-days route case; verify in the simulator that the row clamps, no screen opens, and a gap change moves the grid's REST days.
- [x] 4.3 Turn `ExceptionDatesScreen` into `ExceptionsScreen` with one list for dated ranges and weekday closures and a DATES / WEEKDAY add form; verify in the simulator that a weekday row closes every matching cell and that a duplicate weekday is refused with a note.
- [x] 4.4 Update `CalendarCopy` (drop the rest-day summary and the ordered weekdays, rename the exception copy) and the settings screens' copy: the day sheet notes say a closed day skips that session instead of consuming none; verify the copy in the simulator and the existing `CalendarCopy` tests still pass.
- [x] 4.5 Remove WEEK STARTS: delete the row, `WeekStartEditorScreen`, `CalendarRoute.weekStart` and its `RootView` case, and the model's `setWeekStart` and `firstWeekday`; read `Calendar.current.firstWeekday` in `CalendarScreen`. Verify in the simulator that the grid and weekday row follow the device and that the calendar has no week-start row.
- [x] 4.6 Add `setDayChange(day:presetID:)` and `clearDayChange(day:)` to `CalendarSettingsModel`; verify `RestlessTests/CalendarSettingsModelTests.swift` covers the saved change, the clear and its persistence across a fresh model.

## 5. Grid, day sheet and repository docs

- [x] 5.1 Draw the skip word in the month grid and keep filter dimming and the 44 pt cell at an accessibility text size; verify in the simulator at the default and an accessibility size that a skipped day shows the word, carries no session code and still opens its sheet.
- [x] 5.2 Build the Brief day sheet: date, session, summary, START, each block with its rounds, sets and set/round rests, then a footer of outline buttons CHANGE, SKIP and NEW ROUND (stacked at accessibility sizes). CHANGE opens the ordered-session picker; the scheduled row clears the change; a changed date shows the chosen preset with a CHANGED tag. A skipped day keeps the title with a SKIPPED tag and swaps in UNSKIP; a rest day shows the gap and only NEW ROUND; a no-record day shows NEXT and NEW ROUND; a recorded day shows the session with a RECORDED tag, the start time and duration, the snapshot blocks, and moves DELETE RECORD to the footer; a new round is offered only today or later, so a past date and a past record have none; every day without START shows NEXT. Add the block-rest, record-time and picker copy to `CalendarCopy`. Verify with an Argent e2e flow that a change leaves the next code, the picker resets, a skip hides the plan and unskip restores it, a round on a future rest day re-phases the codes, a past date and a past record have no round, and the record card stays read-only.
- [x] 5.3 Update `AGENTS.md` rule 12, the Layout notes and the calendar e2e header sentence for the cadence, the rest gap, the two exception kinds, skips, per-date changes and the today-or-later new round; verify the rule text matches the shipped names, no line still says "rest weekdays", and nothing claims a settable week start.

## 6. Verification

- [x] 6.1 Run `swiftlint lint --quiet --reporter summary` from the repository root and clear the warnings this change introduced.
- [x] 6.2 Run the full suite with `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test` and confirm every test passes, including the new settings, rotation and model tests.
- [x] 6.3 Walk the cadence on the simulator: change the gap during a running rest (the rest deadline and phase do not change), change a planned date's exercise and confirm the next date's code, skip and unskip, start a round on a future rest day, and confirm a past date and a past record offer no round.
- [x] 6.4 Open the store written by the shipped build and confirm the v1 document migrates: the anchor is kept, each rest weekday appears as a weekday closure, the week start is ignored, and the gap is 0.
- [x] 6.5 Run `openspec validate training-cadence --strict` and fix any spec-shape error before archive.

## Workflow follow-up

- Archive the change after the review requirements are satisfied and the `training-calendar` deltas are synced.
