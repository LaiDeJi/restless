# Tasks

## 1. Rule text

- [x] 1.1 Update the session rule in `.agents/skills/restless-rest-timer/SKILL.md` (the "The active session follows the day." bullet): the app activates today's planned session when the current one has no completed sets, is done, **or sits at the gate with completed sets from an earlier local day**; a session whose completed sets are from today is never replaced. Verify with `grep -n "earlier local day" .agents/skills/restless-rest-timer/SKILL.md`.

## 2. Decision logic

- [x] 2.1 In `Shared/ActiveSessionDecision.swift`, extend the `.notStarted`/`.ready` branch of `isReplaceable`: the session is replaceable when `doneSets == 0` or when the local day of the snapshot's `startedAt` is earlier than `today` (`Calendar.startOfDay` comparison). `.done`, `.performing`, `.resting` and `.paused` branches stay as they are. `decide` already receives `today`, `calendar` and the snapshot, so no signature or caller changes. Verify with the new unit tests in 3.1.

## 3. Tests

- [x] 3.1 Add `ActiveSessionDecision` tests with the fixed `TestCalendar`: a `.ready` snapshot with sets done whose `startedAt` is an earlier day decides `.switchTo` for today's plan; the same snapshot with `startedAt` on today decides `.keep`; a `.performing`/`.resting`/`.paused` snapshot from an earlier day still decides `.keep`; a `.done` snapshot from an earlier day still decides `.switchTo`. Verify with `xcodebuild ... test -only-testing:RestlessTests` showing the new cases passing.
- [x] 3.2 Rework `RestlessTests/ActiveSessionFollowerTests.swift`: `completedSetIsNotReplaced` currently performs a set with the real clock and follows on a fixture day, so after the change it would pass for the wrong reason. Drive the engine with `perform(_:at:id:)` at a fixture instant so `startedAt` is controlled, then assert both sides: a partial session started on an earlier day yields to the new day's plan (engine preset switches, snapshot resets to the gate, marker moves to today), and a partial session started today is not replaced. Verify with the same test run.

## 4. Gates

- [x] 4.1 Run the full suite: `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test` reports 0 failures, and `swiftlint lint --quiet --reporter summary` reports nothing new.
- [x] 4.2 End-to-end check on the simulator (manual seeding, same recipe as the repro in this change's investigation): with two sessions in order, terminate the app, write `restless.session.v6` as a `.ready` snapshot with 3 of 9 sets whose `startedAt` and marker are yesterday and the rotation anchor is yesterday, kill the simulator's cfprefsd, cold-launch, and confirm TIMER shows today's planned session at its gate with the ACTIVE badge moved, while the calendar still shows yesterday's record.

## 5. Workflow follow-up

- Archive the change with `openspec archive` only after the user confirms the fix behaves as expected on their phone.
