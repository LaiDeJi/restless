# Tasks

## 1. Move the notification response onto the main actor

- [x] 1.1 In `Restless/Alerts/CountdownAlertScheduler.swift`, replace the async `willPresent`/`didReceive` delegate methods with the completion-handler forms; in `didReceive` post `.countdownAlertOpened` in a main-actor hop and call `completionHandler()` from that same main-actor hop, and suppress the banner from `willPresent`. Verify `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build build` succeeds and `swiftlint lint --quiet --reporter summary` reports no new warning.
- [x] 1.2 Extract the response decision into a non-UI helper that returns "show the timer" for a countdown alert (current prefix or legacy id) and "ignore" for a foreign identifier. Verify a unit test in `RestlessTests/` covers the prefix, the legacy identifier, an unrelated identifier, and that the result carries no `SessionAction`.
- [x] 1.3 Run `xcodebuild -project Restless.xcodeproj -scheme Restless -destination 'platform=iOS Simulator,name=iPhone 18 Pro' -derivedDataPath build test` and confirm all tests pass, including the existing alert-centre and session-transition suites.

## 3. Verify on the physical iPhone

- [x] 3.1 Build and install with `-destination "platform=iOS,id=00008130-001A05810190001C"`, start a session, complete a set, background the app, wait for SET REST OVER, and tap the alert. Verify Restless opens on TIMER at the next set and `xcrun devicectl device info files --device 00008130-001A05810190001C --domain-type systemCrashLogs --subdirectory Retired` shows no new `Restless-*.ips` report after the tap.
- [x] 3.2 With Restless already open on SESSIONS, background it until the alert arrives, then tap it. Verify the app switches to TIMER with the same set count and phase.
- [x] 3.3 Force-quit Restless during a rest, wait for the alert, and tap it. Verify a cold launch reaches the TIMER tab at the next set without aborting.

## 4. Close the planning gate

- [x] 4.1 Run `openspec validate fix-notification-tap-crash --strict` and confirm it passes with the delta against `countdown-alerts`.

## Workflow follow-up

- Archive the change after the device checks pass and the project review requirements are satisfied.
