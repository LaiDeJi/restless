# Proposal

## Why

On a physical iPhone, tapping the rest-finished notification terminates Restless instead of opening the timer. The device crash reports from Nov 9 and Nov 10 (including the report from 21:00 today) all end in `EXC_CRASH` / `SIGABRT` inside `-[UIApplication _updateStateRestorationArchiveForBackgroundEvent:...]`, called from `CountdownNotificationDelegate.userNotificationCenter(_:didReceive:)` on the `com.apple.root.user-initiated-qos.cooperative` queue. The alert is unusable: the user cannot get back to the session from the notification, and the app appears closed.

## What Changes

- Handle a tapped countdown notification on the main actor so UIKit's post-response snapshot and state-restoration work also runs on the main thread.
- Deliver the "open the TIMER tab" signal and complete the notification response only after that main-actor hop.
- Keep the existing alert rules unchanged: one notification per deadline, no alert for a paused or skipped rest, and no second state transition from the tap.
- Add regression coverage for the delegate's routing decision and record a device check that tapping the notification opens Restless at the next set without aborting.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `countdown-alerts`: add the requirement that tapping a completion alert opens Restless on the TIMER tab at the next set and never terminates the app, with scenarios for the app suspended in the background, terminated, and already running.

## Impact

- `Restless/Alerts/CountdownAlertScheduler.swift`: `CountdownNotificationDelegate` and its call into `NotificationCenter` / `RootView`.
- `RestlessTests/`: a test for the notification response routing, if the response handling is extracted into a testable value.
- Verification: physical iPhone 15 Pro Max run of start rest, background, wait for the alert, tap it; no crash report and the timer shows the next set.
- No change to deadlines, the session state machine, persistence, Live Activity content, or alert copy.
